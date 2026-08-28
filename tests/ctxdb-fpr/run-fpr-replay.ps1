# tests/ctxdb-fpr/run-fpr-replay.ps1
# ctxdb 회수 훅 오탐률(false-positive rate) 리플레이 하네스 — toolkit 개발 자산, 배포본 미포함.
#
# 회귀셋(tests/ctxdb-recall)이 "합성 픽스처로 회수가 되는가"를 본다면,
# 이 하네스는 "실제 INDEX + 실제 과거 프롬프트에서 얼마나 엉뚱하게 걸리는가"를 본다.
# 제품 코드는 건드리지 않는다 — 실 훅을 그대로 별도 프로세스로 돌린다.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\ctxdb-fpr\run-fpr-replay.ps1 `
#       -CorpusJson <prompts.json> -CtxdbSource <repo-root> -Out <out.tsv> [-CjkFloor 3] [-Tag toolkit]
#
# -CorpusJson  [{ "ts":..., "sid":..., "uuid":..., "text": "프롬프트" }, ...] JSON 배열
# -CtxdbSource 실 .ctxdb 를 가진 repo 루트. INDEX/L1/L2/L3/L4/keywords 만 임시 픽스처로 복제(.state 제외)
# -CjkFloor    2 = 현행(v2.48) / 3 = 대조군(v2.47 동작 재현: Test-TokenLength CJK 하한만 3으로 패치)
# -Tag         출력 TSV의 source 컬럼 값

param(
    [Parameter(Mandatory=$true)][string]$CorpusJson,
    [Parameter(Mandatory=$true)][string]$CtxdbSource,
    [Parameter(Mandatory=$true)][string]$Out,
    [string]$Hook = ".claude/hooks/ctxdb-inject.ps1",
    [ValidateSet(2,3)][int]$CjkFloor = 2,
    [string]$Tag = "corpus",
    [int]$Max = 0,
    [switch]$KeepFixture
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$HookAbs = if ([IO.Path]::IsPathRooted($Hook)) { $Hook } else { Join-Path $RepoRoot $Hook }
if (-not (Test-Path $HookAbs)) { Write-Host "hook not found: $HookAbs" -ForegroundColor Red; exit 2 }
$HookAbs = (Resolve-Path $HookAbs).Path
$Runtime = if ($HookAbs -match "[\/]\.codex[\/]") { "codex" } else { "claude" }

$TmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("pawpad-fpr-" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $TmpRoot | Out-Null

# ── 훅 사본 (대조군은 Test-TokenLength 의 CJK 하한만 바꾼다) ──────────────────
$HookRun = Join-Path $TmpRoot "ctxdb-inject.ps1"
$hookText = [IO.File]::ReadAllText($HookAbs, [Text.Encoding]::UTF8)
if ($CjkFloor -eq 3) {
    # Test-TokenLength 함수 본문 안의 CJK 분기만 치환. Get-TokenVariants 의 '어간 2자' 조건은 건드리지 않는다.
    $pat = '(?s)(function Test-TokenLength \{.*?IsKatakana.*?\)\s*\{\s*\r?\n\s*return \(\$Text\.Length -ge )2(\))'
    if ($hookText -notmatch $pat) { Write-Host "CjkFloor 패치 앵커 불일치 - 훅 구조 변경됨" -ForegroundColor Red; exit 2 }
    $hookText = [regex]::Replace($hookText, $pat, '${1}3${2}')
}
[IO.File]::WriteAllText($HookRun, $hookText, (New-Object Text.UTF8Encoding $true))

# ── 픽스처: 실 .ctxdb 복제(.state 제외) ──────────────────────────────────────
$srcCtx = Join-Path $CtxdbSource ".ctxdb"
if (-not (Test-Path (Join-Path $srcCtx "INDEX.md"))) { Write-Host "INDEX not found: $srcCtx" -ForegroundColor Red; exit 2 }
$Fixture = Join-Path $TmpRoot "fx"
New-Item -ItemType Directory -Force -Path (Join-Path $Fixture ".ctxdb") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Fixture ".claude") | Out-Null
Get-ChildItem -Path $srcCtx -Recurse -File | Where-Object { $_.FullName -notmatch "[\/]\.state[\/]" } | ForEach-Object {
    $rel = $_.FullName.Substring($srcCtx.Length).TrimStart('\','/')
    $dst = Join-Path (Join-Path $Fixture ".ctxdb") $rel
    $par = Split-Path $dst -Parent
    if (-not (Test-Path $par)) { New-Item -ItemType Directory -Force -Path $par | Out-Null }
    Copy-Item $_.FullName $dst -Force
}
# codemap 주입은 끈다 - 이 측정의 대상은 ctxdb 회수뿐이다.
Set-Content -Path (Join-Path $Fixture ".claude\pawpad-config.json") `
    -Value '{"ctxdb":{"injectMode":"full"},"codemap":{"inject":"off"}}' -Encoding UTF8

# ── 훅 호출 (회귀셋과 동일한 ASCII 이스케이프 규약) ──────────────────────────
# 파이프 바이트가 [Console]::OutputEncoding 에 좌우돼 중첩 프로세스에서 한글이 깨지면
# tokens=0 이 되어 오탐률이 0%로 위장된다(tests/ctxdb-recall README 함정 ②와 동일).
function ConvertTo-AsciiJson {
    param([string]$Json)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Json.ToCharArray()) {
        if ([int]$ch -lt 128) { [void]$sb.Append($ch) } else { [void]$sb.AppendFormat('\u{0:x4}', [int]$ch) }
    }
    return $sb.ToString()
}

function Invoke-HookOnce {
    param([string]$Prompt, [string]$SessionId)
    $json = ConvertTo-AsciiJson (@{ session_id = $SessionId; prompt = $Prompt } | ConvertTo-Json -Compress)
    Push-Location $Fixture
    try { $raw = ($json | & powershell -NoProfile -ExecutionPolicy Bypass -File $HookRun | Out-String).Trim() }
    finally { Pop-Location }
    $ctx = ""
    if ($raw -and $raw -ne "{}") {
        try { $ctx = [string](($raw | ConvertFrom-Json).hookSpecificOutput.additionalContext) } catch { $ctx = "" }
    }
    $status = ""; $l1 = ""; $loadedRefs = ""
    foreach ($line in ($ctx -split "`n")) {
        if (-not $status -and $line -match "^ctxdb:\s") { $status = $line.Trim() }
        if (-not $l1 -and $line -match "^---\s*L1:\s*(\S+)") { $l1 = $Matches[1] }
    }
    # status 줄 형식: "ctxdb: {project} | {date} | {loaded} | {verdict}"
    $verdict = "empty"
    if ($status) {
        $parts = $status -split "\|"
        if ($parts.Count -ge 4) { $loadedRefs = $parts[2].Trim(); $verdict = $parts[3].Trim() }
    }
    $dec = ""
    $decPath = Join-Path $Fixture ".ctxdb\.state\$Runtime-last-decision"
    if (Test-Path $decPath) { $dec = ((Get-Content $decPath -Encoding UTF8) | Select-Object -Skip 1) -join " " }
    return [pscustomobject]@{
        Verdict = $verdict; L1 = $l1; LoadedRefs = $loadedRefs; Decision = $dec
        CtxLines = @($ctx -split "`n").Count; Empty = ($raw -eq "{}")
    }
}

