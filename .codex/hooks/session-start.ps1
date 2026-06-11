$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Json {
    param([hashtable]$Payload)
    $Payload | ConvertTo-Json -Depth 6 -Compress
}

function Find-PawpadRoot {
    $dir = (Get-Location).Path
    while ($dir) {
        if ((Test-Path (Join-Path $dir ".ctxdb/INDEX.md")) -and
            (Test-Path (Join-Path $dir ".claude/pawpad/_wip.md"))) {
            return $dir
        }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
    $event = $null
    if ($raw.Trim()) { $event = $raw | ConvertFrom-Json }
    $sessionId = if ($event -and $event.session_id) { [string]$event.session_id } else { "manual" }
    $root = Find-PawpadRoot
    if (-not $root) {
        Write-Json @{}
        exit 0
    }

    $stateDir = Join-Path $root ".ctxdb/.state"
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
    Set-Content -Path (Join-Path $stateDir "codex-turn-count") -Value @("session:$sessionId", "turn:0") -Encoding UTF8
    Set-Content -Path (Join-Path $stateDir "codex-loaded") -Value @($sessionId) -Encoding UTF8
    Write-Json @{}
} catch {
    Write-Json @{}
}
