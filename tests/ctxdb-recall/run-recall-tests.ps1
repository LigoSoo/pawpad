# tests/ctxdb-recall/run-recall-tests.ps1
# ctxdb 회수 훅 회귀셋 (v2.48). toolkit 개발 자산 — 배포본(설치처)에는 넣지 않는다.
#
# 각 케이스는 임시 디렉터리에 '가짜 설치처'(.ctxdb 트리 + pawpad-config.json)를 만들고
# 그 안에서 훅을 실제 프로세스로 실행한 뒤 stdout JSON / .state 판정파일을 검사한다.
# 픽스처를 저장소에 커밋하지 않고 매 실행 생성하는 이유: git이 빈 디렉터리를 추적하지 않아
# clean clone에서 복사 기반 픽스처가 깨진다(Codex review-01 finding).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\ctxdb-recall\run-recall-tests.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\ctxdb-recall\run-recall-tests.ps1 -Hook ".codex/hooks/ctxdb-inject.ps1"
#
# -Filter C7        특정 케이스만 (콤마 구분)
# -KeepFixtures     실패 분석용으로 임시 픽스처 보존

param(
    [string]$Hook = ".claude/hooks/ctxdb-inject.ps1",
    [string]$Filter = "",
    [switch]$KeepFixtures
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:HookAbs = if ([IO.Path]::IsPathRooted($Hook)) { $Hook } else { Join-Path $script:RepoRoot $Hook }
if (-not (Test-Path $script:HookAbs)) { Write-Host "hook not found: $script:HookAbs" -ForegroundColor Red; exit 2 }
$script:HookAbs = (Resolve-Path $script:HookAbs).Path
$script:Runtime = if ($script:HookAbs -match "[\\/]\.codex[\\/]") { "codex" } else { "claude" }
$script:TmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("pawpad-recall-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $script:TmpRoot | Out-Null

# ─── 픽스처 ──────────────────────────────────────────────────────────────────

function New-Fixture {
    # $Files: 상대경로 -> 내용. .ctxdb 디렉터리는 항상 생성(root 마커 = Find-PawpadRoot).
    # 기본 config는 injectMode=full — Codex pointer 렌더링을 벗겨 회수 로직 자체를 본다(C18만 예외).
    param([hashtable]$Files, [switch]$PointerMode)
    $dir = Join-Path $script:TmpRoot ("fx-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $dir ".ctxdb") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $dir ".claude") | Out-Null
    foreach ($rel in $Files.Keys) {
        $p = Join-Path $dir $rel
        $parent = Split-Path $p -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        Set-Content -Path $p -Value $Files[$rel] -Encoding UTF8
    }
    $mode = if ($PointerMode) { "pointer" } else { "full" }
    Set-Content -Path (Join-Path $dir ".claude\pawpad-config.json") `
        -Value ('{"ctxdb":{"injectMode":"' + $mode + '"},"codemap":{"inject":"off"}}') -Encoding UTF8
    return $dir
}

function New-IndexText {
    # $Rows: 이미 완성된 표 행 문자열 배열. $Header4=$false면 구 3컬럼 형식.
    param([string[]]$Rows, [bool]$Header4 = $true)
    $head = if ($Header4) {
        "| 우선순위 | 키워드 | L1 파일 경로 | L2/L3 경로 |`n|---|---|---|---|"
    } else {
        "| 우선순위 | 키워드 | L1 파일 경로 |`n|---|---|---|"
    }
    # AGENT SYNC의 L2 셀은 '-' 로 둔다. 실제 경로를 적으면 주입 컨텍스트에 섞여 어서션을 오염시킨다.
    return @"
# .ctxdb/INDEX.md — recall fixture

## 키워드 -> L1 매핑 테이블
$head
$($Rows -join "`n")

## AGENT SYNC 테이블
| Agent | 마지막 작업일 | 기록된 L2 파일 | 상태 |
|---|---|---|---|
| Claude Code | 2026-08-27 | - | fixture |
"@
}

function New-L1Text {
    param([string]$Name, [string[]]$Refs = @(), [int]$PadLines = 0)
    $body = "# L1/$Name`n> fixture domain`n"
    for ($i = 1; $i -le $PadLines; $i++) { $body += "- filler line $i (포인터를 읽기범위 밖으로 밀어내기 위한 패딩)`n" }
    $body += "`n## pointers`n"
    foreach ($r in $Refs) { $body += "- $r  (fixture pointer)`n" }
    return $body
}

# ─── 실행 / 판정 ─────────────────────────────────────────────────────────────

# 파이프로 native powershell에 넘기는 바이트는 [Console]::OutputEncoding에 좌우된다.
# 조부모-부모-자식 3단 프로세스에서 이게 ANSI로 잡히면 한글 프롬프트가 깨져 tokens=0이 되고,
# 회귀셋 전체가 "한글 회수 실패"로 오탐한다(실측). JSON의 \uXXXX 이스케이프로 페이로드를
# 순수 ASCII로 만들어 인코딩 의존성을 제거한다 — ConvertFrom-Json이 훅 쪽에서 되돌린다.
function ConvertTo-AsciiJson {
    param([string]$Json)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Json.ToCharArray()) {
        if ([int]$ch -lt 128) { [void]$sb.Append($ch) }
        else { [void]$sb.AppendFormat('\u{0:x4}', [int]$ch) }
    }
    return $sb.ToString()
}

function Invoke-Hook {
    param([string]$Fixture, [string]$Prompt, [string]$SessionId = "sess-1")
    $json = ConvertTo-AsciiJson (@{ session_id = $SessionId; prompt = $Prompt } | ConvertTo-Json -Compress)
    Push-Location $Fixture
    try {
        $raw = ($json | & powershell -NoProfile -ExecutionPolicy Bypass -File $script:HookAbs | Out-String).Trim()
    } finally { Pop-Location }

    $ctx = ""
    if ($raw -and $raw -ne "{}") {
        try { $ctx = [string](($raw | ConvertFrom-Json).hookSpecificOutput.additionalContext) } catch { $ctx = "" }
    }
    $decPath = Join-Path $Fixture ".ctxdb\.state\$($script:Runtime)-last-decision"
    $dec = ""
    if (Test-Path $decPath) { $dec = ((Get-Content $decPath -Encoding UTF8) -join " | ") }
    $status = ""
    foreach ($line in ($ctx -split "`n")) { if ($line -match "^ctxdb:\s") { $status = $line.Trim(); break } }

    return [pscustomobject]@{
        Raw = $raw; Context = $ctx; Empty = ($raw -eq "{}"); Decision = $dec; Status = $status
    }
}

function Get-InjectedBlock {
    # `--- <marker> ---` 헤더 아래, 다음 `--- ` 헤더 전까지의 줄 수.
    param([string]$Context, [string]$Marker)
    $lines = $Context -split "`n"
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -like "*$Marker*" -and $lines[$i].TrimStart().StartsWith("---")) { $start = $i; break }
    }
    if ($start -lt 0) { return @() }
    $out = @()
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].TrimStart().StartsWith("--- ")) { break }
        $out += $lines[$i]
    }
    return $out
}

