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

function Get-SessionId {
    param($Event)
    if ($Event -and $Event.session_id) { return [string]$Event.session_id }
    return "manual"
}

function Get-TurnState {
    param([string]$Path, [string]$SessionId)
    if (-not (Test-Path $Path)) { return 0 }
    $lines = Get-Content -Path $Path -Encoding UTF8
    if ($lines.Count -ge 2 -and $lines[0] -like "session:*") {
        $storedSession = $lines[0].Substring(8)
        $storedTurn = $lines[1] -replace "^turn:", ""
        if ($storedSession -eq $SessionId -and $storedTurn -match "^\d+$") {
            return [int]$storedTurn
        }
        return 0
    }
    $legacy = ($lines -join "").Trim()
    if ($legacy -match "^\d+$") { return [int]$legacy }
    return 0
}

function Save-TurnState {
    param([string]$Path, [string]$SessionId, [int]$Turn)
    Set-Content -Path $Path -Value @("session:$SessionId", "turn:$Turn") -Encoding UTF8
}

try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
    $event = $null
    if ($raw.Trim()) { $event = $raw | ConvertFrom-Json }

    if ($event.stop_hook_active -eq $true) {
        Write-Json @{}
        exit 0
    }

    $root = Find-PawpadRoot
    if (-not $root) {
        Write-Json @{}
        exit 0
    }

    $stateDir = Join-Path $root ".ctxdb/.state"
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
    $turnPath = Join-Path $stateDir "codex-turn-count"
    $sessionId = Get-SessionId $event
    $turn = Get-TurnState $turnPath $sessionId
    $turn += 1
    Save-TurnState $turnPath $sessionId $turn

    $oversized = New-Object System.Collections.Generic.List[string]
    $l2Dir = Join-Path $root ".ctxdb/L2"
    if (Test-Path $l2Dir) {
        Get-ChildItem -Path $l2Dir -Filter "*.md" -File | ForEach-Object {
            $text = Get-Content -Path $_.FullName -Encoding UTF8 -Raw
            $lineCount = if ($text.Length -eq 0) { 0 } else { ([regex]::Matches($text, "`n").Count + 1) }
            $approxTokens = [math]::Ceiling($text.Length / 3.5)
            if ($lineCount -gt 150 -or $approxTokens -gt 2000) {
                $oversized.Add(($_.FullName.Substring($root.Length + 1)).Replace("\", "/"))
            }
        }
    }

    $cmOver = New-Object System.Collections.Generic.List[string]
    $cmDir = Join-Path $root ".claude/codemap"
    if (Test-Path $cmDir) {
        $cmRoot = (Resolve-Path $cmDir).Path
        Get-ChildItem -Path $cmDir -Filter "*.md" -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $rel = $_.FullName.Substring($cmRoot.Length + 1).Replace("\", "/")
            $cap = if ($rel -eq "_root.md") { 2048 } elseif ($rel -eq "_index.md") { 30720 } else { 4096 }
            if ($_.Length -gt $cap) { $cmOver.Add(("{0}({1}B/{2})" -f $rel, $_.Length, $cap)) }
        }
    }
    # PreCompact 중복 가드: 최근 8턴 내 compaction 저장 유도 있었으면 checkpoint 생략
    $lastCompactTurn = -1
    $lcPath = Join-Path $stateDir "codex-last-compact"
    if (Test-Path $lcPath) {
        $lc = Get-Content -Path $lcPath -Encoding UTF8
        if ($lc.Count -ge 2 -and $lc[1] -match "^turn:(\d+)$") { $lastCompactTurn = [int]$Matches[1] }
    }

    $needsCheckpoint = ($turn % 8 -eq 0) -and -not ($lastCompactTurn -gt ($turn - 8))
    $needsSplit = ($oversized.Count -gt 0)
    if ($needsSplit) {
        $splitSig = $sessionId + "|" + ($oversized -join "|")
        $splitWarnPath = Join-Path $stateDir "codex-oversize-warned"
        $lastSig = ""
        if (Test-Path $splitWarnPath) {
            $lastSig = (Get-Content -Path $splitWarnPath -Encoding UTF8 -Raw).Trim()
        }
        if ($lastSig -eq $splitSig) {
            $needsSplit = $false
        } else {
            Set-Content -Path $splitWarnPath -Value $splitSig -Encoding UTF8
        }
    }

    $needsCmap = ($cmOver.Count -gt 0)
    if ($needsCmap) {
        $cmSig = $sessionId + "|" + ($cmOver -join "|")
        $cmWarnPath = Join-Path $stateDir "codex-codemap-warned"
        $cmLast = ""
        if (Test-Path $cmWarnPath) { $cmLast = (Get-Content -Path $cmWarnPath -Encoding UTF8 -Raw).Trim() }
        if ($cmLast -eq $cmSig) { $needsCmap = $false } else { Set-Content -Path $cmWarnPath -Value $cmSig -Encoding UTF8 }
    }
    if ($needsCheckpoint -or $needsSplit -or $needsCmap) {
        $reasonParts = New-Object System.Collections.Generic.List[string]
        if ($needsCheckpoint) {
            $reasonParts.Add("Codex checkpoint: $turn turns reached. Run context-saver: append current session summary to .ctxdb/L2, update .ctxdb/INDEX.md Codex row, refresh lane/_wip.md, and update codemap for new symbols.")
        }
        if ($needsSplit) {
            $reasonParts.Add("L2 split needed: " + ($oversized -join ", ") + " exceeds 150 lines or 2000 tokens. Split old entries or route via L1/L3 before continuing.")
        }
        if ($needsCmap) {
            $reasonParts.Add("codemap split needed: " + ($cmOver -join ", ") + " exceeds codemap size cap (_root.md 2KB / _index.md 30KB / others 4KB). Phase B leaves are read whole on lookup. Split into .claude/codemap/features/{id}/{subtopic}.md and keep the original as a routing stub; if _index.md is over, switch to Phase B. Rule: codemap SKILL size cap.")
        }
        Write-Json @{
            decision = "block"
            reason = ($reasonParts -join " ")
        }
        exit 0
    }

    Write-Json @{}
} catch {
    Write-Json @{}
}
