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
# retrieval 계측 표시 (read-track hook 누적: cmap/ctx/src. 세션 시작 시 reset)
# 색상: 라우팅 활성=초록, 소스직행(src만)=노랑. route%=(cmap+ctx)/total. hit%=Retrieval 선언 hit/miss율(stop-check 파싱).
E=$(printf '\033'); G="${E}[32m"; Y="${E}[33m"; R="${E}[31m"; D="${E}[90m"; Z="${E}[0m"
sf=".ctxdb/.state/claude-read-stats"
if [ -f "$sf" ]; then
  cmapn="$(grep -c '^cmap$' "$sf" 2>/dev/null)"; ctxn="$(grep -c '^ctx$' "$sf" 2>/dev/null)"; srcn="$(grep -c '^src$' "$sf" 2>/dev/null)"
  case "$cmapn" in (''|*[!0-9]*) cmapn=0 ;; esac
  case "$ctxn" in (''|*[!0-9]*) ctxn=0 ;; esac
  case "$srcn" in (''|*[!0-9]*) srcn=0 ;; esac
  tot=$(( cmapn + ctxn + srcn ))
  if [ "$tot" -gt 0 ]; then
    routed=$(( cmapn + ctxn ))
    if [ "$routed" -gt 0 ]; then tcol="$G"; else tcol="$Y"; fi
    out="$out | 📡 ${tcol}cmap ${cmapn} ctx ${ctxn} src ${srcn}${Z}"
    route=$(( (routed * 100 + tot / 2) / tot ))
    if [ "$route" -ge 50 ]; then rcol="$G"; elif [ "$route" -ge 25 ]; then rcol="$Y"; else rcol="$R"; fi
    out="$out ${D}route${Z} ${rcol}${route}%${Z}"
  fi
fi
# hit율 (stop-check가 응답 '📡 Retrieval:' 선언의 codemap/ctxdb hit|miss 누적). 미사용 턴은 분모 제외.
rf=".ctxdb/.state/claude-retrieval-stats"
if [ -f "$rf" ]; then
  ch="$(grep -c '^cmap:hit$' "$rf" 2>/dev/null)"; cm="$(grep -c '^cmap:miss$' "$rf" 2>/dev/null)"
  xh="$(grep -c '^ctx:hit$' "$rf" 2>/dev/null)"; xm="$(grep -c '^ctx:miss$' "$rf" 2>/dev/null)"
  for v in ch cm xh xm; do eval "case \"\$$v\" in (''|*[!0-9]*) $v=0 ;; esac"; done
  hit=""
  cden=$(( ch + cm ))
  if [ "$cden" -gt 0 ]; then r=$(( (ch * 100 + cden / 2) / cden )); if [ "$r" -ge 70 ]; then c="$G"; elif [ "$r" -ge 40 ]; then c="$Y"; else c="$R"; fi; hit="c ${c}${r}%${Z}(${ch}/${cden})"; fi
  xden=$(( xh + xm ))
  if [ "$xden" -gt 0 ]; then r=$(( (xh * 100 + xden / 2) / xden )); if [ "$r" -ge 70 ]; then c="$G"; elif [ "$r" -ge 40 ]; then c="$Y"; else c="$R"; fi; if [ -n "$hit" ]; then hit="$hit "; fi; hit="${hit}x ${c}${r}%${Z}(${xh}/${xden})"; fi
  if [ -n "$hit" ]; then out="$out ${D}hit${Z} $hit"; fi
fi
printf '%s' "$out"