# ─── 케이스 정의 ─────────────────────────────────────────────────────────────
# 각 Run 스크립트블록은 실패 사유 문자열 배열을 반환한다(빈 배열 = PASS).

$brandRow4  = '| 1 | 로고, 배너, banner, 회전 | L1/domain-brand.md | L2/brand.md |'
$deployRow4 = '| 2 | 배포, deploy, release, 릴리스 | L1/domain-deploy.md | L3/deploy-2026-07.md |'

function New-BaseFixture {
    New-Fixture @{
        ".ctxdb\INDEX.md"              = New-IndexText @($brandRow4, $deployRow4)
        ".ctxdb\L1\domain-brand.md"    = New-L1Text "domain-brand.md"
        ".ctxdb\L1\domain-deploy.md"   = New-L1Text "domain-deploy.md"
        ".ctxdb\L2\brand.md"           = "# brand`nicon.png 기반 ASCII 16프레임 사전 렌더."
        ".ctxdb\L2\progress-current.md" = "# progress`n폴백 대상 파일."
        ".ctxdb\L3\deploy-2026-07.md"  = "## 2026-07-01 배포 이력`n-Upgrade 3곳 0 failed.`n`n## 2026-07-20 무관 주제`nZZUNRELATEDZZ 전혀 다른 내용."
    }
}

