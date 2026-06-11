# PreCompact hook (Claude Code) - native compaction 직전 context-saver 유도 + 중복 가드 기록.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$sessionId = "manual"
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
    if ($raw.Trim()) { $ev = $raw | ConvertFrom-Json; if ($ev.session_id) { $sessionId = [string]$ev.session_id } }
} catch {}

$stateDir = ".ctxdb/.state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

$turn = 0
$tcPath = Join-Path $stateDir "turn-count"
if (Test-Path $tcPath) {
    $lines = Get-Content -Path $tcPath -Encoding UTF8
    if ($lines.Count -ge 2 -and $lines[1] -match "^turn:(\d+)$") { $turn = [int]$Matches[1] }
    elseif (($lines -join "").Trim() -match "^\d+$") { $turn = [int](($lines -join "").Trim()) }
}
Set-Content -Path (Join-Path $stateDir "last-compact") -Value @("session:$sessionId", "turn:$turn") -Encoding ascii

"=== PawPad PreCompact ===`nnative compaction 직전. context-saver 절차로 현재 세션 요약을 .ctxdb/L2에 저장하고 INDEX.md AGENT SYNC + lane/_wip.md + codemap을 먼저 갱신하라. (Stop 8턴 checkpoint는 이번 주기 중복 생략됨)"
exit 0
