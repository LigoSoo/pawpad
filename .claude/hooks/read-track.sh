#!/bin/bash
# PostToolUse(Read|Grep|Glob) - retrieval 계측 (read-track.ps1 bash 포트). 관측 전용(항상 exit 0).
raw="$(cat)"
target="$(printf '%s' "$raw" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$target" ] && target="$(printf '%s' "$raw" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
# 경계 정규화: 앞뒤 / 부착 → 디렉토리 자체 경로(트레일링 / 없음)·유사 이름(myproject.claude) 오분류 방지
target="/$target/"
case "$target" in
  *"/.claude/codemap/"*) kind=cmap ;;
  *"/.ctxdb/"*) kind=ctx ;;
  *"/.claude/"*|*"/.agents/"*|*"/.codex/"*) exit 0 ;;
  *) kind=src ;;
esac
mkdir -p ".ctxdb/.state"
echo "$kind" >> ".ctxdb/.state/claude-read-stats"
exit 0