$cases = @(
    @{ Id = "C1"; Name = "한글 2음절 키워드 회수 (D-1)"; Run = {
        $fx = New-BaseFixture
        $r = Invoke-Hook $fx "로고 어떻게 만들었지"
        $f = @()
        if ($r.Empty) { $f += "무주입(빈 응답) — 2음절 키워드가 길이 하한에서 탈락" }
        if ($r.Status -notmatch "L2/brand\.md") { $f += "status에 L2/brand.md 없음: $($r.Status)" }
        return $f
    }}

    @{ Id = "C2"; Name = "조사 스트립 (로고를 -> 로고)"; Run = {
        $fx = New-BaseFixture
        $r = Invoke-Hook $fx "로고를 다시 보자"
        $f = @()
        if ($r.Empty) { $f += "무주입 — 조사가 붙은 토큰이 매칭 실패" }
        if ($r.Status -notmatch "L2/brand\.md") { $f += "status에 L2/brand.md 없음: $($r.Status)" }
        return $f
    }}

    @{ Id = "C3"; Name = "라틴 키워드 회귀 보존"; Run = {
        $fx = New-BaseFixture
        $r = Invoke-Hook $fx "deploy pipeline 확인"
        $f = @()
        if ($r.Empty) { $f += "무주입 — 하한 분리가 라틴 경로를 깨뜨림" }
        if ($r.Context -notmatch "L1: L1/domain-deploy\.md") { $f += "domain-deploy L1 미주입" }
        return $f
    }}

    @{ Id = "C4"; Name = "무관 주제 무주입 + 사유 기록 (D-6)"; Run = {
        $fx = New-BaseFixture
        $r = Invoke-Hook $fx "양자컴퓨터 초전도 큐비트 결맞음"
        $f = @()
        if (-not $r.Empty) { $f += "과발화 — 무관 주제에 주입됨" }
        if ($r.Decision -notmatch "no-match") { $f += "무주입 사유 미기록: '$($r.Decision)'" }
        return $f
    }}

    @{ Id = "C5"; Name = "L1 150행 아래 포인터 탐색 (D-4)"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"           = New-IndexText @('| 1 | 로고, 배너 | L1/domain-brand.md |')
            ".ctxdb\L1\domain-brand.md" = New-L1Text "domain-brand.md" @("L2/deep.md") 200
            ".ctxdb\L2\deep.md"         = "# deep`n읽기범위(120줄) 밖 포인터가 가리키는 파일."
            ".ctxdb\L2\progress-current.md" = "# progress`n폴백."
        }
        $r = Invoke-Hook $fx "로고 얘기"
        $f = @()
        if ($r.Status -notmatch "L2/deep\.md") { $f += "200행 L1의 하단 포인터 미회수: $($r.Status)" }
        return $f
    }}

    @{ Id = "C6"; Name = "매칭 성공 + 포인터 0 -> 폴백 상시 (D-5)"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"           = New-IndexText @('| 1 | 로고, 배너 | L1/domain-brand.md |')
            ".ctxdb\L1\domain-brand.md" = New-L1Text "domain-brand.md"
            ".ctxdb\L2\progress-current.md" = "# progress`n폴백 대상."
        }
        $r = Invoke-Hook $fx "로고 얘기"
        $f = @()
        if ($r.Empty) { $f += "무주입 — 매칭 성공이 폴백을 껐다" }
        if ($r.Status -notmatch "progress-current\.md") { $f += "폴백 미적용: $($r.Status)" }
        return $f
    }}

    @{ Id = "C7"; Name = "L3 블록 선별 — 무관 블록 미포함 (D-3)"; Run = {
        $fx = New-BaseFixture
        $r = Invoke-Hook $fx "배포 이력 확인"
        $f = @()
        if ($r.Status -notmatch "L3/deploy-2026-07\.md") { $f += "L3 미회수: $($r.Status)" }
        if ($r.Context -notmatch "2026-07-01 배포 이력") { $f += "히트 블록 미포함" }
        if ($r.Context -match "ZZUNRELATEDZZ") { $f += "무관 블록까지 주입 — 파일 통째 로드" }
        return $f
    }}

    @{ Id = "C8"; Name = "다중 히트 우선 (D-2, 첫 히트 즉시반환 폐기)"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md" = New-IndexText @(
                '| 1 | 로고, 배너 | L1/domain-brand.md | L2/brand.md |',
                '| 2 | 로고, 배포, 릴리스 | L1/domain-deploy.md | L2/deploy.md |')
            ".ctxdb\L1\domain-brand.md"  = New-L1Text "domain-brand.md"
            ".ctxdb\L1\domain-deploy.md" = New-L1Text "domain-deploy.md"
            ".ctxdb\L2\brand.md"  = "# brand"
            ".ctxdb\L2\deploy.md" = "# deploy"
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        # row1 히트 1(로고) vs row2 히트 3(로고·배포·릴리스) -> 우선순위 숫자가 낮은 row1이 이기면 안 된다.
        $r = Invoke-Hook $fx "로고 배포 릴리스 정리"
        $f = @()
        if ($r.Context -notmatch "L1: L1/domain-deploy\.md") { $f += "히트 수 최대 행이 아니라 첫 행이 선택됨: $($r.Status)" }
        return $f
    }}

    @{ Id = "C9"; Name = "세션 dedupe — 같은 세션 재주입 금지"; Run = {
        $fx = New-BaseFixture
        $null = Invoke-Hook $fx "로고 얘기" "sess-dup"
        $r = Invoke-Hook $fx "로고 얘기" "sess-dup"
        $f = @()
        if (-not $r.Empty) { $f += "같은 세션에서 중복 주입" }
        if ($r.Decision -notmatch "already-loaded") { $f += "dedupe 사유 미기록: '$($r.Decision)'" }
        return $f
    }}

    @{ Id = "C10"; Name = "세션 dedupe — 새 세션은 다시 주입"; Run = {
        $fx = New-BaseFixture
        $null = Invoke-Hook $fx "로고 얘기" "sess-a"
        $r = Invoke-Hook $fx "로고 얘기" "sess-b"
        $f = @()
        if ($r.Empty) { $f += "새 세션인데 주입 안 됨 — dedupe가 세션 경계를 넘음" }
        return $f
    }}

    @{ Id = "C11"; Name = "구 3컬럼 INDEX 호환 — 매칭/주입"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"           = New-IndexText @('| 1 | 로고, 배너 | L1/domain-brand.md |') $false
            ".ctxdb\L1\domain-brand.md" = New-L1Text "domain-brand.md" @("L2/brand.md")
            ".ctxdb\L2\brand.md"        = "# brand"
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        $r = Invoke-Hook $fx "로고 얘기"
        $f = @()
        if ($r.Status -notmatch "L2/brand\.md") { $f += "3컬럼 INDEX에서 L1 본문 포인터 미회수: $($r.Status)" }
        return $f
    }}

    @{ Id = "C12"; Name = "구 3컬럼 INDEX 호환 — L3 아카이브 회수"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"           = New-IndexText @('| 1 | 배포, deploy | L1/domain-deploy.md |') $false
            ".ctxdb\L1\domain-deploy.md" = New-L1Text "domain-deploy.md" @("L3/deploy-old.md")
            ".ctxdb\L3\deploy-old.md"   = "## 배포 아카이브`n지난 배포 기록."
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        $r = Invoke-Hook $fx "배포 기록 보자"
        $f = @()
        if ($r.Status -notmatch "L3/deploy-old\.md") { $f += "3컬럼 + L3 조합 미회수: $($r.Status)" }
        return $f
    }}

    @{ Id = "C13"; Name = "mixed L2/L3 — 아카이브 미절단 (타입별 상한)"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"            = New-IndexText @('| 1 | 배포, deploy | L1/domain-deploy.md |')
            ".ctxdb\L1\domain-deploy.md" = New-L1Text "domain-deploy.md" @(
                "L2/a.md", "L2/b.md", "L2/c.md", "L2/d.md", "L2/e.md", "L3/old.md")
            ".ctxdb\L2\a.md" = "# a"; ".ctxdb\L2\b.md" = "# b"; ".ctxdb\L2\c.md" = "# c"
            ".ctxdb\L2\d.md" = "# d"; ".ctxdb\L2\e.md" = "# e"
            ".ctxdb\L3\old.md" = "## 배포 아카이브`n오래된 배포 기록."
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        $r = Invoke-Hook $fx "배포 기록"
        $f = @()
        if ($r.Status -notmatch "L3/old\.md") { $f += "앞선 L2 다수에 밀려 L3가 통째로 잘림: $($r.Status)" }
        return $f
    }}

    @{ Id = "C14"; Name = "조사 오분해 금지 — 음성 (전문가 -/-> 전문)"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"          = New-IndexText @('| 1 | 전문, 컨설팅 | L1/domain-spec.md | L2/spec.md |')
            ".ctxdb\L1\domain-spec.md" = New-L1Text "domain-spec.md"
            ".ctxdb\L2\spec.md"        = "# spec"
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        $r = Invoke-Hook $fx "전문가에게 물어봤다"
        $f = @()
        if (-not $r.Empty) { $f += "'전문가'를 '전문'+조사로 오분해해 오매칭: $($r.Status)" }
        return $f
    }}

    @{ Id = "C15"; Name = "INDEX 부재 진단 기록"; Run = {
        $fx = New-Fixture @{ ".ctxdb\L2\progress-current.md" = "# progress" }
        $r = Invoke-Hook $fx "로고 얘기"
        $f = @()
        if (-not $r.Empty) { $f += "INDEX 없는데 주입됨" }
        if ($r.Decision -notmatch "index-missing") { $f += "index-missing 미기록: '$($r.Decision)'" }
        return $f
    }}

    @{ Id = "C16"; Name = "L4 회수"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"            = New-IndexText @('| 1 | 배포, deploy | L1/domain-deploy.md | L4/ancient.md |')
            ".ctxdb\L1\domain-deploy.md" = New-L1Text "domain-deploy.md"
            ".ctxdb\L4\ancient.md"       = "## 배포 태초 기록`n가장 오래된 배포 로그."
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        $r = Invoke-Hook $fx "배포 태초 기록"
        $f = @()
        if ($r.Status -notmatch "L4/ancient\.md") { $f += "L4 미회수 — 정규식이 L4를 빠뜨림: $($r.Status)" }
        return $f
    }}

    @{ Id = "C17"; Name = "아카이브 블록 60줄 컷"; Run = {
        $big = "## 배포 대량 블록`n" + ((1..200 | ForEach-Object { "배포 로그 라인 $_" }) -join "`n")
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"            = New-IndexText @('| 1 | 배포, deploy | L1/domain-deploy.md | L3/big.md |')
            ".ctxdb\L1\domain-deploy.md" = New-L1Text "domain-deploy.md"
            ".ctxdb\L3\big.md"           = $big
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        $r = Invoke-Hook $fx "배포 로그"
        $f = @()
        $block = Get-InjectedBlock $r.Context "L3/big.md"
        if ($block.Count -eq 0) { $f += "L3 블록 미주입" }
        elseif ($block.Count -gt 60) { $f += "60줄 컷 미적용 — 실제 $($block.Count)줄" }
        return $f
    }}

    @{ Id = "C19"; Name = "영문 어간 + 한글 조사 (React를)"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"          = New-IndexText @('| 1 | react, 프론트 | L1/domain-front.md | L2/front.md |')
            ".ctxdb\L1\domain-front.md" = New-L1Text "domain-front.md"
            ".ctxdb\L2\front.md"       = "# front"
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        $r = Invoke-Hook $fx "React를 쓰자"
        $f = @()
        if ($r.Empty) { $f += "무주입 — 영문 어간이라 받침 계산 불가로 조사 스트립이 중단됨" }
        if ($r.Status -notmatch "L2/front\.md") { $f += "status에 L2/front.md 없음: $($r.Status)" }
        return $f
    }}

    @{ Id = "C20"; Name = "영문 어간 + A형 조사 (Docker에서)"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"          = New-IndexText @('| 1 | docker, 컨테이너 | L1/domain-infra.md | L2/infra.md |')
            ".ctxdb\L1\domain-infra.md" = New-L1Text "domain-infra.md"
            ".ctxdb\L2\infra.md"       = "# infra"
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        $r = Invoke-Hook $fx "Docker에서 확인해줘"
        $f = @()
        if ($r.Status -notmatch "L2/infra\.md") { $f += "A형 조사 + 영문 어간 미회수: $($r.Status)" }
        return $f
    }}

    @{ Id = "C21"; Name = "영문 어간 + 로 (Flutter로)"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"          = New-IndexText @('| 1 | flutter, 앱 | L1/domain-app.md | L2/app.md |')
            ".ctxdb\L1\domain-app.md"  = New-L1Text "domain-app.md"
            ".ctxdb\L2\app.md"         = "# app"
            ".ctxdb\L2\progress-current.md" = "# progress"
        }
        $r = Invoke-Hook $fx "Flutter로 만들자"
        $f = @()
        if ($r.Status -notmatch "L2/app\.md") { $f += "Rieul 예외형 조사 + 영문 어간 미회수: $($r.Status)" }
        return $f
    }}

    @{ Id = "C18"; Name = "Codex pointer 모드 렌더링"; Runtime = "codex"; Run = {
        $fx = New-Fixture @{
            ".ctxdb\INDEX.md"           = New-IndexText @($brandRow4)
            ".ctxdb\L1\domain-brand.md" = New-L1Text "domain-brand.md"
            ".ctxdb\L2\brand.md"        = "# brand"
            ".ctxdb\L2\progress-current.md" = "# progress"
        } -PointerMode
        $r = Invoke-Hook $fx "로고 얘기"
        $f = @()
        if ($r.Empty) { $f += "무주입" }
        if ($r.Context -notmatch "\(pointer\)") { $f += "pointer 헤더 없음" }
        if ($r.Context -notmatch "read: \.ctxdb/L2/brand\.md") { $f += "read 지시 미생성" }
        if ($r.Context -match "^# brand") { $f += "pointer 모드인데 본문이 실림" }
        return $f
    }}
)

