#!/usr/bin/env bash
# Stop hook - 루프가드 후 8턴 정기저장 / L2 분할규칙 / lane-close 백스톱 시 decision:block (stop-check.ps1 bash 포트).
raw="$(cat)"
# block 재진입 가드. 즉시 exit 아님 — 교정 응답의 Retrieval 선언 파싱/계측은 수행하고 판정·turn 증가만 생략.
hookActive=0
case "$raw" in
  *'"stop_hook_active": true'*|*'"stop_hook_active":true'*) hookActive=1 ;;
esac
sid="$(printf '%s' "$raw" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$sid" ] && sid="manual"

stateDir=".ctxdb/.state"
mkdir -p "$stateDir"

# read-track(PostToolUse) 실측 델타: 직전 stop 이후 이번 턴에 쌓인 kind만 집계 (watermark 방식).
# session-start가 read-stats를 비우므로 mark에 session을 묶어 stale mark를 0으로 처리.
rsPath="$stateDir/claude-read-stats"
mkPath="$stateDir/claude-read-mark"
total=0
if [ -f "$rsPath" ]; then total="$(wc -l < "$rsPath" 2>/dev/null | tr -d ' ')"; fi
[ -z "$total" ] && total=0
mark=0
if [ -f "$mkPath" ]; then
  ms="$(sed -n 's/^session:\(.*\)$/\1/p' "$mkPath" | head -1)"
  mr="$(sed -n 's/^read:\([0-9]*\)$/\1/p' "$mkPath" | head -1)"
  if [ "$ms" = "$sid" ] && [ -n "$mr" ]; then mark="$mr"; fi
fi
[ "$mark" -gt "$total" ] && mark=0   # 외부 truncate 방어
srcDelta=0; cmapDelta=0
if [ "$total" -gt "$mark" ] && [ -f "$rsPath" ]; then
  d="$(tail -n +$((mark + 1)) "$rsPath" 2>/dev/null)"
  srcDelta="$(printf '%s\n' "$d" | grep -c '^src$' || true)"
  cmapDelta="$(printf '%s\n' "$d" | grep -c '^cmap$' || true)"
fi
printf 'session:%s\nread:%s\n' "$sid" "$total" > "$mkPath"

