#!/usr/bin/env bash
# statusLine - 컨텍스트 윈도우 사용량(%) 표시 (statusline.ps1 bash 포트). JSON 파싱에 jq 사용.
raw="$(cat)"
if ! command -v jq >/dev/null 2>&1; then printf 'ctx n/a (jq 필요)'; exit 0; fi
tp="$(printf '%s' "$raw" | jq -r '.transcript_path // empty' 2>/dev/null)"
model="$(printf '%s' "$raw" | jq -r '.model.display_name // empty' 2>/dev/null)"
limit=200000
used=0
if [ -n "$tp" ] && [ -f "$tp" ]; then
  used="$(tail -n 80 "$tp" 2>/dev/null | jq -rs '[ .[] | select(.message.usage.input_tokens != null) ] | last | if . then ((.message.usage.input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0)) else 0 end' 2>/dev/null)"
fi
case "$used" in (''|*[!0-9]*) used=0 ;; esac
exceeds="$(printf '%s' "$raw" | jq -r '.exceeds_200k_tokens // false' 2>/dev/null)"
if [ "$exceeds" = "true" ] || [ "$used" -gt 200000 ]; then limit=1000000; fi
pct=$(( used * 100 / limit ))
usedk=$(( used / 1000 ))
if [ "$limit" -ge 1000000 ]; then limitlabel="1M"; else limitlabel="$(( limit / 1000 ))k"; fi
out="ctx ${pct}% (${usedk}k/${limitlabel})"
[ -n "$model" ] && out="$out | $model"
printf '%s' "$out"
