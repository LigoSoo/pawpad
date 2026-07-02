#!/usr/bin/env bash
# SessionStart hook - INDEX 라우터 주입 + session state reset + codemap 토글 (session-start.ps1 bash 포트).
# bash는 기본 UTF-8. CRLF면 shebang 깨지므로 이 파일은 반드시 LF.
raw="$(cat)"
sid="$(printf '%s' "$raw" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$sid" ] && sid="manual"
mkdir -p ".ctxdb/.state"
printf 'session:%s\nturn:0\n' "$sid" > ".ctxdb/.state/turn-count"
printf '%s\n' "$sid" > ".ctxdb/.state/claude-loaded"
: > ".ctxdb/.state/claude-read-stats"

cm=".claude/codemap/_index.md"
idx=".ctxdb/INDEX.md"
# codemap inject 토글 (pawpad-config.json: auto/on/off, auto=INDEX 심볼>=threshold)
mode="auto"; threshold=60
cfg=".claude/pawpad-config.json"
if [ -f "$cfg" ]; then
  m="$(sed -n 's/.*"inject"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$cfg" | head -1)"
  [ -n "$m" ] && mode="$m"
  t="$(sed -n 's/.*"largeRepoSymbolThreshold"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$cfg" | head -1)"
  [ -n "$t" ] && threshold="$t"
fi
inject=0
if [ "$mode" = "on" ]; then inject=1
elif [ "$mode" = "off" ]; then inject=0
elif [ -f "$cm" ]; then
  count="$(awk '/^# INDEX/{f=1;next} /^# /{f=0} f && NF && $0 !~ /^[[:space:]]*<!--/{c++} END{print c+0}' "$cm")"
  [ "$count" -ge "$threshold" ] && inject=1
fi

emitted=0
if [ "$inject" -eq 1 ] && [ -f "$cm" ]; then
  echo "=== codemap (symbol registry / HOT) ==="
  head -n 40 "$cm"
  emitted=1
else
  echo "=== codemap: inject skipped (소형 repo / off). 필요 시 .claude/codemap/_index.md 직접 read 또는 pawpad-config.json codemap.inject=on ==="
  emitted=1
fi
if [ -f "$idx" ]; then
  echo ""
  echo "=== .ctxdb INDEX (keyword -> L1/L2 router) ==="
  head -n 50 "$idx"
  emitted=1
fi
if [ "$emitted" -eq 1 ]; then
  echo ""
  echo "[load rule] UserPromptSubmit hook이 prompt keyword로 L1<=1 / L2<=2 자동 최소로드(세션 dedupe). 추가 read는 매칭 항목만. 전체 로드 금지."
fi
exit 0
