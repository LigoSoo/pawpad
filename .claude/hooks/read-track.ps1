# PostToolUse(Read|Grep|Glob) - retrieval 계측. 분류: cmap / ctx / src. 관측 전용(항상 exit 0).
$ErrorActionPreference = 'SilentlyContinue'
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
    if (-not $raw.Trim()) { exit 0 }
    $ev = $raw | ConvertFrom-Json
    $ti = $ev.tool_input
    $tn = if ($ev.tool_name) { [string]$ev.tool_name } else { '' }
    $target = ''
    if ($ti) {
        if ($ti.file_path) { $target = [string]$ti.file_path }
        elseif ($ti.path) { $target = [string]$ti.path }
        # path 없는 검색은 tool별 경로형 필드로 폴백 (v2.43 B4): Glob의 pattern은 경로 glob,
        # Grep의 glob은 경로 필터. Grep의 pattern은 내용 regex라 경로가 아니므로 제외.
        elseif ($tn -eq 'Glob' -and $ti.pattern) { $target = [string]$ti.pattern }
        elseif ($tn -eq 'Grep' -and $ti.glob) { $target = [string]$ti.glob }
    }
    $target = $target -replace '\\', '/'
    $kind = 'src'
    if ($target -match '(^|/)\.claude/codemap(/|$)') { $kind = 'cmap' }
    elseif ($target -match '(^|/)\.ctxdb(/|$)') { $kind = 'ctx' }
    elseif ($target -match '(^|/)(\.claude|\.agents|\.codex)(/|$)') { exit 0 }
    $stateDir = ".ctxdb/.state"
    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    Add-Content -Path (Join-Path $stateDir "claude-read-stats") -Value $kind -Encoding ascii
} catch {}
exit 0