# retrieval hit/miss 계측 (stop-check.ps1 파리티): 방금 완료된 assistant 응답의 '📡 Retrieval:' 선언 파싱.
# 미사용 턴은 미기록(hit율 분모 제외). uuid dedupe로 재계수 방지. jq 없으면 graceful skip.
if command -v jq >/dev/null 2>&1; then
  tp="$(printf '%s' "$raw" | jq -r '.transcript_path // empty' 2>/dev/null)"
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    # transcript는 응답을 text/thinking/tool_use 별개 엔트리로 기록 -> 마지막 assistant가 tool_use/thinking면 text 없음.
    # 유효 Retrieval 선언을 담은 가장 최근 assistant text 엔트리를 찾음(마지막 엔트리만 보면 놓침).
    # 앵커 필수: 'Retrieval:'/'codemap'을 라인 어디서나 찾으면 훅 자신을 논하는 산문이 선언으로 오탐돼 지표가 거짓이 된다.
    # 선두 앵커(선택적 📡) + 백틱/중괄호 라인(인용·예시) 배제.
    # -rs(엄격 slurp)는 window에 깨진 JSON 한 줄만 있어도 전체 실패(동시 append 중 tail이 미완성 줄 잡는 케이스) -> 라인 관용 fromjson?로 해당 줄만 skip.
    res="$(tail -n 60 "$tp" 2>/dev/null | jq -rRn '
      [ inputs | fromjson? // empty
        | select(.message.role=="assistant")
        | { uuid, line: ([ .message.content[]? | select(.type=="text") | .text ] | join("\n")
              | split("\n")[] | select(test("^\\s*(📡\\s*)?Retrieval:\\s*codemap\\s") and (test("[{`]")|not))) }
        | select(.line != null) ]
      | last | if . == null then "" else (.uuid + "\t" + .line) end' 2>/dev/null)"
    uuid="${res%%$'\t'*}"; rline="${res#*$'\t'}"
    seenP="$stateDir/claude-retrieval-seen"; seen=""; [ -f "$seenP" ] && seen="$(cat "$seenP" 2>/dev/null)"
    if [ -n "$uuid" ] && [ "$uuid" != "$seen" ] && [ -n "$rline" ]; then
      # 고정 순서 codemap | ctxdb | src 로 위치 분해 (greedy sed는 마지막 'codemap'=src의 "(codemap 경유)" 매칭→cmap 누락).
      # 구조 검증(3세그먼트 + 각 세그먼트 키워드)까지 통과해야 선언으로 인정 — 앵커만으론 부분 인용이 샌다.
      nseg="$(printf '%s' "$rline" | awk -F'|' '{print NF}')"
      cseg="$(printf '%s' "$rline" | awk -F'|' '{print $1}')"
      xseg="$(printf '%s' "$rline" | awk -F'|' '{print $2}')"
      sseg="$(printf '%s' "$rline" | awk -F'|' '{print $3}')"
      case "$xseg" in *ctxdb*) okx=1 ;; *) okx=0 ;; esac
      case "$sseg" in *src*) oks=1 ;; *) oks=0 ;; esac
      if [ "${nseg:-0}" -ge 3 ] && [ "$okx" -eq 1 ] && [ "$oks" -eq 1 ]; then
        case "$cseg" in *hit*) printf 'cmap:hit\n' >> "$stateDir/claude-retrieval-stats" ;; *miss*) printf 'cmap:miss\n' >> "$stateDir/claude-retrieval-stats" ;; esac
        case "$xseg" in *hit*) printf 'ctx:hit\n' >> "$stateDir/claude-retrieval-stats" ;; *miss*) printf 'ctx:miss\n' >> "$stateDir/claude-retrieval-stats" ;; esac
        printf '%s' "$uuid" > "$seenP"
        # codemap을 hit/miss로 선언한 경우에만 백스톱 면제. '미사용' 선언은 면제 아님 ->
        # src를 여러 개 읽고 '미사용'이라 적는 허위 선언이 조용히 통과하던 구멍(분모 제외)을 막는다.
        case "$cseg" in *hit*|*miss*) freshDecl=1 ;; esac
      fi
    fi
    # 가장 최근 assistant text 엔트리 (thinking/tool_use skip). lane-close + retrieval 백스톱 공용.
    res2="$(tail -n 60 "$tp" 2>/dev/null | jq -rRn '
      [ inputs | fromjson? // empty
        | select(.message.role=="assistant")
        | { uuid, txt: ([ .message.content[]? | select(.type=="text") | .text ] | join(" ")) }
        | select(.txt != "") ]
      | last | if . == null then "" else (.uuid + "\t" + (.txt | gsub("[\t\n]";" "))) end' 2>/dev/null)"
    u2="${res2%%$'\t'*}"; t2="${res2#*$'\t'}"

    laneClose=0
    if [ "$hookActive" -eq 0 ]; then
      # lane-close 백스톱 (v2.43): 마지막 assistant 응답이 완료/종료 선언인데 _wip Active Lanes 잔존 -> task-done 리마인더 1회 (uuid dedupe).
      wip=".claude/pawpad/_wip.md"
      if [ -f "$wip" ]; then
        # 오탐 감쇄 2종: ①헤더 앵커($) — '## Active Lanes 필드 명세' 섹션이 f를 재점화하지 않도록
        #                ②stock _wip.md는 Active Lanes 섹션 안에 예시 블록('- feature-a:' 등)을 둔다 -> 예시 라인에서 절단
        lanes="$(awk '/^## Active Lanes[[:space:]]*$/{f=1;next} /^## /{f=0} /^[[:space:]]*(예시|[Ee]xample)/{f=0} f' "$wip" | grep -c '^[[:space:]]*- ' 2>/dev/null || true)"
        if [ "${lanes:-0}" -gt 0 ]; then
          # 스킬명 'task-done' 언급 자체는 완료 선언 아님 -> 제거 후 매칭 (오탐 감쇄).
          t2s="$(printf '%s' "$t2" | sed 's/task-done//g')"
          if [ -n "$u2" ] && printf '%s' "$t2s" | grep -qE '(작업|이슈|태스크|task|lane).{0,30}(완료|종료|마무리|done)'; then
            tdP="$stateDir/claude-taskdone-warned"; tdSeen=""
            [ -f "$tdP" ] && tdSeen="$(cat "$tdP" 2>/dev/null)"
            if [ "$u2" != "$tdSeen" ]; then
              printf '%s' "$u2" > "$tdP"
              laneClose=1
            fi
          fi
        fi
      fi
      # retrieval 백스톱 (v2.43): hit율은 선언 기반이라 선언을 빼먹으면 조용히 0이 된다. read-track 실측과 대조해
      # "codemap lookup 0 + src 직접읽기 2건 이상 + codemap hit/miss 선언 없음(누락 또는 '미사용')" = 미선언 full-scan으로
      # 보고 리마인더 1회 (uuid dedupe). src 1건은 면제 (이미 아는 파일 재편집 — CLAUDE.md가 라인 생략을 허용하는 케이스).
      if [ "${freshDecl:-0}" -eq 0 ] && [ "${srcDelta:-0}" -ge 2 ] && [ "${cmapDelta:-0}" -eq 0 ] && [ -n "$u2" ]; then
        # 세션당 최대 2회 하드캡. uuid dedupe는 "같은 응답 재경고"만 막고, 매 턴 새 uuid로 block이
        # 재발행되는 교착은 못 막는다 (block 1회 = 전체 응답 재생성 -> 수십 분 정지로 나타남).
        rwP="$stateDir/claude-retrieval-warned"; rwSession=""; rwSeen=""; rwCount=0
        if [ -f "$rwP" ]; then
          rwSession="$(sed -n '1p' "$rwP" 2>/dev/null)"
          rwSeen="$(sed -n '2p' "$rwP" 2>/dev/null)"
          rwCount="$(sed -n '3p' "$rwP" 2>/dev/null)"
          case "$rwCount" in ''|*[!0-9]*) rwCount=0 ;; esac
          # legacy 1줄 포맷(uuid만): 1행을 uuid로 해석
          if [ -z "$rwSeen" ]; then rwSeen="$rwSession"; rwSession=""; fi
        fi
        [ "$rwSession" != "$sessionId" ] && rwCount=0
        if [ "$u2" != "$rwSeen" ] && [ "$rwCount" -lt 2 ]; then
          printf '%s\n%s\n%s\n' "$sessionId" "$u2" "$((rwCount + 1))" > "$rwP"
          retrMiss="$srcDelta"
        fi
      fi
    fi
  fi
