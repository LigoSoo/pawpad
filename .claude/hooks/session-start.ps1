# SessionStart hook - codemap + .ctxdb INDEX 라우터를 세션 시작 시 주입 + 세션 state reset.
# 목적: INDEX 라우터(작은 파일)는 항상 주입, codemap은 토글(대형 repo opt-in)에 따라 주입.
#       세션별 turn-count / claude-loaded(ctxdb dedupe) state를 reset (keyword 최소로드는 UserPromptSubmit hook 담당).
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$sessionId = "manual"
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
    if ($raw.Trim()) {
        $ev = $raw | ConvertFrom-Json
        if ($ev.session_id) { $sessionId = [string]$ev.session_id }
    }
} catch {}
$stateDir = ".ctxdb/.state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
Set-Content -Path (Join-Path $stateDir "turn-count") -Value @("session:$sessionId", "turn:0") -Encoding ascii
Set-Content -Path (Join-Path $stateDir "claude-loaded") -Value @($sessionId) -Encoding UTF8
Set-Content -Path (Join-Path $stateDir "claude-read-stats") -Value @() -Encoding ascii

function Test-CodemapInject {
    $cfg = ".claude/pawpad-config.json"
    $mode = "auto"; $threshold = 60
    if (Test-Path $cfg) {
        try {
            $j = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.codemap.inject) { $mode = [string]$j.codemap.inject }
            if ($j.codemap.largeRepoSymbolThreshold) { $threshold = [int]$j.codemap.largeRepoSymbolThreshold }
        } catch {}
    }
    if ($mode -eq "off") { return $false }
    if ($mode -eq "on") { return $true }
    $cm = ".claude/codemap/_index.md"
    if (-not (Test-Path $cm)) { return $false }
    $inIndex = $false; $count = 0
    foreach ($line in (Get-Content $cm -Encoding UTF8)) {
        if ($line -match "^# INDEX") { $inIndex = $true; continue }
        if ($line -match "^# ") { $inIndex = $false; continue }
        if ($inIndex -and $line.Trim() -and -not $line.Trim().StartsWith("<!--")) { $count++ }
    }
    return ($count -ge $threshold)
}

$out = @()
if (Test-CodemapInject) {
    $cm = ".claude/codemap/_index.md"
    if (Test-Path $cm) {
        $out += "=== codemap (symbol registry / HOT) ==="
        $out += (Get-Content $cm -TotalCount 40 -Encoding UTF8)
    }
} else {
    $out += "=== codemap: inject skipped (소형 repo / off). 필요 시 .claude/codemap/_index.md 직접 read 또는 pawpad-config.json codemap.inject=on ==="
}
$idx = ".ctxdb/INDEX.md"
if (Test-Path $idx) {
    $out += ""
    $out += "=== .ctxdb INDEX (keyword -> L1/L2 router) ==="
    $out += (Get-Content $idx -TotalCount 50 -Encoding UTF8)
}
if ($out.Count -gt 0) {
    $out += ""
    $out += "[load rule] UserPromptSubmit hook이 prompt keyword로 L1<=1 / L2<=2 자동 최소로드(세션 dedupe). 추가 read는 매칭 항목만. 전체 로드 금지."
    $out -join "`n"
}
exit 0
