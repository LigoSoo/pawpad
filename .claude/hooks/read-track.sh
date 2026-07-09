#!/bin/bash
# PostToolUse(Read|Grep|Glob) - retrieval 계측 (read-track.ps1 bash 포트). 관측 전용(항상 exit 0).
raw="$(cat)"
tool="$(printf '%s' "$raw" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
target="$(printf '%s' "$raw" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$target" ] && target="$(printf '%s' "$raw" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
# path 없는 검색은 tool별 경로형 필드로 폴백 (v2.43 B4): Glob의 pattern은 경로 glob,
# Grep의 glob은 경로 필터. Grep의 pattern은 내용 regex라 경로가 아니므로 제외.
if [ -z "$target" ] && [ "$tool" = "Glob" ]; then
  target="$(printf '%s' "$raw" | sed -n 's/.*"pattern"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi
if [ -z "$target" ] && [ "$tool" = "Grep" ]; then
  target="$(printf '%s' "$raw" | sed -n 's/.*"glob"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi
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
