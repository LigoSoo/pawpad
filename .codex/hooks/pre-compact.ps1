$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# PreCompact hook (Codex) - native compaction 직전 context-saver 유도 + 중복 가드 기록.
# 저장 시점(turn)을 .ctxdb/.state/codex-last-compact에 기록해 Stop 8턴 checkpoint 중복 발화 방지.

function Find-PawpadRoot {
    $dir = (Get-Location).Path
    while ($dir) {
        if ((Test-Path (Join-Path $dir ".ctxdb/INDEX.md")) -and
            (Test-Path (Join-Path $dir ".claude/pawpad/_wip.md"))) { return $dir }
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
    if (-not $root) { "{}"; exit 0 }

    $stateDir = Join-Path $root ".ctxdb/.state"
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

    $turn = 0
    $tcPath = Join-Path $stateDir "codex-turn-count"
    if (Test-Path $tcPath) {
        $lines = Get-Content -Path $tcPath -Encoding UTF8
        if ($lines.Count -ge 2 -and $lines[1] -match "^turn:(\d+)$") { $turn = [int]$Matches[1] }
    }
    Set-Content -Path (Join-Path $stateDir "codex-last-compact") -Value @("session:$sessionId", "turn:$turn") -Encoding ascii

    $msg = "=== PawPad PreCompact === native compaction 직전. context-saver 절차로 현재 세션 요약을 .ctxdb/L2에 저장하고 INDEX.md AGENT SYNC + lane/_wip.md + codemap을 먼저 갱신하라. (Stop 8턴 checkpoint는 이번 주기 중복 생략됨)"
    # suppressOutput: parsed-but-not-yet-implemented (openai/codex#16933). 구현 시 전문 숨김+1줄 표시. 선반영.
    @{
        hookSpecificOutput = @{ hookEventName = "PreCompact"; additionalContext = $msg }
        suppressOutput = $true
        systemMessage = "PawPad PreCompact: context-saver reminder injected"
    } | ConvertTo-Json -Depth 6 -Compress
} catch {
    "{}"
}
