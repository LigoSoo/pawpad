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
# retrieval routing 표시: codemap 경유율(선언 기반) 주지표 + src 직접읽기 볼륨(백스톱).
# codemap N% = routed/(routed+full-scan). 선언 0 + src>0 = 미선언 직접읽기 → src 노랑. ctx N%은 샘플 있을 때만.
E=$(printf '\033'); G="${E}[32m"; Y="${E}[33m"; R="${E}[31m"; D="${E}[90m"; Z="${E}[0m"
ch=0; cm=0; cd=0; xh=0; xm=0
rf=".ctxdb/.state/claude-retrieval-stats"
if [ -f "$rf" ]; then
  ch="$(grep -c '^cmap:hit$' "$rf" 2>/dev/null)"; cm="$(grep -c '^cmap:miss$' "$rf" 2>/dev/null)"
  cd="$(grep -c '^cmap:direct$' "$rf" 2>/dev/null)"
  xh="$(grep -c '^ctx:hit$' "$rf" 2>/dev/null)"; xm="$(grep -c '^ctx:miss$' "$rf" 2>/dev/null)"
fi
srcn=0
sf=".ctxdb/.state/claude-read-stats"
if [ -f "$sf" ]; then srcn="$(grep -c '^src$' "$sf" 2>/dev/null)"; fi
for v in ch cm cd xh xm srcn; do eval "case \"\$$v\" in (''|*[!0-9]*) $v=0 ;; esac"; done
# 응답 단위 통일 (v2.44 사후수정#2): 분모 = hit 선언(경유) + miss 선언 + 미선언 풀스캔(cmap:direct).
# 활용률 = 경유 / 전체 탐색 응답. 분모 3 미만은 소표본 스윙 방지로 % 숨김.
fsn=$(( cm + cd ))
cden=$(( ch + fsn ))
if [ $(( cden + srcn )) -gt 0 ]; then
  if [ "$cden" -ge 3 ]; then
    rate=$(( (ch * 100 + cden / 2) / cden ))
    if [ "$rate" -ge 70 ]; then rcol="$G"; elif [ "$rate" -ge 40 ]; then rcol="$Y"; else rcol="$R"; fi
    seg="${D}codemap${Z} ${rcol}활용 ${rate}%${Z} ${D}(경유 ${ch} · 직행 ${fsn})${Z}"
  elif [ "$cden" -gt 0 ]; then
    seg="${D}codemap${Z} 경유 ${ch} ${D}·${Z} 직행 ${fsn}"
  else
    seg="${D}codemap –${Z}"
  fi
  if [ "$srcn" -gt 0 ]; then
    seg="$seg ${D}·${Z} ${D}소스 읽기 ${srcn}${Z}"
  fi
  xden=$(( xh + xm ))
  if [ "$xden" -gt 0 ]; then
    xrate=$(( (xh * 100 + xden / 2) / xden ))
    if [ "$xrate" -ge 70 ]; then xcol="$G"; elif [ "$xrate" -ge 40 ]; then xcol="$Y"; else xcol="$R"; fi
    seg="$seg ${D}· ctx${Z} ${xcol}${xrate}%${Z}"
  fi
  out="$out | 📡 $seg"
fi
# cache 모드 (opt-in: env PAWPAD_CACHE_STATUS=1|on|true). statusline.ps1 cache 블록 포트 — 규칙 동일.
# R=이번 응답 cache_read, W=이번 응답 cache_creation, TTL=최근 쓰기의 ephemeral_1h/5m 판별(없으면 5m 가정).
# 남은 시간 = 마지막 응답 시각 + TTL - 지금 (읽기도 TTL 재충전). 서버 조기 축출은 감지 불가 -> 추정값.
# reset = 직전 응답 대비 read 급감 + write 급증 (prefix 변경/모델 전환/TTL 만료 등으로 캐시 깨짐).
case "${PAWPAD_CACHE_STATUS:-}" in
  1|on|true)
    cseg="${D}cache -${Z}"
    tp="$(printf '%s' "$raw" | jq -r '.transcript_path // empty' 2>/dev/null)"
    if [ -n "$tp" ] && [ -f "$tp" ]; then
      # 같은 message.id가 content block마다 반복 기록됨 -> 1건으로 합침
      cinfo="$(tail -n 200 "$tp" 2>/dev/null | jq -rRs '
        [ split("\n")[] | fromjson? | select(.type == "assistant" and .message.usage != null) ]
        | reduce .[] as $o ([]; if length > 0 and $o.message.id != null and .[-1].message.id == $o.message.id then .[:-1] + [$o] else . + [$o] end)
        | map({ r: (.message.usage.cache_read_input_tokens // 0), w: (.message.usage.cache_creation_input_tokens // 0),
                h: (.message.usage.cache_creation.ephemeral_1h_input_tokens // 0), m: (.message.usage.cache_creation.ephemeral_5m_input_tokens // 0),
                t: ((.timestamp // "") | sub("\\.[0-9]+"; "") | (fromdateiso8601? // 0)) })
        | if length == 0 then empty else
            .[-1] as $c
            | (if length > 1 then .[-2] else {r: 0, w: 0} end) as $p
            | ([.[] | select(.h > 0 or .m > 0)] | last) as $k
            | (if $k != null and $k.h > 0 then 3600 else 300 end) as $ttl
            | "\($c.r) \($c.w) \($ttl) \($c.t) \($p.r) \($p.w) \(length)"
          end' 2>/dev/null)"
      set -- $cinfo
      if [ "$#" -eq 7 ]; then
        cr=$1; cw=$2; ttl=$3; ct=$4; pr=$5; pw=$6; cn=$7
        if [ $(( cr + cw )) -gt 0 ]; then
          kf() { if [ "$1" -lt 1000 ]; then printf '%s' "$1"; else printf '%sk' $(( ($1 + 500) / 1000 )); fi; }
          if [ "$ttl" -ge 3600 ]; then tl=1h; else tl=5m; fi
          cseg="${D}cache${Z} R $(kf "$cr") ${D}·${Z} W $(kf "$cw")${D}(${tl})${Z}"
          if [ "$cn" -gt 1 ] && [ "$cw" -ge 1024 ] && [ $(( cr * 2 )) -lt "$pr" ] && [ $(( cw * 2 )) -gt $(( pr + pw )) ]; then
            cseg="$cseg ${R}💥reset${Z}"
          fi
          if [ "$ct" -gt 0 ]; then
            rem=$(( ct + ttl - $(date +%s) ))
            if [ "$rem" -le 0 ]; then
              cseg="$cseg ${D}·${Z} ${R}⏳ expired${Z}"
            else
              if [ $(( rem * 100 )) -ge $(( ttl * 25 )) ]; then tcol="$G"; elif [ $(( rem * 100 )) -ge $(( ttl * 10 )) ]; then tcol="$Y"; else tcol="$R"; fi
              cseg="$cseg ${D}·${Z} ${tcol}⏳ $(printf '%02d:%02d' $(( rem / 60 )) $(( rem % 60 )))${Z}"
            fi
          fi
        fi
      fi
    fi
    out="$out | $cseg"
    ;;
esac
printf '%s' "$out"