function Get-Flat { param([string]$Text, [int]$Max = 400)
    $t = ($Text -replace "[`r`n`t]+", " ").Trim()
    if ($t.Length -gt $Max) { $t = $t.Substring(0, $Max) + "…" }
    return $t
}

# ── 실행 ────────────────────────────────────────────────────────────────────
# PS 5.1의 ConvertFrom-Json은 JSON 배열을 파이프라인에서 풀지 않는다 - @()로 감싸면
# "배열 하나를 담은 1원소 배열"이 되어 코퍼스 전체가 프롬프트 1건으로 접힌다(실측).
$parsed = ConvertFrom-Json ((Get-Content -Path $CorpusJson -Encoding UTF8 -Raw))
$corpus = New-Object System.Collections.Generic.List[object]
foreach ($x in $parsed) {
    if ($x -is [Array]) { foreach ($y in $x) { [void]$corpus.Add($y) } } else { [void]$corpus.Add($x) }
}
if ($Max -gt 0 -and $corpus.Count -gt $Max) { $corpus = $corpus.GetRange(0, $Max) }

$rows = New-Object System.Collections.Generic.List[string]
$rows.Add(("id`tsource`tcjkFloor`tts`tverdict`tl1`tloadedRefs`tctxLines`tdecision`tprompt"))
$i = 0
foreach ($item in $corpus) {
    $i++
    $sid = [guid]::NewGuid().ToString()   # 프롬프트마다 새 세션 - 세션 dedupe(already-loaded) 회피
    $r = Invoke-HookOnce $item.text $sid
    $rows.Add((@($i, $Tag, $CjkFloor, $item.ts, $r.Verdict, $r.L1, $r.LoadedRefs, $r.CtxLines, $r.Decision, (Get-Flat $item.text)) -join "`t"))
    if ($i % 10 -eq 0) { Write-Host "  $i / $($corpus.Count)" -ForegroundColor DarkGray }
}

$outDir = Split-Path $Out -Parent
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
Set-Content -Path $Out -Value $rows -Encoding UTF8
Write-Host "wrote $Out ($($corpus.Count) prompts, tag=$Tag, cjkFloor=$CjkFloor)" -ForegroundColor Green

if (-not $KeepFixture) { Remove-Item -Recurse -Force $TmpRoot -ErrorAction SilentlyContinue }
else { Write-Host "fixture kept: $TmpRoot" -ForegroundColor DarkGray }
