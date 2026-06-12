# statusLine - 현재 세션 컨텍스트 윈도우 사용량(%) 표시.
# 1순위: stdin JSON의 context_window 필드 (Claude Code v2.1.132+, 모델별 실제 한도 + /context 동일 계산).
# 2순위(구버전 폴백): transcript JSONL 마지막 usage + model.id 기반 한도 테이블.
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# stdin은 UTF-8. 콘솔 코드페이지(CP949 등)에 의존하는 [Console]::In 대신 raw 바이트를 UTF-8로 디코딩
# (Korean username 등 non-ASCII transcript_path가 깨져 JSON 파싱 실패하던 버그 방지).
$raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
try { $j = $raw | ConvertFrom-Json } catch { return }
$model = $j.model.display_name
$used = 0
$limit = 0
$cw = $j.context_window
if ($cw -and [long]$cw.context_window_size -gt 0) {
    # 공식 필드: context_window_size = 모델별 실제 한도(200k/1M). used = input+cache_read+cache_creation.
    $limit = [long]$cw.context_window_size
    $cu = $cw.current_usage
    if ($cu -and $null -ne $cu.input_tokens) {
        $used = [long]$cu.input_tokens + [long]$cu.cache_read_input_tokens + [long]$cu.cache_creation_input_tokens
    } elseif ($null -ne $cw.total_input_tokens) {
        # current_usage는 첫 API 호출 전/compact 직후 null
        $used = [long]$cw.total_input_tokens
    }
} else {
    # 구버전 Claude Code 폴백: transcript 마지막 usage
    $tp = $j.transcript_path
    if ($tp -and (Test-Path -LiteralPath $tp)) {
        $lines = @(Get-Content -LiteralPath $tp -Tail 80 -ErrorAction SilentlyContinue)
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            try { $o = $lines[$i] | ConvertFrom-Json } catch { continue }
            $u = $o.message.usage
            if ($u -and $null -ne $u.input_tokens) {
                $used = [long]$u.input_tokens + [long]$u.cache_read_input_tokens + [long]$u.cache_creation_input_tokens
                break
            }
        }
    }
    # model.id 기반 한도: Fable/Mythos/Opus 4.6+/1M 컨텍스트 변형 = 1M, 그 외 기본 200k.
    $mid = [string]$j.model.id
    if ($mid -match 'fable|mythos' -or $mid -match '\[1m\]' -or $mid -match 'opus-4-[6-9]') { $limit = 1000000 }
    else { $limit = 200000 }
    # 안전망: 1M 세션 신호(exceeds_200k_tokens) 또는 실측 200k 초과 시 1M 보정.
    if ($j.exceeds_200k_tokens -or $used -gt 200000) { $limit = 1000000 }
}
$pct = if ($limit -gt 0) { [math]::Round($used * 100.0 / $limit) } else { 0 }
$usedK = [math]::Round($used / 1000.0)
if ($limit -ge 1000000) {
    $m = [math]::Round($limit / 1000000.0, 1)
    $limitLabel = if ($m -eq [math]::Floor($m)) { "$([int]$m)M" } else { "${m}M" }
} else {
    $limitLabel = "$([math]::Round($limit / 1000.0))k"
}
$out = "ctx $pct% (${usedK}k/$limitLabel)"
if ($model) { $out += " | $model" }
Write-Output $out
