$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-HookContext {
    param([string]$Context, [string]$SystemMessage)
    # suppressOutput: Codex spec상 parsed-but-not-yet-implemented (openai/codex#16933).
    # 구현되는 즉시 additionalContext 전문이 TUI에서 숨고 systemMessage 1줄만 표시됨. 선반영(무해).
    $payload = @{
        hookSpecificOutput = @{
            hookEventName = "UserPromptSubmit"
            additionalContext = $Context
        }
        suppressOutput = $true
    }
    if ($SystemMessage) { $payload.systemMessage = $SystemMessage }
    $payload | ConvertTo-Json -Depth 6 -Compress
}

function Write-EmptyHook {
    "{}"
}

function Find-PawpadRoot {
    $dir = (Get-Location).Path
    while ($dir) {
        if ((Test-Path (Join-Path $dir ".ctxdb/INDEX.md")) -and
            (Test-Path (Join-Path $dir ".claude/codemap/_index.md"))) {
            return $dir
        }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return (Get-Location).Path
}

function Get-SessionId {
    param($Event)
    if ($Event -and $Event.session_id) { return [string]$Event.session_id }
    return "manual"
}

function Get-LoadedRefs {
    param([string]$Root, [string]$SessionId)
    $path = Join-Path $Root ".ctxdb/.state/codex-loaded"
    if (-not (Test-Path $path)) { return @() }
    $lines = Get-Content -Path $path -Encoding UTF8
    if ($lines.Count -eq 0 -or $lines[0] -ne $SessionId) { return @() }
    if ($lines.Count -eq 1) { return @() }
    return $lines | Select-Object -Skip 1
}

function Save-LoadedRefs {
    param([string]$Root, [string]$SessionId, [string[]]$Refs)
    $stateDir = Join-Path $Root ".ctxdb/.state"
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
    $path = Join-Path $stateDir "codex-loaded"
    $unique = @($Refs | Where-Object { $_ } | Select-Object -Unique)
    Set-Content -Path $path -Value (@($SessionId) + $unique) -Encoding UTF8
}

function Get-TextLines {
    param([string]$Path, [int]$MaxLines = 150, [switch]$Tail)
    if (-not (Test-Path $Path)) { return @() }
    $lines = Get-Content -Path $Path -Encoding UTF8
    if ($lines.Count -le $MaxLines) { return $lines }
    if ($Tail) { return $lines | Select-Object -Last $MaxLines }
    return $lines | Select-Object -First $MaxLines
}

function Get-PromptTokens {
    param([string]$Prompt)
    if (-not $Prompt) { return @() }
    $stopwords = @{
        "and" = $true; "for" = $true; "the" = $true; "this" = $true
        "that" = $true; "with" = $true; "from" = $true; "into" = $true
        "about" = $true; "please" = $true; "file" = $true
    }
    return ($Prompt.ToLowerInvariant() -split "[^\p{L}\p{Nd}_:-]+") |
        Where-Object { $_.Length -ge 3 -and -not $stopwords.ContainsKey($_) } |
        Select-Object -Unique
}

function Test-ExplicitContextPrompt {
    param([string]$Prompt)
    $p = $Prompt.ToLowerInvariant()
    # 재개 의도어만 매칭. 프로젝트/에이전트명(pawpad/claude/codex)이나 일반어(context/continue/previous)는
    # 프로젝트명 포함 일반 프롬프트에서 과발화 -> 무관한 stale L2 주입 (2026-06-11 finding). 금지.
    $needles = @(
        "ctxdb", "context-saver", "resume", "handoff", "save context",
        "이어서", "재개", "핸드오프", "지난 세션", "세션저장", "세션 저장", "컨텍스트 로드"
    )
    foreach ($needle in $needles) {
        if ($p.Contains($needle)) { return $true }
    }
    return $false
}

function Get-AgentSyncSummary {
    param([string[]]$IndexLines)
    $sync = @()
    foreach ($line in $IndexLines) {
        if ($line -match "^\|\s*(Claude Code|Codex)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|") {
            $sync += ($line.Trim())
        }
    }
    return $sync
}

function Find-L1Match {
    param([string[]]$IndexLines, [string[]]$PromptTokens)
    $promptSet = @{}
    foreach ($token in $PromptTokens) { $promptSet[$token] = $true }

    foreach ($line in $IndexLines) {
        if ($line -notmatch "^\|\s*\d+\s*\|\s*([^|]+)\|\s*(L1/[^|]+)\|") { continue }
        $keywordsCell = $Matches[1].Trim()
        $l1Path = $Matches[2].Trim()
        if ($l1Path -match "domain-sample" -or $keywordsCell -match "AUTH") { continue }

        $keywords = ($keywordsCell -split "[,\s/|]+") |
            ForEach-Object { $_.Trim("()[]{} `t`r`n").ToLowerInvariant() } |
            Where-Object { $_.Length -ge 3 }

        foreach ($keyword in $keywords) {
            if ($promptSet.ContainsKey($keyword)) {
                return @{
                    Keywords = $keywordsCell
                    L1 = $l1Path
                }
            }
        }
    }
    return $null
}

function Get-L2Refs {
    param([string[]]$Lines)
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

function Test-CodemapInject {
    param([string]$Root)
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

function Get-CtxdbInjectMode {
    param([string]$Root)
    # pointer(기본) = 본문 대신 read 지시만 주입. Codex TUI가 additionalContext 전문을 화면 렌더링하므로
    # 파일 본문 주입 = 화면 노이즈. agent가 tool read로 가져오면 collapsed 1줄로 표시됨.
    # full = 기존 본문 주입 (pawpad-config.json ctxdb.injectMode 로 전환).
    $cfg = Join-Path $Root ".claude/pawpad-config.json"
    $mode = "pointer"
    if (Test-Path $cfg) {
        try {
            $j = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.ctxdb.injectMode) { $mode = [string]$j.ctxdb.injectMode }
        } catch {}
    }
    if ($mode -ne "full") { $mode = "pointer" }
    return $mode
}

function Get-CodemapContext {
    param([string]$Root, [string[]]$Tokens, [bool]$IncludeHot = $false)
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

        if ($section -eq "HOT" -and $line.Trim() -and -not $line.Trim().StartsWith("(")) {
            $hot.Add($line)
            continue
        }

        if ($section -eq "INDEX" -and $line.Trim() -and -not $line.Trim().StartsWith("(")) {
            $trimmed = $line.Trim()
            $symbol = (($trimmed -split "\s+")[0]).ToLowerInvariant()
            $symbolParts = $symbol -split "[:_.\-/]+"
            foreach ($token in $Tokens) {
                if ($token -eq $symbol -or ($symbolParts -contains $token)) {
                    $codemapMatches.Add($line)
                    break
                }
            }
        }
    }

    $out = New-Object System.Collections.Generic.List[string]
    if ($IncludeHot -and $hot.Count -gt 0) {
        $out.Add("--- codemap HOT ---")
        $hot | Select-Object -First 5 | ForEach-Object { $out.Add($_) }
    }
    if ($codemapMatches.Count -gt 0) {
        $out.Add("--- codemap keyword matches ---")
        $codemapMatches | Select-Object -First 8 | ForEach-Object { $out.Add($_) }
    }
    return $out.ToArray()
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

    if (-not (Test-Path $indexPath)) {
        Write-EmptyHook
        exit 0
    }

    $indexLines = Get-Content -Path $indexPath -Encoding UTF8
    $tokens = Get-PromptTokens $prompt
    $match = Find-L1Match $indexLines $tokens
    $explicit = Test-ExplicitContextPrompt $prompt

    if (-not $match -and -not $explicit) {
        Write-EmptyHook
        exit 0
    }

    $alreadyLoaded = @(Get-LoadedRefs $root $sessionId)
    $candidateRefs = New-Object System.Collections.Generic.List[string]
    $l1Lines = @()
    if ($match) {
        $l1Rel = $match.L1.Replace("/", [IO.Path]::DirectorySeparatorChar)
        $l1Path = Join-Path $root (Join-Path ".ctxdb" $l1Rel)
        $l1Lines = Get-TextLines $l1Path 120
        Get-L2Refs $l1Lines | ForEach-Object {
            if (-not $candidateRefs.Contains($_)) { $candidateRefs.Add($_) }
        }
    } elseif ($explicit) {
        $candidateRefs.Add("L2/progress-current.md")
    }

    $newRefs = @($candidateRefs | Where-Object { $alreadyLoaded -notcontains $_ })
    if ($newRefs.Count -eq 0) {
        Write-EmptyHook
        exit 0
    }

    $mode = Get-CtxdbInjectMode $root
    $loaded = New-Object System.Collections.Generic.List[string]
    $context = New-Object System.Collections.Generic.List[string]
    $sync = Get-AgentSyncSummary $indexLines

    $lastDate = "-"
    foreach ($line in $sync) {
        if ($line -match "\|\s*Codex\s*\|\s*([^|]+)\|") {
            $lastDate = $Matches[1].Trim()
            break
        }
    }

    if ($mode -eq "pointer") {
        $context.Add("=== PawPad Codex Auto Context (pointer) ===")
        $context.Add("rule: 아래 파일을 지금 read한 뒤 작업 시작. 그 외 ctxdb 전체 로드 금지 (L1<=1/L2<=2).")
        if ($match -and $l1Lines.Count -gt 0) {
            $context.Add("read: .ctxdb/$($match.L1)")
        }
        foreach ($l2Ref in $newRefs) {
            $l2Rel = $l2Ref.Replace("/", [IO.Path]::DirectorySeparatorChar)
            $l2Path = Join-Path (Join-Path $root ".ctxdb") $l2Rel
            if (Test-Path $l2Path) {
                $loaded.Add($l2Ref)
                $context.Add("read: .ctxdb/$l2Ref (tail 150줄만)")
            }
        }
        if (Test-CodemapInject $root) {
            $context.Add("read: .claude/codemap/_index.md (HOT + prompt keyword 매칭 심볼만)")
        }
    } else {
        $context.Add("=== PawPad Codex Auto Context ===")
        $context.Add("rule: .ctxdb INDEX -> L1<=1 -> L2<=2; full ctxdb load forbidden.")
        if ($sync.Count -gt 0) {
            $context.Add("--- AGENT SYNC ---")
            $sync | ForEach-Object { $context.Add($_) }
        }

        if ($match) {
            if ($l1Lines.Count -gt 0) {
                $context.Add("--- L1: $($match.L1) ---")
                $l1Lines | ForEach-Object { $context.Add($_) }
            }
            foreach ($l2Ref in $newRefs) {
                $l2Rel = $l2Ref.Replace("/", [IO.Path]::DirectorySeparatorChar)
                $l2Path = Join-Path (Join-Path $root ".ctxdb") $l2Rel
                $l2Lines = Get-TextLines $l2Path 150 -Tail
                if ($l2Lines.Count -gt 0) {
                    $loaded.Add($l2Ref)
                    $context.Add("--- $l2Ref ---")
                    $l2Lines | ForEach-Object { $context.Add($_) }
                }
            }
        } elseif ($explicit -and $newRefs.Count -gt 0) {
            $l2Ref = $newRefs[0]
            $l2Path = Join-Path $root ".ctxdb/L2/progress-current.md"
            $l2Lines = Get-TextLines $l2Path 150 -Tail
            if ($l2Lines.Count -gt 0) {
                $loaded.Add($l2Ref)
                $context.Add("--- $l2Ref (fallback) ---")
                $l2Lines | ForEach-Object { $context.Add($_) }
            }
        }

        $includeHot = ($loaded.Count -gt 0 -or $match -or $explicit)
        $codemap = Get-CodemapContext $root $tokens $includeHot
        $codemap | ForEach-Object { $context.Add($_) }
    }

    if ($loaded.Count -eq 0 -and -not ($match -and $l1Lines.Count -gt 0)) {
        Write-EmptyHook
        exit 0
    }

    $status = if ($mode -eq "pointer" -and $loaded.Count -gt 0) { "pointer" } elseif ($loaded.Count -gt 0) { "loaded" } elseif ($match) { "matched-no-l2" } else { "no-keyword-match" }
    $loadedText = if ($loaded.Count -gt 0) { ($loaded -join ", ") } else { "L2 0 files" }
    $statusLine = "ctxdb: $project | $lastDate | $loadedText | $status"
    $context.Insert(1, $statusLine)

    Save-LoadedRefs $root $sessionId (@($alreadyLoaded) + @($loaded.ToArray()))
    Write-HookContext ($context -join "`n") "PawPad $statusLine"
} catch {
    $message = "ctxdb: hook-error | - | L2 0 files | " + $_.Exception.Message
    Write-HookContext $message "PawPad $message"
}
