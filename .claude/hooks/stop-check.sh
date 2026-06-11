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
