#!/usr/bin/env bash
# Stop hook - 루프가드 후 8턴 정기저장 또는 L2 분할규칙 위반 시 decision:block (stop-check.ps1 bash 포트).
raw="$(cat)"
case "$raw" in
  *'"stop_hook_active": true'*|*'"stop_hook_active":true'*) exit 0 ;;
esac
sid="$(printf '%s' "$raw" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$sid" ] && sid="manual"

stateDir=".ctxdb/.state"
mkdir -p "$stateDir"

# retrieval hit/miss 계측 (stop-check.ps1 파리티): 방금 완료된 assistant 응답의 '📡 Retrieval:' 선언 파싱.
# 미사용 턴은 미기록(hit율 분모 제외). uuid dedupe로 재계수 방지. jq 없으면 graceful skip.
if command -v jq >/dev/null 2>&1; then
  tp="$(printf '%s' "$raw" | jq -r '.transcript_path // empty' 2>/dev/null)"
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    # transcript는 응답을 text/thinking/tool_use 별개 엔트리로 기록 -> 마지막 assistant가 tool_use/thinking면 text 없음.
    # 유효 Retrieval 선언('{}' 예시 제외)을 담은 가장 최근 assistant text 엔트리를 찾음(마지막 엔트리만 보면 놓침).
    res="$(tail -n 60 "$tp" 2>/dev/null | jq -rs '
      [ .[] | select(.message.role=="assistant")
        | { uuid, line: ([ .message.content[]? | select(.type=="text") | .text ] | join("\n")
              | split("\n")[] | select(test("Retrieval:") and test("codemap") and (test("[{]")|not))) }
        | select(.line != null) ]
      | last | if . == null then "" else (.uuid + "\t" + .line) end' 2>/dev/null)"
    uuid="${res%%$'\t'*}"; rline="${res#*$'\t'}"
    seenP="$stateDir/claude-retrieval-seen"; seen=""; [ -f "$seenP" ] && seen="$(cat "$seenP" 2>/dev/null)"
    if [ -n "$uuid" ] && [ "$uuid" != "$seen" ] && [ -n "$rline" ]; then
      # 고정 순서 codemap | ctxdb | src 로 위치 분해 (greedy sed는 마지막 'codemap'=src의 "(codemap 경유)" 매칭→cmap 누락).
      cseg="$(printf '%s' "$rline" | awk -F'|' '{print $1}')"
      xseg="$(printf '%s' "$rline" | awk -F'|' '{print $2}')"
      case "$cseg" in *hit*) printf 'cmap:hit\n' >> "$stateDir/claude-retrieval-stats" ;; *miss*) printf 'cmap:miss\n' >> "$stateDir/claude-retrieval-stats" ;; esac
      case "$xseg" in *hit*) printf 'ctx:hit\n' >> "$stateDir/claude-retrieval-stats" ;; *miss*) printf 'ctx:miss\n' >> "$stateDir/claude-retrieval-stats" ;; esac
      printf '%s' "$uuid" > "$seenP"
    fi
  fi
fi

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
if [ -z "$parts" ]; then
  exit 0
fi
reason="$parts Report one line, then stop."
printf '{"decision": "block", "reason": "%s"}\n' "$reason"
exit 0