# ─── 러너 ────────────────────────────────────────────────────────────────────

$wanted = @()
if ($Filter) { $wanted = ($Filter -split "[,\s]+") | Where-Object { $_ } }

Write-Host ""
Write-Host "ctxdb recall regression — hook: $Hook (runtime: $script:Runtime)" -ForegroundColor Cyan
Write-Host ""

$pass = 0; $fail = 0; $skip = 0
$failed = @()

foreach ($case in $cases) {
    if ($wanted.Count -gt 0 -and $wanted -notcontains $case.Id) { continue }
    if ($case.Runtime -and $case.Runtime -ne $script:Runtime) {
        Write-Host ("  SKIP  {0,-4} {1}  ({2} 전용)" -f $case.Id, $case.Name, $case.Runtime) -ForegroundColor DarkGray
        $skip++
        continue
    }
    try { $reasons = @(& $case.Run) }
    catch { $reasons = @("러너 예외: $($_.Exception.Message)") }

    if ($reasons.Count -eq 0) {
        Write-Host ("  PASS  {0,-4} {1}" -f $case.Id, $case.Name) -ForegroundColor Green
        $pass++
    } else {
        Write-Host ("  FAIL  {0,-4} {1}" -f $case.Id, $case.Name) -ForegroundColor Red
        foreach ($reason in $reasons) { Write-Host "          - $reason" -ForegroundColor Red }
        $fail++; $failed += $case.Id
    }
}

Write-Host ""
$color = if ($fail -eq 0) { "Green" } else { "Red" }
Write-Host ("결과: {0}/{1} PASS" -f $pass, ($pass + $fail)) -ForegroundColor $color -NoNewline
if ($skip -gt 0) { Write-Host ("  (+{0} SKIP)" -f $skip) -ForegroundColor DarkGray } else { Write-Host "" }
if ($fail -gt 0) { Write-Host ("실패: " + ($failed -join ", ")) -ForegroundColor Red }

if ($KeepFixtures) {
    Write-Host "픽스처 보존: $script:TmpRoot" -ForegroundColor DarkCyan
} else {
    Remove-Item $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ""

if ($fail -gt 0) { exit 1 } else { exit 0 }