fi

[ "$hookActive" -eq 1 ] && exit 0   # 재진입: 계측/watermark는 위에서 끝냈고, block 재발행과 turn 증가는 생략 -> 루프 방지

tcPath="$stateDir/turn-count"
turn=0
if [ -f "$tcPath" ]; then
  s="$(sed -n 's/^session:\(.*\)$/\1/p' "$tcPath" | head -1)"
  t="$(sed -n 's/^turn:\([0-9]*\)$/\1/p' "$tcPath" | head -1)"
  if [ "$s" = "$sid" ] && [ -n "$t" ]; then turn="$t"
  else
    legacy="$(tr -d '[:space:]' < "$tcPath" 2>/dev/null)"
    case "$legacy" in ''|*[!0-9]*) turn=0 ;; *) turn="$legacy" ;; esac
  fi
fi
turn=$((turn + 1))
printf 'session:%s\nturn:%s\n' "$sid" "$turn" > "$tcPath"

# PreCompact 중복 가드: 최근 8턴 내 compaction 저장 유도 있었으면 checkpoint 생략
lastCompact=-1
if [ -f "$stateDir/last-compact" ]; then
  lc="$(sed -n 's/^turn:\([0-9]*\)$/\1/p' "$stateDir/last-compact" | head -1)"
  [ -n "$lc" ] && lastCompact="$lc"
fi

# L2 분할 규칙 (150줄 또는 ~2000토큰 초과). bash 정수라 토큰 추정은 chars/4.
oversized="$(find ".ctxdb/L2" -name '*.md' -type f 2>/dev/null | while IFS= read -r f; do
  lines="$(wc -l < "$f" 2>/dev/null | tr -d ' ')"
  chars="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  [ -z "$lines" ] && lines=0
  [ -z "$chars" ] && chars=0
  tok=$((chars / 4))
  if [ "$lines" -gt 150 ] || [ "$tok" -gt 2000 ]; then
    printf ' %s(%sL/~%stok)' "$(basename "$f")" "$lines" "$tok"
  fi
done)"

needCheckpoint=0
if [ $((turn % 8)) -eq 0 ] && [ "$lastCompact" -le $((turn - 8)) ]; then needCheckpoint=1; fi

needSplit=0
if [ -n "$oversized" ]; then
  sig="$sid|$oversized"
  warn="$stateDir/claude-oversize-warned"
  last=""
  [ -f "$warn" ] && last="$(cat "$warn" 2>/dev/null)"
  if [ "$last" = "$sig" ]; then needSplit=0; else printf '%s' "$sig" > "$warn"; needSplit=1; fi
fi

parts=""
if [ "$needCheckpoint" -eq 1 ]; then
  parts="[checkpoint $turn turns] Update .claude/codemap/_index.md for new/changed symbols + refresh lane/_wip.md (on done: move to wip/done + _meta.md + git commit) + run context-saver to write .ctxdb/L2 and update INDEX.md AGENT SYNC."
fi
if [ "$needSplit" -eq 1 ]; then
  parts="$parts [L2 split needed]$oversized : exceeds 150 lines / 2000 tokens -> keyword load still pulls the whole file, defeating token savings. Split old entries into .ctxdb/L3/{name}-YYYY-MM.md or split by domain, then update INDEX/L1 pointers."
fi
if [ "${laneClose:-0}" -eq 1 ]; then
  parts="$parts [lane-close] The last response declares task completion but active lane(s) remain in .claude/pawpad/_wip.md. If the task is truly done, run the task-done skill now (full closure: lane -> wip/done move + _wip removal + _meta RECENT + tasklog + codemap + git commit). If not done, ignore this and continue."
fi
if [ -n "${retrMiss:-}" ]; then
  parts="$parts [retrieval] read-track measured $retrMiss source reads this turn with zero .claude/codemap lookup and no codemap hit/miss declaration (line missing, or declared '미사용'). codemap lookup must precede source search. Grep .claude/codemap/_index.md for the symbol; if it is genuinely a miss, emit the Retrieval line declaring full-scan with the reason."
fi
if [ -z "$parts" ]; then
  exit 0
fi
if [ "${laneClose:-0}" -eq 1 ]; then
  reason="$parts If closing, execute task-done fully before stopping; otherwise report one line, then stop."
elif [ -n "${retrMiss:-}" ]; then
  reason="$parts Emit the missing Retrieval line (one line, honest hit/miss), then stop."
else
  reason="$parts Report one line, then stop."
fi
printf '{"decision": "block", "reason": "%s"}\n' "$reason"
exit 0
