$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# UserPromptSubmit hook (Claude Code) - prompt keyword로 .ctxdb L1<=1/L2<=2 최소 로드 + 세션 dedupe.
# Codex .codex/hooks/ctxdb-inject.ps1과 동일 전략. 상태파일은 claude-loaded 사용.

function Write-HookContext {
    param([string]$Context)
    @{ hookSpecificOutput = @{ hookEventName = "UserPromptSubmit"; additionalContext = $Context } } |
        ConvertTo-Json -Depth 6 -Compress
}
function Write-EmptyHook { "{}" }

function Find-PawpadRoot {
    $dir = (Get-Location).Path
    while ($dir) {
        if ((Test-Path (Join-Path $dir ".ctxdb/INDEX.md")) -and
            (Test-Path (Join-Path $dir ".claude/codemap/_index.md"))) { return $dir }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return (Get-Location).Path
}

function Get-SessionId { param($Event)
    if ($Event -and $Event.session_id) { return [string]$Event.session_id }
    return "manual"
}

function Get-LoadedRefs { param([string]$Root, [string]$SessionId)
    $path = Join-Path $Root ".ctxdb/.state/claude-loaded"
    if (-not (Test-Path $path)) { return @() }
    $lines = Get-Content -Path $path -Encoding UTF8
    if ($lines.Count -eq 0 -or $lines[0] -ne $SessionId) { return @() }
    if ($lines.Count -eq 1) { return @() }
    return $lines | Select-Object -Skip 1
}
function Save-LoadedRefs { param([string]$Root, [string]$SessionId, [string[]]$Refs)
    $stateDir = Join-Path $Root ".ctxdb/.state"
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
    $unique = @($Refs | Where-Object { $_ } | Select-Object -Unique)
    Set-Content -Path (Join-Path $stateDir "claude-loaded") -Value (@($SessionId) + $unique) -Encoding UTF8
}

function Get-TextLines { param([string]$Path, [int]$MaxLines = 150, [switch]$Tail)
    if (-not (Test-Path $Path)) { return @() }
    $lines = Get-Content -Path $Path -Encoding UTF8
    if ($lines.Count -le $MaxLines) { return $lines }
    if ($Tail) { return $lines | Select-Object -Last $MaxLines }
    return $lines | Select-Object -First $MaxLines
}

function Get-PromptTokens { param([string]$Prompt)
    if (-not $Prompt) { return @() }
    $stopwords = @{ "and"=$true;"for"=$true;"the"=$true;"this"=$true;"that"=$true;
        "with"=$true;"from"=$true;"into"=$true;"about"=$true;"please"=$true;"file"=$true }
    return ($Prompt.ToLowerInvariant() -split "[^\p{L}\p{Nd}_:-]+") |
        Where-Object { $_.Length -ge 3 -and -not $stopwords.ContainsKey($_) } | Select-Object -Unique
}

function Test-ExplicitContextPrompt { param([string]$Prompt)
    $p = $Prompt.ToLowerInvariant()
    # 재개 의도어만. 프로젝트/에이전트명·일반어는 일반 프롬프트 과발화 -> stale L2 오주입 (2026-06-11 finding)
    foreach ($needle in @("ctxdb","context-saver","resume","handoff","save context","이어서","재개","핸드오프","지난 세션","세션저장","세션 저장","컨텍스트 로드")) {
        if ($p.Contains($needle)) { return $true }
    }
    return $false
}

function Get-AgentSyncSummary { param([string[]]$IndexLines)
    $sync = @()
    foreach ($line in $IndexLines) {
        if ($line -match "^\|\s*(Claude Code|Codex)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|") { $sync += ($line.Trim()) }
    }
    return $sync
}

function Find-L1Match { param([string[]]$IndexLines, [string[]]$PromptTokens)
    $promptSet = @{}; foreach ($t in $PromptTokens) { $promptSet[$t] = $true }
    foreach ($line in $IndexLines) {
        if ($line -notmatch "^\|\s*\d+\s*\|\s*([^|]+)\|\s*(L1/[^|]+)\|") { continue }
        $keywordsCell = $Matches[1].Trim(); $l1Path = $Matches[2].Trim()
        if ($l1Path -match "domain-sample" -or $keywordsCell -match "AUTH") { continue }
        $keywords = ($keywordsCell -split "[,\s/|]+") |
            ForEach-Object { $_.Trim("()[]{} `t`r`n").ToLowerInvariant() } | Where-Object { $_.Length -ge 3 }
        foreach ($keyword in $keywords) {
            if ($promptSet.ContainsKey($keyword)) { return @{ Keywords = $keywordsCell; L1 = $l1Path } }
        }
    }
    return $null
}

function Get-L2Refs { param([string[]]$Lines)
    $refs = New-Object System.Collections.Generic.List[string]
    foreach ($line in $Lines) {
        foreach ($match in [regex]::Matches($line, "(?:\.ctxdb/)?(L2/[A-Za-z0-9_.\-/]+\.md)")) {
            $ref = $match.Groups[1].Value.Replace("\", "/")
            if (-not $refs.Contains($ref)) { $refs.Add($ref) }
            if ($refs.Count -ge 2) { return $refs.ToArray() }
        }
    }
    return $refs.ToArray()
}

function Test-CodemapInject { param([string]$Root)
    $cfg = Join-Path $Root ".claude/pawpad-config.json"
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
    $cm = Join-Path $Root ".claude/codemap/_index.md"
    if (-not (Test-Path $cm)) { return $false }
    $inIndex = $false; $count = 0
    foreach ($line in (Get-Content $cm -Encoding UTF8)) {
        if ($line -match "^# INDEX") { $inIndex = $true; continue }
        if ($line -match "^# ") { $inIndex = $false; continue }
        if ($inIndex -and $line.Trim() -and -not $line.Trim().StartsWith("<!--")) { $count++ }
    }
    return ($count -ge $threshold)
}

function Get-CodemapContext { param([string]$Root, [string[]]$Tokens, [bool]$IncludeHot = $false)
    if (-not (Test-CodemapInject $Root)) { return @() }
    $path = Join-Path $Root ".claude/codemap/_index.md"
    if (-not (Test-Path $path)) { return @() }
    $lines = Get-Content -Path $path -Encoding UTF8
    $hot = New-Object System.Collections.Generic.List[string]
    $codemapMatches = New-Object System.Collections.Generic.List[string]
    $section = ""
    foreach ($line in $lines) {
        if ($line -match "^# HOT") { $section = "HOT"; continue }
        if ($line -match "^# INDEX") { $section = "INDEX"; continue }
        if ($line -match "^# ") { $section = ""; continue }
        if ($section -eq "HOT" -and $line.Trim() -and -not $line.Trim().StartsWith("(")) { $hot.Add($line); continue }
        if ($section -eq "INDEX" -and $line.Trim() -and -not $line.Trim().StartsWith("(")) {
            $symbol = ((($line.Trim()) -split "\s+")[0]).ToLowerInvariant()
            $symbolParts = $symbol -split "[:_.\-/]+"
            foreach ($token in $Tokens) {
                if ($token -eq $symbol -or ($symbolParts -contains $token)) { $codemapMatches.Add($line); break }
            }
        }
    }
    $outList = New-Object System.Collections.Generic.List[string]
    if ($IncludeHot -and $hot.Count -gt 0) {
        $outList.Add("--- codemap HOT ---"); $hot | Select-Object -First 5 | ForEach-Object { $outList.Add($_) }
    }
    if ($codemapMatches.Count -gt 0) {
        $outList.Add("--- codemap keyword matches ---"); $codemapMatches | Select-Object -First 8 | ForEach-Object { $outList.Add($_) }
    }
    return $outList.ToArray()
}

try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
    $event = $null
    if ($raw.Trim()) { $event = $raw | ConvertFrom-Json }
    $prompt = [string]$event.prompt
    $root = Find-PawpadRoot
    $sessionId = Get-SessionId $event
    $project = Split-Path $root -Leaf
    $indexPath = Join-Path $root ".ctxdb/INDEX.md"
    if (-not (Test-Path $indexPath)) { Write-EmptyHook; exit 0 }

    $indexLines = Get-Content -Path $indexPath -Encoding UTF8
    $tokens = Get-PromptTokens $prompt
    $match = Find-L1Match $indexLines $tokens
    $explicit = Test-ExplicitContextPrompt $prompt
    if (-not $match -and -not $explicit) { Write-EmptyHook; exit 0 }

    $alreadyLoaded = @(Get-LoadedRefs $root $sessionId)
    $candidateRefs = New-Object System.Collections.Generic.List[string]
    $l1Lines = @()
    if ($match) {
        $l1Rel = $match.L1.Replace("/", [IO.Path]::DirectorySeparatorChar)
        $l1Path = Join-Path $root (Join-Path ".ctxdb" $l1Rel)
        $l1Lines = Get-TextLines $l1Path 120
        Get-L2Refs $l1Lines | ForEach-Object { if (-not $candidateRefs.Contains($_)) { $candidateRefs.Add($_) } }
    } elseif ($explicit) {
        $candidateRefs.Add("L2/progress-current.md")
    }

    $newRefs = @($candidateRefs | Where-Object { $alreadyLoaded -notcontains $_ })
    if ($newRefs.Count -eq 0) { Write-EmptyHook; exit 0 }

    $loaded = New-Object System.Collections.Generic.List[string]
    $context = New-Object System.Collections.Generic.List[string]
    $sync = Get-AgentSyncSummary $indexLines
    $lastDate = "-"
    foreach ($line in $sync) { if ($line -match "\|\s*Claude Code\s*\|\s*([^|]+)\|") { $lastDate = $Matches[1].Trim(); break } }

    $context.Add("=== PawPad Claude Auto Context ===")
    $context.Add("rule: .ctxdb INDEX -> L1<=1 -> L2<=2; full ctxdb load forbidden.")
    if ($sync.Count -gt 0) { $context.Add("--- AGENT SYNC ---"); $sync | ForEach-Object { $context.Add($_) } }

    if ($match) {
        if ($l1Lines.Count -gt 0) { $context.Add("--- L1: $($match.L1) ---"); $l1Lines | ForEach-Object { $context.Add($_) } }
        foreach ($l2Ref in $newRefs) {
            $l2Rel = $l2Ref.Replace("/", [IO.Path]::DirectorySeparatorChar)
            $l2Path = Join-Path (Join-Path $root ".ctxdb") $l2Rel
            $l2Lines = Get-TextLines $l2Path 150 -Tail
            if ($l2Lines.Count -gt 0) { $loaded.Add($l2Ref); $context.Add("--- $l2Ref ---"); $l2Lines | ForEach-Object { $context.Add($_) } }
        }
    } elseif ($explicit -and $newRefs.Count -gt 0) {
        $l2Path = Join-Path $root ".ctxdb/L2/progress-current.md"
        $l2Lines = Get-TextLines $l2Path 150 -Tail
        if ($l2Lines.Count -gt 0) { $loaded.Add($newRefs[0]); $context.Add("--- $($newRefs[0]) (fallback) ---"); $l2Lines | ForEach-Object { $context.Add($_) } }
    }

    $includeHot = ($loaded.Count -gt 0 -or $match -or $explicit)
    Get-CodemapContext $root $tokens $includeHot | ForEach-Object { $context.Add($_) }

    $status = if ($loaded.Count -gt 0) { "loaded" } elseif ($match) { "matched-no-l2" } else { "no-keyword-match" }
    $loadedText = if ($loaded.Count -gt 0) { ($loaded -join ", ") } else { "L2 0 files" }
    $context.Insert(1, "ctxdb: $project | $lastDate | $loadedText | $status")

    Save-LoadedRefs $root $sessionId (@($alreadyLoaded) + @($loaded.ToArray()))
    Write-HookContext ($context -join "`n")
} catch {
    Write-HookContext ("ctxdb: hook-error | - | L2 0 files | " + $_.Exception.Message)
}
