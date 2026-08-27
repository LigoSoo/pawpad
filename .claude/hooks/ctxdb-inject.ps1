$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# UserPromptSubmit hook (Claude Code) - prompt keyword로 .ctxdb L1<=1/L2<=2(+L3/L4 블록) 최소 로드 + 세션 dedupe.
# Codex .codex/hooks/ctxdb-inject.ps1과 동일 전략. 상태파일은 claude-loaded 사용.

function Write-HookContext {
    param([string]$Context)
    @{ hookSpecificOutput = @{ hookEventName = "UserPromptSubmit"; additionalContext = $Context } } |
        ConvertTo-Json -Depth 6 -Compress
}
function Write-EmptyHook { "{}" }

function Find-PawpadRoot {
    # 마커가 하나라도 있는 '가장 가까운' 디렉터리가 root다.
    # INDEX.md 존재를 root 조건으로 걸면 INDEX가 없을 때 상위 repo까지 올라가
    # 남의 .ctxdb를 읽고 진단도 엉뚱한 곳에 남는다 (중첩 설치·픽스처에서 실측).
    $dir = (Get-Location).Path
    while ($dir) {
        if ((Test-Path (Join-Path $dir ".ctxdb")) -or
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

# 판정 기록. 무주입도 {} 출력 계약을 유지하되 사유는 state로 남긴다 (진단 불가 방지).
function Save-Decision { param([string]$Root, [string]$SessionId, [string]$Decision)
    try {
        $stateDir = Join-Path $Root ".ctxdb/.state"
        New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
        Set-Content -Path (Join-Path $stateDir "claude-last-decision") -Value @($SessionId, $Decision) -Encoding UTF8
    } catch { }
}

function Get-TextLines { param([string]$Path, [int]$MaxLines = 150, [switch]$Tail)
    if (-not (Test-Path $Path)) { return @() }
    $lines = Get-Content -Path $Path -Encoding UTF8
    if ($lines.Count -le $MaxLines) { return $lines }
    if ($Tail) { return $lines | Select-Object -Last $MaxLines }
    return $lines | Select-Object -First $MaxLines
}

# 토큰 길이 하한은 문자 종류별로 다르다. 한국어는 2음절이 가장 흔한 어휘 길이라
# 라틴 기준 3자를 그대로 쓰면 한글 키워드가 대량 탈락한다.
function Test-TokenLength { param([string]$Text)
    if (-not $Text) { return $false }
    if ($Text -match "[\p{IsHangulSyllables}\p{IsHangulJamo}\p{IsCJKUnifiedIdeographs}\p{IsHiragana}\p{IsKatakana}]") {
        return ($Text.Length -ge 2)
    }
    return ($Text.Length -ge 3)
}

# 한국어 조사가 붙은 토큰은 키워드와 직접 매칭되지 않는다. 원형 + 조사 제거형 둘 다 후보로 둔다.
# 접미사만 보고 자르면 명사를 오분해한다("전문가" -> "전문"). 짝 조사는 어간 받침에 따라
# 형태가 정해지므로(은/는·이/가·을/를·과/와·으로/로) 받침 일치를 검사해 오분해를 막는다.
# Form: C=받침 있는 어간에만 / V=받침 없는 어간에만 / A=무관. Rieul=ㄹ 받침도 V형 허용(…로).
$script:CtxJosa = @(
    @{ S="으로써"; Form="C" }, @{ S="으로서"; Form="C" }, @{ S="이라고"; Form="C" },
    @{ S="이라는"; Form="C" }, @{ S="으로는"; Form="C" }, @{ S="이라도"; Form="C" },
    @{ S="에서는"; Form="A" }, @{ S="에서도"; Form="A" }, @{ S="한테서"; Form="A" },
    @{ S="에게서"; Form="A" }, @{ S="까지도"; Form="A" }, @{ S="부터는"; Form="A" },
    @{ S="으로"; Form="C" }, @{ S="이라"; Form="C" }, @{ S="이란"; Form="C" },
    @{ S="이나"; Form="C" }, @{ S="이랑"; Form="C" },
    @{ S="라고"; Form="V" }, @{ S="라는"; Form="V" }, @{ S="라도"; Form="V" },
    @{ S="에서"; Form="A" }, @{ S="에게"; Form="A" }, @{ S="까지"; Form="A" },
    @{ S="부터"; Form="A" }, @{ S="한테"; Form="A" }, @{ S="보다"; Form="A" },
    @{ S="마저"; Form="A" }, @{ S="조차"; Form="A" }, @{ S="처럼"; Form="A" },
    @{ S="에는"; Form="A" }, @{ S="에도"; Form="A" },
    @{ S="은"; Form="C" }, @{ S="이"; Form="C" }, @{ S="을"; Form="C" }, @{ S="과"; Form="C" },
    @{ S="는"; Form="V" }, @{ S="가"; Form="V" }, @{ S="를"; Form="V" }, @{ S="와"; Form="V" },
    @{ S="랑"; Form="V" }, @{ S="로"; Form="V"; Rieul=$true },
    @{ S="의"; Form="A" }, @{ S="에"; Form="A" }, @{ S="도"; Form="A" }, @{ S="만"; Form="A" }
)
# 한글 음절의 종성(받침) 인덱스. 0 = 받침 없음, 8 = ㄹ.
function Get-Jongseong { param([char]$Ch)
    $code = [int]$Ch
    if ($code -lt 0xAC00 -or $code -gt 0xD7A3) { return -1 }
    return (($code - 0xAC00) % 28)
}
function Get-TokenVariants { param([string]$Token)
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add($Token)
    if ($Token -notmatch "[\p{IsHangulSyllables}]$") { return $out.ToArray() }
    foreach ($josa in $script:CtxJosa) {
        if (-not $Token.EndsWith($josa.S)) { continue }
        $stem = $Token.Substring(0, $Token.Length - $josa.S.Length)
        if ($stem.Length -lt 2) { continue }
        $jong = Get-Jongseong $stem[$stem.Length - 1]
        if ($jong -lt 0) { break }
        $ok = $false
        if ($josa.Form -eq "A") { $ok = $true }
        elseif ($josa.Form -eq "C") { $ok = ($jong -ne 0) }
        else { $ok = ($jong -eq 0) -or ($josa.Rieul -and $jong -eq 8) }
        # 형태가 안 맞으면 그 접미사는 조사가 아니라 어간의 일부다. 더 짧은 조사도 시도하지 않는다.
        if ($ok -and -not $out.Contains($stem)) { $out.Add($stem) }
        break
    }
    return $out.ToArray()
}

function Get-PromptTokens { param([string]$Prompt)
    if (-not $Prompt) { return @() }
    $stopwords = @{ "and"=$true;"for"=$true;"the"=$true;"this"=$true;"that"=$true;
        "with"=$true;"from"=$true;"into"=$true;"about"=$true;"please"=$true;"file"=$true }
    $raw = ($Prompt.ToLowerInvariant() -split "[^\p{L}\p{Nd}_:-]+") |
        Where-Object { (Test-TokenLength $_) -and -not $stopwords.ContainsKey($_) }
    $all = New-Object System.Collections.Generic.List[string]
    foreach ($token in $raw) {
        foreach ($variant in (Get-TokenVariants $token)) {
            if ($variant -and -not $all.Contains($variant) -and -not $stopwords.ContainsKey($variant)) { $all.Add($variant) }
        }
    }
    return $all.ToArray()
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

# INDEX 행: | 우선순위 | 키워드 | L1 경로 | (선택) L2/L3 경로 |
# 첫 히트 즉시 반환하면 짧은 일반어가 엉뚱한 도메인을 먼저 잡는다 -> 전 행 점수화 후 최다 히트 선택.
function Find-L1Match { param([string[]]$IndexLines, [string[]]$PromptTokens)
    $promptSet = @{}; foreach ($t in $PromptTokens) { $promptSet[$t] = $true }
    $best = $null; $bestScore = 0; $bestPriority = [int]::MaxValue
    foreach ($line in $IndexLines) {
        if ($line -notmatch "^\|\s*(\d+)\s*\|\s*([^|]+)\|\s*(L1/[^|]+?)\s*\|(.*)$") { continue }
        $priority = [int]$Matches[1]
        $keywordsCell = $Matches[2].Trim()
        $l1Path = $Matches[3].Trim()
        $refsCell = $Matches[4]
        if ($l1Path -match "domain-sample" -or $keywordsCell -match "AUTH") { continue }
        $keywords = ($keywordsCell -split "[,\s/|]+") |
            ForEach-Object { $_.Trim("()[]{} `t`r`n").ToLowerInvariant() } | Where-Object { Test-TokenLength $_ }
        $score = 0
        foreach ($keyword in $keywords) { if ($promptSet.ContainsKey($keyword)) { $score++ } }
        if ($score -gt 0 -and ($score -gt $bestScore -or ($score -eq $bestScore -and $priority -lt $bestPriority))) {
            $best = @{ Keywords = $keywordsCell; L1 = $l1Path; Score = $score; RefsCell = $refsCell }
            $bestScore = $score; $bestPriority = $priority
        }
    }
    return $best
}

# L2뿐 아니라 장기보관(L3/L4) 포인터도 회수 대상. L2만 매칭하면 이월된 기억이 회수 불가가 된다.
# 상한은 타입별로 건다 - 전체 개수로 자르면 L2가 여럿일 때 뒤에 오는 L3/L4가 통째로 잘려나간다.
function Get-CtxRefs { param([string[]]$Lines, [int]$MaxL2 = 4, [int]$MaxArchive = 2)
    $l2 = New-Object System.Collections.Generic.List[string]
    $archive = New-Object System.Collections.Generic.List[string]
    foreach ($line in $Lines) {
        if (-not $line) { continue }
        foreach ($match in [regex]::Matches($line, "(?:\.ctxdb/)?(L[234]/[A-Za-z0-9_.\-/]+\.md)")) {
            $ref = $match.Groups[1].Value.Replace("\", "/")
            if ($ref -match "^L[34]/") {
                if (-not $archive.Contains($ref) -and $archive.Count -lt $MaxArchive) { $archive.Add($ref) }
            } else {
                if (-not $l2.Contains($ref) -and $l2.Count -lt $MaxL2) { $l2.Add($ref) }
            }
        }
        if ($l2.Count -ge $MaxL2 -and $archive.Count -ge $MaxArchive) { break }
    }
    return (@($l2.ToArray()) + @($archive.ToArray()))
}

# L3/L4는 파일이 크다. tail 통째가 아니라 '## ' 헤더 블록으로 잘라 키워드가 맞는 블록만 싣는다.
function Get-BlockMatches { param([string]$Path, [string[]]$Tokens, [int]$MaxLines = 60)
    if (-not (Test-Path $Path)) { return @() }
    $lines = Get-Content -Path $Path -Encoding UTF8
    $blocks = New-Object System.Collections.Generic.List[object]
    $cur = $null
    foreach ($line in $lines) {
        if ($line -match "^##\s") {
            if ($null -ne $cur -and $cur.Count -gt 0) { $blocks.Add($cur) }
            $cur = New-Object System.Collections.Generic.List[string]
        }
        if ($null -ne $cur) { $cur.Add($line) }
    }
    if ($null -ne $cur -and $cur.Count -gt 0) { $blocks.Add($cur) }
    if ($blocks.Count -eq 0) { return (Get-TextLines $Path $MaxLines -Tail) }

    $scored = @()
    foreach ($block in $blocks) {
        $text = (($block -join "`n")).ToLowerInvariant()
        $hits = 0
        foreach ($token in $Tokens) { if ($token -and $text.Contains($token)) { $hits++ } }
        if ($hits -gt 0) { $scored += ,@{ Hits = $hits; Lines = $block } }
    }
    if ($scored.Count -eq 0) { return @() }

    $out = New-Object System.Collections.Generic.List[string]
    foreach ($entry in ($scored | Sort-Object { - $_.Hits })) {
        if ($out.Count -ge $MaxLines) { break }
        foreach ($line in $entry.Lines) {
            if ($out.Count -ge $MaxLines) { break }
            $out.Add($line)
        }
    }
    return $out.ToArray()
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
    if (-not (Test-Path $indexPath)) {
        Save-Decision $root $sessionId "index-missing | $indexPath"
        Write-EmptyHook; exit 0
    }

    $indexLines = Get-Content -Path $indexPath -Encoding UTF8
    $tokens = Get-PromptTokens $prompt
    $match = Find-L1Match $indexLines $tokens
    $explicit = Test-ExplicitContextPrompt $prompt
    if (-not $match -and -not $explicit) {
        Save-Decision $root $sessionId ("no-match | tokens=" + @($tokens).Count)
        Write-EmptyHook; exit 0
    }

    $alreadyLoaded = @(Get-LoadedRefs $root $sessionId)
    $candidateRefs = New-Object System.Collections.Generic.List[string]
    $l1Lines = @()
    if ($match) {
        # INDEX 행의 L2/L3 컬럼이 있으면 우선 사용 - L1 본문 길이와 무관하게 포인터가 잡힌다.
        if ($match.RefsCell) {
            Get-CtxRefs @($match.RefsCell) | ForEach-Object { if (-not $candidateRefs.Contains($_)) { $candidateRefs.Add($_) } }
        }
        $l1Rel = $match.L1.Replace("/", [IO.Path]::DirectorySeparatorChar)
        $l1Path = Join-Path $root (Join-Path ".ctxdb" $l1Rel)
        # 포인터 탐색은 본문 전체, 주입만 앞 120줄. 둘을 같은 범위로 묶으면 L1이 자랄 때 조용히 실패한다.
        $l1All = @(Get-TextLines $l1Path 100000)
        $l1Lines = if ($l1All.Count -gt 120) { @($l1All | Select-Object -First 120) } else { $l1All }
        Get-CtxRefs $l1All | ForEach-Object { if (-not $candidateRefs.Contains($_)) { $candidateRefs.Add($_) } }
    }
    # 폴백은 매칭 성공 여부와 무관하게 적용한다. 매칭될수록 폴백이 꺼지면 가장 관련 있는 프롬프트에서 실패한다.
    if ($candidateRefs.Count -eq 0) { $candidateRefs.Add("L2/progress-current.md") }

    $newRefs = @($candidateRefs | Where-Object { $alreadyLoaded -notcontains $_ })
    if ($newRefs.Count -eq 0) {
        Save-Decision $root $sessionId ("already-loaded | " + ($candidateRefs -join ", "))
        Write-EmptyHook; exit 0
    }

    $loaded = New-Object System.Collections.Generic.List[string]
    $context = New-Object System.Collections.Generic.List[string]
    $sync = Get-AgentSyncSummary $indexLines
    $lastDate = "-"
    foreach ($line in $sync) { if ($line -match "\|\s*Claude Code\s*\|\s*([^|]+)\|") { $lastDate = $Matches[1].Trim(); break } }

    $context.Add("=== PawPad Claude Auto Context ===")
    $context.Add("rule: .ctxdb INDEX -> L1<=1 -> L2<=2 (+L3/L4 keyword blocks); full ctxdb load forbidden.")
    if ($sync.Count -gt 0) { $context.Add("--- AGENT SYNC ---"); $sync | ForEach-Object { $context.Add($_) } }
    if ($match -and $l1Lines.Count -gt 0) { $context.Add("--- L1: $($match.L1) ---"); $l1Lines | ForEach-Object { $context.Add($_) } }

    # 주입 상한도 타입별. L2 2개 + 장기보관 1개 - archive를 L2와 같은 카운터로 묶으면 다시 잘린다.
    $l2Count = 0; $archiveCount = 0
    foreach ($ref in $newRefs) {
        $rel = $ref.Replace("/", [IO.Path]::DirectorySeparatorChar)
        $path = Join-Path (Join-Path $root ".ctxdb") $rel
        if ($ref -match "^L[34]/") {
            if ($archiveCount -ge 1) { continue }
            $blockLines = @(Get-BlockMatches $path $tokens 60)
            if ($blockLines.Count -gt 0) {
                $archiveCount++; $loaded.Add($ref); $context.Add("--- $ref (keyword blocks) ---")
                $blockLines | ForEach-Object { $context.Add($_) }
            }
        } else {
            if ($l2Count -ge 2) { continue }
            $l2Lines = @(Get-TextLines $path 150 -Tail)
            if ($l2Lines.Count -gt 0) {
                $l2Count++; $loaded.Add($ref); $context.Add("--- $ref ---")
                $l2Lines | ForEach-Object { $context.Add($_) }
            }
        }
    }

    # 실을 것이 하나도 없으면 헤더만 주입하지 않는다 (Codex 훅과 동일 판정).
    if ($loaded.Count -eq 0 -and -not ($match -and $l1Lines.Count -gt 0)) {
        Save-Decision $root $sessionId ("no-refs | " + ($newRefs -join ", "))
        Write-EmptyHook; exit 0
    }

    $includeHot = ($loaded.Count -gt 0 -or $match -or $explicit)
    Get-CodemapContext $root $tokens $includeHot | ForEach-Object { $context.Add($_) }

    $status = if ($loaded.Count -gt 0) { "loaded" } elseif ($match) { "matched-no-l2" } else { "no-keyword-match" }
    $loadedText = if ($loaded.Count -gt 0) { ($loaded -join ", ") } else { "L2 0 files" }
    $context.Insert(1, "ctxdb: $project | $lastDate | $loadedText | $status")

    Save-Decision $root $sessionId "$status | $loadedText"
    Save-LoadedRefs $root $sessionId (@($alreadyLoaded) + @($loaded.ToArray()))
    Write-HookContext ($context -join "`n")
} catch {
    Write-HookContext ("ctxdb: hook-error | - | L2 0 files | " + $_.Exception.Message)
}
