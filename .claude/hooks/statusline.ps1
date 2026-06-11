# statusLine - 현재 세션 컨텍스트 윈도우 사용량(%) 표시.
# transcript JSONL의 마지막 usage(input + cache_read + cache_creation 토큰)를 컨텍스트 크기로 사용. limit=200k.
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
try { $j = $raw | ConvertFrom-Json } catch { return }
$tp = $j.transcript_path
$model = $j.model.display_name
$limit = 200000
$used = 0
if ($tp -and (Test-Path -LiteralPath $tp)) {
    $lines = @(Get-Content -LiteralPath $tp -Tail 80 -ErrorAction SilentlyContinue)
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        try { $o = $lines[$i] | ConvertFrom-Json } catch { continue }
        $u = $o.message.usage
        if ($u -and $null -ne $u.input_tokens) {
            $used = [int]$u.input_tokens + [int]$u.cache_read_input_tokens + [int]$u.cache_creation_input_tokens
            break
        }
    }
}
# 컨텍스트 한도: 기본 200k. exceeds_200k_tokens(1M 컨텍스트 세션)이거나 used가 200k 초과면 1M로 보정.
if ($j.exceeds_200k_tokens -or $used -gt 200000) { $limit = 1000000 }
$pct = if ($limit -gt 0) { [math]::Round($used * 100.0 / $limit) } else { 0 }
$usedK = [math]::Round($used / 1000.0)
$limitLabel = if ($limit -ge 1000000) { '1M' } else { "$([math]::Round($limit / 1000.0))k" }
$out = "ctx $pct% (${usedK}k/$limitLabel)"
if ($model) { $out += " | $model" }
Write-Output $out
