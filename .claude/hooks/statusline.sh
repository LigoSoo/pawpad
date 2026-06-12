#!/usr/bin/env bash
# statusLine - 컨텍스트 윈도우 사용량(%) 표시 (statusline.ps1 bash 포트). JSON 파싱에 jq 사용.
# 1순위: stdin JSON의 context_window 필드 (Claude Code v2.1.132+, 모델별 실제 한도 + /context 동일 계산).
# 2순위(구버전 폴백): transcript JSONL 마지막 usage + model.id 기반 한도 테이블.
raw="$(cat)"
if ! command -v jq >/dev/null 2>&1; then printf 'ctx n/a (jq 필요)'; exit 0; fi
model="$(printf '%s' "$raw" | jq -r '.model.display_name // empty' 2>/dev/null)"
limit=0
used=0
cw_size="$(printf '%s' "$raw" | jq -r '.context_window.context_window_size // 0' 2>/dev/null)"
case "$cw_size" in (''|*[!0-9]*) cw_size=0 ;; esac
if [ "$cw_size" -gt 0 ]; then
  # 공식 필드: context_window_size = 모델별 실제 한도. used = input+cache_read+cache_creation (null이면 total_input_tokens 폴백).
  limit=$cw_size
  used="$(printf '%s' "$raw" | jq -r 'if .context_window.current_usage and .context_window.current_usage.input_tokens != null then ((.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0)) else (.context_window.total_input_tokens // 0) end' 2>/dev/null)"
else
  # 구버전 Claude Code 폴백: transcript 마지막 usage
  tp="$(printf '%s' "$raw" | jq -r '.transcript_path // empty' 2>/dev/null)"
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    used="$(tail -n 80 "$tp" 2>/dev/null | jq -rs '[ .[] | select(.message.usage.input_tokens != null) ] | last | if . then ((.message.usage.input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0)) else 0 end' 2>/dev/null)"
  fi
  # model.id 기반 한도: Fable/Mythos/Opus 4.6+/1M 컨텍스트 변형 = 1M, 그 외 기본 200k.
  mid="$(printf '%s' "$raw" | jq -r '.model.id // empty' 2>/dev/null)"
  case "$mid" in
    *fable*|*mythos*|*'[1m]'*|*opus-4-6*|*opus-4-7*|*opus-4-8*|*opus-4-9*) limit=1000000 ;;
    *) limit=200000 ;;
  esac
fi
case "$used" in (''|*[!0-9]*) used=0 ;; esac
# 안전망: 1M 세션 신호(exceeds_200k_tokens) 또는 실측 200k 초과 시 1M 보정.
exceeds="$(printf '%s' "$raw" | jq -r '.exceeds_200k_tokens // false' 2>/dev/null)"
if [ "$limit" -lt 1000000 ]; then
  if [ "$exceeds" = "true" ] || [ "$used" -gt 200000 ]; then limit=1000000; fi
fi
pct=$(( used * 100 / limit ))
usedk=$(( used / 1000 ))
if [ "$limit" -ge 1000000 ]; then limitlabel="$(( limit / 1000000 ))M"; else limitlabel="$(( limit / 1000 ))k"; fi
out="ctx ${pct}% (${usedk}k/${limitlabel})"
[ -n "$model" ] && out="$out | $model"
printf '%s' "$out"
