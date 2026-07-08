# PawPad — Agentic Engineering Toolkit | Setup Script v2.42 (Unified Claude + Codex Distribution, PowerShell)
# STATUS: FROZEN (v2.42. v2.41 기반 + retrieval 계측 시각화 강화 — statusline "📡 cmap N ctx N src N"에 ①색상(라우팅 활성 cmap|ctx>0=초록 / 소스직행 src만=노랑 경고) ②route%=(cmap+ctx)/total ③hit%=codemap·ctxdb 선언 hit·miss율(stop-check가 완료 응답의 "📡 Retrieval:" 라인 파싱→claude-retrieval-stats 누적, uuid dedupe·미사용 턴 분모제외). statusline은 UI 렌더=모델 토큰 0. 스킬 19 불변. 보고서: docs/CHANGELOG_v2.42.md.
#         이전: v2.41 retrieval-source 표시 A+B(선언식 "📡 Retrieval" 라인 + 계측식 read-track hook→statusline "cmap N ctx N src N"). 보고서: docs/CHANGELOG_v2.41.md.
#         이전: v2.40 codemap trim-router(small-page, cap root2KB·그외4KB, lookup 알고리즘+의미매칭) + 내 보강: analyze hook 2단계 fix(-File 스크립트 통일 + stderr 재전송·exit2/0 정규화 + Unix pipefail). 보고서: docs/CHANGELOG_v2.40.md).
#         이전: v2.38 codemap ON START 부분읽기 — MAP+HOT(조망)만 read, INDEX(전체 심볼표)는 심볼 필요 시 Grep on-demand. 코드세션 ON START codemap read ~7k→~0.5k tok 절감. 보고서: docs/CHANGELOG_v2.38.md).
#         이전: v2.36 통합 기획 뷰어(데이터-구동, no-backend) — 범용 spec-viewer.html(File System Access API)가 고정명 외부 JSON(src/viewer/{prd,fts,userflow,wire}.json)을 폴더 1회 선택 후 자동 로드·편집·제자리 저장·재로드. 신규 스킬 viewer-apply(19→20) + mockup viewer 모드. 보고서: docs/CHANGELOG_v2.36.md).
#         이전: v2.35 resume 최소로드 — ON START 읽기 토큰 절감(HYBRID 조건부화+_meta RECENT skip). 보고서: docs/CHANGELOG_v2.35.md).
#         이전: v2.34 skill rename memory → resume. 보고서: docs/CHANGELOG_v2.34.md).
#         이전: v2.33 code-delegate 스킬 신규(18→19) — 코딩 단계 서브에이전트 위임(설계=상위 Opus, 코딩=하위 모델). 보고서: docs/CHANGELOG_v2.33.md).
#         이전: v2.32 clarity 접근법 게이트(brainstorming "2-3 대안 제시" 이식). 보고서: docs/CHANGELOG_v2.32.md).
#         이전: v2.25 skill rename karpathy -> lean-code(인물명 제거, -Upgrade 구 섹션명 자동 마이그레이션) + 임베디드 템플릿 동기(session-token-slim, statusline ctx-accuracy). 보고서: docs/CHANGELOG_v2.25.md).
#         이전: v2.24 설치 UI live 모드(진행 바 1줄 제자리 갱신(`r) + 파일 로그 숨김(-ShowLog 복원) + 배너 발바닥 아트 보정. 설치 내용물 변경 없음. 보고서: docs/CHANGELOG_v2.24.md).
#         이전: v2.23 설치 UI 도입(paw 배너 + 28단계 진행 바 + 실측 체크리스트, Codex 리뷰 PASS. 보고서: docs/CHANGELOG_v2.23.md).
#         - Stack 프리셋: flutter | node | python | generic (생략 시 대화형 선택)
#         - hooks/statusline: Windows=.ps1 / Unix=.sh, settings.json이 설치 OS 감지해 자동 선택
#         - Codex native hooks: /hooks trust 후 ctxdb/codemap 최소 로드 + checkpoint continuation.
#         이전: v2.17 statusLine/ctxdb/codemap(FROZEN). 보고서: docs/CHANGELOG_v2.17.md.
#         변경 시 새 버전 번호 + 변경 보고서 + Codex 리뷰 절차 따를 것.
# Usage: .\pawpad-setup.ps1 [-Stack <flutter|node|python|generic>] [-Force | -Upgrade] [-ShowLog] [-Preset <lean|standard|full>] [-Bundles <prd,ui,delegate,review>] [-Lang <en|ko>]
#        -Stack/-Preset/-Lang 생략 시 대화형 프롬프트(Enter=generic/full/ko). pwsh로 Mac/Linux에서도 실행 가능.
#
# 한 번에 모든 것을 세팅합니다:
# - CLAUDE.md, AGENTS.md (Context files, 하이브리드 프로토콜 반영)
# - .claude/settings.json (Claude Code hooks: SessionStart 자동주입 + Stop decision:block)
# - .claude/hooks/* (session-start.{ps1,sh}, stop-check.{ps1,sh}, statusline.{ps1,sh} - 크로스플랫폼 자동화/상태줄)
# - .claude/skills/* (resume, codemap, codebase-map, caveman, lean-code, feature-architecture, clarity, handoff, checkpoint, grill-me, to-prd, design, mockup, review, code-delegate, viewer-apply, ctxdb-navigator, context-saver, security-check)
# - .agents/skills/* (Codex repo skill mirror, .claude/skills 단일 소스에서 재생성)
# - .claude/pawpad/* (_wip router, wip/lanes, wip/done, handoffs/, specs/, decisions/)
# - .claude/codemap/_index.md
# - .ctxdb/* (키워드 depth 컨텍스트 DB: INDEX/L1/L2, 토큰 절약 lazy-load)
# - .claude/HYBRID.md (Claude Code <-> Codex 협업)
# - .codex/config.json (보조 설정. projectName 자동 추출)
# - .codex/config.toml, .codex/hooks.json, .codex/hooks/* (Codex native lifecycle hooks)
# - .gitignore (PawPad backup 디렉토리 제외)
#
# -Force : 기존 파일 덮어쓰기 (기본: 기존 파일 건너뜀)
# -Upgrade : 기존 설치 업그레이드. 툴킷 소유 파일만 갱신(UPDATED), 사용자 데이터 보존(SKIP),
#            혼합 파일(CLAUDE/AGENTS/settings/config.json)은 툴킷 섹션·키만 자동 병합(MERGED).
#            -Force와 동시 지정 불가. 실행 전 -Force와 동일하게 자동 백업.
#         사용자 데이터 자동 백업 후 덮어쓰기 (.claude/pawpad/backup/{timestamp}/)
#         백업 대상: PawPad + Context files + Codex adapter files
#
# 실행 위치: 프로젝트 루트에서 실행
#   .\pawpad-setup.ps1
#   .\pawpad-setup.ps1 -Force
#   .\pawpad-setup.ps1 -Upgrade
#
# 실행 정책 오류 시:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

param([switch]$Force, [switch]$Upgrade, [string]$Stack = "", [switch]$ShowLog, [string]$Preset = "", [string]$Bundles = "", [string]$Lang = "")

if ($Force -and $Upgrade) {
    Write-Host "ERROR: -Force와 -Upgrade는 동시 지정 불가. 하나만 선택하세요." -ForegroundColor Red
    exit 1
}

$ver = "2.42"
$created = 0
$skipped = 0
$failed = 0
$updated = 0
$merged = 0
$mergePending = @()
$today = Get-Date -Format "yyyy-MM-dd"
$projectName = Split-Path (Get-Location) -Leaf

function ConvertTo-ForwardSlashPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $abs = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location).Path $Path }
    return $abs.Replace('\', '/')
}

# ── Install UI (paw 배너 + 실시간 진행 바 + 설치 체크리스트) ──────────────────────
# 블록 문자(█▄▀░)·체크 마크 출력을 위해 콘솔 UTF-8 보장 (legacy cp949 콘솔 대비)
try { if ([Console]::OutputEncoding.CodePage -ne 65001) { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } } catch {}
$script:E = [char]27
$script:useAnsi = $false
try {
    # truecolor ANSI: Windows Terminal / ConEmu / pwsh 7+ / TERM_PROGRAM 감지. 리다이렉트 시 비활성.
    $script:useAnsi = (-not [Console]::IsOutputRedirected) -and
        (($env:WT_SESSION) -or ($env:ConEmuANSI -eq 'ON') -or ($env:TERM_PROGRAM) -or ($PSVersionTable.PSVersion.Major -ge 7))
} catch {}

function Write-UiLine {
    # ANSI truecolor 지원 시 escape 코드, 아니면 ConsoleColor 폴백
    param([string]$Text, [string]$Ansi = '', [ConsoleColor]$Fallback = [ConsoleColor]::Gray)
    if ($script:useAnsi -and $Ansi) {
        Write-Host ("{0}[{1}m{2}{0}[0m" -f $script:E, $Ansi, $Text)
    } else {
        Write-Host $Text -ForegroundColor $Fallback
    }
}

# live 모드: 진행 바 1줄 제자리 갱신 + 파일 단위 로그 숨김 (FAILED 등 -Always 예외).
# -ShowLog 지정 또는 비ANSI/리다이렉트 환경이면 기존 순차 출력 유지 (CI 로그 보존).
$script:uiLive = $script:useAnsi -and -not $ShowLog
$script:barOnLine = $false
$script:lastBarLen = 0

function Write-InstallLog {
    # 설치 중 파일 단위 로그 출력 게이트. live 모드에서는 숨김(-Always 예외).
    # 바가 화면에 떠 있으면 줄을 내려서 바를 침범하지 않게 출력.
    param([string]$Text, [ConsoleColor]$Color = [ConsoleColor]::Gray, [switch]$Always)
    if ($script:uiLive -and -not $Always) { return }
    if ($script:barOnLine) { Write-Host ""; $script:barOnLine = $false }
    Write-Host $Text -ForegroundColor $Color
}

$script:uiCoral = '38;2;240;130;130'   # pawpad-mark.png 발바닥 코랄
$script:uiMint  = '38;2;126;200;177'   # pawpad-mark.png 원 테두리 민트

function Show-PawBanner {
    $rule = '  ' + ('═' * 29)
    $paw = @(
        '          ▄██▄    ▄██▄',
        '          ████    ████',
        '          ▀██▀    ▀██▀',
        '     ▄██▄     ▄▄▄▄     ▄██▄',
        '     ████   ▄██████▄   ████',
        '     ▀██▀ ▄██████████▄ ▀██▀',
        '         ██████████████',
        '        ████████████████',
        '        ████████████████',
        '         ▀████▀  ▀████▀'
    )
    Write-Host ""
    Write-UiLine $rule $script:uiMint Cyan
    Write-Host ""
    foreach ($l in $paw) { Write-UiLine $l $script:uiCoral Red }
    Write-Host ""
    Write-UiLine '         P A W   P A D' '1;37' White
    Write-UiLine '   Agentic Engineering Toolkit' $script:uiMint Cyan
    Write-Host ""
    Write-UiLine $rule $script:uiMint Cyan
    Write-UiLine "  Installing PawPad Toolkit  v$ver" '37' Gray
}

# 진행 단계: Step-Begin 호출 수와 $stepTotal 일치 유지 (불일치 시 % 표시만 어긋남, 동작 무관)
$script:stepTotal = 28
$script:stepIndex = 0
$script:stepResults = @()
$script:currentStep = $null
$script:stepFailBase = 0
$script:stepWriteBase = 0
$script:stepMergeQBase = 0
$script:mergePassHadFailure = $false

function Complete-CurrentStep {
    # 직전 단계 실제 결과 판정: 단계 중 failed 증가=fail, 쓰기(생성/갱신/병합) 발생=ok,
    # MERGE-PENDING queue 발생=merge-q(후단 병합 pass 결과로 체크리스트 출력 시 확정), 전부 기존 유지=skip
    if ($null -ne $script:currentStep) {
        $status = if ($script:failed -gt $script:stepFailBase) { 'fail' }
                  elseif (($script:created + $script:updated + $script:merged) -gt $script:stepWriteBase) { 'ok' }
                  elseif ($script:mergePending.Count -gt $script:stepMergeQBase) { 'merge-q' }
                  else { 'skip' }
        $script:stepResults += [pscustomobject]@{ Name = $script:currentStep; Status = $status }
        $script:currentStep = $null
    }
}

function Step-Begin {
    param([string]$Label)
    Complete-CurrentStep
    $script:stepIndex++
    $script:currentStep = $Label
    $script:stepFailBase = $script:failed
    $script:stepWriteBase = $script:created + $script:updated + $script:merged
    $script:stepMergeQBase = $script:mergePending.Count
    $idx = [Math]::Min($script:stepIndex, $script:stepTotal)
    $done = $idx - 1
    $pct = [int][Math]::Floor($done * 100 / $script:stepTotal)
    $width = 30
    $fill = [int][Math]::Floor($width * $done / $script:stepTotal)
    $bar = ('█' * $fill) + ('░' * ($width - $fill))
    $line = "  [{0}] {1,3}%  ({2,2}/{3})  {4}" -f $bar, $pct, $idx, $script:stepTotal, $Label
    if ($script:uiLive) {
        # 한 줄 제자리 갱신: `r로 줄 처음 복귀 + 이전 라벨이 더 길었으면 공백으로 지움
        $pad = [Math]::Max(0, $script:lastBarLen - $line.Length)
        Write-Host -NoNewline ("`r" + ("{0}[{1}m{2}{0}[0m" -f $script:E, $script:uiMint, $line) + (' ' * $pad))
        $script:lastBarLen = $line.Length
        $script:barOnLine = $true
    } else {
        Write-Host ""
        Write-UiLine $line $script:uiMint Cyan
    }
}

function Show-InstallChecklist {
    # 설치 종료 시 단계별 실제 결과 2열 체크리스트 출력
    Complete-CurrentStep
    $final = "  [{0}] 100%  ({1}/{1})  complete" -f ('█' * 30), $script:stepTotal
    if ($script:uiLive -and $script:barOnLine) {
        # live 바를 100%로 마지막 갱신 후 줄 확정
        $pad = [Math]::Max(0, $script:lastBarLen - $final.Length)
        Write-Host ("`r" + ("{0}[{1}m{2}{0}[0m" -f $script:E, $script:uiMint, $final) + (' ' * $pad))
        $script:barOnLine = $false
    } else {
        Write-Host ""
        Write-UiLine $final $script:uiMint Cyan
    }
    Write-Host ""
    Write-Host $L.checklistHeader -ForegroundColor White
    $items = @($script:stepResults)
    # merge-q 확정: 후단 병합 pass(이 함수보다 먼저 실행됨) 실패 여부로 판정
    foreach ($pending in $items) {
        if ($pending.Status -eq 'merge-q') {
            $pending.Status = if ($script:mergePassHadFailure) { 'fail' } else { 'ok' }
        }
    }
    for ($i = 0; $i -lt $items.Count; $i += 2) {
        Write-Host '  ' -NoNewline
        foreach ($j in @($i, ($i + 1))) {
            if ($j -ge $items.Count) { break }
            $it = $items[$j]
            $mark = '-'; $color = [ConsoleColor]::DarkGray
            if ($it.Status -eq 'ok')   { $mark = '✓'; $color = [ConsoleColor]::Green }
            if ($it.Status -eq 'fail') { $mark = '✗'; $color = [ConsoleColor]::Red }
            $cell = "$mark $($it.Name)"
            if ($cell.Length -lt 32) { $cell = $cell.PadRight(32) }
            Write-Host $cell -NoNewline -ForegroundColor $color
        }
        Write-Host ''
    }
}

Show-PawBanner

# ── 안내 언어 테이블 (Install guidance i18n, v2.39) ──────────────────────────────
# 사람 대상 안내 메시지만 지역화. 스킬 내용/CLAUDE.md 등 에이전트 문서는 무관(단일 소스).
$TR = @{
    ko = @{
        stackPrompt = "스택 선택 (Enter=generic):"; stackOpts = "  1) flutter   2) node   3) python   4) generic"
        inputNumName = "번호 또는 이름"; unknownStack = "알 수 없는 스택 '{0}' -> generic 사용"
        bundlePrompt = "스킬 번들 선택 (Enter=full 전체 설치):"; bundleOpts = "  1) lean (Core 11)   2) standard (Core+PRD+위임+리뷰 16)   3) full (전체 19)"
        unknownPreset = "알 수 없는 preset '{0}' -> full 사용"; bundleLine = "번들 설치: {0} = {1} 스킬 (제거 {2}: {3})"
        coreOnly = "Core 전용"; corePlus = "Core + "
        complete = "프로젝트 초기화 완료 (PawPad v{0})"; failed = "{0} 개 항목 실패. 권한 확인 후 다시 시도하세요."
        genericNote1 = "[generic] CLAUDE.md / AGENTS.md / config.json 의 <YOUR_*> 플레이스홀더를 실제 값으로 채우세요."
        genericNote2 = "          (analyze 명령 미지정 -> PostToolUse 자동검사 hook은 생략됨)"
        nextSteps = "다음 단계:"
        step1 = "  1. CLAUDE.md / AGENTS.md 의 Stack(Commands/Boundaries) 정보 확인 및 수정"
        step2 = "  2. .claude/pawpad/_meta.md 의 STACK 정보 확인"
        step3 = "  3. .claude/HYBRID.md 읽기 (협업 프로토콜 숙지)"
        step4 = "  4. 기존 코드 있으면: '.claude/codemap/_index.md 초기값 만들어줘' 요청"
        forceHint1 = "기존 파일 덮어쓰려면: .\pawpad-setup.ps1 -Force"
        forceHint2 = "기존 설치 업그레이드: .\pawpad-setup.ps1 -Upgrade (사용자 데이터 보존, 툴킷 파일만 갱신)"
        forceHint3 = "(둘 다 PawPad + Context files 자동 백업됩니다)"
        shadow1 = "⚠ 전역 Codex 스킬 섀도잉 감지: ~/.codex/skills/ 에 동일 이름 스킬 {0}개"
        shadow3 = "  Codex는 전역을 repo mirror(.agents/skills)보다 우선 조회 -> 구버전 섀도잉 위험."
        shadow4 = "  정리 권장(삭제 아닌 백업 이동): Move-Item '{0}\{{skill}}' '{0}.pawpad-backup\'"
        doneShort = "설치 완료 (PawPad v{0})."
        checklistHeader = "  설치 체크리스트 (✓ 설치/갱신/병합 · - 기존 유지 · ✗ 실패):"
        backupNone = "  (백업할 데이터 없음)"
    }
    en = @{
        stackPrompt = "Select stack (Enter=generic):"; stackOpts = "  1) flutter   2) node   3) python   4) generic"
        inputNumName = "number or name"; unknownStack = "Unknown stack '{0}' -> using generic"
        bundlePrompt = "Select skill bundles (Enter=full):"; bundleOpts = "  1) lean (Core 11)   2) standard (Core+PRD+delegate+review 16)   3) full (all 19)"
        unknownPreset = "Unknown preset '{0}' -> using full"; bundleLine = "Bundles: {0} = {1} skills (removed {2}: {3})"
        coreOnly = "Core only"; corePlus = "Core + "
        complete = "Project initialized (PawPad v{0})"; failed = "{0} item(s) failed. Check permissions and retry."
        genericNote1 = "[generic] Fill <YOUR_*> placeholders in CLAUDE.md / AGENTS.md / config.json with real values."
        genericNote2 = "          (no analyze command set -> PostToolUse auto-check hook skipped)"
        nextSteps = "Next steps:"
        step1 = "  1. Review/edit Stack info (Commands/Boundaries) in CLAUDE.md / AGENTS.md"
        step2 = "  2. Check STACK info in .claude/pawpad/_meta.md"
        step3 = "  3. Read .claude/HYBRID.md (collaboration protocol)"
        step4 = "  4. If existing code: ask 'create initial .claude/codemap/_index.md'"
        forceHint1 = "Overwrite existing files: .\pawpad-setup.ps1 -Force"
        forceHint2 = "Upgrade existing install: .\pawpad-setup.ps1 -Upgrade (preserves user data, toolkit files only)"
        forceHint3 = "(both auto-backup PawPad + Context files)"
        shadow1 = "WARNING: global Codex skill shadowing: {0} same-named skill(s) in ~/.codex/skills/"
        shadow3 = "  Codex queries global before repo mirror (.agents/skills) -> stale-version shadowing risk."
        shadow4 = "  Recommended (backup-move, not delete): Move-Item '{0}\{{skill}}' '{0}.pawpad-backup\'"
        doneShort = "Install complete (PawPad v{0})."
        checklistHeader = "  Install checklist (✓ installed/updated/merged · - kept · ✗ failed):"
        backupNone = "  (no data to back up)"
    }
}
# ── 언어 선택 (Language) ─────────────────────────────────────────────────────────
$validLangs = @('en', 'ko')
if (-not $Lang) {
    $lsel = ''
    try {
        if (-not [Console]::IsInputRedirected) {
            Write-Host ""
            Write-Host "Language / 언어 (Enter=ko):" -ForegroundColor Cyan
            Write-Host "  1) English   2) 한국어"
            $lsel = Read-Host "number / 번호"
        }
    } catch { $lsel = '' }
    switch -Regex ($lsel.Trim().ToLower()) { '^(1|en|english)$' { $Lang = 'en' } default { $Lang = 'ko' } }
}
$Lang = $Lang.Trim().ToLower()
if ($validLangs -notcontains $Lang) { $Lang = 'ko' }
$L = $TR[$Lang]

# ── Stack 선택 (v2.15) ─────────────────────────────────────────────────────────
$validStacks = @('flutter', 'node', 'python', 'generic')
if (-not $Stack) {
    Write-Host ""
    Write-Host $L.stackPrompt -ForegroundColor Cyan
    Write-Host $L.stackOpts
    try { $sel = Read-Host $L.inputNumName } catch { $sel = "" }
    switch -Regex ($sel.Trim().ToLower()) {
        '^(1|flutter)$' { $Stack = 'flutter' }
        '^(2|node)$'    { $Stack = 'node' }
        '^(3|python)$'  { $Stack = 'python' }
        default         { $Stack = 'generic' }
    }
}
$Stack = $Stack.Trim().ToLower()
if ($validStacks -notcontains $Stack) {
    Write-Host ($L.unknownStack -f $Stack) -ForegroundColor Yellow
    $Stack = 'generic'
}

# ── Bundle 선택 (선택 번들 설치, v2.39) ──────────────────────────────────────────
# Core 11 항상 설치. Optional 번들: prd / ui / delegate / review. ui·delegate는 prd 의존(자동 포함).
$validBundles = @('prd', 'ui', 'delegate', 'review')
$bundlePresets = @{ lean = @(); standard = @('prd', 'delegate', 'review'); full = @('prd', 'ui', 'delegate', 'review') }
$script:bundleSelected = @()
$script:bundleMode = 'full'
if ($Preset) {
    $pk = $Preset.Trim().ToLower()
    if (-not $bundlePresets.ContainsKey($pk)) { Write-Host ($L.unknownPreset -f $pk) -ForegroundColor Yellow; $pk = 'full' }
    $script:bundleSelected = @($bundlePresets[$pk])
    $script:bundleMode = if ($pk -eq 'full') { 'full' } else { 'custom' }
}
elseif ($Bundles) {
    $script:bundleSelected = @($Bundles.Split(',') | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -and ($validBundles -contains $_) })
    $script:bundleMode = 'custom'
}
else {
    $bsel = ''
    try {
        if (-not [Console]::IsInputRedirected) {
            Write-Host ""
            Write-Host $L.bundlePrompt -ForegroundColor Cyan
            Write-Host $L.bundleOpts
            $bsel = Read-Host $L.inputNumName
        }
    } catch { $bsel = '' }
    switch -Regex ($bsel.Trim().ToLower()) {
        '^(1|lean)$' { $script:bundleSelected = @($bundlePresets['lean']); $script:bundleMode = 'custom' }
        '^(2|standard)$' { $script:bundleSelected = @($bundlePresets['standard']); $script:bundleMode = 'custom' }
        default { $script:bundleSelected = @($bundlePresets['full']); $script:bundleMode = 'full' }
    }
}

# OS 감지 (Windows PowerShell 5.1: $IsWindows 자동변수 미정의 -> Windows로 간주. pwsh: 정의됨)
$isWin = (-not (Test-Path variable:IsWindows)) -or $IsWindows

# ── Stack 프로파일 (스택별 Commands / Boundaries / Directories / Conventions / ADR) ──
$profiles = @{ }
$profiles['flutter'] = @{
    Label = 'Flutter/Dart + Riverpod + Firestore'
    Commands = @'
- Install:     flutter pub get
- Dev:         flutter run
- Test:        flutter test
- Test single: flutter test test/path/to_test.dart
- Analyze:     dart analyze
- Lint:        dart fix --dry-run
- Build:       flutter build apk --release
- Codegen:     dart run build_runner build --delete-conflicting-outputs
'@
    NeverModify = @'
- lib/generated/
- pubspec.lock (without instruction)
- firebase_options.dart
'@
    NeverRun = @'
- Firestore Security Rules deployment
- Production build & upload
- Data migration or deletion scripts
'@
    Directories = @'
lib/
├── features/    # feature-first slices
├── core/        # shared services, repositories
├── models/      # freezed models
├── generated/   # do not touch
└── main.dart
'@
    Conventions = @'
- Models: freezed + json_serializable
- State:  Riverpod only - no mixing
- Screen files: snake_case_screen.dart
- Widget files: snake_case_widget.dart
- No dynamic types, no print(), no BuildContext across async gaps
- Constants: AppColors, AppStrings only
'@
    AnalyzePS   = 'dart analyze | Select-Object -Last 5'
    AnalyzeBash = 'dart analyze | tail -5'
    MetaStack   = 'Flutter+Riverpod+Firestore'
    StackInfo = @'
    "framework": "Flutter",
    "language": "Dart",
    "stateManagement": "Riverpod",
    "database": "Firestore"
'@
    VerifyCmds = '["dart analyze", "flutter test"]'
    Adr = @'
## ADR-001: 상태 관리 - Riverpod
결정: Riverpod 단독. 혼용 금지.
이유: 코드베이스 일관성.
날짜: __TODAY__

## ADR-002: 데이터 모델 - freezed + json_serializable
결정: 모든 모델에 적용.
이유: 불변성 보장, copyWith 자동 생성, JSON 직렬화 일관성.
날짜: __TODAY__
'@
}
$profiles['node'] = @{
    Label = 'Node.js + TypeScript'
    Commands = @'
- Install:     npm install
- Dev:         npm run dev
- Test:        npm test
- Test single: npm test -- path/to/test.spec.ts
- Analyze:     npx tsc --noEmit
- Lint:        npx eslint .
- Build:       npm run build
- Codegen:     (n/a)
'@
    NeverModify = @'
- node_modules/
- dist/ , build/
- package-lock.json (without instruction)
'@
    NeverRun = @'
- Production deploy (npm publish / release)
- Database migration scripts
- Destructive data scripts
'@
    Directories = @'
src/
├── routes/      # HTTP routes / controllers
├── services/    # business logic
├── models/      # types, schemas
├── lib/         # shared utils
└── index.ts
'@
    Conventions = @'
- TypeScript strict - no any, no implicit any
- ESLint + Prettier enforced
- Files: kebab-case.ts
- No console.log in committed code
- async/await - no floating promises
'@
    AnalyzePS   = 'npx tsc --noEmit | Select-Object -Last 5'
    AnalyzeBash = 'npx tsc --noEmit | tail -5'
    MetaStack   = 'Node+TypeScript'
    StackInfo = @'
    "framework": "Node.js",
    "language": "TypeScript",
    "stateManagement": "-",
    "database": "-"
'@
    VerifyCmds = '["npx tsc --noEmit", "npm test"]'
    Adr = @'
## ADR-001: 언어 - TypeScript strict
결정: strict 모드. any 금지.
이유: 타입 안정성, 리팩토링 내성.
날짜: __TODAY__

## ADR-002: 모듈 시스템 - ESM
결정: ESM(import/export) 사용.
이유: 표준 모듈, tree-shaking 지원.
날짜: __TODAY__
'@
}
$profiles['python'] = @{
    Label = 'Python'
    Commands = @'
- Install:     pip install -r requirements.txt
- Dev:         python -m app
- Test:        pytest
- Test single: pytest path/to/test.py::test_name
- Analyze:     mypy .
- Lint:        ruff check .
- Build:       python -m build
- Codegen:     (n/a)
'@
    NeverModify = @'
- .venv/ , venv/
- __pycache__/
- *.egg-info/
'@
    NeverRun = @'
- Production deploy / release
- Database migration (alembic upgrade) scripts
- Destructive data scripts
'@
    Directories = @'
src/
├── api/         # routes / endpoints
├── services/    # business logic
├── models/      # data models, schemas
├── core/        # config, shared
└── main.py
'@
    Conventions = @'
- Type hints required - mypy strict
- ruff (lint) + black (format)
- Files: snake_case.py
- No print() in committed code - use logging
- Constants: UPPER_SNAKE_CASE
'@
    AnalyzePS   = 'mypy . | Select-Object -Last 5'
    AnalyzeBash = 'mypy . | tail -5'
    MetaStack   = 'Python'
    StackInfo = @'
    "framework": "-",
    "language": "Python",
    "stateManagement": "-",
    "database": "-"
'@
    VerifyCmds = '["mypy .", "pytest"]'
    Adr = @'
## ADR-001: 타입 체크 - mypy strict
결정: 모든 함수 타입 힌트 + mypy strict.
이유: 런타임 오류 사전 차단.
날짜: __TODAY__

## ADR-002: 린트/포맷 - ruff + black
결정: ruff(lint) + black(format) 조합.
이유: 일관 포맷, 빠른 린트.
날짜: __TODAY__
'@
}
$profiles['generic'] = @{
    Label = '<YOUR_STACK>'
    Commands = @'
- Install:     <YOUR_INSTALL_CMD>
- Dev:         <YOUR_DEV_CMD>
- Test:        <YOUR_TEST_CMD>
- Test single: <YOUR_TEST_SINGLE_CMD>
- Analyze:     <YOUR_ANALYZE_CMD>
- Lint:        <YOUR_LINT_CMD>
- Build:       <YOUR_BUILD_CMD>
'@
    NeverModify = @'
- <BUILD_OUTPUT_DIR>      (예: dist/, build/, target/)
- <LOCKFILE> (without instruction)
- <GENERATED_DIR>
'@
    NeverRun = @'
- Production deploy / release
- Database migration or deletion scripts
- Destructive data scripts
'@
    Directories = @'
<YOUR_PROJECT_STRUCTURE>
(예시:)
src/
├── ...
└── ...
'@
    Conventions = @'
- <YOUR_CODE_CONVENTIONS>
- (예: 파일 명명 규칙, 타입 정책, 로깅 정책, 상수 정책)
'@
    AnalyzePS   = ''
    AnalyzeBash = ''
    MetaStack   = '<YOUR_STACK>'
    StackInfo = @'
    "framework": "<YOUR_FRAMEWORK>",
    "language": "<YOUR_LANGUAGE>",
    "stateManagement": "-",
    "database": "-"
'@
    VerifyCmds = '["<YOUR_ANALYZE_CMD>", "<YOUR_TEST_CMD>"]'
    Adr = @'
## ADR-001: (예시) 핵심 아키텍처 결정
결정: <결정 내용>
이유: <대안 대비 이 선택을 한 이유>
날짜: __TODAY__
# 되돌리기 어렵고 / 맥락 없이는 의외이고 / 실제 트레이드오프인 결정만 ADR-NNN으로 append.
'@
}

$p = $profiles[$Stack]
$pAdr = $p.Adr -replace '__TODAY__', $today

function Get-UpgradeAction {
    # -Upgrade 시 기존 파일 분류: OVERWRITE(툴킷 소유) / MERGE(혼합, post-pass 병합) / SKIP(사용자 데이터)
    param([string]$Path)
    $norm = $Path -replace '/', '\'
    $mixed = @('CLAUDE.md', 'AGENTS.md', '.codex\config.json', '.claude\settings.json')
    if ($norm -in $mixed) { return 'MERGE' }
    $toolkitExact = @(
        '.claude\pawpad\wip\README.md', '.claude\pawpad\wip\done\README.md',
        '.claude\pawpad\handoffs\README.md', '.claude\pawpad\handoffs\TEMPLATE.md',
        '.claude\pawpad\specs\README.md', '.claude\pawpad\specs\TEMPLATE.md',
        '.claude\pawpad\codebase\README.md', '.ctxdb\VERSION'
    )
    if ($norm -in $toolkitExact) { return 'OVERWRITE' }
    $userPrefixes = @('.claude\pawpad\', '.claude\codemap\', '.ctxdb\', '.claude\pawpad-config.json', 'CONTEXT.md')
    foreach ($u in $userPrefixes) { if ($norm -like "$u*") { return 'SKIP' } }
    return 'OVERWRITE'
}

function Write-FileContent {
    # -NoBom: UTF-8 BOM 없이 작성 (skill SKILL.md는 frontmatter '---'가 첫 바이트여야 등록됨.
    #         .json/.toml도 필수 — Codex/Claude JSON·TOML 파서가 leading BOM에서 "expected value line 1 col 1" 실패)
    # -Unix: UTF-8 BOM 없이 + LF 줄바꿈 (.sh 훅용. CRLF면 bash가 shebang을 깨먹음)
    param([string]$Path, [string]$Content, [switch]$NoBom, [switch]$Unix)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $writeMode = 'CREATE'
    if (Test-Path $Path) {
        if ($Force) { $writeMode = 'CREATE' }
        elseif ($Upgrade) {
            $ua = Get-UpgradeAction $Path
            if ($ua -eq 'OVERWRITE') { $writeMode = 'UPDATE' }
            elseif ($ua -eq 'MERGE') { $writeMode = 'MERGE-PENDING' }
            else { $writeMode = 'SKIP' }
        }
        else { $writeMode = 'SKIP' }
    }
    if ($writeMode -eq 'MERGE-PENDING') {
        $script:mergePending += ($Path -replace '/', '\')
        Write-InstallLog "  MERGE-Q $Path (혼합 파일, 설치 후 병합)" DarkCyan
    } elseif ($writeMode -eq 'SKIP') {
        Write-InstallLog "  SKIP    $Path" DarkGray
        $script:skipped++
    } else {
        try {
            if ($Unix) {
                $enc = New-Object System.Text.UTF8Encoding($false)
                $abs = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
                $lf = ($Content -replace "`r`n", "`n") + "`n"
                [System.IO.File]::WriteAllText($abs, $lf, $enc)
            } elseif ($NoBom) {
                $enc = New-Object System.Text.UTF8Encoding($false)
                $abs = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
                [System.IO.File]::WriteAllText($abs, ($Content + "`r`n"), $enc)
            } else {
                Set-Content -Path $Path -Value $Content -Encoding UTF8 -ErrorAction Stop
            }
            if ($writeMode -eq 'UPDATE') {
                Write-InstallLog "  UPDATED $Path" Cyan
                $script:updated++
            } else {
                Write-InstallLog "  CREATED $Path" Green
                $script:created++
            }
        } catch {
            # 쓰기 실패를 성공으로 보고하지 않음 (sandbox/권한 환경에서 Access denied 가능). live 모드에서도 항상 표시.
            Write-InstallLog "  FAILED  $Path ($($_.Exception.Message))" Red -Always
            $script:failed++
        }
    }
}

function Merge-MdToolkitSections {
    # 기존 md의 툴킷 소유 '## 섹션'만 템플릿 버전으로 교체. 사용자 섹션/헤더 보존.
    # 섹션 = '^## {name}' 줄부터 다음 '^## ' 직전까지. 기존에 없는 섹션은 파일 끝에 추가.
    param([string]$Path, [string]$Template, [string[]]$ToolkitSections)
    $abs = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
    $existing = [System.IO.File]::ReadAllText($abs)
    foreach ($sec in $ToolkitSections) {
        $pattern = "(?ms)^## $([regex]::Escape($sec))[ \t]*\r?$.*?(?=^## |\z)"
        $tm = [regex]::Match($Template, $pattern)
        if (-not $tm.Success) { continue }
        # 마지막 템플릿 섹션(예: Response Style)은 here-string 종료 직전이라 trailing newline이
        # 없을 수 있음. 개행 없는 값이 기존 파일 중간에 splice되면 다음 '## 헤더'가 같은 줄에
        # 붙으므로 항상 trailing newline 보장.
        $secText = $tm.Value
        if (-not $secText.EndsWith("`n")) { $secText += "`r`n" }
        $em = [regex]::Match($existing, $pattern)
        if ($em.Success) {
            $existing = $existing.Substring(0, $em.Index) + $secText + $existing.Substring($em.Index + $em.Length)
        } else {
            if (-not $existing.EndsWith("`n")) { $existing += "`r`n" }
            $existing += "`r`n" + $secText
        }
    }
    try {
        Set-Content -Path $Path -Value $existing -Encoding UTF8 -ErrorAction Stop
    } catch {
        # 쓰기 실패를 MERGED로 보고하지 않음 (읽기전용/잠금/권한). live 모드에서도 항상 표시.
        Write-InstallLog "  MERGE-FAIL $Path (쓰기 실패: $($_.Exception.Message))" Red -Always
        $script:failed++
        return
    }
    Write-InstallLog "  MERGED  $Path (toolkit sections: $($ToolkitSections.Count))" Cyan
    $script:merged++
}

function Merge-JsonToolkitKeys {
    # 기존 JSON의 툴킷 소유 최상위 키만 템플릿 값으로 교체. 사용자 키(미지 키 포함) 보존.
    param([string]$Path, [string]$Template, [string[]]$ToolkitKeys)
    try {
        $existingObj = Get-Content -Path $Path -Encoding UTF8 -Raw | ConvertFrom-Json -ErrorAction Stop
        $templateObj = $Template | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-InstallLog "  MERGE-FAIL $Path (JSON parse 실패 - 수동 병합 필요. 백업 참조)" Red -Always
        $script:failed++
        return
    }
    foreach ($key in $ToolkitKeys) {
        $tmplProp = $templateObj.PSObject.Properties[$key]
        if ($null -eq $tmplProp) { continue }
        if ($existingObj.PSObject.Properties[$key]) {
            $existingObj.$key = $tmplProp.Value
        } else {
            $existingObj | Add-Member -NotePropertyName $key -NotePropertyValue $tmplProp.Value
        }
    }
    $json = $existingObj | ConvertTo-Json -Depth 10
    # PS5.1 ConvertTo-Json은 non-ASCII를 \uXXXX로 escape -> 한글 가독성 복원
    $json = [regex]::Replace($json, '(?<!\\)\\u([0-9a-fA-F]{4})', { param($m) [string][char]([Convert]::ToInt32($m.Groups[1].Value, 16)) })
    try {
        # JSON은 BOM 없이 작성 (Codex/Claude JSON 파서가 leading BOM에서 parse 실패).
        $enc = New-Object System.Text.UTF8Encoding($false)
        $abs = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
        [System.IO.File]::WriteAllText($abs, ($json + "`r`n"), $enc)
    } catch {
        # 쓰기 실패를 MERGED로 보고하지 않음 (읽기전용/잠금/권한). live 모드에서도 항상 표시.
        Write-InstallLog "  MERGE-FAIL $Path (쓰기 실패: $($_.Exception.Message))" Red -Always
        $script:failed++
        return
    }
    Write-InstallLog "  MERGED  $Path (toolkit keys: $($ToolkitKeys -join ','))" Cyan
    $script:merged++
}

function Backup-ProjectData {
    # -Force 시 사용자 작성 PawPad + Context files 자동 백업
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
    $backupDir = ".claude\pawpad\backup\$timestamp"

    # 백업 대상: PawPad 데이터 + Context files (커스터마이징 보존)
    $preserveItems = @(
        # PawPad 데이터
        ".claude\pawpad\_wip.md",
        ".claude\pawpad\_meta.md",
        ".claude\pawpad\decisions",
        ".claude\codemap\_index.md",
        ".claude\pawpad\wip",
        ".claude\pawpad\handoffs",
        ".claude\pawpad\specs",
        ".claude\pawpad\verifications",
        ".claude\pawpad\codebase",
        ".ctxdb",
        ".claude\hooks",
        # Context files (사용자 커스터마이징 보존)
        "CLAUDE.md",
        "AGENTS.md",
        ".claude\HYBRID.md",
        ".claude\settings.json",
        ".claude\pawpad-config.json",
        ".codex\config.json",
        ".codex\config.toml",
        ".codex\hooks.json",
        ".codex\hooks",
        ".agents\skills",
        ".gitignore",
        "CONTEXT.md",
        ".claude\SKILLS_MANIFEST.md"
    )

    # 백업할 내용이 있는지 확인
    $hasContent = $false
    foreach ($item in $preserveItems) {
        if (Test-Path $item) {
            $hasContent = $true
            break
        }
    }
    if (-not $hasContent) { return $null }

    # 백업 디렉토리 생성
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # 각 항목 백업
    foreach ($item in $preserveItems) {
        if (Test-Path $item) {
            $dest = Join-Path $backupDir $item
            $destParent = Split-Path $dest -Parent
            if (-not (Test-Path $destParent)) {
                New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            }
            Copy-Item -Path $item -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    return $backupDir
}

function Update-Gitignore {
    # .gitignore에 PawPad 필수 항목 자동 추가
    $gitignorePath = ".gitignore"
    $pawpadEntries = @(
        ".claude/pawpad/backup/",
        ".claude/settings.local.json",
        ".ctxdb/.state/"
    )

    if (Test-Path $gitignorePath) {
        $existing = Get-Content $gitignorePath -Raw -ErrorAction SilentlyContinue
        if (-not $existing) { $existing = "" }
        $newEntries = @()
        foreach ($entry in $pawpadEntries) {
            if ($existing -notmatch [regex]::Escape($entry)) {
                $newEntries += $entry
            }
        }
        if ($newEntries.Count -gt 0) {
            $append = "`n# PawPad Agentic Engineering Toolkit`n" + ($newEntries -join "`n") + "`n"
            try {
                Add-Content -Path $gitignorePath -Value $append -Encoding UTF8 -NoNewline -ErrorAction Stop
                Write-InstallLog "  UPDATED .gitignore (PawPad entries appended)" Yellow
                $script:created++
            } catch {
                Write-InstallLog "  FAILED  .gitignore ($($_.Exception.Message))" Red -Always
                $script:failed++
            }
        } else {
            Write-InstallLog "  SKIP    .gitignore (PawPad entries already present)" DarkGray
            $script:skipped++
        }
    } else {
        $content = @"
# PawPad Agentic Engineering Toolkit
.claude/pawpad/backup/
.claude/settings.local.json
.ctxdb/.state/
"@
        try {
            Set-Content -Path $gitignorePath -Value $content -Encoding UTF8 -ErrorAction Stop
            Write-InstallLog "  CREATED .gitignore" Green
            $script:created++
        } catch {
            Write-InstallLog "  FAILED  .gitignore ($($_.Exception.Message))" Red -Always
            $script:failed++
        }
    }
}

Write-Host ""
Write-Host "Hybrid Harness (Claude Code <-> Codex)" -ForegroundColor Yellow
Write-Host "Project: $projectName" -ForegroundColor Yellow
Write-Host "Stack:   $Stack ($($p.Label))" -ForegroundColor Yellow
Write-Host "Hooks:   $(if ($isWin) { 'Windows (.ps1)' } else { 'Unix (.sh)' })" -ForegroundColor Yellow
Write-Host ""

# -Upgrade: v2.21 이하(KMS 경로) 설치본 자동 마이그레이션. 백업 전에 수행해 새 경로 기준으로 백업.
if ($Upgrade) {
    if ((Test-Path ".claude\KMS") -and -not (Test-Path ".claude\pawpad")) {
        Move-Item ".claude\KMS" ".claude\pawpad"
        Write-Host "  MIGRATED .claude\KMS -> .claude\pawpad (구버전 구조 이동, 내용 보존)" -ForegroundColor Cyan
    }
    if ((Test-Path ".claude\kms-config.json") -and -not (Test-Path ".claude\pawpad-config.json")) {
        Move-Item ".claude\kms-config.json" ".claude\pawpad-config.json"
        Write-Host "  MIGRATED .claude\kms-config.json -> .claude\pawpad-config.json" -ForegroundColor Cyan
    }
    # v2.34: skill rename memory -> resume. 구 디렉토리 Move/제거(신규 resume/ 재생성됨, 백업 전 수행).
    foreach ($skillRoot in @(".claude\skills", ".agents\skills")) {
        if ((Test-Path "$skillRoot\memory") -and -not (Test-Path "$skillRoot\resume")) {
            Move-Item "$skillRoot\memory" "$skillRoot\resume"
            Write-Host "  MIGRATED $skillRoot\memory -> $skillRoot\resume (v2.34 skill rename)" -ForegroundColor Cyan
        } elseif (Test-Path "$skillRoot\memory") {
            Remove-Item "$skillRoot\memory" -Recurse -Force
            Write-Host "  REMOVED  $skillRoot\memory (v2.34 skill rename, resume/ 재생성)" -ForegroundColor Cyan
        }
    }
    # v2.34: .codex/config.json skills 배열 "memory" -> "resume" (병합 union 시 구 항목 잔존 방지).
    if (Test-Path ".codex\config.json") {
        $cfgAbs = Join-Path (Get-Location) ".codex\config.json"
        $cfgText = [System.IO.File]::ReadAllText($cfgAbs)
        $cfgNew = $cfgText.Replace('"memory"', '"resume"')
        if ($cfgNew -ne $cfgText) {
            [System.IO.File]::WriteAllText($cfgAbs, $cfgNew, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "  MIGRATED .codex\config.json skills: memory -> resume (v2.34)" -ForegroundColor Cyan
        }
    }
    # v2.37: grill-with-docs -> grill-me 흡수. 구 스킬 디렉토리 제거(grill-me 재생성·보강됨, 백업 전 수행).
    foreach ($skillRoot in @(".claude\skills", ".agents\skills")) {
        if (Test-Path "$skillRoot\grill-with-docs") {
            Remove-Item "$skillRoot\grill-with-docs" -Recurse -Force
            Write-Host "  REMOVED  $skillRoot\grill-with-docs (v2.37 grill-with-docs -> grill-me 흡수)" -ForegroundColor Cyan
        }
    }
    # v2.37: .codex/config.json skills 배열에서 "grill-with-docs" 제거(병합 union 시 구 항목 잔존 방지).
    if (Test-Path ".codex\config.json") {
        $cfgAbs = Join-Path (Get-Location) ".codex\config.json"
        $cfgText = [System.IO.File]::ReadAllText($cfgAbs)
        $cfgNew = $cfgText -replace '(?m)^\s*"grill-with-docs",\r?\n', ''
        if ($cfgNew -ne $cfgText) {
            [System.IO.File]::WriteAllText($cfgAbs, $cfgNew, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "  MIGRATED .codex\config.json skills: grill-with-docs 제거 (v2.37)" -ForegroundColor Cyan
        }
    }
}

# -Force/-Upgrade 시 자동 백업 (PawPad + Context files)
if ($Force -or $Upgrade) {
    Write-Host "Backing up existing project data (PawPad + Context files)..." -ForegroundColor White
    $backupPath = Backup-ProjectData
    if ($backupPath) {
        Write-Host "  BACKUP  $backupPath" -ForegroundColor Yellow
    } else {
        Write-Host $L.backupNone -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ── CLAUDE.md ─────────────────────────────────────────────────────────────────
Step-Begin "CLAUDE.md"
$tmplClaudeMd = @"
# CLAUDE.md
# Tool: Claude Code | Stack: $($p.Label)
# Edit Commands / Directories / Conventions to match your project.

## Commands
$($p.Commands)

## Definition of Done
Task complete when ALL pass:
1. Analyze (Commands의 Analyze) - zero errors
2. Test (Commands의 Test) - all green
3. No files outside stated scope modified
4. lane 파일 갱신 또는 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동
5. .claude/codemap/_index.md updated for new/changed symbols
6. 핸드오프 발생 시 .claude/pawpad/handoffs/ snapshot 작성
7. lane ``## Verification Evidence``에 검증 근거 기록 — 최근 2건만 lane 유지, 초과분은 .claude/pawpad/verifications/{feature-id}-archive.md 상단 append + 포인터 1줄 (분석전용/소작업은 ``not applicable: analysis-only``). 규칙: .claude/HYBRID.md Verification Evidence.
8. 코드 변경 시 /security-check 🔴 zero (분석전용/문서전용 면제). 규칙: .claude/skills/security-check/SKILL.md
9. 코드 변경 시 신규/변경 코드가 Architecture Principles (Feature-First) 준수 (분석/문서전용 면제). 규칙: .claude/skills/feature-architecture/SKILL.md

## Escalation Rules
- Stuck > 3 attempts same error: STOP, report findings
- Scope unclear: ASK before touching new files
- Destructive op (DROP/DELETE/rm -rf): STOP, confirm
- Credential required: STOP - use env var reference

## Boundaries
NEVER modify:
$($p.NeverModify)

NEVER run without confirm:
$($p.NeverRun)

## Directories
$($p.Directories)

## Code Conventions
$($p.Conventions)

## Coding Principles (Lean Code)
1. Implement only what is asked. No extra abstractions.
2. Do not modify files outside stated scope.
3. Read existing code before writing new code.
4. When scope is unclear, ask before implementing.

## Architecture Principles (Feature-First)
신규/변경 코드만 적용(레거시 강제 리팩토링 X). 상세·결정트리: .claude/skills/feature-architecture/SKILL.md
1. 모듈 경계: 기능 폴더 응집(colocation) + 단일 public boundary(스택 관례). 내부 직접 import 금지.
2. 횡단 import 금지: 기능 간 내부 참조 X (public boundary 의존은 OK). 공통은 소속 범위 따라 hoist.
3. Rule of Three: 2곳 중복 유지, 3곳째 추출.
4. 신규 = 가산적: feature 내부 추가 중심 + route/menu registry 등 최소 integration edit 허용. integration 파일에 로직 늘면 경계 재검토.
새 기능 위치: 기존 도메인 하위 / 새 도메인 폴더 / 도메인 비소속 shared 중 하나. 결정트리는 skill 참조.

## Doc Update Rules
| Change           | Update target                            |
|------------------|------------------------------------------|
| Feature spec     | .claude/pawpad/specs/{feature-id}.md        |
| Feature/UX       | src/prd/{area}.md (영역 shard)            |
| New feature      | src/PRD-tree.md(인덱스 행) + src/prd/{area}.md(상세) |
| New screen/route | Feature ID in PRD-tree.md (인덱스)        |
| 메뉴구성도        | src/viewer/userflow.json (메뉴 계층 트리 JSON; 뷰어 드래그 편집·on-demand) |
| 스팩 진행률       | specs/{feature-id}.md 상단 status 행 (draft/ready/implementing/done — 뷰어 진행률 SoT) |
| 결정 기록 위치    | .claude/HYBRID.md Decision Placement Matrix 참조 |
| 검증 결과        | lane ``## Verification Evidence`` 최근 2건, 초과분 → .claude/pawpad/verifications/{feature-id}-archive.md (상단 append) |
PRD 상세 read: PRD-tree(인덱스) → lane feature-id 접두로 영역 해석 → 해당 src/prd/{area}.md만 (✓완료 영역 skip, 부족 시 on-demand). PRD-tree 영역 행에 상태 마커 ✓완료/🔨진행/⬜예정.
뷰어 데이터(src/viewer/*.json: prd/fts/userflow/wire)는 ON START/resume 자동 로드 금지 — /mockup viewer·/viewer-apply 등 해당 작업 시점에만 on-demand read(초기 기획 강화로 후속 수정 최소화·context 절감). 항목 존재=설계/개발 대상, status(예정/진행중/완료)는 agent가 구현하며 갱신.
Code + doc update = one atomic unit. Keep * markers accurate.

## Session Protocol
ON START (agent가 순차 실행):
  0. read .ctxdb/INDEX.md -> 첫 메시지 키워드 매칭 -> L1<=1 / L2<=2개만 로드 (전체 로드 금지)
     (hook 가용 시 자동 최소로드/checkpoint 주입; 상세: .ctxdb/L1/domain-codex-adapter.md. 첫 응답 최상단 검증 1줄: 📂 ctxdb: {project} | {last-date} | {loaded L2} | {status})
  1. read .claude/pawpad/_wip.md (active lane router)
  2. Active Lanes 있으면 read .claude/HYBRID.md (협업 프로토콜). 없으면 skip -> 신규 lane 생성/핸드오프/인수 시점에 read
  3. assigned lane 있으면 read .claude/pawpad/wip/{lane}.md
  4. _wip.md Active Lanes에 state=HANDOFF_TO_* 발견 시 -> handoff 필드 경로 read
  5. state=SPEC_READY 또는 spec 있으면 read .claude/pawpad/specs/{feature}.md
  6. read .claude/pawpad/_meta.md 상단만 (헤더 SPRINT/PHASE/STACK + BLOCKED + NEXT; RECENT 완료이력은 하단·재개 불요 -> 생략, history 시 on-demand)
  7. .claude/codemap/_index.md는 코드 수정 작업 시작 시점에 read — MAP+HOT(조망)만 부분읽기(상단), INDEX(전체 심볼표)는 심볼 필요 시 Grep on-demand (질문/분석 전용 세션은 skip)
ON SUBTASK DONE: agent가 lane 파일 next steps 갱신
ON TASK DONE:    agent가 lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 + _meta.md 1줄 append (RECENT 8줄 초과 시 초과분을 sessions/{YYYY-MM}.md 상단으로 이동, newest first 유지) + 완료(✅) 작업항목 누적 시 verifications/{feature-id}-tasklog.md 이월(HYBRID Completed Task Log) + _index.md 갱신 + git commit (git repo일 때만; 비-git이면 _meta RECENT에 "git unavailable" 기록, 완료 차단 안 함)
ON STOP:         agent가 lane 파일 (state + reason) 갱신
ON 8턴/60% CONTEXT: Stop hook이 8턴마다 checkpoint block -> context-saver(.ctxdb/L2 저장) + codemap 갱신. PreCompact hook이 native compaction 직전 동일 저장 유도(최근 8턴 내 발생 시 Stop checkpoint 중복 생략). 60% 시 /checkpoint -> 필요시 /handoff
-> Detail: .claude/skills/resume/SKILL.md | .claude/skills/codemap/SKILL.md | .claude/skills/ctxdb-navigator/SKILL.md | .claude/skills/context-saver/SKILL.md | .claude/skills/handoff/SKILL.md | .claude/skills/checkpoint/SKILL.md

## Hybrid Lane Rule
- 신규 작업: .claude/pawpad/wip/{feature-id}.md 생성 + _wip.md Active Lanes 등록
- 본인 lane만 수정. 타 에이전트 lane 읽기 가능, 수정 금지.
- 파일 충돌 위험 시 _wip.md Locks 섹션에 경로 매핑.
- codemap/_index.md: 추가는 누구나, 수정/삭제는 lane owner만.
- 완료 lane: wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 (삭제 금지, audit 보존, timestamp로 재작업 보존)
- 핸드오프 수신 시: state HANDOFF_TO_* -> WIP, owner -> 받는 agent로 변경
- 리뷰(review skill): state REVIEW_REQUESTED(요청, work owner 불변·``reviewer`` 지정) ↔ REVIEW_DONE(완료). 리뷰어는 work lane 미점유 — review state·result 경로만 갱신, work 내용 수정 X. 종결은 요청측 재량.

## Idea → PRD Routing
아이디어→PRD 구체화 시 agent가 다음 스킬 추천(강제 X, 명시 호출 우선).
판정: 정보 부족→clarity / 설계 결정 어려움→grill-me / 둘 다 충족→to-prd.
- 큰 덩어리: clarity 전 "분해 권장"(굵은 조각+순서, 조각별 반복).
- clarity PASS 후: grill-me 신호(결정 상호의존·트레이드오프 연쇄·스택/아키텍처/스키마 비가역) 있으면 →grill-me, 없으면 →to-prd.
- grill-me 종결 후: →to-prd.
- UI/화면 기획 시: design(토큰/레이아웃 게이트) + mockup(PRD-tree→단일 HTML 시각화, lo/hi-fi) 추천.
### 자동제안 (단계 경계)
agent가 흐름 중 다음 시점에 다음 스킬 또는 목업을 **1회 추천**(강제 X):
- PRD/PRD-tree 생성·갱신 직후 → mockup 추천(통합 4탭 검토는 /mockup viewer; 뷰어 결정 저장 통지 시 /viewer-apply 로 반영).
- clarity/grill-me/to-prd 종료 시 → 다음 단계 스킬 추천.
- 매 응답 판단 X(과추천 방지). 거절 시 같은 산출물 버전엔 재제안 X → 다음 단계 경계까지 침묵.
- 추천 대상 한정: clarity·grill-me·to-prd·design·mockup·brainstorming. 나머지(resume·codemap·security-check·checkpoint·handoff·context-saver 등)는 Session Protocol/DoD/hook이 트리거 → 자동제안 제외(이중 트리거 방지).
- 리뷰 제안(구현완료 경계): 코드/배포본 변경 완료(DoD) 직전 + 고위험·배포본 영향이면 → ``/review`` 1회 권장(강제 X, 저비용 문서형 라운드트립). 광범위·맹점우려·설치 스크립트 변경은 codex exec 자율 리뷰로 에스컬레이션.
- 코딩 위임 제안(구현 진입 경계): SPEC_READY 또는 written 설계 직후 코딩 진입 시 → ``/code-delegate`` 1회 권장(강제 X). 사용자 선택 모델의 코딩 서브에이전트로 위임해 부모 컨텍스트·토큰 절감(written 설계 없으면 제안 안 함, 이점 반감).
### 선택지 질문 = 체크박스
기획/설계 스킬(clarity·grill-me·to-prd·design·mockup·review) 진행 중 **선택지가 N개인 질문은 AskUserQuestion(체크박스)** 로 받는다. 자유서술·수치 입력은 텍스트 유지.

## Response Style
한글로 답변. 기술 용어 코드 원문 유지.
Terse. Drop: a/an/the, filler, pleasantries, hedging.
Pattern: [대상] [동작] [이유]. [다음 단계].
ACTIVE EVERY RESPONSE. Off: "normal mode"
-> Full rules: .claude/skills/caveman/SKILL.md

### Active Skills 표시 (매 응답 최상단 1줄)
형식: ``🐾 Active Skills: {활성 스킬 | 구분}`` (🐾=pawpad). 단계 첨자: ``clarity r2/5``, ``grill-me``, ``to-prd``, ``brainstorming``, ``design``, ``mockup lo/hi``, ``review``.
caveman 항상 포함. off 시 라인에 ``normal mode (caveman 압축 off)``로 표기(자기설명). 스킬 없으면 caveman만. ON START는 📂 ctxdb 라인 아래.

### Retrieval 표시 (탐색 수행 응답만, Active Skills 라인 아래 1줄)
형식: ``📡 Retrieval: codemap {hit(경로)|miss|미사용} | ctxdb {hit(파일)|miss|미사용} | src {read N (codemap 경유)|full-scan N (사유)}``
- 소스 탐색 전 codemap lookup 의무. miss여도 곧장 full-scan 금지 — keywords/INDEX 의미매칭 재시도 후에도 miss면 **사유와 함께 full-scan 선언**.
- 코드/컨텍스트 탐색이 없는 응답(순수 문답·이미 아는 파일 재편집)은 라인 생략.
- 허위 선언 금지: statusline ``📡 cmap/ctx/src`` 실측 카운터(PostToolUse read-track hook)와 대조된다.
"@
Write-FileContent "CLAUDE.md" $tmplClaudeMd

# ── AGENTS.md ─────────────────────────────────────────────────────────────────
Step-Begin "AGENTS.md"
$tmplAgentsMd = @"
# AGENTS.md
# Tool: OpenAI Codex Agent | Stack: $($p.Label)
# Edit Commands / Directories / Conventions to match your project.

## Setup / Commands
$($p.Commands)

## Definition of Done
Task complete when ALL pass:
1. Analyze (Commands의 Analyze) - zero errors
2. Test (Commands의 Test) - all green
3. No files outside stated scope modified
4. lane 파일 갱신 또는 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동
5. .claude/codemap/_index.md updated for new/changed symbols
6. 핸드오프 발생 시 .claude/pawpad/handoffs/ snapshot 작성
7. lane ``## Verification Evidence``에 검증 근거 기록 — 최근 2건만 lane 유지, 초과분은 .claude/pawpad/verifications/{feature-id}-archive.md 상단 append + 포인터 1줄 (분석전용/소작업은 ``not applicable: analysis-only``). 규칙: .claude/HYBRID.md Verification Evidence.
8. 코드 변경 시 /security-check 🔴 zero (분석전용/문서전용 면제). 규칙: .agents/skills/security-check/SKILL.md
9. 코드 변경 시 신규/변경 코드가 Architecture Principles (Feature-First) 준수 (분석/문서전용 면제). 규칙: .agents/skills/feature-architecture/SKILL.md

## Escalation Rules
- Stuck > 3 attempts same error: STOP, report findings
- Scope unclear: ASK before touching new files
- Destructive op (DROP/DELETE/rm -rf): STOP, confirm
- Credential required: STOP - use env var reference

## Boundaries
NEVER modify:
$($p.NeverModify)

NEVER run without confirm:
$($p.NeverRun)

## Directories
$($p.Directories)

## Conventions
$($p.Conventions)

## Coding Principles (Lean Code)
1. Implement only what is asked. No extra abstractions.
2. Do not modify files outside stated scope.
3. Read existing code before writing new code.
4. When scope is unclear, ask before implementing.

## Architecture Principles (Feature-First)
신규/변경 코드만 적용(레거시 강제 리팩토링 X). 상세·결정트리: .agents/skills/feature-architecture/SKILL.md
1. 모듈 경계: 기능 폴더 응집(colocation) + 단일 public boundary(스택 관례). 내부 직접 import 금지.
2. 횡단 import 금지: 기능 간 내부 참조 X (public boundary 의존은 OK). 공통은 소속 범위 따라 hoist.
3. Rule of Three: 2곳 중복 유지, 3곳째 추출.
4. 신규 = 가산적: feature 내부 추가 중심 + route/menu registry 등 최소 integration edit 허용. integration 파일에 로직 늘면 경계 재검토.
새 기능 위치: 기존 도메인 하위 / 새 도메인 폴더 / 도메인 비소속 shared 중 하나. 결정트리는 skill 참조.

## Doc Update Rules
| Change           | Update target                            |
|------------------|------------------------------------------|
| Feature spec     | .claude/pawpad/specs/{feature-id}.md        |
| Feature/UX       | src/prd/{area}.md (영역 shard)            |
| New feature      | src/PRD-tree.md(인덱스 행) + src/prd/{area}.md(상세) |
| New screen/route | Feature ID in PRD-tree.md (인덱스)        |
| 메뉴구성도        | src/viewer/userflow.json (메뉴 계층 트리 JSON; 뷰어 드래그 편집·on-demand) |
| 스팩 진행률       | specs/{feature-id}.md 상단 status 행 (draft/ready/implementing/done — 뷰어 진행률 SoT) |
| 결정 기록 위치    | .claude/HYBRID.md Decision Placement Matrix 참조 |
| 검증 결과        | lane ``## Verification Evidence`` 최근 2건, 초과분 → .claude/pawpad/verifications/{feature-id}-archive.md (상단 append) |
PRD 상세 read: PRD-tree(인덱스) → lane feature-id 접두로 영역 해석 → 해당 src/prd/{area}.md만 (✓완료 영역 skip, 부족 시 on-demand). PRD-tree 영역 행에 상태 마커 ✓완료/🔨진행/⬜예정.
뷰어 데이터(src/viewer/*.json: prd/fts/userflow/wire)는 ON START/resume 자동 로드 금지 — /mockup viewer·/viewer-apply 등 해당 작업 시점에만 on-demand read(초기 기획 강화로 후속 수정 최소화·context 절감). 항목 존재=설계/개발 대상, status(예정/진행중/완료)는 agent가 구현하며 갱신.
Code + doc update = one atomic unit. Keep * markers accurate.

## Session Protocol
ON START (agent가 순차 실행):
  0. read .ctxdb/INDEX.md -> 첫 메시지 키워드 매칭 -> L1<=1 / L2<=2개만 로드 (전체 로드 금지)
     (첫 응답 최상단에 검증 1줄: 📂 ctxdb: {project} | {last-date} | {loaded L2} | {status})
  1. read .claude/pawpad/_wip.md (active lane router)
  2. Active Lanes 있으면 read .claude/HYBRID.md (협업 프로토콜). 없으면 skip -> 신규 lane 생성/핸드오프/인수 시점에 read
  3. assigned lane 있으면 read .claude/pawpad/wip/{lane}.md
  4. _wip.md Active Lanes에 state=HANDOFF_TO_* 발견 시 -> handoff 필드 경로 read
  5. state=SPEC_READY 또는 spec 있으면 read .claude/pawpad/specs/{feature}.md
  6. read .claude/pawpad/_meta.md 상단만 (헤더 SPRINT/PHASE/STACK + BLOCKED + NEXT; RECENT 완료이력은 하단·재개 불요 -> 생략, history 시 on-demand)
  7. .claude/codemap/_index.md는 코드 수정 작업 시작 시점에 read — MAP+HOT(조망)만 부분읽기(상단), INDEX(전체 심볼표)는 심볼 필요 시 Grep on-demand (질문/분석 전용 세션은 skip)
ON SUBTASK DONE: agent가 lane 파일 next steps 갱신
ON TASK DONE:    agent가 lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 + _meta.md 1줄 append (RECENT 8줄 초과 시 초과분을 sessions/{YYYY-MM}.md 상단으로 이동, newest first 유지) + 완료(✅) 작업항목 누적 시 verifications/{feature-id}-tasklog.md 이월(HYBRID Completed Task Log) + _index.md 갱신 + git commit (git repo일 때만; 비-git이면 _meta RECENT에 "git unavailable" 기록, 완료 차단 안 함)
ON STOP:         agent가 lane 파일 (state + reason) 갱신
ON 8턴/60% CONTEXT:
  - Claude Code: Stop hook이 8턴마다 checkpoint block -> context-saver(.ctxdb/L2 저장) + codemap 갱신.
  - Codex: ``.codex/hooks.json`` Stop hook이 trust된 경우 8턴마다 checkpoint continuation -> context-saver + codemap 갱신.
           hook 미신뢰/비활성 시 수동 수행.
  - 공통: 60% 시 /checkpoint -> 필요시 /handoff {to-agent} {feature}

## Codex 주의 (native hook adapter)
- ``.agents/skills/*/SKILL.md`` = Codex skill mirror (Claude ``.claude/skills/*``와 동일 절차). hook은 ``.codex/hooks.json`` 정의, ``/hooks``로 review/trust해야 자동 실행. ``.codex/config.toml``은 안내 주석만.
- SessionStart: ``.ctxdb/.state/codex-turn-count``·``codex-loaded`` reset.
- UserPromptSubmit: INDEX keyword 매칭 → L1<=1/L2<=2 로드(session dedupe). injectMode(pawpad-config.json ctxdb): pointer(기본)=read 지시만 주입→**agent 즉시 read 필수**, full=본문. codemap HOT/match 추가(codemap.inject auto/on/off). explicit fallback(progress-current)은 재개 의도어만.
- PreCompact: compaction 직전 context-saver + ``codex-last-compact`` 기록(Stop 8턴과 중복 방지). Stop: ``codex-turn-count`` 카운트, 8턴/L2 초과 시 context-saver 요구.
- ``.codex/hooks/*.sh``는 ``pwsh`` 필요; 부재 시 ctxdb-inject skip·나머지 ``{}`` 반환. ``turn-count``=Claude 전용, Codex=``codex-turn-count``.
- hook 미신뢰/비활성 시 수동: ctxdb 로드(step0 INDEX read) + 저장(8턴/종료/60% context-saver) + codemap(read+갱신).

## Hybrid Lane Rule
- 신규 작업: .claude/pawpad/wip/{feature-id}.md 생성 + _wip.md Active Lanes 등록
- 본인 lane만 수정. 타 에이전트 lane 읽기 가능, 수정 금지.
- _wip.md Locks 섹션에서 파일 경로 매핑 확인.
- codemap/_index.md: 추가는 누구나, 수정/삭제는 lane owner만.
- 완료 lane: wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 (삭제 금지, audit 보존, timestamp로 재작업 보존)
- 핸드오프 수신 시: state HANDOFF_TO_* -> WIP, owner -> 받는 agent로 변경
- 리뷰(review skill): state REVIEW_REQUESTED(요청, work owner 불변·``reviewer`` 지정) ↔ REVIEW_DONE(완료). 리뷰어는 work lane 미점유 — review state·result 경로만 갱신, work 내용 수정 X. 종결은 요청측 재량.

## Handoff Protocol
60% context 추정 시 정리. snapshot: ``.claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md`` (TEMPLATE.md 따름). 절차 상세: handoff skill / HYBRID.md.
state 마커: HANDOFF_TO_CODEX(Claude→Codex), HANDOFF_TO_CLAUDE(Codex→Claude), HANDOFF_TO_NEXT_AGENT(미정), SPEC_READY(기획 완료, 구현 대기), REVIEW_REQUESTED/REVIEW_DONE(리뷰 라운드트립, work owner 불변 — review skill).
다음 agent는 _wip.md Active Lanes state/handoff로 snapshot 위치 파악. 인수 시: state→WIP, owner→받는 agent.

## Idea → PRD Routing
아이디어→PRD 구체화 시 agent가 다음 스킬 추천(강제 X, 명시 호출 우선). skill mirror: ``.agents/skills/{clarity,grill-me,to-prd,design,mockup}/``.
판정: 정보 부족→clarity / 설계 결정 어려움→grill-me / 둘 다 충족→to-prd.
- 큰 덩어리: clarity 전 "분해 권장"(굵은 조각+순서, 조각별 반복).
- clarity PASS 후: grill-me 신호(결정 상호의존·트레이드오프 연쇄·스택/아키텍처/스키마 비가역) 있으면 →grill-me, 없으면 →to-prd.
- grill-me 종결 후: →to-prd.
- UI/화면 기획 시: design(토큰/레이아웃 게이트) + mockup(PRD-tree→단일 HTML 시각화, lo/hi-fi) 추천.
### 자동제안 (단계 경계)
다음 시점에 다음 스킬 또는 목업 1회 추천(강제 X): PRD/PRD-tree 갱신 직후→mockup(통합 4탭=/mockup viewer; 뷰어 결정 저장 통지 시 /viewer-apply 반영), clarity/grill-me/to-prd 종료 시→다음 스킬. 매 응답 판단 X. 거절 시 다음 단계 경계까지 침묵. 대상 한정: clarity·grill-me·to-prd·design·mockup·brainstorming(나머지는 Checkpoint/hook 트리거 → 제외). 리뷰 제안(구현완료 경계): 코드/배포본 변경 완료 직전 고위험·배포본 영향이면 /review 권장(강제 X); 광범위·맹점우려·설치 스크립트는 codex exec 에스컬레이션. 코딩 위임 제안(구현 진입 경계): SPEC_READY/written 설계 직후 코딩 진입 시 /code-delegate 1회 권장(강제 X, 선택 모델 서브에이전트 위임으로 부모 컨텍스트·토큰 절감; 설계 미작성 시 제안 X).
### 선택지 질문 = 체크박스
기획/설계 스킬 진행 중 선택지 N개 질문은 AskUserQuestion(체크박스)로, 자유서술·수치는 텍스트로.

## Response Style
한글로 답변. 기술 용어 코드 원문 유지.
Terse. Drop: a/an/the, filler, pleasantries, hedging.
Pattern: [대상] [동작] [이유]. [다음 단계].
ACTIVE EVERY RESPONSE.

### Active Skills 표시 (매 응답 최상단 1줄)
형식: ``🐾 Active Skills: {활성 스킬 | 구분}`` (🐾=pawpad, Codex는 statusLine 없어 라인 표시). 단계 첨자: ``clarity r2/5``, ``grill-me``, ``to-prd``, ``brainstorming``, ``design``, ``mockup lo/hi``, ``review``.
스킬 없으면 생략 가능. ON START는 📂 ctxdb 라인 아래.

### Retrieval 표시 (탐색 수행 응답만, Active Skills 라인 아래 1줄)
형식: ``📡 Retrieval: codemap {hit(경로)|miss|미사용} | ctxdb {hit(파일)|miss|미사용} | src {read N (codemap 경유)|full-scan N (사유)}``
- 소스 탐색 전 codemap lookup 의무. miss여도 곧장 full-scan 금지 — keywords/INDEX 의미매칭 재시도 후에도 miss면 **사유와 함께 full-scan 선언**.
- 코드/컨텍스트 탐색이 없는 응답(순수 문답·이미 아는 파일 재편집)은 라인 생략.

## Checkpoint (매 응답 종료 전 확인 - hooks 대체)
자세한 운영은 .claude/HYBRID.md 참조.
- [ ] lane 파일 (또는 _wip.md) 현재 상태 반영됐나?
- [ ] 신규 파일 생성 시 _index.md 심볼 추가됐나?
- [ ] 태스크 완료 시 lane을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 + _meta.md 1줄 append + git commit(git repo일 때만; 비-git이면 _meta RECENT에 "git unavailable" 기록) 됐나?
- [ ] context 60% 추정 초과 시 /handoff 또는 /checkpoint 실행했나?
- [ ] 핸드오프 인수 시 owner를 자기 이름으로 변경했나?
"@
Write-FileContent "AGENTS.md" $tmplAgentsMd

# ── settings.json (OS 감지 + 스택별 analyze 조건부) ───────────────────────────
Step-Begin "settings + pawpad-config"
# 설치 OS에 맞춰 hook 명령을 선택 (Windows=.ps1 / Unix=.sh). 핸드: pwsh로 Mac/Linux 설치 시 .sh 선택.
$claudeHookRoot = ConvertTo-ForwardSlashPath ".claude/hooks"
$claudeRunHook = "$claudeHookRoot/run-hook.ps1"
$sessionCmd = if ($isWin) { "powershell -NoProfile -ExecutionPolicy Bypass -File $claudeRunHook session-start.ps1" } else { "bash $claudeHookRoot/session-start.sh" }
$promptCmd  = if ($isWin) { "powershell -NoProfile -ExecutionPolicy Bypass -File $claudeRunHook ctxdb-inject.ps1" } else { "sh $claudeHookRoot/ctxdb-inject.sh" }
$compactCmd = if ($isWin) { "powershell -NoProfile -ExecutionPolicy Bypass -File $claudeRunHook pre-compact.ps1" } else { "sh $claudeHookRoot/pre-compact.sh" }
$stopCmd    = if ($isWin) { "powershell -NoProfile -ExecutionPolicy Bypass -File $claudeRunHook stop-check.ps1" } else { "bash $claudeHookRoot/stop-check.sh" }
$analyzeCmd = if ($isWin) { if ($p.AnalyzePS) { "powershell -NoProfile -ExecutionPolicy Bypass -File $claudeRunHook analyze.ps1" } else { '' } } else { if ($p.AnalyzeBash) { "bash $claudeHookRoot/analyze.sh" } else { '' } }
$readTrackCmd = if ($isWin) { "powershell -NoProfile -ExecutionPolicy Bypass -File $claudeRunHook read-track.ps1" } else { "bash $claudeHookRoot/read-track.sh" }
$statusCmd  = if ($isWin) { "powershell -NoProfile -ExecutionPolicy Bypass -File $claudeRunHook statusline.ps1" } else { "bash $claudeHookRoot/statusline.sh" }

# JSON 하드빌드 (5.1 ConvertTo-Json 단일요소 배열 unwrap 회피). PostToolUse: read-track(항상) + analyze(스택 조건부).
$nl = "`n"
$sl = @()
$sl += '{'
$sl += '  "hooks": {'
$sl += '    "SessionStart": ['
$sl += '      {'
$sl += '        "hooks": ['
$sl += '          {'
$sl += '            "type": "command",'
$sl += "            ""command"": ""$sessionCmd"""
$sl += '          }'
$sl += '        ]'
$sl += '      }'
$sl += '    ],'
$sl += '    "UserPromptSubmit": ['
$sl += '      {'
$sl += '        "hooks": ['
$sl += '          {'
$sl += '            "type": "command",'
$sl += "            ""command"": ""$promptCmd"""
$sl += '          }'
$sl += '        ]'
$sl += '      }'
$sl += '    ],'
$sl += '    "PreCompact": ['
$sl += '      {'
$sl += '        "hooks": ['
$sl += '          {'
$sl += '            "type": "command",'
$sl += "            ""command"": ""$compactCmd"""
$sl += '          }'
$sl += '        ]'
$sl += '      }'
$sl += '    ],'
$sl += '    "PostToolUse": ['
$sl += '      {'
$sl += '        "matcher": "Read|Grep|Glob",'
$sl += '        "hooks": ['
$sl += '          {'
$sl += '            "type": "command",'
$sl += "            ""command"": ""$readTrackCmd"""
$sl += '          }'
$sl += '        ]'
if ($analyzeCmd) {
    $sl += '      },'
    $sl += '      {'
    $sl += '        "matcher": "Write|Edit|MultiEdit",'
    $sl += '        "hooks": ['
    $sl += '          {'
    $sl += '            "type": "command",'
    $sl += "            ""command"": ""$analyzeCmd"""
    $sl += '          }'
    $sl += '        ]'
    $sl += '      }'
} else {
    $sl += '      }'
}
$sl += '    ],'
$sl += '    "Stop": ['
$sl += '      {'
$sl += '        "hooks": ['
$sl += '          {'
$sl += '            "type": "command",'
$sl += "            ""command"": ""$stopCmd"""
$sl += '          }'
$sl += '        ]'
$sl += '      }'
$sl += '    ]'
$sl += '  },'
$sl += '  "statusLine": {'
$sl += '    "type": "command",'
$sl += "    ""command"": ""$statusCmd"""
$sl += '  }'
$sl += '}'
$tmplSettingsJson = ($sl -join $nl)
Write-FileContent ".claude\settings.json" $tmplSettingsJson -NoBom

# ── pawpad-config.json (toolkit 런타임 토글: codemap inject) ──────────────────────
Write-FileContent -NoBom ".claude\pawpad-config.json" @'
{
  "_note": "PawPad (Agentic Engineering Toolkit) runtime toggles. Read by Claude/Codex hooks (session-start, ctxdb-inject).",
  "codemap": {
    "inject": "auto",
    "_inject_values": "auto = inject only when symbol count >= largeRepoSymbolThreshold (대형 repo opt-in); on = always; off = never",
    "largeRepoSymbolThreshold": 60
  },
  "ctxdb": {
    "injectMode": "pointer",
    "_injectMode_values": "pointer(기본) = Codex hook이 본문 대신 read 지시만 주입 (Codex TUI가 additionalContext를 화면 렌더링하므로 노이즈 최소화, agent가 직접 read); full = 본문 주입. Claude hook은 화면 비표시라 항상 full (이 키 무시)."
  }
}
'@

# ── hooks: run-hook.ps1 (settings.json root-aware wrapper) ───────────────────
Step-Begin "Claude hooks + statusline"
Write-FileContent ".claude\hooks\run-hook.ps1" @'
param(
    [Parameter(Mandatory = $true)]
    [string]$HookName
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $hookDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = Split-Path -Parent (Split-Path -Parent $hookDir)
    $hookPath = Join-Path $hookDir $HookName

    if (-not (Test-Path -LiteralPath $hookPath)) {
        exit 0
    }

    Push-Location $repoRoot
    try {
        & $hookPath
        $code = if ($null -ne $global:LASTEXITCODE) { [int]$global:LASTEXITCODE } else { 0 }
        exit $code
    } finally {
        Pop-Location
    }
} catch {
    exit 0
}
'@

# ── hooks: analyze.ps1 / analyze.sh (PostToolUse:Edit 정적분석 — 스택별 raw 커맨드 파일화, v2.40 내 보강) ──
# 배경1: settings.json "command"에 raw PowerShell 파이프라인(`... | Select-Object ...`)을 직접 넣으면
#       Claude Code가 hook command를 bash로 디스패치할 때 `Select-Object`를 못 찾아 실패한다(Git Bash에는 없는 cmdlet).
#       다른 훅과 동일하게 -File로 .ps1 스크립트를 실행시켜 셸(bash/cmd) 종류와 무관하게 powershell.exe 내부에서 파이프가 해석되도록 한다.
# 배경2: Claude Code PostToolUse hook은 exit 2일 때만 **stderr**를 agent에게 전달한다(stdout은 무시).
#       analyze 커맨드는 진단 결과를 stdout으로만 내보내 왔으므로, 에러가 있어도 "No stderr output"만 뜨고
#       실제 tsc/dart/mypy 진단 내용은 agent에게 전혀 전달되지 않았다. 진단 결과를 stderr로 재전송 + exit 2/0 정규화.
if ($isWin -and $p.AnalyzePS) {
    $analyzeScript = @"
`$__out = ( $($p.AnalyzePS) ) | Out-String
if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) {
    [Console]::Error.Write(`$__out)
    exit 2
}
exit 0
"@
    Write-FileContent ".claude\hooks\analyze.ps1" $analyzeScript
}
if (-not $isWin -and $p.AnalyzeBash) {
    # bash에서 `cmd | tail -N` 뒤의 `$?`는 파이프 마지막 명령(tail)의 exit(항상 0)라 에러가 소실되고,
    # `2>&1`도 마지막 명령에만 바인딩된다. pipefail + 그룹 리다이렉트로 analyze 명령의 exit/stderr를 함께 캡처.
    $analyzeScript = @"
#!/bin/bash
set -o pipefail
out=`$( { $($p.AnalyzeBash); } 2>&1 )
code=`$?
if [ `$code -ne 0 ]; then
    echo "`$out" >&2
    exit 2
fi
exit 0
"@
    Write-FileContent ".claude\hooks\analyze.sh" $analyzeScript -Unix
}

# ── hooks: read-track.ps1 / read-track.sh (PostToolUse:Read|Grep|Glob retrieval 계측, v2.41) ──
# 목적: agent가 읽은 경로를 cmap(.claude/codemap)/ctx(.ctxdb)/src(그 외)로 분류해 세션 카운터에 누적.
#       statusline이 "📡 cmap N ctx N src N"으로 실측 표시 → codemap을 안 타고 전체 소스를 뒤지는
#       행동(src 폭증)을 자기보고가 아닌 계측으로 관측. 관측 전용: 항상 exit 0, agent 피드백 없음(exit 2 금지).
# ctx는 agent 직접 read 기준(UserPromptSubmit hook 자동주입 로드는 미포함). toolkit 내부(.claude/.agents/.codex) read는 잡음 → 미집계.
Write-FileContent ".claude\hooks\read-track.ps1" @'
# PostToolUse(Read|Grep|Glob) - retrieval 계측. 분류: cmap / ctx / src. 관측 전용(항상 exit 0).
$ErrorActionPreference = 'SilentlyContinue'
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
    if (-not $raw.Trim()) { exit 0 }
    $ev = $raw | ConvertFrom-Json
    $ti = $ev.tool_input
    $target = ''
    if ($ti) {
        if ($ti.file_path) { $target = [string]$ti.file_path }
        elseif ($ti.path) { $target = [string]$ti.path }
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
'@

Write-FileContent ".claude\hooks\read-track.sh" -Unix @'
#!/bin/bash
# PostToolUse(Read|Grep|Glob) - retrieval 계측 (read-track.ps1 bash 포트). 관측 전용(항상 exit 0).
raw="$(cat)"
target="$(printf '%s' "$raw" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$target" ] && target="$(printf '%s' "$raw" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
# 경계 정규화: 앞뒤 / 부착 → 디렉토리 자체 경로(트레일링 / 없음)·유사 이름(myproject.claude) 오분류 방지
target="/$target/"
case "$target" in
  *"/.claude/codemap/"*) kind=cmap ;;
  *"/.ctxdb/"*) kind=ctx ;;
  *"/.claude/"*|*"/.agents/"*|*"/.codex/"*) exit 0 ;;
  *) kind=src ;;
esac
mkdir -p ".ctxdb/.state"
echo "$kind" >> ".ctxdb/.state/claude-read-stats"
exit 0
'@

# ── hooks: session-start.ps1 (INDEX 라우터 주입 + session state reset + codemap 토글) ──
Write-FileContent ".claude\hooks\session-start.ps1" @'
# SessionStart hook - codemap + .ctxdb INDEX 라우터를 세션 시작 시 주입 + 세션 state reset.
# 목적: INDEX 라우터(작은 파일)는 항상 주입, codemap은 토글(대형 repo opt-in)에 따라 주입.
#       세션별 turn-count / claude-loaded(ctxdb dedupe) state를 reset (keyword 최소로드는 UserPromptSubmit hook 담당).
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$sessionId = "manual"
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
    if ($raw.Trim()) {
        $ev = $raw | ConvertFrom-Json
        if ($ev.session_id) { $sessionId = [string]$ev.session_id }
    }
} catch {}
$stateDir = ".ctxdb/.state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
Set-Content -Path (Join-Path $stateDir "turn-count") -Value @("session:$sessionId", "turn:0") -Encoding ascii
Set-Content -Path (Join-Path $stateDir "claude-loaded") -Value @($sessionId) -Encoding UTF8
Set-Content -Path (Join-Path $stateDir "claude-read-stats") -Value @() -Encoding ascii
Set-Content -Path (Join-Path $stateDir "claude-retrieval-stats") -Value @() -Encoding ascii
Set-Content -Path (Join-Path $stateDir "claude-retrieval-seen") -Value @() -Encoding ascii

function Test-CodemapInject {
    $cfg = ".claude/pawpad-config.json"
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
    $cm = ".claude/codemap/_index.md"
    if (-not (Test-Path $cm)) { return $false }
    $inIndex = $false; $count = 0
    foreach ($line in (Get-Content $cm -Encoding UTF8)) {
        if ($line -match "^# INDEX") { $inIndex = $true; continue }
        if ($line -match "^# ") { $inIndex = $false; continue }
        if ($inIndex -and $line.Trim() -and -not $line.Trim().StartsWith("<!--")) { $count++ }
    }
    return ($count -ge $threshold)
}

$out = @()
if (Test-CodemapInject) {
    $cm = ".claude/codemap/_index.md"
    if (Test-Path $cm) {
        $out += "=== codemap (symbol registry / HOT) ==="
        $out += (Get-Content $cm -TotalCount 40 -Encoding UTF8)
    }
} else {
    $out += "=== codemap: inject skipped (소형 repo / off). 필요 시 .claude/codemap/_index.md 직접 read 또는 pawpad-config.json codemap.inject=on ==="
}
$idx = ".ctxdb/INDEX.md"
if (Test-Path $idx) {
    $out += ""
    $out += "=== .ctxdb INDEX (keyword -> L1/L2 router) ==="
    $out += (Get-Content $idx -TotalCount 50 -Encoding UTF8)
}
if ($out.Count -gt 0) {
    $out += ""
    $out += "[load rule] UserPromptSubmit hook이 prompt keyword로 L1<=1 / L2<=2 자동 최소로드(세션 dedupe). 추가 read는 매칭 항목만. 전체 로드 금지."
    $out -join "`n"
}
exit 0
'@

# ── hooks: stop-check.ps1 (session-aware 8턴 저장 + PreCompact 가드 + L2 분할규칙) ──
Write-FileContent ".claude\hooks\stop-check.ps1" @'
# Stop hook - 루프가드 후 8턴 정기저장 또는 L2 분할규칙 위반 시 decision:block.
# session-aware turn-count. PreCompact가 최근 8턴 내 저장 유도했으면 checkpoint 중복 생략.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
$event = $null
try { $event = $raw | ConvertFrom-Json } catch {}
if ($event.stop_hook_active -eq $true) { exit 0 }   # block 재진입 -> 루프 방지

$sessionId = if ($event -and $event.session_id) { [string]$event.session_id } else { "manual" }

$stateDir = ".ctxdb/.state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

# retrieval hit/miss 계측: 방금 완료된 assistant 응답의 '📡 Retrieval:' 선언을 파싱해 누적 (statusline hit율 SoT).
# 미사용(선언 없음/미사용)은 기록 안 함 -> hit율 분모에서 제외. uuid dedupe로 동일 응답 재계수 방지.
$tp = if ($event) { [string]$event.transcript_path } else { "" }
if ($tp -and (Test-Path -LiteralPath $tp)) {
    try {
        $tlines = @(Get-Content -LiteralPath $tp -Tail 40 -Encoding UTF8 -ErrorAction SilentlyContinue)
        $lastText = ""; $lastUuid = ""
        for ($i = $tlines.Count - 1; $i -ge 0; $i--) {
            try { $o = $tlines[$i] | ConvertFrom-Json } catch { continue }
            if ($o.message.role -eq 'assistant') {
                $lastUuid = [string]$o.uuid
                foreach ($c in @($o.message.content)) { if ($c.type -eq 'text') { $lastText += [string]$c.text + "`n" } }
                break
            }
        }
        $seenPath = Join-Path $stateDir "claude-retrieval-seen"
        $seen = if (Test-Path $seenPath) { (Get-Content -LiteralPath $seenPath -Raw -Encoding UTF8).Trim() } else { "" }
        if ($lastUuid -and $lastUuid -ne $seen -and $lastText) {
            # 실제 선언 라인만 (형식 예시 '{hit|miss}'는 중괄호 포함 -> 제외해 예시/인용 오계수 방지).
            $rl = ($lastText -split "`n") | Where-Object { $_ -match 'Retrieval:' -and $_ -match 'codemap' -and $_ -notmatch '\{' } | Select-Object -First 1
            if ($rl) {
                # 고정 순서 codemap | ctxdb | src 로 위치 분해 (키워드 매칭 시 경로 내 'codemap'/'ctxdb' 부분문자열과 충돌).
                $segs = $rl -split '\|'
                $cseg = if ($segs.Count -ge 1) { $segs[0] } else { "" }
                $xseg = if ($segs.Count -ge 2) { $segs[1] } else { "" }
                $rec = @()
                if ($cseg) { if ($cseg -match 'hit') { $rec += 'cmap:hit' } elseif ($cseg -match 'miss') { $rec += 'cmap:miss' } }
                if ($xseg) { if ($xseg -match 'hit') { $rec += 'ctx:hit' } elseif ($xseg -match 'miss') { $rec += 'ctx:miss' } }
                if ($rec.Count -gt 0) { Add-Content -Path (Join-Path $stateDir "claude-retrieval-stats") -Value $rec -Encoding ascii }
            }
            Set-Content -Path $seenPath -Value $lastUuid -Encoding ascii
        }
    } catch {}
}

$tcPath = Join-Path $stateDir "turn-count"

$turn = 0
if (Test-Path $tcPath) {
    $lines = Get-Content -Path $tcPath -Encoding UTF8
    if ($lines.Count -ge 2 -and $lines[0] -like "session:*") {
        if ($lines[0].Substring(8) -eq $sessionId -and $lines[1] -match "^turn:(\d+)$") { $turn = [int]$Matches[1] }
    } elseif (($lines -join "").Trim() -match "^\d+$") { $turn = [int](($lines -join "").Trim()) }
}
$turn++
Set-Content -Path $tcPath -Value @("session:$sessionId", "turn:$turn") -Encoding ascii

# PreCompact 중복 가드: 최근 8턴 내 compaction 저장 유도 있었으면 이번 checkpoint 생략
$lastCompactTurn = -1
$lcPath = Join-Path $stateDir "last-compact"
if (Test-Path $lcPath) {
    $lc = Get-Content -Path $lcPath -Encoding UTF8
    if ($lc.Count -ge 2 -and $lc[1] -match "^turn:(\d+)$") { $lastCompactTurn = [int]$Matches[1] }
}

# L2 분할 규칙 점검 (150줄 또는 ~2000토큰 초과 = 키워드 로드 시 토큰절약 무력화)
$oversized = @()
$l2dir = ".ctxdb/L2"
if (Test-Path $l2dir) {
    Get-ChildItem -Path $l2dir -Filter *.md -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        $chars = if ($content) { $content.Length } else { 0 }
        $lcount = if ($chars -eq 0) { 0 } else { ([regex]::Matches($content, "`n").Count + 1) }
        $tok = [int]($chars / 3.5)
        if ($lcount -gt 150 -or $tok -gt 2000) { $oversized += ("{0}({1}L/~{2}tok)" -f $_.Name, $lcount, $tok) }
    }
}

$needsCheckpoint = ($turn % 8 -eq 0) -and -not ($lastCompactTurn -gt ($turn - 8))
$needsSplit = ($oversized.Count -gt 0)
if ($needsSplit) {
    $sig = $sessionId + "|" + ($oversized -join "|")
    $warnPath = Join-Path $stateDir "claude-oversize-warned"
    $lastSig = ""
    if (Test-Path $warnPath) { $lastSig = (Get-Content -Path $warnPath -Raw -Encoding UTF8).Trim() }
    if ($lastSig -eq $sig) { $needsSplit = $false } else { Set-Content -Path $warnPath -Value $sig -Encoding UTF8 }
}

$parts = @()
if ($needsCheckpoint) {
    $parts += "[checkpoint $turn turns] Update .claude/codemap/_index.md for new/changed symbols + refresh lane/_wip.md (on done: move to wip/done + _meta.md + git commit) + run context-saver to write .ctxdb/L2 and update INDEX.md AGENT SYNC."
}
if ($needsSplit) {
    $parts += ("[L2 split needed] " + ($oversized -join ", ") + " : exceeds 150 lines / 2000 tokens -> keyword load still pulls the whole file, defeating token savings. Split old entries into .ctxdb/L3/{name}-YYYY-MM.md or split by domain, then update INDEX/L1 pointers.")
}
if ($parts.Count -eq 0) { exit 0 }

$reason = ($parts -join " ") + " Report one line, then stop."
@{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress | Write-Output
exit 0
'@

# ── hooks: ctxdb-inject.ps1 (UserPromptSubmit keyword 최소로드 + session dedupe) ──
Write-FileContent ".claude\hooks\ctxdb-inject.ps1" @'
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
'@

# ── hooks: pre-compact.ps1 (native compaction 직전 context-saver 유도 + 중복 가드) ──
Write-FileContent ".claude\hooks\pre-compact.ps1" @'
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
'@

# ── hooks: session-start.sh (state reset + codemap 토글, bash 포트, LF/no-BOM) ──
Write-FileContent ".claude\hooks\session-start.sh" -Unix @'
#!/usr/bin/env bash
# SessionStart hook - INDEX 라우터 주입 + session state reset + codemap 토글 (session-start.ps1 bash 포트).
# bash는 기본 UTF-8. CRLF면 shebang 깨지므로 이 파일은 반드시 LF.
raw="$(cat)"
sid="$(printf '%s' "$raw" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$sid" ] && sid="manual"
mkdir -p ".ctxdb/.state"
printf 'session:%s\nturn:0\n' "$sid" > ".ctxdb/.state/turn-count"
printf '%s\n' "$sid" > ".ctxdb/.state/claude-loaded"
: > ".ctxdb/.state/claude-read-stats"
: > ".ctxdb/.state/claude-retrieval-stats"
: > ".ctxdb/.state/claude-retrieval-seen"

cm=".claude/codemap/_index.md"
idx=".ctxdb/INDEX.md"
# codemap inject 토글 (pawpad-config.json: auto/on/off, auto=INDEX 심볼>=threshold)
mode="auto"; threshold=60
cfg=".claude/pawpad-config.json"
if [ -f "$cfg" ]; then
  m="$(sed -n 's/.*"inject"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$cfg" | head -1)"
  [ -n "$m" ] && mode="$m"
  t="$(sed -n 's/.*"largeRepoSymbolThreshold"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$cfg" | head -1)"
  [ -n "$t" ] && threshold="$t"
fi
inject=0
if [ "$mode" = "on" ]; then inject=1
elif [ "$mode" = "off" ]; then inject=0
elif [ -f "$cm" ]; then
  count="$(awk '/^# INDEX/{f=1;next} /^# /{f=0} f && NF && $0 !~ /^[[:space:]]*<!--/{c++} END{print c+0}' "$cm")"
  [ "$count" -ge "$threshold" ] && inject=1
fi

emitted=0
if [ "$inject" -eq 1 ] && [ -f "$cm" ]; then
  echo "=== codemap (symbol registry / HOT) ==="
  head -n 40 "$cm"
  emitted=1
else
  echo "=== codemap: inject skipped (소형 repo / off). 필요 시 .claude/codemap/_index.md 직접 read 또는 pawpad-config.json codemap.inject=on ==="
  emitted=1
fi
if [ -f "$idx" ]; then
  echo ""
  echo "=== .ctxdb INDEX (keyword -> L1/L2 router) ==="
  head -n 50 "$idx"
  emitted=1
fi
if [ "$emitted" -eq 1 ]; then
  echo ""
  echo "[load rule] UserPromptSubmit hook이 prompt keyword로 L1<=1 / L2<=2 자동 최소로드(세션 dedupe). 추가 read는 매칭 항목만. 전체 로드 금지."
fi
exit 0
'@

# ── hooks: stop-check.sh (session-aware 8턴 + PreCompact 가드, bash 포트) ──────────
Write-FileContent ".claude\hooks\stop-check.sh" -Unix @'
#!/usr/bin/env bash
# Stop hook - 루프가드 후 8턴 정기저장 또는 L2 분할규칙 위반 시 decision:block (stop-check.ps1 bash 포트).
raw="$(cat)"
case "$raw" in
  *'"stop_hook_active": true'*|*'"stop_hook_active":true'*) exit 0 ;;
esac
sid="$(printf '%s' "$raw" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$sid" ] && sid="manual"

stateDir=".ctxdb/.state"
mkdir -p "$stateDir"

# retrieval hit/miss 계측 (stop-check.ps1 파리티): 방금 완료된 assistant 응답의 '📡 Retrieval:' 선언 파싱.
# 미사용 턴은 미기록(hit율 분모 제외). uuid dedupe로 재계수 방지. jq 없으면 graceful skip.
if command -v jq >/dev/null 2>&1; then
  tp="$(printf '%s' "$raw" | jq -r '.transcript_path // empty' 2>/dev/null)"
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    last="$(tail -n 40 "$tp" 2>/dev/null | jq -rs '[ .[] | select(.message.role=="assistant") ] | last | if . then ((.uuid // "") + "\t" + ([ .message.content[]? | select(.type=="text") | .text ] | join(" "))) else "" end' 2>/dev/null)"
    uuid="${last%%$'\t'*}"; text="${last#*$'\t'}"
    seenP="$stateDir/claude-retrieval-seen"; seen=""; [ -f "$seenP" ] && seen="$(cat "$seenP" 2>/dev/null)"
    if [ -n "$uuid" ] && [ "$uuid" != "$seen" ] && [ -n "$text" ]; then
      # 실제 선언 라인만 (형식 예시 '{hit|miss}'는 중괄호 포함 -> grep -v '{'로 예시/인용 오계수 방지).
      rline="$(printf '%s' "$text" | grep 'Retrieval:.*codemap' 2>/dev/null | grep -v '{' | head -1)"
      if [ -n "$rline" ]; then
        # 고정 순서 codemap | ctxdb | src 로 위치 분해 (greedy sed는 마지막 'codemap'=src의 "(codemap 경유)" 매칭→cmap 누락).
        cseg="$(printf '%s' "$rline" | awk -F'|' '{print $1}')"
        xseg="$(printf '%s' "$rline" | awk -F'|' '{print $2}')"
        case "$cseg" in *hit*) printf 'cmap:hit\n' >> "$stateDir/claude-retrieval-stats" ;; *miss*) printf 'cmap:miss\n' >> "$stateDir/claude-retrieval-stats" ;; esac
        case "$xseg" in *hit*) printf 'ctx:hit\n' >> "$stateDir/claude-retrieval-stats" ;; *miss*) printf 'ctx:miss\n' >> "$stateDir/claude-retrieval-stats" ;; esac
      fi
      printf '%s' "$uuid" > "$seenP"
    fi
  fi
fi

tcPath="$stateDir/turn-count"
turn=0
if [ -f "$tcPath" ]; then
  s="$(sed -n 's/^session:\(.*\)$/\1/p' "$tcPath" | head -1)"
  t="$(sed -n 's/^turn:\([0-9]*\)$/\1/p' "$tcPath" | head -1)"
  if [ "$s" = "$sid" ] && [ -n "$t" ]; then turn="$t"
  else
    legacy="$(tr -d '[:space:]' < "$tcPath" 2>/dev/null)"
    case "$legacy" in ''|*[!0-9]*) turn=0 ;; *) turn="$legacy" ;; esac
  fi
fi
turn=$((turn + 1))
printf 'session:%s\nturn:%s\n' "$sid" "$turn" > "$tcPath"

# PreCompact 중복 가드: 최근 8턴 내 compaction 저장 유도 있었으면 checkpoint 생략
lastCompact=-1
if [ -f "$stateDir/last-compact" ]; then
  lc="$(sed -n 's/^turn:\([0-9]*\)$/\1/p' "$stateDir/last-compact" | head -1)"
  [ -n "$lc" ] && lastCompact="$lc"
fi

# L2 분할 규칙 (150줄 또는 ~2000토큰 초과). bash 정수라 토큰 추정은 chars/4.
oversized="$(find ".ctxdb/L2" -name '*.md' -type f 2>/dev/null | while IFS= read -r f; do
  lines="$(wc -l < "$f" 2>/dev/null | tr -d ' ')"
  chars="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  [ -z "$lines" ] && lines=0
  [ -z "$chars" ] && chars=0
  tok=$((chars / 4))
  if [ "$lines" -gt 150 ] || [ "$tok" -gt 2000 ]; then
    printf ' %s(%sL/~%stok)' "$(basename "$f")" "$lines" "$tok"
  fi
done)"

needCheckpoint=0
if [ $((turn % 8)) -eq 0 ] && [ "$lastCompact" -le $((turn - 8)) ]; then needCheckpoint=1; fi

needSplit=0
if [ -n "$oversized" ]; then
  sig="$sid|$oversized"
  warn="$stateDir/claude-oversize-warned"
  last=""
  [ -f "$warn" ] && last="$(cat "$warn" 2>/dev/null)"
  if [ "$last" = "$sig" ]; then needSplit=0; else printf '%s' "$sig" > "$warn"; needSplit=1; fi
fi

parts=""
if [ "$needCheckpoint" -eq 1 ]; then
  parts="[checkpoint $turn turns] Update .claude/codemap/_index.md for new/changed symbols + refresh lane/_wip.md (on done: move to wip/done + _meta.md + git commit) + run context-saver to write .ctxdb/L2 and update INDEX.md AGENT SYNC."
fi
if [ "$needSplit" -eq 1 ]; then
  parts="$parts [L2 split needed]$oversized : exceeds 150 lines / 2000 tokens -> keyword load still pulls the whole file, defeating token savings. Split old entries into .ctxdb/L3/{name}-YYYY-MM.md or split by domain, then update INDEX/L1 pointers."
fi
if [ -z "$parts" ]; then
  exit 0
fi
reason="$parts Report one line, then stop."
printf '{"decision": "block", "reason": "%s"}\n' "$reason"
exit 0
'@

# ── hooks: ctxdb-inject.sh / pre-compact.sh (Unix: pwsh wrapper, 없으면 안전반환) ──
Write-FileContent ".claude\hooks\ctxdb-inject.sh" -Unix @'
#!/usr/bin/env sh
set -eu
if command -v pwsh >/dev/null 2>&1; then
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  exec pwsh -NoProfile -File "$script_dir/ctxdb-inject.ps1"
fi
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"ctxdb: hook-skip | - | L2 0 files | pwsh not found for .claude/hooks/ctxdb-inject.sh"}}'
'@

Write-FileContent ".claude\hooks\pre-compact.sh" -Unix @'
#!/usr/bin/env sh
set -eu
if command -v pwsh >/dev/null 2>&1; then
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  exec pwsh -NoProfile -File "$script_dir/pre-compact.ps1"
fi
printf '%s\n' ''
'@

# ── statusline.ps1 (Claude Code 컨텍스트 윈도우 사용량 표시) ──────────────────
Write-FileContent ".claude\hooks\statusline.ps1" @'
# statusLine - 현재 세션 컨텍스트 윈도우 사용량(%) 표시.
# 1순위: stdin JSON의 context_window 필드 (Claude Code v2.1.132+, 모델별 실제 한도 + /context 동일 계산).
# 2순위(구버전 폴백): transcript JSONL 마지막 usage + model.id 기반 한도 테이블.
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# stdin은 UTF-8. 콘솔 코드페이지(CP949 등)에 의존하는 [Console]::In 대신 raw 바이트를 UTF-8로 디코딩
# (Korean username 등 non-ASCII transcript_path가 깨져 JSON 파싱 실패하던 버그 방지).
$raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()
try { $j = $raw | ConvertFrom-Json } catch { return }
$model = $j.model.display_name
$used = 0
$limit = 0
$cw = $j.context_window
if ($cw -and [long]$cw.context_window_size -gt 0) {
    # 공식 필드: context_window_size = 모델별 실제 한도(200k/1M). used = input+cache_read+cache_creation.
    $limit = [long]$cw.context_window_size
    $cu = $cw.current_usage
    if ($cu -and $null -ne $cu.input_tokens) {
        $used = [long]$cu.input_tokens + [long]$cu.cache_read_input_tokens + [long]$cu.cache_creation_input_tokens
    } elseif ($null -ne $cw.total_input_tokens) {
        # current_usage는 첫 API 호출 전/compact 직후 null
        $used = [long]$cw.total_input_tokens
    }
} else {
    # 구버전 Claude Code 폴백: transcript 마지막 usage
    $tp = $j.transcript_path
    if ($tp -and (Test-Path -LiteralPath $tp)) {
        $lines = @(Get-Content -LiteralPath $tp -Tail 80 -ErrorAction SilentlyContinue)
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            try { $o = $lines[$i] | ConvertFrom-Json } catch { continue }
            $u = $o.message.usage
            if ($u -and $null -ne $u.input_tokens) {
                $used = [long]$u.input_tokens + [long]$u.cache_read_input_tokens + [long]$u.cache_creation_input_tokens
                break
            }
        }
    }
    # model.id 기반 한도: Fable/Mythos/Opus 4.6+/1M 컨텍스트 변형 = 1M, 그 외 기본 200k.
    $mid = [string]$j.model.id
    if ($mid -match 'fable|mythos' -or $mid -match '\[1m\]' -or $mid -match 'opus-4-[6-9]') { $limit = 1000000 }
    else { $limit = 200000 }
    # 안전망: 1M 세션 신호(exceeds_200k_tokens) 또는 실측 200k 초과 시 1M 보정.
    if ($j.exceeds_200k_tokens -or $used -gt 200000) { $limit = 1000000 }
}
$pct = if ($limit -gt 0) { [math]::Round($used * 100.0 / $limit) } else { 0 }
$usedK = [math]::Round($used / 1000.0)
if ($limit -ge 1000000) {
    $m = [math]::Round($limit / 1000000.0, 1)
    $limitLabel = if ($m -eq [math]::Floor($m)) { "$([int]$m)M" } else { "${m}M" }
} else {
    $limitLabel = "$([math]::Round($limit / 1000.0))k"
}
$out = "ctx $pct% (${usedK}k/$limitLabel)"
if ($model) { $out += " | $model" }
# retrieval 계측 표시 (read-track hook 누적: cmap=.claude/codemap, ctx=.ctxdb, src=그 외. 세션 시작 시 reset)
# 색상: 라우팅 활성(cmap|ctx>0)=초록, 소스직행(src만)=노랑 경고. route%=(cmap+ctx)/total. hit%=Retrieval 선언 hit/miss율(stop-check 파싱).
$e = [char]27; $G = "$e[32m"; $Y = "$e[33m"; $R = "$e[31m"; $D = "$e[90m"; $Z = "$e[0m"
$statsFile = ".ctxdb/.state/claude-read-stats"
if (Test-Path -LiteralPath $statsFile) {
    $st = @(Get-Content -LiteralPath $statsFile -ErrorAction SilentlyContinue)
    $cmapN = @($st -eq 'cmap').Count
    $ctxN = @($st -eq 'ctx').Count
    $srcN = @($st -eq 'src').Count
    $tot = $cmapN + $ctxN + $srcN
    if ($tot -gt 0) {
        $routed = $cmapN + $ctxN
        $tcol = if ($routed -gt 0) { $G } else { $Y }
        $out += " | $([char]::ConvertFromUtf32(0x1F4E1)) ${tcol}cmap $cmapN ctx $ctxN src $srcN${Z}"
        $route = [int][math]::Floor($routed * 100.0 / $tot + 0.5)
        $rcol = if ($route -ge 50) { $G } elseif ($route -ge 25) { $Y } else { $R }
        $out += " ${D}route${Z} ${rcol}${route}%${Z}"
    }
}
# hit율 (stop-check가 응답 '📡 Retrieval:' 선언의 codemap/ctxdb hit|miss를 누적). 미사용 턴은 분모 제외.
$retFile = ".ctxdb/.state/claude-retrieval-stats"
if (Test-Path -LiteralPath $retFile) {
    $rs = @(Get-Content -LiteralPath $retFile -ErrorAction SilentlyContinue)
    $ch = @($rs -eq 'cmap:hit').Count; $cm = @($rs -eq 'cmap:miss').Count
    $xh = @($rs -eq 'ctx:hit').Count;  $xm = @($rs -eq 'ctx:miss').Count
    $hitParts = @()
    if (($ch + $cm) -gt 0) { $r = [int][math]::Floor($ch * 100.0 / ($ch + $cm) + 0.5); $c = if ($r -ge 70) { $G } elseif ($r -ge 40) { $Y } else { $R }; $hitParts += "c ${c}${r}%${Z}($ch/$($ch + $cm))" }
    if (($xh + $xm) -gt 0) { $r = [int][math]::Floor($xh * 100.0 / ($xh + $xm) + 0.5); $c = if ($r -ge 70) { $G } elseif ($r -ge 40) { $Y } else { $R }; $hitParts += "x ${c}${r}%${Z}($xh/$($xh + $xm))" }
    if ($hitParts.Count -gt 0) { $out += " ${D}hit${Z} " + ($hitParts -join " ") }
}
Write-Output $out
'@

# ── statusline.sh (Mac/Linux bash 포트, LF/no-BOM. jq 필요) ────────────────────
Write-FileContent ".claude\hooks\statusline.sh" -Unix @'
#!/usr/bin/env bash
# statusLine - 컨텍스트 윈도우 사용량(%) 표시 (statusline.ps1 bash 포트). JSON 파싱에 jq 사용.
# 1순위: stdin JSON의 context_window 필드 (Claude Code v2.1.132+, 모델별 실제 한도 + /context 동일 계산).
# 2순위(구버전 폴백): transcript JSONL 마지막 usage + model.id 기반 한도 테이블.
raw="$(cat)"
if ! command -v jq >/dev/null 2>&1; then printf 'ctx n/a (jq 필요)'; exit 0; fi
model="$(printf '%s' "$raw" | jq -r '.model.display_name // empty' 2>/dev/null)"
limit=0
used=0
cw_size="$(printf '%s' "$raw" | jq -r '.context_window.context_window_size // 0' 2>/dev/null)"
case "$cw_size" in (''|*[!0-9]*) cw_size=0 ;; esac
if [ "$cw_size" -gt 0 ]; then
  # 공식 필드: context_window_size = 모델별 실제 한도. used = input+cache_read+cache_creation (null이면 total_input_tokens 폴백).
  limit=$cw_size
  used="$(printf '%s' "$raw" | jq -r 'if .context_window.current_usage and .context_window.current_usage.input_tokens != null then ((.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0)) else (.context_window.total_input_tokens // 0) end' 2>/dev/null)"
else
  # 구버전 Claude Code 폴백: transcript 마지막 usage
  tp="$(printf '%s' "$raw" | jq -r '.transcript_path // empty' 2>/dev/null)"
  if [ -n "$tp" ] && [ -f "$tp" ]; then
    used="$(tail -n 80 "$tp" 2>/dev/null | jq -rs '[ .[] | select(.message.usage.input_tokens != null) ] | last | if . then ((.message.usage.input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0)) else 0 end' 2>/dev/null)"
  fi
  # model.id 기반 한도: Fable/Mythos/Opus 4.6+/1M 컨텍스트 변형 = 1M, 그 외 기본 200k.
  mid="$(printf '%s' "$raw" | jq -r '.model.id // empty' 2>/dev/null)"
  case "$mid" in
    *fable*|*mythos*|*'[1m]'*|*opus-4-6*|*opus-4-7*|*opus-4-8*|*opus-4-9*) limit=1000000 ;;
    *) limit=200000 ;;
  esac
fi
case "$used" in (''|*[!0-9]*) used=0 ;; esac
# 안전망: 1M 세션 신호(exceeds_200k_tokens) 또는 실측 200k 초과 시 1M 보정.
exceeds="$(printf '%s' "$raw" | jq -r '.exceeds_200k_tokens // false' 2>/dev/null)"
if [ "$limit" -lt 1000000 ]; then
  if [ "$exceeds" = "true" ] || [ "$used" -gt 200000 ]; then limit=1000000; fi
fi
pct=$(( used * 100 / limit ))
usedk=$(( used / 1000 ))
if [ "$limit" -ge 1000000 ]; then limitlabel="$(( limit / 1000000 ))M"; else limitlabel="$(( limit / 1000 ))k"; fi
out="ctx ${pct}% (${usedk}k/${limitlabel})"
[ -n "$model" ] && out="$out | $model"
# retrieval 계측 표시 (read-track hook 누적: cmap/ctx/src. 세션 시작 시 reset)
# 색상: 라우팅 활성=초록, 소스직행(src만)=노랑. route%=(cmap+ctx)/total. hit%=Retrieval 선언 hit/miss율(stop-check 파싱).
E=$(printf '\033'); G="${E}[32m"; Y="${E}[33m"; R="${E}[31m"; D="${E}[90m"; Z="${E}[0m"
sf=".ctxdb/.state/claude-read-stats"
if [ -f "$sf" ]; then
  cmapn="$(grep -c '^cmap$' "$sf" 2>/dev/null)"; ctxn="$(grep -c '^ctx$' "$sf" 2>/dev/null)"; srcn="$(grep -c '^src$' "$sf" 2>/dev/null)"
  case "$cmapn" in (''|*[!0-9]*) cmapn=0 ;; esac
  case "$ctxn" in (''|*[!0-9]*) ctxn=0 ;; esac
  case "$srcn" in (''|*[!0-9]*) srcn=0 ;; esac
  tot=$(( cmapn + ctxn + srcn ))
  if [ "$tot" -gt 0 ]; then
    routed=$(( cmapn + ctxn ))
    if [ "$routed" -gt 0 ]; then tcol="$G"; else tcol="$Y"; fi
    out="$out | 📡 ${tcol}cmap ${cmapn} ctx ${ctxn} src ${srcn}${Z}"
    route=$(( (routed * 100 + tot / 2) / tot ))
    if [ "$route" -ge 50 ]; then rcol="$G"; elif [ "$route" -ge 25 ]; then rcol="$Y"; else rcol="$R"; fi
    out="$out ${D}route${Z} ${rcol}${route}%${Z}"
  fi
fi
# hit율 (stop-check가 응답 '📡 Retrieval:' 선언의 codemap/ctxdb hit|miss 누적). 미사용 턴은 분모 제외.
rf=".ctxdb/.state/claude-retrieval-stats"
if [ -f "$rf" ]; then
  ch="$(grep -c '^cmap:hit$' "$rf" 2>/dev/null)"; cm="$(grep -c '^cmap:miss$' "$rf" 2>/dev/null)"
  xh="$(grep -c '^ctx:hit$' "$rf" 2>/dev/null)"; xm="$(grep -c '^ctx:miss$' "$rf" 2>/dev/null)"
  for v in ch cm xh xm; do eval "case \"\$$v\" in (''|*[!0-9]*) $v=0 ;; esac"; done
  hit=""
  cden=$(( ch + cm ))
  if [ "$cden" -gt 0 ]; then r=$(( (ch * 100 + cden / 2) / cden )); if [ "$r" -ge 70 ]; then c="$G"; elif [ "$r" -ge 40 ]; then c="$Y"; else c="$R"; fi; hit="c ${c}${r}%${Z}(${ch}/${cden})"; fi
  xden=$(( xh + xm ))
  if [ "$xden" -gt 0 ]; then r=$(( (xh * 100 + xden / 2) / xden )); if [ "$r" -ge 70 ]; then c="$G"; elif [ "$r" -ge 40 ]; then c="$Y"; else c="$R"; fi; if [ -n "$hit" ]; then hit="$hit "; fi; hit="${hit}x ${c}${r}%${Z}(${xh}/${xden})"; fi
  if [ -n "$hit" ]; then out="$out ${D}hit${Z} $hit"; fi
fi
printf '%s' "$out"
'@

# ── Codex native adapter: config + hooks ─────────────────────────────────────
Step-Begin "Codex native adapter"
Write-FileContent -NoBom ".codex\config.toml" @'
# Project hook definitions live in .codex/hooks.json.
# Codex loads hooks.json from trusted config layers.
# Run /hooks in Codex after changes to review and trust project-local hooks.
'@

Write-FileContent -NoBom ".codex\hooks.json" @'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'd=\"$PWD\"; while :; do f=\"$d/.codex/hooks/session-start.sh\"; if [ -f \"$f\" ]; then exec sh \"$f\"; fi; p=$(dirname \"$d\"); [ \"$p\" = \"$d\" ] && break; d=\"$p\"; done; printf \"{}\\n\"'",
            "commandWindows": "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABQAHIAbwBnAHIAZQBzAHMAUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwBpAGwAZQBuAHQAbAB5AEMAbwBuAHQAaQBuAHUAZQAnAAoAJABkAD0AKABHAGUAdAAtAEwAbwBjAGEAdABpAG8AbgApAC4AUABhAHQAaAAKAHcAaABpAGwAZQAgACgAJAB0AHIAdQBlACkAIAB7AAoAIAAgACQAcAAgAD0AIABKAG8AaQBuAC0AUABhAHQAaAAgACQAZAAgACcALgBjAG8AZABlAHgALwBoAG8AbwBrAHMALwBzAGUAcwBzAGkAbwBuAC0AcwB0AGEAcgB0AC4AcABzADEAJwAKACAAIABpAGYAIAAoAFQAZQBzAHQALQBQAGEAdABoACAAJABwACkAIAB7ACAAJgAgACQAcAA7ACAAZQB4AGkAdAAgACQATABBAFMAVABFAFgASQBUAEMATwBEAEUAIAB9AAoAIAAgACQAcABhAHIAZQBuAHQAIAA9ACAAUwBwAGwAaQB0AC0AUABhAHQAaAAgAC0AUABhAHIAZQBuAHQAIAAkAGQACgAgACAAaQBmACAAKAAtAG4AbwB0ACAAJABwAGEAcgBlAG4AdAAgAC0AbwByACAAJABwAGEAcgBlAG4AdAAgAC0AZQBxACAAJABkACkAIAB7ACAAJwB7AH0AJwA7ACAAZQB4AGkAdAAgADAAIAB9AAoAIAAgACQAZAAgAD0AIAAkAHAAYQByAGUAbgB0AAoAfQAKAA==",
            "timeout": 10,
            "statusMessage": "Resetting PawPad Codex session state"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'd=\"$PWD\"; while :; do f=\"$d/.codex/hooks/ctxdb-inject.sh\"; if [ -f \"$f\" ]; then exec sh \"$f\"; fi; p=$(dirname \"$d\"); [ \"$p\" = \"$d\" ] && break; d=\"$p\"; done; printf \"{}\\n\"'",
            "commandWindows": "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABQAHIAbwBnAHIAZQBzAHMAUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwBpAGwAZQBuAHQAbAB5AEMAbwBuAHQAaQBuAHUAZQAnAAoAJABkAD0AKABHAGUAdAAtAEwAbwBjAGEAdABpAG8AbgApAC4AUABhAHQAaAAKAHcAaABpAGwAZQAgACgAJAB0AHIAdQBlACkAIAB7AAoAIAAgACQAcAAgAD0AIABKAG8AaQBuAC0AUABhAHQAaAAgACQAZAAgACcALgBjAG8AZABlAHgALwBoAG8AbwBrAHMALwBjAHQAeABkAGIALQBpAG4AagBlAGMAdAAuAHAAcwAxACcACgAgACAAaQBmACAAKABUAGUAcwB0AC0AUABhAHQAaAAgACQAcAApACAAewAgACYAIAAkAHAAOwAgAGUAeABpAHQAIAAkAEwAQQBTAFQARQBYAEkAVABDAE8ARABFACAAfQAKACAAIAAkAHAAYQByAGUAbgB0ACAAPQAgAFMAcABsAGkAdAAtAFAAYQB0AGgAIAAtAFAAYQByAGUAbgB0ACAAJABkAAoAIAAgAGkAZgAgACgALQBuAG8AdAAgACQAcABhAHIAZQBuAHQAIAAtAG8AcgAgACQAcABhAHIAZQBuAHQAIAAtAGUAcQAgACQAZAApACAAewAgACcAewB9ACcAOwAgAGUAeABpAHQAIAAwACAAfQAKACAAIAAkAGQAIAA9ACAAJABwAGEAcgBlAG4AdAAKAH0ACgA=",
            "timeout": 10,
            "statusMessage": "Loading PawPad ctxdb context"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'd=\"$PWD\"; while :; do f=\"$d/.codex/hooks/pre-compact.sh\"; if [ -f \"$f\" ]; then exec sh \"$f\"; fi; p=$(dirname \"$d\"); [ \"$p\" = \"$d\" ] && break; d=\"$p\"; done; printf \"{}\\n\"'",
            "commandWindows": "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABQAHIAbwBnAHIAZQBzAHMAUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwBpAGwAZQBuAHQAbAB5AEMAbwBuAHQAaQBuAHUAZQAnAAoAJABkAD0AKABHAGUAdAAtAEwAbwBjAGEAdABpAG8AbgApAC4AUABhAHQAaAAKAHcAaABpAGwAZQAgACgAJAB0AHIAdQBlACkAIAB7AAoAIAAgACQAcAAgAD0AIABKAG8AaQBuAC0AUABhAHQAaAAgACQAZAAgACcALgBjAG8AZABlAHgALwBoAG8AbwBrAHMALwBwAHIAZQAtAGMAbwBtAHAAYQBjAHQALgBwAHMAMQAnAAoAIAAgAGkAZgAgACgAVABlAHMAdAAtAFAAYQB0AGgAIAAkAHAAKQAgAHsAIAAmACAAJABwADsAIABlAHgAaQB0ACAAJABMAEEAUwBUAEUAWABJAFQAQwBPAEQARQAgAH0ACgAgACAAJABwAGEAcgBlAG4AdAAgAD0AIABTAHAAbABpAHQALQBQAGEAdABoACAALQBQAGEAcgBlAG4AdAAgACQAZAAKACAAIABpAGYAIAAoAC0AbgBvAHQAIAAkAHAAYQByAGUAbgB0ACAALQBvAHIAIAAkAHAAYQByAGUAbgB0ACAALQBlAHEAIAAkAGQAKQAgAHsAIAAnAHsAfQAnADsAIABlAHgAaQB0ACAAMAAgAH0ACgAgACAAJABkACAAPQAgACQAcABhAHIAZQBuAHQACgB9AAoA",
            "timeout": 10,
            "statusMessage": "PawPad PreCompact context-saver reminder"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'd=\"$PWD\"; while :; do f=\"$d/.codex/hooks/stop-check.sh\"; if [ -f \"$f\" ]; then exec sh \"$f\"; fi; p=$(dirname \"$d\"); [ \"$p\" = \"$d\" ] && break; d=\"$p\"; done; printf \"{}\\n\"'",
            "commandWindows": "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABQAHIAbwBnAHIAZQBzAHMAUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwBpAGwAZQBuAHQAbAB5AEMAbwBuAHQAaQBuAHUAZQAnAAoAJABkAD0AKABHAGUAdAAtAEwAbwBjAGEAdABpAG8AbgApAC4AUABhAHQAaAAKAHcAaABpAGwAZQAgACgAJAB0AHIAdQBlACkAIAB7AAoAIAAgACQAcAAgAD0AIABKAG8AaQBuAC0AUABhAHQAaAAgACQAZAAgACcALgBjAG8AZABlAHgALwBoAG8AbwBrAHMALwBzAHQAbwBwAC0AYwBoAGUAYwBrAC4AcABzADEAJwAKACAAIABpAGYAIAAoAFQAZQBzAHQALQBQAGEAdABoACAAJABwACkAIAB7ACAAJgAgACQAcAA7ACAAZQB4AGkAdAAgACQATABBAFMAVABFAFgASQBUAEMATwBEAEUAIAB9AAoAIAAgACQAcABhAHIAZQBuAHQAIAA9ACAAUwBwAGwAaQB0AC0AUABhAHQAaAAgAC0AUABhAHIAZQBuAHQAIAAkAGQACgAgACAAaQBmACAAKAAtAG4AbwB0ACAAJABwAGEAcgBlAG4AdAAgAC0AbwByACAAJABwAGEAcgBlAG4AdAAgAC0AZQBxACAAJABkACkAIAB7ACAAJwB7AH0AJwA7ACAAZQB4AGkAdAAgADAAIAB9AAoAIAAgACQAZAAgAD0AIAAkAHAAYQByAGUAbgB0AAoAfQAKAA==",
            "timeout": 10,
            "statusMessage": "Checking PawPad checkpoint rules"
          }
        ]
      }
    ]
  }
}
'@

Write-FileContent ".codex\hooks\session-start.ps1" @'
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
'@

Write-FileContent ".codex\hooks\session-start.sh" -Unix @'
#!/usr/bin/env sh
set -eu

if command -v pwsh >/dev/null 2>&1; then
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  exec pwsh -NoProfile -File "$script_dir/session-start.ps1"
fi

printf '%s\n' '{}'
'@

Write-FileContent ".codex\hooks\ctxdb-inject.ps1" @'
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
'@

Write-FileContent ".codex\hooks\ctxdb-inject.sh" -Unix @'
#!/usr/bin/env sh
set -eu

if command -v pwsh >/dev/null 2>&1; then
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  exec pwsh -NoProfile -File "$script_dir/ctxdb-inject.ps1"
fi

printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"ctxdb: hook-skip | - | L2 0 files | pwsh not found for .codex/hooks/ctxdb-inject.sh"}}'
'@

Write-FileContent ".codex\hooks\stop-check.ps1" @'
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

    if ($needsCheckpoint -or $needsSplit) {
        $reasonParts = New-Object System.Collections.Generic.List[string]
        if ($needsCheckpoint) {
            $reasonParts.Add("Codex checkpoint: $turn turns reached. Run context-saver: append current session summary to .ctxdb/L2, update .ctxdb/INDEX.md Codex row, refresh lane/_wip.md, and update codemap for new symbols.")
        }
        if ($needsSplit) {
            $reasonParts.Add("L2 split needed: " + ($oversized -join ", ") + " exceeds 150 lines or 2000 tokens. Split old entries or route via L1/L3 before continuing.")
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
'@

Write-FileContent ".codex\hooks\stop-check.sh" -Unix @'
#!/usr/bin/env sh
set -eu

if command -v pwsh >/dev/null 2>&1; then
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  exec pwsh -NoProfile -File "$script_dir/stop-check.ps1"
fi

printf '%s\n' '{}'
'@

# ── hooks: pre-compact.ps1 (Codex native compaction 직전 context-saver 유도 + 가드) ──
Write-FileContent ".codex\hooks\pre-compact.ps1" @'
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
'@

Write-FileContent ".codex\hooks\pre-compact.sh" -Unix @'
#!/usr/bin/env sh
set -eu

if command -v pwsh >/dev/null 2>&1; then
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  exec pwsh -NoProfile -File "$script_dir/pre-compact.ps1"
fi

printf '%s\n' '{}'
'@

# ── .ctxdb: 키워드 depth 컨텍스트 DB (토큰 절약 lazy-load) ──────────────────────
Step-Begin "ctxdb (context DB)"
Write-FileContent ".ctxdb\INDEX.md" @"
# .ctxdb/INDEX.md — $projectName 컨텍스트 인덱스
> 생성일: $today | Phase: 1 | depth: keyword -> L1 -> L2
> 이 파일 수정 에이전트는 AGENT SYNC 테이블의 자기 행만 갱신.

## 키워드 -> L1 매핑 테이블
| 우선순위 | 키워드 | L1 파일 경로 |
|---|---|---|
| 1 | (예: AUTH, 인증, 로그인) | L1/domain-sample.md |
| 2 | codebase-map, architecture, structure, conventions, concerns, project map, high-level map | L1/domain-codebase-map.md |

## AGENT SYNC 테이블
| Agent | 마지막 작업일 | 기록된 L2 파일 | 상태 |
|---|---|---|---|
| Claude Code | - | - | pending |
| Codex | - | - | pending |

## 예외 규칙
| 조건 | 예외 내용 |
|---|---|
| (예: 미디어/AI 합성) | L2 최대 3개 로드 (기본 2개) |
"@

Write-FileContent ".ctxdb\L1\domain-sample.md" @"
# L1/domain-sample.md — (샘플 도메인) 라우팅
> L2 파일 포인터. 새 도메인 추가 시 이 형식 복사 후 INDEX.md 키워드 테이블에 등록.

| 키워드 | L2 파일 경로 | 설명 |
|---|---|---|
| 구조 | L2/arch-overview.md | 아키텍처 |
"@

Write-FileContent ".ctxdb\L2\arch-overview.md" @"
# L2/arch-overview.md
> 기술스택 · 프로젝트 구조 · 데이터 모델 (프로젝트에 맞게 작성)
> 크기 제한: 150줄 또는 2,000토큰 초과 시 L3 분할.

## 기술 스택
(작성)

## 프로젝트 구조
(작성)
"@

Write-FileContent ".ctxdb\L2\progress-current.md" @"
# L2/progress-current.md
> Phase: 1 | 마지막 업데이트: $today

## 현재 작업 상태
(작업 시작 후 context-saver 스킬이 세션 요약을 append)
"@

Write-FileContent ".ctxdb\L1\domain-codebase-map.md" @"
# L1/domain-codebase-map.md
> Keywords: codebase-map, architecture, structure, conventions, concerns, testing, project map, high-level map

## L2 pointers
- L2/codebase-map-current.md  (digest, 주입 전용)

## Scope
7축 고수준 코드베이스 맵(ARCH/STRUCT/CONV/TEST/CONCERNS + optional STACK/INTEG).
canonical .claude/pawpad/codebase/, digest .ctxdb/L2/codebase-map-current.md, skill .claude/skills/codebase-map.
주입 정책: digest-only. full 7축은 on-demand read. codemap(심볼위치)과 별개 고고도 정신모델.
"@

Write-FileContent ".ctxdb\L2\codebase-map-current.md" @"
# codebase-map digest
> source: .claude/pawpad/codebase/ | refreshed: $today | budget: 120
> 주입 정책: digest-only. full 7축은 on-demand read.

(codebase-map skill로 7축 작성 후 축당 3~6줄 요약 + full pointer를 여기 채움.
 required: ARCH/STRUCT/CONV/TEST/CONCERNS. optional: STACK/INTEG는 해당 시만 행 추가.)
"@

Write-FileContent ".claude\pawpad\codebase\README.md" @"
# codebase/ — High-Level CodeBase Map (7 axes)

Canonical 7축 고수준 코드베이스 맵. 스킬 정의: .claude/skills/codebase-map/SKILL.md.

## 파일
| 축 | 파일 | required | budget |
|----|------|:--------:|:------:|
| ARCH    | architecture.md | Y | 220 |
| STRUCT  | structure.md    | Y | 150 |
| CONV    | conventions.md  | Y | 150 |
| TEST    | testing.md      | Y | 150 |
| CONCERNS| concerns.md     | Y | 150 |
| STACK   | stack.md        | optional | 150 |
| INTEG   | integrations.md | optional | 150 |

## 규칙
- 각 파일 stale-guard 헤더 필수(Last refreshed / Stale when / Budget).
- digest: .ctxdb/L2/codebase-map-current.md (주입 전용, budget 120).
- 주입은 digest-only. full docs는 on-demand read.
- 갱신: code+doc atomic. 구조 변경 시 해당 축만 수정 + digest 동기.
- 권한: 추가=누구나, 수정=lane owner.
"@

Write-FileContent ".ctxdb\.state\turn-count" "0"
Write-FileContent ".ctxdb\.state\codex-turn-count" "session:manual`nturn:0"
Write-FileContent ".ctxdb\.state\codex-loaded" "manual"
Write-FileContent ".ctxdb\VERSION" "1.0.0"

# ── Skills: ctxdb-navigator (세션시작 키워드 최소 로드) ────────────────────────
Step-Begin "skill: ctxdb-navigator"
Write-FileContent ".claude\skills\ctxdb-navigator\SKILL.md" -NoBom @'
---
name: ctxdb-navigator
description: Keyword depth context loader. Use at session start (or "컨텍스트 로드"/"INDEX 읽어줘") to traverse .ctxdb/ INDEX->L1->L2 and load only the minimum keyword-matched files, saving tokens.
---
# ctxdb-navigator - 키워드 depth 컨텍스트 로더

## 목적
.ctxdb/ 계층 인덱스를 탐색해 작업에 필요한 최소 L1/L2 파일만 로드. 전체 로드 금지로 토큰 절약.

## 트리거
- 세션 시작 시 자동 (SessionStart hook이 INDEX 미리 주입 -> 키워드 매칭만 수행)
- "INDEX.md 읽어줘", "컨텍스트 로드" 입력 시

## 절차
STEP 1: INDEX.md 읽기
  .ctxdb/INDEX.md 읽기. 없으면 즉시 보고.
STEP 2: AGENT SYNC 확인
  이전 에이전트의 마지막 작업 L2 파일 / 상태 확인.
STEP 3: 키워드 매핑
  사용자 첫 메시지에서 키워드 추출 -> INDEX 매핑 테이블 -> L1/{파일}.md -> L2/{파일}.md
  키워드 충돌: 매핑 테이블 첫 행 우선.
  키워드 불명확: L2/progress-current.md만 로드 후 사용자 명확화 요청.
STEP 4: 최소 로드
  L1 <= 1개, L2 <= 2개 (예외규칙 해당 시 L2 3개).
STEP 5: 크기 점검
  L2 150줄 초과 또는 2,000토큰(문자수/3.5) 초과 -> "분할 필요" 경고.
STEP 6: 요약
  "로드 완료: {파일목록} / 핵심: {2~3줄}"

## 첫 응답 검증 출력 (의무)
첫 응답 최상단에 1줄: 📂 .ctxdb: {project} | {last-date} | {loaded L2} | {status}
누락 시 사용자는 INDEX 미로드로 간주 -> 재확인 요청.
'@

# ── Skills: context-saver (세션 종료/8턴 저장) ─────────────────────────────────
Step-Begin "skill: context-saver"
Write-FileContent ".claude\skills\context-saver\SKILL.md" -NoBom @'
---
name: context-saver
description: Save the current session work into .ctxdb/L2/, update INDEX.md AGENT SYNC, and refresh INDEX/L1 keyword mapping for any new domain/symbol. Use when the Stop hook emits a checkpoint block, on "세션저장"/"save context", or before /compact.
---
# context-saver - 세션 컨텍스트 저장

## 목적
현재 세션 작업을 .ctxdb/L2/ 에 기록하고 INDEX.md AGENT SYNC를 갱신. 다음 세션이 키워드로 재로드.

## 트리거
- Stop hook decision:block (checkpoint) 수신 시
- "저장해줘", "세션저장", "컨텍스트저장", "save context" 입력 시
- /compact 실행 전 반드시 먼저 실행 (순서 역전 금지)

## 절차
STEP 1: 저장 대상 L2 결정
  작업 내용 분석 -> 해당 도메인 L2 파일 선택 (없으면 progress-current.md).
STEP 2: L2 기록 (append)
  형식: ## [{에이전트명}] YYYY-MM-DD HH:MM — {작업 요약}
  내용: 완료 작업, 결정사항, 변경 파일, 미완료, 다음 작업.
  크기(세션 블록): **1회 append ≤ 40줄**. digest 전용 — 항목당 1줄 위주, 코드/로그/diff 원문 금지.
    (L2 tail 150줄이 hook으로 매 세션 화면·컨텍스트에 주입됨. 긴 블록 = 토큰 낭비 + Codex CLI 화면 노이즈.)
    40줄 초과가 필요하면 본문은 canonical 위치(spec/ADR/verifications/lane)에 쓰고 L2에는 포인터 1줄.
  크기(파일 전체): 150줄 또는 2,000토큰 초과 시 분할 경고.
STEP 3: INDEX.md AGENT SYNC 갱신
  자기 행만 수정 (타 에이전트 행 금지). 컬럼: 마지막 작업일, 기록 L2, 상태.
  L2 3개+ -> L1 포인터로 대체 (-> L1/{파일}.md).
STEP 4: 키워드 인덱스 갱신 (신규 도메인/심볼 등장 시만)
  이번 작업에서 기존 INDEX/L1에 없는 도메인·핵심 용어가 생겼으면 반영:
  - 신규 도메인: L1/domain-{new}.md 생성(키워드 + 파일/심볼 포인터) + INDEX 키워드->L1 매핑 1행 추가
  - 기존 도메인 새 용어: 해당 L1 키워드 열에 누락된 핵심어만 추가 (중복/유사어 금지)
  - codemap 연계: 이번에 _index.md에 추가한 신규 심볼의 도메인이 INDEX 키워드로 잡히는지 확인, 누락 시 추가
  - 폭주 방지: INDEX는 도메인당 1행. L1 키워드는 검색용 핵심어만 (심볼 전수나열 금지 = codemap 역할). 변화 없으면 이 STEP 건너뜀.
  - 권한(하이브리드): 키워드 추가는 누구나 / 기존 매핑 행 수정·삭제는 신중 (codemap 권한 준용, 충돌 시 양쪽 보존 후 정리)
STEP 5: 보고
  "저장 완료: {L2 파일 목록}" 출력. 키워드 갱신 시 "INDEX/L1 키워드 갱신: {요약}" 추가.

## 주의
- L2 초과 시 L3 분할(.ctxdb/L3/) 안내 후 사용자 확인.
- codemap(_index.md)과 역할 분리: codemap=심볼 위치(전수, 정밀), ctxdb 키워드=도메인 라우팅(핵심어 소수). 키워드에 심볼 전부 넣지 말 것.
- Decision Placement(.claude/HYBRID.md Decision Placement Matrix): L2는 세션 재개 digest 전용. 지속 결정(arch ADR / spec scope / 거절기록)은 L2에만 묻지 말고 canonical 위치(decisions/arch.md, specs/, decisions/rejected.md)에도 기록.
'@

# ── Skills: resume ────────────────────────────────────────────────────────────
Step-Begin "skill: resume"
Write-FileContent ".claude\skills\resume\SKILL.md" -NoBom @"
---
name: resume
description: Hybrid session resume protocol. Use at session start (ON START) to read HYBRID/_wip/lane/handoff/meta/codemap and resume cross-agent (Claude<->Codex) work without losing context.
---
# Resume Skill - Session Resume Protocol (Hybrid)

## 파일 역할
| 파일/경로 | 역할 | 읽는 시점 |
|----------|------|---------|
| .claude/HYBRID.md                 | 협업 프로토콜               | ON START - active lane 시(없으면 skip) |
| .claude/pawpad/_wip.md               | active lane router          | ON START - 1번째     |
| .claude/pawpad/wip/{feature}.md      | 기능별 lane 상세            | active lane 있을 때  |
| .claude/pawpad/wip/done/             | 완료된 lane 보관 (audit)    | 히스토리 조회 시     |
| .claude/pawpad/handoffs/             | 핸드오프 snapshot           | state=HANDOFF_TO_* 시 |
| .claude/pawpad/specs/{feature}.md    | feature spec (기획 산출물) | state=SPEC_READY 또는 구현 직전 |
| .claude/pawpad/_meta.md              | Sprint/BLOCKED/NEXT(상단)+RECENT 완료이력(하단) | ON START 상단만 / RECENT on-demand |
| .claude/pawpad/sessions/             | 세션 상세 (온디맨드)         | 필요 시만            |
| .claude/pawpad/decisions/rejected.md | 실패 기록                   | 유사 작업 전         |
| .claude/pawpad/decisions/arch.md     | ADR                         | 아키텍처 결정 전     |
| .claude/pawpad/backup/               | -Force 시 자동 백업          | 복구 필요 시         |

## ON START 절차 (agent가 순차 실행 — CLAUDE.md/AGENTS.md Session Protocol과 동일 순서)
1. read .claude/pawpad/_wip.md (active lane router)
   -> Active Lanes 비어있음: 새 작업 시작 (이후 HYBRID 등 skip)
   -> Active Lanes 존재: assigned lane 읽기
2. Active Lanes 있으면 read .claude/HYBRID.md (협업 프로토콜). 없으면 skip -> 신규 lane 생성/핸드오프/인수 시점에 read
3. lane 파일 있으면: read .claude/pawpad/wip/{feature}.md
4. lane state=HANDOFF_TO_* : _wip.md의 handoff 필드 경로로 snapshot read
5. lane state=SPEC_READY 또는 spec 있으면: read .claude/pawpad/specs/{feature}.md
6. read .claude/pawpad/_meta.md 상단만 (헤더 SPRINT/PHASE/STACK + BLOCKED + NEXT). RECENT(완료 이력)는 파일 하단·재개 불요 -> 생략, history 필요 시 on-demand
7. read .claude/codemap/_index.md (코드 수정 작업 시점만; 질문/분석 세션 skip)

## _wip.md (Router) 포맷
# WIP ROUTER

## Active Lanes
- {feature-id}: .claude/pawpad/wip/{feature-id}.md
  - owner: {Claude Code | Codex}
  - state: WIP | SPEC_READY | HANDOFF_TO_CODEX | HANDOFF_TO_CLAUDE | HANDOFF_TO_NEXT_AGENT | BLOCKED
  - handoff: .claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md   (state=HANDOFF_* 일 때만)
  - updated: YYYY-MM-DD HH:MM

## Locks
- {파일 경로 glob} -> {owner agent}

## State Enum 명세
| state | 의미 | 추가 필드 | 후속 agent 행동 |
|-------|------|---------|--------------|
| WIP | 작업 진행 중 | - | 본인 lane이면 계속 |
| SPEC_READY | 기획 완료, 구현 대기 | - | specs/{feature}.md read 후 구현 시작 |
| HANDOFF_TO_CODEX | Codex로 인수 요청 | handoff | Codex가 snapshot read, state=WIP, owner=Codex로 변경 |
| HANDOFF_TO_CLAUDE | Claude로 인수 요청 | handoff | Claude가 snapshot read, state=WIP, owner=Claude로 변경 |
| HANDOFF_TO_NEXT_AGENT | 다음 agent 미정 | handoff | 인수 agent가 snapshot read, state=WIP, owner=자기로 변경 |
| BLOCKED | 외부 의존 대기 | - | 차단 해소 시 owner가 state=WIP로 복귀 |

## lane 파일 (.claude/pawpad/wip/{feature}.md) 포맷
# LANE - {feature-id} - YYYY-MM-DD HH:MM

## Owner
{Claude Code | Codex}

## State
WIP | SPEC_READY | HANDOFF_TO_* | BLOCKED

## 작업 중
- [domain:feature] [설명] ([진행률 %])
  - 완료: [한 것]
  - 미완: [남은 것]

## 수정한 파일 (미커밋)
- src/path/to/file.<ext>    <- [수정중 / 미완성]

## 다음 단계
1. [액션]
2. [액션]

## 중단 이유 (중단 시만)
- [이유]

## 업데이트 타이밍
| 시점 | agent 액션 |
|------|----------|
| 서브태스크 완료       | lane 파일 "다음 단계" 갱신                            |
| 세션 중단 예상       | lane 전체 상태 + 중단 이유 작성                       |
| 60% context 도달    | /checkpoint -> 필요시 /handoff                       |
| spec 작성 완료      | state=SPEC_READY, _wip.md 갱신                       |
| 핸드오프 발생       | state=HANDOFF_TO_*, handoff 필드 추가                |
| 인수 시            | state=WIP, owner=받는 agent로 변경                   |
| 전체 태스크 완료     | lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 |

## 완료 lane 처리 (audit 보존, timestamp 명명)
- 작업 완료 시: .claude/pawpad/wip/{feature-id}.md -> .claude/pawpad/wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md
  - timestamp는 완료 시각
  - 같은 feature 재작업 시 이전 done 파일 보존 (덮어쓰기 방지)
- _wip.md Active Lanes에서 해당 lane 제거
- _meta.md RECENT에 1줄 추가
- 삭제 절대 금지 (history 추적 불가능 방지)

예시:
- 첫 완료: wip/done/feature-auth_2026-05-29_143012.md
- 재작업 완료: wip/done/feature-auth_2026-06-15_092044.md (이전 파일 그대로 보존)
- 초 단위(SS)까지 명명: 같은 분 2회 완료 시 충돌 방지

## _meta.md 포맷 (재개 비용 최적화: RECENT를 하단에 둬 ON START가 상단만 부분읽기)
# SPRINT: [W번호] | PHASE: [번호] | STACK: {프로젝트 스택}

## BLOCKED
- [항목] -> [이유]

## NEXT
- [다음 예정 작업]

## RECENT (newest first)
YYYY-MM-DD: [완료 내용]. [영향 파일]. [agent]

## _meta.md 업데이트 규칙
- 태스크 완료 시: RECENT(하단 섹션) 최상단에 1줄 추가 (agent 명시)
- RECENT > 8줄: 초과분 -> .claude/pawpad/sessions/YYYY-MM.md 상단 이동 (newest first)
- BLOCKED / NEXT: 상태 변화 시 즉시 갱신
- ON START는 헤더+BLOCKED+NEXT만 읽음 (RECENT 하단 = 재개 불요, history 시 on-demand)

## Handoff Rules
- 60% context 도달 추정 시 agent가 snapshot 작성 (handoff skill 참조)
- snapshot 경로: .claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md
- agent는 _wip.md Active Lanes의 state와 handoff 필드를 동시에 갱신
- HANDOFF marker:
  - HANDOFF_TO_CODEX : Claude -> Codex
  - HANDOFF_TO_CLAUDE : Codex -> Claude
  - HANDOFF_TO_NEXT_AGENT : 미정
  - SPEC_READY : 기획 산출물 준비 완료
- **인수 절차** (HANDOFF 받는 agent):
  1. _wip.md state/handoff 필드로 snapshot 위치 파악
  2. snapshot read + Next Commands 우선 실행
  3. lane 파일 State: HANDOFF_TO_* -> WIP 변경
  4. lane 파일 Owner: 받는 agent (자기 이름)로 변경
  5. _wip.md Active Lanes: state=WIP, owner=받는 agent, handoff 필드 제거, updated 갱신

## Session Rollover
- 세션 종료 시 lane 파일 + _wip.md + codemap 갱신 강제
- _meta.md RECENT > 8줄 -> sessions/YYYY-MM.md 상단 이동 (newest first)
- 새 세션 시 ON START 절차 그대로 실행 -> 끊김 없는 재개

## Backup
- -Force 실행 시 자동 백업: .claude/pawpad/backup/{timestamp}/
- 백업 대상:
  - **PawPad**: _wip.md, _meta.md, decisions/, wip/ (done 포함), handoffs/, specs/, codemap/_index.md
  - **Context files**: CLAUDE.md, AGENTS.md, .claude/HYBRID.md, .claude/settings.json, .codex/config.json, .gitignore, CONTEXT.md, .claude/SKILLS_MANIFEST.md
- 복구 필요 시 백업 디렉토리에서 수동 복원
- .gitignore에서 .claude/pawpad/backup/ 자동 제외 (민감 정보 보호)

## rejected.md 포맷
## [제목]
시도: [무엇을]
결과: [왜 실패]
해결: [올바른 방법]
날짜: YYYY-MM-DD
agent: [Claude Code | Codex]
"@

# ── Skills: codemap ───────────────────────────────────────────────────────────
Step-Begin "skill: codemap"
Write-FileContent ".claude\skills\codemap\SKILL.md" -NoBom @"
---
name: codemap
description: Symbol location registry. Use to record or look up where feature components live without searching files; enforces owner-separated edit permissions for multi-agent work.
---
# CodeMap Skill - Symbol Location Registry

## 목적
구현된 기능 컴포넌트 위치를 심볼 테이블로 관리.
수정/참조 시 파일 탐색 없이 즉시 위치 파악.

## 심볼 포맷
[domain]:[symbol]    [file_path]    [핵심 시그니처/타입]: [역할 1줄]
목적: 에이전트가 파일을 열지 않고 위치+시그니처+역할 파악 -> 토큰 절약. 실제 수정 시에만 해당 파일 read.
핵심/자주 만지는 심볼만 시그니처+역할 상세. 주변부는 위치만. (codemap=요약, 코드=전체. 로직 복붙 금지)

예시:
auth:login         src/features/auth/login.<ext>         Login: 로그인 화면(이메일+소셜)
db:user            src/models/user.<ext>                 User{id,name,role}: 사용자 모델
api:fetchUser      src/api/user_api.<ext>                fetchUser(id)->User: 유저 조회

## 도메인 분류
| 도메인 | 대상 |
|--------|------|
| auth   | 인증 화면, services |
| club   | (예시 도메인) |
| member | (예시 도메인) |
| db     | 데이터 모델, repository |
| api    | 외부 API 연동 |
| ui     | 공통 UI 컴포넌트 |
| core   | 공통 서비스, 유틸 |

## _index.md 구조
# MAP (data flow / 한눈 조망)   <- 모듈 흐름 다이어그램 (구조·영향범위 파악, 선택)
[레이어/화살표. 예: ui --입력--> core --결과--> render]
# HOT (최근 접근 3~5개)
[최근 심볼]
# INDEX
[전체: domain:symbol  file_path  시그니처: 역할]

## ON START 읽기 (토큰 절감)
- ON START/재개 시 MAP+HOT(조망)만 부분읽기(상단). INDEX는 context에 올리지 않음.
- 특정 심볼 위치 필요 시 INDEX를 Grep(domain:symbol 또는 파일명) — 매칭 줄만 반환 = 전체 로드보다 쌈.
- HOT 규율 필수: 최근 3~5개·각 1줄. 비대하면 부분읽기 효과 반감 -> 초과·노후 항목은 INDEX로 강등.

## 권한 (Owner 분리)
| 작업 | 허용 |
|------|------|
| 신규 항목 추가 (append) | 누구나 (어느 lane이든) |
| 기존 항목 수정 (경로/이름 변경) | lane owner만 |
| 기존 항목 삭제 | lane owner만 |
| HOT 섹션 갱신 | 누구나 |

owner 확인: _wip.md Locks 섹션에서 해당 파일 매핑 확인.
Lock 없는 파일은 추가만 허용, 수정/삭제 시 _wip.md Locks에 임시 lock 등록 권장.

## 업데이트 규칙
| 시점 | 액션 | 누가 |
|------|------|------|
| 새 화면/컴포넌트/서비스 생성 | INDEX에 추가 | 생성한 lane |
| 파일 경로/클래스명 변경        | 해당 행 수정 | **owner만** |
| 파일 삭제                     | 해당 행 제거 | **owner만** |
| 작업 후                       | HOT 섹션 상단 | 누구나 |

## 동시 수정 충돌 방지 (하이브리드)
- 두 에이전트가 동시에 _index.md 수정 시:
  - append 충돌 -> 양쪽 라인 모두 보존
  - 명백한 중복 -> 다음 세션에서 owner가 정리
- 같은 행을 양쪽이 수정 시 -> owner가 우선, 비owner는 _wip.md에 충돌 보고

## 성장 전략 (size-aware, trim-router)
파일 작으면 flat, 커지면 trim-router로 split. page-type별 cap 초과 = task 완료 전 split 필수.
1차 비대 제어는 entry 1줄 규율(긴 문단 entry가 진짜 bloat 원인 — 상세는 spec/lane, codemap엔 포인터만).

### Phase A — flat (~30KB / ~80 entries 이하)
단일 _index.md. MAP + HOT + feature 섹션(# features/...)으로 그룹. 1줄 규율 엄수.

### Phase B — trim-router (~30KB 초과 또는 통째읽기 사고 빈발)
작은 페이지로 분할. domain 중간층 없음(feature leaf와 내용 중복·3중쓰기 drift 유발 → 제외).
구조:
  .claude/codemap/_root.md      -> route + MAP + HOT. source pointer 금지. hard-cap 2KB
  .claude/codemap/keywords.md   -> 한국어/동의어를 feature로 라우팅. source pointer 금지. hard-cap 4KB
  .claude/codemap/features/{feature-id}.md -> source pointer + 최소 판단근거. hard-cap 4KB
- root: route만, 심볼표 금지.
- keywords: 사용자 표현/의도/증상 -> feature 경로만 (동의어 나열보다 "의도·증상→feature" 서술 지향; agent가 의미로 매칭하므로 정확 단어 불요. 파일/심볼 금지 → stale에도 source 무영향). 4KB 초과 시에만 도메인별 분할.
- feature leaf: 실제 수정후보 파일+심볼. leaf 4KB 근접 시 features/{id}/ 하위 ui,data,domain,test로 split.

### Lookup 알고리즘 (최대 3 read)
1. 한국어/자연어/증상 → keywords.md **통째 read 후 의미·맥락 매칭**(grep 아님 — agent가 프롬프트 의도로 해석) → feature leaf 1개 → source. 정확 단어/공백/표현 흔들림 무관(예: "최근완료"="최근 완료", "축하 효과 잘림"→부화 연출 character). (root는 첫 진입만)
2. 영문 심볼 알면 → rg로 .claude/codemap/features 직접 grep (정확매칭·페이지 통째읽기 불필요).
3. 금지: codemap 전체 read / keywords.md를 grep으로 정확매칭(의미매칭이 기본) / 심볼 줄범위 아는데 source 파일 통째 read.
- 핵심: 자연어=의미매칭(표현 강건), 영문심볼=rg 정확매칭. 분할은 lookup 성능 불변 + 실수로 통째읽기만 차단. 다운사이드 없음.

### generated 제외
*.g.dart, *.freezed.dart, lib/generated/** 는 source pointer 대상 아님. 필요시 model leaf에 generated companion exists만 기록.
fallback rg: rg -n "kw|Symbol" lib -g "!*.g.dart" -g "!*.freezed.dart" -g "!lib/generated/**"

### size cap (완료 게이트)
root 2KB / keywords·feature 4KB hard cap. 초과 시 split 후 완료.
검사: .claude/codemap 하위 *.md 각 파일 UTF-8 byte 수가 cap(_root.md=2048, 그외=4096)을 넘으면 FAIL. PowerShell 스크립트는 spec(codemap-8kb-router.md Acceptance) / lane 참조.
"@

# ── Skills: caveman ───────────────────────────────────────────────────────────
Step-Begin "skill: caveman"
Write-FileContent ".claude\skills\caveman\SKILL.md" -NoBom @"
---
name: caveman
description: Output compression reference. Enforcement lives in CLAUDE.md/AGENTS.md Response Style (active every response); this file is the compression spec + commit/review formats. Toggle with "normal mode".
---
# Caveman - Output Compression (참조 문서)

> **강등 안내**: 출력 압축은 **CLAUDE.md/AGENTS.md ``Response Style``이 매 응답 강제**한다.
> 이 파일은 별도 호출 대상이 아니라 **압축 규칙 spec + commit/review 포맷 참조**용이다.
> 해제: "normal mode" / "caveman off" / "원래대로".

## DROP (제거)
- 관사: a / an / the
- 군더더기: just / really / basically / actually / simply
- 인사: "Sure!" / "Certainly" / "물론이죠" / "도와드리겠습니다"
- 헤징: "might be" / "could potentially" / "~일 수도" / "~하면 좋을 것 같습니다"
- 서론/결미: "Let me explain..." / "Hope this helps!"

## KEEP (절대 변경 금지)
- 코드 블록 전체 (들여쓰기 포함)
- 함수명 / 변수명 / 클래스명 / API명
- 에러 메시지 원문
- 파일 경로 / URL / 명령어 / 숫자

## 출력 패턴
[대상] [동작] [이유]. [다음 단계].

## 레벨 (참조)
| 모드   | 설명 |
|--------|------|
| lite  | 관사 인사만 제거. 문법 유지. |
| 기본  | 전부 제거. 조각 문장 허용. |
| ultra | 최대 압축. 화살표(->) 인과관계. |

## commit 포맷 (참조)
Conventional Commits. subject <=50자.
``<type>(<scope>): <subject>`` + (필요 시) body=why.
body 필수: breaking change / security fix / data migration / revert

## review 포맷 (참조)
``L{line}: {emoji} {type}: {problem} - {fix}``
🔴 bug/보안 | 🟡 perf/warning | 🟢 style/minor

## Safety Override
비가역 작업 경고 / 보안 확인 시 -> normal 전환 후 재개.
"@

# ── Skills: feature-architecture ──────────────────────────────────────────────
Step-Begin "skill: feature-architecture"
Write-FileContent ".claude\skills\feature-architecture\SKILL.md" -NoBom @'
---
name: feature-architecture
description: Feature-first structure reference. Enforcement lives in CLAUDE.md/AGENTS.md Architecture Principles; this file is the detailed decision tree, anti-patterns, and stack examples. Use when starting a new feature, placing new code, or restructuring modules.
---
# Feature Architecture - Structure Discipline (참조 문서)

> **강등 안내**: 구조 원칙은 **CLAUDE.md/AGENTS.md `Architecture Principles (Feature-First)`가 강제**한다(신규/변경 코드만, 레거시 비강제).
> 이 파일은 별도 호출 대상이 아닌 **상세 참조** — 경계 판단 결정트리 / 스택별 예시 / anti-pattern.
> **lean-code와 소유권 분리**: lean-code="할지 말지·범위"(restraint), feature-architecture="하기로 한 코드를 어디 둘지"(structure). 접점은 Rule of Three뿐, 모순 없음.

## 코어 규칙 (CLAUDE.md/AGENTS.md가 강제, 여기선 참조)
1. **모듈 경계**: colocation + 단일 public boundary
2. **횡단 import 금지** (단 public boundary 의존은 허용)
3. **Rule of Three**
4. **신규 = 가산적 + 최소 integration edit 허용**

## 상세 규칙
### 5. 파일 1책임 + 비대화 시 분할
한 파일 = 한 책임. 커지면 분할. codemap 심볼과 1:1 유지 → 색인 정확도.

### 6. codemap 도메인 명명 정렬
파일/심볼명이 `domain:symbol`로 깔끔히 매핑되게 명명. 예: `src/menu-c/c-export/export.logic` → `menu-c:exportLogic`. DoD#5(codemap 갱신)와 짝 → "codemap 이용 개발"의 명명 브릿지.

### 7. anti-pattern 체크리스트
- **god-module**: 한 파일/폴더가 여러 도메인 책임 → 분할
- **순환참조**: A→B→A → public boundary 또는 hoist로 단방향화
- **premature 추상화**: 2곳 중복에 성급한 공통화 (Rule of Three 위반)
- **layer-first 회귀**: controllers/·services/ 식 레이어 우선 분할로 복귀
- **shared-dump 회귀**: cross-menu 2회 사용을 즉시 global shared로 올림

### 8. public boundary 스택별 예시 (코어는 관계형, 구체는 여기)
| 스택 | public boundary |
|------|------------------|
| TS/JS | `index.ts` / package exports |
| Python | `__init__.py` / 명시적 module API |
| Rust | `mod.rs` / `lib.rs` |
| Go | package-level exported identifiers |
| Rails/Next | 프레임워크 route/module 관례 **우선** |

## 신규 기능 위치 결정트리
```
새 기능이...
├─ 기존 메뉴(도메인) 소속 → 그 메뉴 폴더 아래 하위 폴더 추가 (형제 로직 불변)
├─ 새 메뉴(도메인)        → 새 도메인 폴더 + 첫 기능 하위 폴더
└─ 메뉴 횡단(공통)        → core/ 또는 shared/ (특정 메뉴 소속 아님)

어느 경우든: route/menu registry, module manifest, DI registration,
            public export 같은 최소 integration edit은 허용 (규칙4).
            단 integration 파일에 feature "로직"이 늘면 경계 재검토 신호.
```
- **허용**(registration-only): router 테이블에 1줄 추가, nav menu 배열에 항목 추가, DI 컨테이너 등록, package export 추가.
- **금지**(logic-bearing parent edit): 기존 형제 기능 파일에 새 기능의 비즈니스 로직을 끼워넣기.

## 공통 코드 승격 = 사용 범위 따라 (Rule of Three와 모순 없이)
```
기능 내부에서만   → 기능 폴더 안
같은 메뉴 2곳     → 기본 duplicate 유지
                   (단 auth/권한/HTTP client/formatting 등 안정된 cross-cutting infra는 즉시 shared 허용)
같은 메뉴 3곳째   → 소속 범위 재판단 → 메뉴 내 shared
다른 메뉴도 사용  → "도메인 소유권 없는 stable utility/infra"일 때만 global shared 승격.
                   특정 feature concept이면 public boundary 의존 또는 duplicate 유지 (shared-dump 회귀 방지)
```
**cross-menu 2회 사용을 즉시 global로 올리지 말 것** (Rule of Three 게이트).

## 프레임워크 관례 우선 (배포 안전)
Next.js(app/ 라우팅), Rails(MVC 규칙) 등 **프레임워크가 구조를 강제하면 그것을 우선** 따르고, 그 관례 **안에서** feature-first 원칙(colocation/단일 경계/횡단 격리)을 적용한다. 프레임워크 관례를 거슬러 강제하지 않는다.
'@

# ── Skills: lean-code ─────────────────────────────────────────────────────────
Step-Begin "skill: lean-code"
Write-FileContent ".claude\skills\lean-code\SKILL.md" -NoBom @"
---
name: lean-code
description: LLM coding anti-pattern reference. Enforcement lives in CLAUDE.md/AGENTS.md Coding Principles; this file is the detailed checklist. No separate invocation needed.
---
# Lean Code Principles - LLM Coding Anti-patterns (참조 문서)

> **강등 안내**: 코딩 원칙은 **CLAUDE.md/AGENTS.md ``Coding Principles (Lean Code)``가 강제**한다.
> 이 파일은 별도 호출 대상이 아니라 **상세 체크리스트 참조**용이다.

## 4 Core Rules

### 1. DO NOT OVER-ENGINEER
요청한 것만. 그 이상 없음.
- 추가 기능/추상화/유연성 임의 도입 금지
- "시니어가 과하다고 할까?" -> 단순화

### 2. DO NOT CHANGE WHAT IS NOT ASKED
명시된 파일/함수만.
- 인접 코드 주석 포맷 임의 개선 금지
- 기존 스타일 그대로
- 기존 데드 코드 -> 언급만, 삭제 금지
- 테스트: 변경된 모든 줄이 요청에 직접 연결되는가.

### 3. VERIFY BEFORE IMPLEMENTING
구현 전 먼저 파악.
- 기존 코드 패턴/의존성 먼저 읽기
- .claude/codemap/_index.md로 관련 파일 위치 먼저 확인
- 가정으로 시작하지 않음

### 4. CONFIRM SCOPE WHEN UNCERTAIN
불명확하면 구현 전 질문.
- 범위 불명확 -> 추측 금지
- 여러 해석 가능 -> 선택지 제시

## Orphan Cleanup
내 변경으로 생긴 미사용 항목 -> 제거. 기존 데드 코드 -> 언급만.
"@

# ── Skills: clarity ───────────────────────────────────────────────────────────
Step-Begin "skill: clarity"
Write-FileContent ".claude\skills\clarity\SKILL.md" -NoBom @"
---
name: clarity
description: Ambiguity gate. Use before implementing to score request ambiguity across 5 dimensions and re-question until a clear spec and implementation plan are produced.
---
# Clarity Skill - Ambiguity Gate

## 목적
구현 요청의 모호도를 수치화하고, 임계값 이하가 될 때까지 재질문하여 명확한 사양을 확보한 뒤 구현 계획을 출력.

## 트리거
/clarity [임계값]
- 임계값 미지정 시 기본값: 30
- 예: /clarity       -> 임계값 30
- 예: /clarity 20    -> 임계값 20 (엄격)
- 예: /clarity 60    -> 임계값 60 (관대)

## 모호도 차원 (5개 × 20점 = 100점)
높을수록 모호. 0 = 완전 명확, 20 = 완전 불명확.

| 차원 | 측정 대상 | 🔴 모호 (13-20) | ⚠ 보통 (6-12) | ✓ 명확 (0-5) |
|------|----------|----------------|---------------|-------------|
| What | 무엇을 만드는가 | 기능/화면명 불명확 | 대략 알지만 세부 모름 | 구체적 명칭 존재 |
| How  | 어떻게 동작하는가 | 로직/흐름 없음 | 일부 조건 있음 | 전체 흐름 명확 |
| Where| 어디에 영향 | 파일/레이어 불명확 | 대략적 범위만 | 파일 단위 특정 |
| Done | 완료 기준 | 검증 조건 없음 | 결과물만 언급 | 테스트 조건 명확 |
| Link | 기존 코드 연결점 | 의존성 전무 | 일부 인터페이스 | 연결 지점 특정 |

## 채점 원칙
- 요청 텍스트에서 명시적으로 언급된 정보만 신뢰
- 추론/가정으로 낮은 점수 부여 금지
- 각 차원 독립 채점 - 다른 차원 영향 없음

## 출력 포맷

### 모호도 블록 (매 라운드)
모호도: {총점}/100  {바}  [{BLOCK > N} 또는 {PASS <= N}]

차원     점수   상태
What   {바}  {점수}/20  {아이콘}
How    {바}  {점수}/20  {아이콘}
Where  {바}  {점수}/20  {아이콘}
Done   {바}  {점수}/20  {아이콘}
Link   {바}  {점수}/20  {아이콘}

바 = ██ (채움) / ░░ (빔), 20칸 기준.
아이콘 = 🔴 (13-20) / ⚠ (6-12) / ✓ (0-5)

### 재질문 블록 (BLOCK 시)
질문 ({N}라운드, 모호도 높은 순 최대 3개):
Q1 [{차원}]: {질문}
Q2 [{차원}]: {질문}
Q3 [{차원}]: {질문}

- 모호도 13 미만 차원은 질문하지 않음
- 동점이면 What -> How -> Where -> Done -> Link 순
- 질문은 단답 또는 짧은 문장으로 답할 수 있게 작성

### 접근법 대안 블록 (PASS 후, 실질 대안 ≥2일 때만)
접근법 ({M}개 · 추천 1개):

▶ A. {접근법명}  (추천)
   트레이드오프: {장점} / {단점}
   추천 근거: {1줄}
  B. {접근법명}
   트레이드오프: {장점} / {단점}
  C. {접근법명}
   트레이드오프: {장점} / {단점}

- 출력 직후 AskUserQuestion(체크박스)로 선택 수신. 추천 옵션 첫 배치, 라벨 끝 "(추천)", description = 트레이드오프.
- 실질 대안 <2 (자명 단일)이면 이 블록 생략 -> 통과 블록 직행.

### 통과 블록 (PASS 시)
모호도: {총점}/100 ✅ PASS (임계값 {N})
선택 접근법: {A/B/C} {접근법명}   (접근법 게이트 발동 시에만; 단일이면 이 줄 생략)

구현 계획:
1. [{파일}] {변경 내용} -> 검증: {방법}
2. [{파일}] {변경 내용} -> 검증: {방법}

전제:
- {가정 또는 확인 필요 항목}

## 실행 흐름

1. 구현 요청 수신 (인수 또는 "구현할 내용을 입력하세요:" 프롬프트)
2. 5개 차원 독립 채점
3. 총점 계산 및 출력
4. 총점 > 임계값 -> 재질문 블록 출력 -> 답변 수신 -> 2로 이동
5. 총점 <= 임계값 -> 접근법 판정:
   - 실질 대안 ≥2 -> 접근법 대안 블록 출력 -> AskUserQuestion 선택 수신 -> 6
   - 자명 단일 -> 6 직행
6. 선택(또는 단일) 접근법으로 통과 블록(구현 계획) 출력 -> 종료

## 라운드 상한
최대 5라운드. 5라운드 후에도 초과 시:
⚠ 5라운드 초과. 현재 모호도 {N}/100.
계속 진행하려면 "강제 통과"를 입력하세요.
중단하려면 "중단"을 입력하세요.

## 구현 계획 작성 원칙
- .claude/codemap/_index.md 확인 후 실제 파일 경로 사용
- lean-code 원칙 적용: 요청된 것만, 최소 범위
- 각 단계에 검증 방법 명시 (프로젝트 Commands의 Analyze / Test 등)
- 전제 섹션에 불확실한 가정 명시

## 대안 제시 원칙 (추천 필수)
접근법 게이트(실행 흐름 5)에서 대안을 제시할 때 적용.
- 대안 2-3개만. 4개 이상 금지 (분석마비 방지).
- 추천 정확히 1개 필수. 0개·복수 추천 금지.
- 추천 항목: 첫 배치 + "(추천)" 라벨 + 추천 근거 1줄 의무.
- 각 대안 트레이드오프 1줄 이상 (장점/단점 양면).
- 가짜 대안 금지: 실질 차이 없거나 자명 단일이면 게이트 생략, 단일 계획 직행 (lean-code 정신).
- 대안 판정 기준: 비가역적이거나 트레이드오프가 갈리는 분기만 (스택/스키마/아키텍처/핵심 UX). 사소한 명명·포맷은 게이트 대상 아님.
- 선택지 질문은 AskUserQuestion(체크박스) 사용 (CLAUDE.md 선택지 규칙 준수).
"@

# ── Skills: handoff (owner transfer 추가) ─────────────────────────────────────
Step-Begin "skill: handoff"
Write-FileContent ".claude\skills\handoff\SKILL.md" -NoBom @"
---
name: handoff
description: Cross-agent state transfer. Use when handing work to another agent (Claude<->Codex) or a new session due to token/context limits — writes a snapshot and transfers lane ownership.
---
# Handoff Skill - Cross-Agent State Transfer (Instruction)

## 목적
세션 토큰 만료 / context window 한계 / 역할 전환 시 다음 에이전트가 끊김 없이 작업을 재개할 수 있도록 상태 snapshot 작성.

## 성격
**Instruction skill**. PowerShell command 아님. agent가 이 SKILL.md를 보고 수동으로 절차를 따라 파일을 생성/수정.

## 트리거
/handoff {to-agent} {feature-id} [reason]
- /handoff codex feature-a token-limit
- /handoff claude feature-b need-design
- /handoff next feature-c shift-change

## 마커 매핑
| {to-agent} | HANDOFF marker (state 필드에 기록) |
|-----------|-----------------------------------|
| codex     | HANDOFF_TO_CODEX                  |
| claude    | HANDOFF_TO_CLAUDE                 |
| next      | HANDOFF_TO_NEXT_AGENT             |

별도: spec 완료 후 구현 대기는 SPEC_READY (handoff 아닌 state 직접 설정).

## 실행 절차 - 송신 측 (agent가 순차 수행)
1. snapshot 파일 생성 (agent가 직접 작성):
   .claude/pawpad/handoffs/{YYYY-MM-DD_HHMM}_{from}_to_{to}_{feature}.md
2. 템플릿(.claude/pawpad/handoffs/TEMPLATE.md) 복사 후 채움
3. 필수 항목:
   - Context (from/to/feature/branch/commit/timestamp)
   - Goal (전체 목표)
   - Completed (완료된 것)
   - Remaining (남은 것)
   - Changed Files (path, status, reason)
   - Verification (Commands의 Analyze / Test 결과)
   - Known Issues
   - Next Commands (다음 에이전트가 즉시 실행할 명령)
4. lane 파일 (.claude/pawpad/wip/{feature}.md) 갱신:
   - State 섹션: HANDOFF_TO_{to}
5. _wip.md Active Lanes에 state + handoff 필드 갱신:
   - state: HANDOFF_TO_{to}
   - handoff: .claude/pawpad/handoffs/{snapshot 경로}
   - owner: 현재 그대로 유지 (송신자 = 현재 owner)
   - updated: YYYY-MM-DD HH:MM
6. _meta.md RECENT에 1줄 추가:
   "YYYY-MM-DD: HANDOFF {feature} {from}->{to}. {reason}"
7. (선택) git commit

## 실행 절차 - 수신 측 (인수 agent, ON START 후)
1. _wip.md Active Lanes에서 state=HANDOFF_TO_(자기) 발견
2. handoff 필드 경로로 snapshot read
3. Next Commands 우선 실행
4. Known Issues 확인 후 작업 재개
5. **lane 파일 갱신** (소유권 이전):
   - State: HANDOFF_TO_* -> WIP
   - Owner: 송신자 -> 본인 (받는 agent)
6. **_wip.md Active Lanes 갱신**:
   - state: HANDOFF_TO_* -> WIP
   - owner: 받는 agent
   - handoff: 필드 제거 (인수 완료)
   - updated: 현재 시각
7. _meta.md RECENT에 인수 기록:
   "YYYY-MM-DD: ACCEPT {feature} by {receiving-agent}"

## Owner Mismatch 감지/복구 (인수 누락 복구)
가장 흔한 운영 실수: 인수 후 owner 변경 누락. ON START 시 다음 점검:
1. lane state=WIP 인데 owner가 송신 agent(=본인 아님)이면 -> 인수 누락 의심
2. 직전 _meta.md RECENT에 해당 feature ACCEPT 기록 없으면 -> 미인수 확정
3. 복구: 본인이 작업 중이면 owner를 본인으로 수정 (lane + _wip.md 동기화)
4. _meta.md RECENT에 복구 기록:
   "YYYY-MM-DD: FIX_OWNER {feature} -> {본인} (인수 시 owner 변경 누락 복구)"
5. 판단 불가 시 (양 agent 모두 작업 가능) STOP, 사용자에게 owner 확인 요청

## Verification 실패 시
- analyze 실패 / test 실패 발견 시
- snapshot에 명시 + Next Commands 첫 항목으로 수정 작업 등록
- 다음 에이전트가 정상화 작업 우선 처리

## SPEC_READY 케이스 (기획 -> 구현)
- handoff와 다름. snapshot 불필요.
- 기획 agent: lane 파일 생성 (state=SPEC_READY, owner=기획 agent) + specs/{feature}.md 작성 + _wip.md 등록
- 구현 agent: ON START -> state=SPEC_READY 발견 -> spec read -> 기존 SPEC_READY lane 인수 (state=WIP, owner=본인). 새 lane 생성 아님.

## /handoff-list (참고)
agent가 .claude/pawpad/handoffs/ 디렉토리 최근 5개 snapshot 출력.
"@

# ── Skills: checkpoint ────────────────────────────────────────────────────────
Step-Begin "skill: checkpoint"
Write-FileContent ".claude\skills\checkpoint\SKILL.md" -NoBom @"
---
name: checkpoint
description: Context rollover gate. Use when the context window nears 50-60% to save lane/codemap/meta state so a new session can resume seamlessly.
---
# Checkpoint Skill - Context Rollover Gate (Instruction)

## 목적
Context window 60% 도달 전 정리. 새 세션에서 끊김 없이 이어가기 위한 상태 보존.

## 성격
**Instruction skill**. agent가 이 SKILL.md를 보고 수동으로 파일을 갱신. PowerShell command 아님.

## 트리거
/checkpoint [강제]
- 50-60% context 추정 시 agent 또는 사용자가 호출
- /checkpoint 강제 -> 즉시 체크포인트 (% 무관)

## Context Window 임계값 (60% 기준)
| 상태       | %      | agent 액션 |
|-----------|--------|----------|
| 정상      | 0-50   | 계속 진행 |
| 체크포인트 | 50-60  | lane 파일/codemap 갱신, /checkpoint 권장 |
| 핸드오프  | 60-70  | /handoff 실행, snapshot 작성 |
| 전환권장  | 70-85  | 새 세션 시작 |
| 임계      | 85+    | 즉시 STOP, 작업 중단 후 handoff |

## % 추정 휴리스틱
LLM 자체 측정 불가. agent가 다음 신호로 추정:
- 50회 이상 응답
- 큰 파일(500줄+) 5회 이상 read
- 도구 호출 100회 이상
- 사용자 명시적 지정

위 신호 2개 이상 -> 50% 초과 추정.

## 실행 절차 (agent가 순차 수행)
1. 현재 작업 lane 파일 갱신:
   - 완료/미완 정리 — 완료(✅) 작업항목은 최근 세션분만 lane 유지, 이전 것은 .claude/pawpad/verifications/{feature-id}-tasklog.md로 이월(HYBRID Completed Task Log). 검증근거도 동일(HYBRID Verification Evidence).
   - 다음 단계 명시
   - 수정 중 파일 목록
2. codemap/_index.md 갱신:
   - 신규 심볼 추가
   - HOT 섹션 최신화
3. _meta.md 갱신 (해당 시):
   - 완료 항목 RECENT에 추가
4. _wip.md Active Lanes의 updated 필드 갱신
5. 60% 초과 추정 시 -> agent가 /handoff 권장 (사용자 안내)
6. 결과:
   - lane 파일이 다음 세션에서 즉시 재개 가능한 상태
   - 새 세션 ON START -> lane 파일 read -> 그대로 이어 작업

## 사용자 안내 메시지 (60% 초과 추정 시)
"Context 약 60% 추정. agent가 정리 권장:
1. lane 파일 갱신 완료
2. codemap 최신화
3. /handoff {to-agent} {feature} 실행 권장 (또는 새 세션 직접 시작)"

## /checkpoint 와 /handoff 차이
- /checkpoint : 같은 에이전트 새 세션에서 이어 작업 (저장만, snapshot 없음, owner 유지)
- /handoff   : 다른 에이전트에게 인수 (snapshot 생성, owner는 인수 시 변경)
"@

# -- Skills: Matt Pocock 계열 (grilling / PRD) --
Step-Begin "skill: grill-me"
Write-FileContent ".claude\skills\grill-me\SKILL.md" -NoBom @"
---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree, sharpening fuzzy terms and surfacing contradictions against the codebase. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead. During exploration also look for existing documentation (specs, PRD, decisions) that bears on the plan.

While grilling, sharpen the conversation:

- Sharpen fuzzy language — 모호하거나 중의적인 용어는 정확한 canonical 용어로 좁힌다. "'account'라고 했는데 Customer인가 User인가? 둘은 다른 개념이다."
- Discuss concrete scenarios — 도메인 관계나 경계가 걸리면 구체 시나리오·엣지 케이스로 stress-test 해 개념 경계를 강제로 드러낸다.
- Cross-reference with code — 사용자가 동작을 설명하면 코드와 일치하는지 확인하고, 모순을 즉시 표면화한다. "코드는 Order 전체를 취소하는데 방금 부분 취소가 가능하다고 했다 — 어느 게 맞나?"
"@

Step-Begin "skill: to-prd"
Write-FileContent ".claude\skills\to-prd\SKILL.md" -NoBom @'
---
name: to-prd
description: Turn the current conversation context into a PRD, save it to the PawPad specs folder, and mark the lane SPEC_READY for the implementation agent. Use when user wants to create a PRD from the current context.
---

This skill takes the current conversation context and codebase understanding and produces a PRD. Do NOT interview the user — just synthesize what you already know.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary (`CONTEXT.md`) vocabulary throughout the PRD, and respect any ADRs in `.claude/pawpad/decisions/arch.md` for the area you're touching.

2. Sketch out the major modules you will need to build or modify to complete the implementation. Actively look for opportunities to extract deep modules that can be tested in isolation.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

Check with the user that these modules match their expectations. Check with the user which modules they want tests written for.

3. Write the PRD using the template below, then save it to `.claude/pawpad/specs/{feature-id}.md`.

4. Register the lane for the hybrid handoff flow (SPEC_READY는 snapshot 불필요 — `/handoff` 쓰지 말 것):
   - **lane 파일 생성**: `.claude/pawpad/wip/{feature-id}.md`
     - Owner: 기획 agent / State: SPEC_READY / spec 경로: `.claude/pawpad/specs/{feature-id}.md` / 다음 단계 / updated
     - 기존 lane 있으면 새로 만들지 말고 갱신 (중복 생성 금지)
   - `.claude/pawpad/_wip.md` Active Lanes에 등록: state=SPEC_READY, owner=기획 agent, lane 경로
   - `.claude/pawpad/_meta.md` RECENT에 1줄 추가: "YYYY-MM-DD: SPEC_READY {feature-id}. spec 작성 완료. [agent]"
   - 구현 agent가 ON START에서 SPEC_READY 발견 → spec + lane read → 인수 (state=WIP, owner=본인). resume skill 참조. snapshot 불필요하므로 `/handoff` 아님.

주의: 외부 이슈 트래커 발행, `ready-for-agent` 라벨, `/setup-matt-pocock-skills` 셋업은 이 프로젝트에서 쓰지 않는다. PRD는 PawPad `specs/` + `SPEC_READY` state로 인계한다.

## PRD Template

```markdown
## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

Example:
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.
```
'@

# -- Skills: design (UI/UX 설계 게이트) --
Step-Begin "skill: design"
Write-FileContent ".claude\skills\design\SKILL.md" -NoBom @'
---
name: design
description: Framework-neutral UI/UX design gate. Use before or while building a screen/component to lock design-system tokens, structure the responsive component layout, and review against core UI principles. Use when user mentions UI, layout, screen design, or "design this".
---

# Design Gate Skill - UI/UX 설계 게이트 (프레임워크 중립)

## 목적
화면/컴포넌트 구현 전·중에 한 번에:
(1) 디자인 시스템 토큰 고정, (2) 반응형 레이아웃 구조 설계, (3) UI 원칙 검토.
clarity가 "무엇을 만드나"를 좁힌다면, design은 "어떻게 보이고 배치되나"를 좁힌다.
프레임워크(Flutter/React/Vue/네이티브/웹 등)는 프로젝트의 것을 따른다 — 이 스킬은 도구 중립.

## 성격
Instruction skill. PowerShell command 아님. 에이전트가 절차를 따라 설계안을 출력.

## 트리거
/design [화면/컴포넌트 설명]
- 예: /design 로그인 화면
- 예: /design 회원 목록 카드

## 3단계 (순차)

### 1단계 — 디자인 시스템 토큰 확인
구현 전 토큰 소스 확인/고정 (하드코딩 금지):
- 색상: 프로젝트 색상 토큰/팔레트 (raw hex 하드코딩 금지)
- 문자열: 문자열/i18n 리소스 (하드코딩 금지)
- 간격: 스페이싱 스케일 (4 / 8 / 12 / 16 / 24 / 32)
- 타이포: 텍스트 스타일 토큰 (theme / 타이포 스케일)
- 컴포넌트: 기존 공용 컴포넌트 재사용 우선 (codemap/_index.md 확인)
누락 토큰 발견 시 → 임의 하드코딩 말고 **토큰 추가 제안** 후 진행.

### 2단계 — 레이아웃 구조 설계
- 컴포넌트 트리 스케치: 루트 컨테이너 > 헤더/본문 > 핵심 컴포넌트 계층
- 반응형: breakpoint(mobile < 600 / tablet 600-1024 / desktop > 1024), 뷰포트/컨테이너 쿼리 필요 여부
- 상태 연결: 프로젝트 상태관리(store/provider/hook) 연결점 (codemap 참조, read/write 구분)
- 출력: 컴포넌트 트리 + 각 노드 책임 한 줄

### 3단계 — UI 원칙 체크 (6항목)
| 원칙 | 확인 |
|------|------|
| 시각 위계 | 주요 액션/정보가 크기·색·위치로 우선 표현되나 |
| 여백·정렬 | 스페이싱 스케일 일관, 정렬 그리드 준수 |
| 대비·가독성 | 텍스트 대비 WCAG AA(4.5:1) 충족 |
| 접근성 | 터치 타깃 충분(>=44~48px), 접근성 라벨, 폰트 스케일 대응 |
| 일관성 | 기존 화면 패턴과 일치, 컴포넌트 재사용 |
| 상태 표현 | 로딩 / 빈 / 에러 / 성공 4상태 모두 다룸 |

## 출력 포맷
```
디자인 계획: {화면명}
1. 토큰   : 색상/간격/타이포 [사용 토큰], [추가 제안]
2. 컴포넌트트리: 루트 > ... (계층 + 책임)
3. 반응형 : [breakpoint별 레이아웃 변화]
4. 원칙체크: 시각위계 ✓ / 여백 ✓ / 대비 ⚠ / 접근성 ✓ / 일관성 ✓ / 상태 ⚠
5. 미해결 : [확인 필요 항목]
```

## 원칙
- 새 색상/간격/타이포 임의 도입 금지 → 토큰 추가는 명시적 제안 후.
- 기존 공용 컴포넌트 재사용 우선 (codemap/_index.md 확인).
- 4상태(로딩/빈/에러/성공) 누락 금지.
- lean-code 적용: 요청된 화면만, 과한 애니메이션/추상화 금지.
- 모든 플랫폼 공통: 반응형 breakpoint 명시. 고정 px 레이아웃 지양.

## 후속 산출물 / PawPad 등록
design 통과 후 spec 필요 시 **to-prd와 동일한 PawPad 등록 절차** 따름 (specs 작성 + lane SPEC_READY + _wip/_meta 등록 + 구현 agent 인수). 상세: to-prd skill. spec에 디자인 계획 포함. SPEC_READY는 snapshot 불필요(`/handoff` 아님).
- _meta.md RECENT 예시(design 맥락): "YYYY-MM-DD: SPEC_READY {feature-id}. 디자인 계획 작성 완료. [agent]"

### 디자인 ADR 기준
- per-screen 배치 결정 → spec에만 기록 (ADR 아님)
- 장기 디자인 시스템 결정(새 token / breakpoint / 재사용 공용 컴포넌트 / navigation pattern)만 `.claude/pawpad/decisions/arch.md`에 append

## clarity / grill 과의 관계
- clarity : 요청 모호도(기능 정의) 게이트 — design 앞 단계.
- grill-me : 설계 의사결정 심문 — 큰 화면/플로우 설계 시 병행.
- design  : 시각·레이아웃·토큰 게이트 — 화면 구현 직전.
'@

# -- Skills: mockup (기획 목업 게이트) --
Step-Begin "skill: mockup"
Write-FileContent ".claude\skills\mockup\SKILL.md" -NoBom @'
---
name: mockup
description: PRD-tree를 단일 HTML 목업으로 투영하는 기획 시각화 게이트. 기능이 어느 메뉴/화면에 위치하는지 코딩 전에 시각 확인하고, Feature ID로 PRD-tree와 동기 상태를 추적(drift 경고)한다. 와이어프레임(lo-fi)/디자인반영(hi-fi) 선택. PRD/PRD-tree 갱신 후 또는 사용자가 "목업"/"mockup"/"화면 시안"을 언급할 때 사용.
---

# Mockup Skill - 기획 목업 게이트 (단일 HTML)

## 목적
기획 단계 산출물(PRD-tree)을 **단일 HTML 목업**으로 투영한다.
- "지금 어떤 기능이 기획됐고, 어느 메뉴/화면에 위치하는지"를 코딩 전에 시각 확인 → 기획 단계에서 수정 → 코딩 재작업 방지.
- 비개발자도 브라우저로 바로 확인(전달 가능).
- 각 화면을 Feature ID로 태깅해 PRD-tree와 동기 상태 추적.

clarity/design과의 관계:
- clarity : 요청 모호도(기능 정의) 게이트.
- design  : 토큰/레이아웃/원칙 게이트 (hi-fi 목업은 design 토큰 재사용).
- mockup  : PRD-tree → 화면 구조 시각 투영 + 트리 동기 게이트.

## 성격
Instruction skill. PowerShell command 아님. agent가 절차를 따라 HTML을 생성한다.

## 트리거
/mockup [화면|all] [lo|hi]
- 인자 생략 시: 전체(all) + lo-fi.
- 예: /mockup all lo      -> 전체 화면 와이어프레임
- 예: /mockup TQ-HOME hi  -> 홈 영역 디자인반영 목업
- fidelity 인자 생략 시 기본 lo-fi.

## 산출물
- 위치: `src/mockups/{feature-id}-mockup.html` (PRD/PRD-tree와 같은 src/ 아래 응집)
- 형식: 단일 HTML. 화면당 섹션 + 화면 간 앵커 클릭 이동.
- 단일 fidelity/파일 (lo·hi 동시 내장 토글 금지 — 동기 부담).

## fidelity 2단계

### lo-fi (와이어프레임, 기본)
- 회색 박스 + 라벨 + Feature ID만. 색/이미지/실 타이포 없음.
- 목적: 초기 반복에서 구조·배치·메뉴 위치만 빠르게 검토(재생성 싸게).
- 구조(PRD-tree)가 안정화되면 hi-fi 전환을 **자동 제안**(CLAUDE.md 단계경계 규칙).

### hi-fi (디자인반영)
- design 스킬 토큰(색/타이포/간격) 적용. **신규 토큰 임의 도입 금지** — 누락 시 design 절차로 토큰 추가 제안 후 진행.
- 목적: 구조 확정 후 실제 룩앤필 확인.

## Feature ID 태깅 (필수)
- 모든 목업 화면에 대응 Feature ID 라벨 부착 (예: 화면 헤더에 `TQ-HOME-01`).
- 화면이 속한 메뉴/내비 위치를 시각적으로 표현(탭바/사이드 등 PRD-tree 계층 반영).

## 동기화 = 단방향 (PRD-tree = source of truth)
- PRD-tree가 단일 진실원. 목업은 트리의 시각 투영.
- 기획 변경은 **PRD-tree(인덱스) + 해당 src/prd/{area}.md를 먼저 수정**하고 목업 재생성. 코드+문서 원자적 갱신 규율 준수.
- 목업에서 직접 고친 내용을 트리로 역반영하지 않음(SoT 이원화 금지).

## drift 검사 (생성 시마다 필수)
PRD-tree leaf의 Feature ID 집합 ↔ 목업 화면 ID 집합을 비교해 출력:
```
drift 검사: {일치 N개}
- 누락 (트리에 있으나 목업에 없음): {ID 목록 또는 없음}
- 고아 (목업에 있으나 트리에 없음): {ID 목록 또는 없음}
```
- 누락/고아가 있으면 사용자에게 알리고, 기획 불일치인지 목업 갱신 필요인지 확인.
- (*) 표시된 후속 기능 ID는 누락 경고에서 제외(트리 규칙 따름).

## 절차
1. PRD-tree.md read → leaf Feature ID + 메뉴 계층 추출.
2. 대상 화면 결정(인자 [화면|all]) + fidelity 결정(인자 [lo|hi], 기본 lo).
3. hi-fi면 design 토큰 소스 확인(없으면 lo-fi 권고 또는 토큰 제안).
4. 단일 HTML 생성 → `src/mockups/{feature-id}-mockup.html`. 화면별 Feature ID 라벨 + 메뉴 위치 표현.
5. drift 검사 출력.
6. lo-fi이고 구조 안정화 판단 시 hi-fi 전환 제안(1회).

## 통합 뷰어 모드 (viewer) — 데이터 구동 (no-backend)
범용 뷰어 `.claude/skills/mockup/spec-viewer.html`(setup 배포·고정·데이터 비종속)를 Chrome/Edge로 열어 `src/viewer/` 폴더 1회 선택 → 4탭(PRD/기능명세서/메뉴구성도/와이어프레임) 자동 로드. 편집 후 같은 JSON에 제자리 저장(File System Access API, 다운로드·백엔드 없음) → 재로드.
/mockup viewer [feature-id]: 대상 프로젝트 데이터 JSON을 PRD-tree/flow/spec에서 생성·갱신(뷰어 HTML은 안 건드림).
- 데이터 SoT(고정명, `src/viewer/`): `prd.json` · `fts.json`(기능그룹→스팩) · `userflow.json`(메뉴 계층 트리 `{root,tree:[{id,label,feature?,tab?,children?}]}`) · `wire.json`(화면별 `{frame,components:[{type,...}]}`). 전부 JSON. agent가 읽고/쓰는 SoT.
- 뷰어 데이터 비종속(HTML에 데이터 안 박음·렌더 엔진 고정) → PRD/명세 변경 시 agent는 **JSON만 수정**(HTML 불변 → 토큰 절감). 렌더: 기능명세서=CSS 트리(그룹──트렁크┬─leaf), 메뉴구성도(구 유저플로우)=계층 트리+드래그앤드랍(순서·위치 재배치 저장), 와이어=디바이스 프레임+컴포넌트 lo-fi(mobile/web).
- **존재=대상**: JSON에 남은 항목 = 설계/개발 대상. 삭제=제외(별도 승인 없음). 사용자 액션 = 수정/삭제/추가만.
- **상태(예정/진행중/완료)**: 개발 진행 가시화 전용 — agent가 구현하며 status 갱신, 사용자 편집 X.
- **context 규율(중요)**: `src/viewer/*.json`은 ON START/resume **자동 로드 금지** — 기획/구현 작업 시점에만 해당 파일 on-demand read(초기 기획 강화로 후속 수정 최소화, context 비대화 방지).
- 반영: 사용자 저장 후 `/viewer-apply`가 JSON 읽어 spec 동기(남은 항목→spec 생성/갱신, 삭제 항목→spec 제거/아카이브).

## 선택지 질문 규칙
대상 화면·fidelity 등 선택지가 있는 질문은 **AskUserQuestion(체크박스)** 로 받는다. 자유서술·수치 입력은 텍스트.

## 원칙
- 정적 화면 투영만. 실제 클릭 로직/상태/인터랙션 비범위(화면 간 앵커 이동만).
- lean-code 적용: 요청 화면만, 과한 연출 금지.
- 신규 디자인 토큰 임의 정의 금지(design 절차 경유).
- 산출물은 기획물 → 코드 아님. 구현은 별도 단계.
'@

# -- mockup viewer: 범용 데이터-구동 뷰어 (FS Access API, 데이터 JSON 외부 로드/저장) --
Write-FileContent ".claude\skills\mockup\spec-viewer.html" -NoBom @'
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>통합 기획 뷰어 (data-driven)</title>
<style>
  /* 범용 데이터 구동 뷰어. 데이터는 외부 JSON(prd/fts/userflow/wire.json), HTML엔 데이터 무. */
  * { box-sizing: border-box; }
  body { font-family:-apple-system,"Segoe UI",system-ui,sans-serif; background:#f3f4f6; color:#1f2430; margin:0; }
  header.top { background:#fff; border-bottom:1px solid #d7dbe2; padding:12px 20px 0; position:sticky; top:0; z-index:5; }
  .titlerow { display:flex; align-items:center; gap:10px; flex-wrap:wrap; }
  h1 { font-size:15px; margin:0; }
  .tbtn { font-size:12px; padding:6px 12px; border:1px solid #c6d0e6; background:#fff; border-radius:7px; cursor:pointer; color:#2a4fb0; }
  .tbtn.primary { background:#2a4fb0; color:#fff; border-color:#2a4fb0; }
  .tbtn:disabled { opacity:.45; cursor:not-allowed; }
  .status { font-size:11px; color:#7a8294; margin-left:auto; max-width:50%; text-align:right; }
  .badges { display:flex; gap:8px; }
  .badge { font-size:11px; padding:3px 9px; border-radius:12px; }
  .badge.prog { background:#e8eefc; color:#2a4fb0; }
  .badge.dirty { background:#fdeccd; color:#8a5a00; }
  .tabbar { display:flex; gap:2px; margin-top:10px; }
  .tab { font-size:13px; padding:9px 16px; cursor:pointer; border:1px solid transparent; border-bottom:none; border-radius:8px 8px 0 0; color:#5a6478; user-select:none; }
  .tab:hover { background:#f0f2f6; }
  .tab.on { background:#f3f4f6; color:#1f2430; font-weight:600; border-color:#d7dbe2; }
  .tab .dot-dirty { color:#e09b00; margin-left:4px; }
  main { max-width:1180px; margin:0 auto; padding:18px 20px 70px; }
  section[data-tab] { display:none; }
  section[data-tab].on { display:block; }
  .hint { font-size:11px; color:#8a92a3; margin:0 0 12px; display:flex; align-items:center; gap:10px; }
  .addbtn { font-size:11px; padding:4px 10px; border:1px dashed #b8bfcc; background:#fff; border-radius:6px; cursor:pointer; color:#5a6478; }
  .gate { max-width:560px; margin:60px auto; text-align:center; background:#fff; border:1px solid #e0e3ea; border-radius:12px; padding:32px; }
  .gate h2 { font-size:16px; margin:0 0 8px; }
  .gate p { font-size:12px; color:#5a6478; line-height:1.6; }
  .gate .warn { color:#a52a2a; font-size:11px; margin-top:10px; }

  /* 공통 컨트롤 */
  .ctrls { display:inline-flex; gap:3px; margin-left:8px; flex:0 0 auto; }
  .ctrls button { font-size:11px; width:22px; height:22px; line-height:1; border:1px solid #d7dbe2; background:#fff; border-radius:5px; cursor:pointer; color:#7a8294; padding:0; }
  .ctrls button:hover { background:#f0f2f6; }
  .editing { border-color:#e7c66a !important; background:#fffdf5 !important; }
  input.ed, textarea.ed { font-size:12px; font-family:inherit; padding:3px 6px; border:1px solid #e7c66a; border-radius:4px; }
  input.ed { width:50%; } textarea.ed { width:100%; min-height:48px; margin-top:5px; }

  /* PRD */
  .prd-block { background:#fff; border:1px solid #e0e3ea; border-radius:8px; padding:12px 14px; margin-bottom:10px; }
  .prd-block h3 { font-size:13px; margin:0 0 5px; display:flex; align-items:center; }
  .prd-block p { font-size:12px; color:#4a5263; margin:0; line-height:1.55; }
  .pill { font-size:10px; padding:1px 7px; border-radius:10px; margin-left:8px; }
  .pill.s-done { background:#e6f6ec; color:#1d7a3e; } .pill.s-prog { background:#e8eefc; color:#2a4fb0; } .pill.s-todo { background:#eceef2; color:#7a8294; }

  /* 기능명세서 트리 (그룹──트렁크┬─leaf 연결선) */
  .fts-group { display:flex; align-items:center; margin:0 0 16px; }
  .fts-gnode { flex:0 0 200px; background:#eef3ff; border:1px solid #c6d6f6; border-radius:8px; padding:9px 11px; }
  .fts-gnode .gname { font-size:13px; font-weight:600; } .fts-gnode .gno { font-size:10px; color:#7a8294; font-family:ui-monospace,Consolas,monospace; }
  .fts-branch { flex:0 0 34px; align-self:stretch; position:relative; }
  .fts-branch::before { content:""; position:absolute; top:50%; left:0; right:0; height:2px; background:#aab2c2; transform:translateY(-1px); }
  .fts-leaves { flex:1 1 auto; position:relative; display:flex; flex-direction:column; gap:7px; }
  .fts-leaves::before { content:""; position:absolute; left:0; top:18px; bottom:18px; width:2px; background:#aab2c2; }
  .fts-leaves.single::before { display:none; }
  .fts-leaf { display:flex; align-items:center; gap:8px; margin-left:22px; background:#fff; border:1px solid #e0e3ea; border-radius:7px; padding:7px 10px; position:relative; }
  .fts-leaf::before { content:""; position:absolute; left:-22px; top:50%; width:22px; height:2px; background:#aab2c2; transform:translateY(-1px); }
  .fts-leaf .lname { font-size:12px; } .fts-leaf .lno { font-size:10px; color:#8a92a3; font-family:ui-monospace,Consolas,monospace; margin-left:auto; }
  .tag-new { font-size:9px; background:#e8eefc; color:#2a4fb0; border-radius:8px; padding:1px 6px; }
  .dot { width:8px; height:8px; border-radius:50%; flex:0 0 8px; } .dot.s-done { background:#2bb463; } .dot.s-prog { background:#3f6fd6; } .dot.s-todo { background:#c4cad6; }
  .gaddbtn { font-size:10px; margin-left:8px; padding:2px 8px; border:1px dashed #b8bfcc; background:#fff; border-radius:5px; cursor:pointer; color:#5a6478; }

  /* 메뉴구성도 (계층 트리 + 드래그앤드랍) — 클래식 커넥터 패턴 */
  #menuTree { background:#fff; border:1px solid #e0e3ea; border-radius:8px; padding:14px 18px; overflow-x:auto; }
  .mroot { font-size:13px; font-weight:700; color:#1f2430; padding:6px 12px; background:#eef3ff; border:1px solid #c6d6f6; border-radius:7px; display:inline-block; margin-bottom:2px; }
  .mroot.drop-inside { outline:2px dashed #2a4fb0; outline-offset:1px; }
  ul.mlist { list-style:none; margin:0; padding:0 0 0 40px; }
  ul.mlist.root { padding-left:8px; }
  li.mli { position:relative; }
  li.mli::before { content:""; position:absolute; left:-22px; top:0; bottom:0; border-left:2px solid #d2d8e4; }
  li.mli:last-child::before { bottom:auto; height:20px; }
  li.mli::after { content:""; position:absolute; left:-22px; top:20px; width:22px; border-top:2px solid #d2d8e4; }
  ul.mlist.root > li.mli::before, ul.mlist.root > li.mli::after { display:none; }
  .mnode { display:inline-flex; align-items:center; gap:8px; background:#fff; border:1px solid #d7dbe2; border-left-width:4px; border-radius:7px; padding:6px 10px; margin:5px 0; position:relative; max-width:100%; }
  /* 뎁스별 색 (좌측 강조선 + 옅은 틴트). 이동 시 renderMenu 재계산으로 자동 갱신 */
  .mnode.d0 { border-left-color:#2a4fb0; background:#f4f7ff; }
  .mnode.d1 { border-left-color:#1d9a8a; background:#edf8f5; }
  .mnode.d2 { border-left-color:#7c5cff; background:#f3efff; }
  .mnode.d3 { border-left-color:#c98a00; background:#fbf4e1; }
  .mnode.d4 { border-left-color:#c4456b; background:#fceaf0; }
  .mnode.d5 { border-left-color:#5a6478; background:#eef0f4; }
  .mnode .mdrag { cursor:grab; color:#aab2c2; font-size:12px; flex:0 0 auto; }
  .mnode .mlabel { font-size:12px; white-space:nowrap; }
  .mnode .mtab { font-size:9px; background:#2a4fb0; color:#fff; border-radius:8px; padding:1px 6px; flex:0 0 auto; }
  .mnode .mfeat { font-size:9px; color:#7a8294; font-family:ui-monospace,Consolas,monospace; background:#eef0f4; border-radius:6px; padding:1px 5px; flex:0 0 auto; }
  .mnode .ctrls { margin-left:4px; }
  .mnode.dragging { opacity:.4; }
  .mnode.drop-before { box-shadow:0 -3px 0 #2a4fb0; }
  .mnode.drop-after { box-shadow:0 3px 0 #2a4fb0; }
  .mnode.drop-inside { outline:2px dashed #2a4fb0; outline-offset:1px; }

  /* 와이어프레임 (디바이스 프레임 + 컴포넌트 lo-fi) */

  .wgrid { display:grid; grid-template-columns:repeat(auto-fill,minmax(300px,1fr)); gap:18px; align-items:start; }
  .wscreen { background:#fff; border:1px solid #c9cfdb; border-radius:10px; overflow:hidden; }
  .wscreen.web { grid-column:1 / -1; }
  .wbar { background:#eceef2; padding:7px 11px; font-size:12px; font-weight:600; display:flex; justify-content:space-between; align-items:center; gap:8px; }
  .wbar .wtitle { flex:1 1 auto; }
  .wbar .wfeat { font-size:10px; font-weight:400; color:#7a8294; font-family:ui-monospace,Consolas,monospace; }
  .wbar .navtag { font-size:10px; font-weight:400; color:#7a8294; background:#f7f8fa; border:1px solid #d7dbe2; border-radius:10px; padding:1px 8px; cursor:pointer; }
  .wframe { padding:14px; display:flex; justify-content:center; background:#f3f4f6; }
  .device { position:relative; background:#fff; border:2px solid #2c2f36; border-radius:18px; padding:9px 8px; width:248px; display:flex; flex-direction:column; gap:6px; }
  .device.web { width:100%; border-radius:8px; padding:11px; }
  .comp { position:relative; }
  .comp .cctrls { position:absolute; top:-1px; right:-1px; display:none; gap:2px; z-index:2; }
  .comp:hover .cctrls { display:inline-flex; }
  .comp .cctrls button { font-size:10px; width:18px; height:18px; line-height:1; border:1px solid #d7dbe2; background:#fff; border-radius:4px; cursor:pointer; color:#7a8294; padding:0; }
  .c-appbar { display:flex; align-items:center; justify-content:space-between; background:#e3e6ec; border-radius:5px; padding:7px 8px; font-size:11px; font-weight:600; }
  .c-appbar .c-ic { width:16px; text-align:center; color:#7a8294; }
  .c-tabbar { display:flex; background:#e3e6ec; border-radius:5px; overflow:hidden; }
  .c-tabbar span { flex:1; text-align:center; font-size:9px; padding:6px 2px; color:#7a8294; border-right:1px solid #d2d8e4; }
  .c-tabbar span:last-child { border-right:none; } .c-tabbar span.on { background:#cdd4e0; color:#2a4fb0; font-weight:600; }
  .c-seg { display:flex; border:1px solid #cdd4e0; border-radius:6px; overflow:hidden; }
  .c-seg span { flex:1; text-align:center; font-size:10px; padding:5px 4px; color:#7a8294; border-right:1px solid #cdd4e0; }
  .c-seg span:last-child { border-right:none; } .c-seg span.on { background:#dde3ef; color:#2a4fb0; }
  .c-list { display:flex; flex-direction:column; border:1px solid #e0e3ea; border-radius:6px; overflow:hidden; }
  .c-list .row { font-size:11px; padding:7px 9px; border-bottom:1px dashed #e0e3ea; color:#4a5263; display:flex; gap:6px; align-items:center; }
  .c-list .row:last-child { border-bottom:none; }
  .c-list .row .lead { color:#9aa2b1; } .c-list .row .trail { margin-left:auto; color:#9aa2b1; }
  .c-card { border:1px solid #d7dbe2; border-radius:7px; padding:9px; font-size:11px; }
  .c-card b { display:block; margin-bottom:3px; } .c-card span { color:#7a8294; }
  .c-btn { text-align:center; font-size:11px; padding:8px; border-radius:6px; }
  .c-btn.v-primary { background:#2a4fb0; color:#fff; } .c-btn.v-secondary { background:#e3e6ec; color:#2a4fb0; } .c-btn.v-text { color:#2a4fb0; }
  .c-fab { align-self:flex-end; width:38px; height:38px; border-radius:50%; background:#2a4fb0; color:#fff; display:flex; align-items:center; justify-content:center; font-size:18px; }
  .c-input { border:1px solid #cdd4e0; border-radius:6px; padding:8px 9px; font-size:11px; color:#9aa2b1; background:#fbfcfd; }
  .c-prog { font-size:10px; color:#7a8294; } .c-prog .bar { background:#e3e6ec; border-radius:6px; height:8px; margin-top:3px; overflow:hidden; } .c-prog .bar i { display:block; height:100%; background:#7c5cff; }
  .c-chips { display:flex; flex-wrap:wrap; gap:4px; } .c-chips span { font-size:9px; background:#eef0f4; color:#5a6478; border-radius:10px; padding:2px 8px; }
  .c-avatar { width:42px; height:42px; border-radius:50%; background:#dde0e7; align-self:center; }
  .c-img { border:1px solid #d7dbe2; border-radius:6px; min-height:60px; display:flex; align-items:center; justify-content:center; font-size:10px; color:#9aa2b1; background:linear-gradient(135deg,transparent 47%,#d7dbe2 47%,#d7dbe2 53%,transparent 53%),linear-gradient(45deg,transparent 47%,#d7dbe2 47%,#d7dbe2 53%,transparent 53%); }
  .c-text { font-size:11px; color:#4a5263; } .c-text.heading { font-size:13px; font-weight:700; color:#1f2430; } .c-text.caption { font-size:9px; color:#9aa2b1; }
  .c-banner { background:#e9e2d0; border:1px dashed #c9bd99; border-radius:5px; text-align:center; font-size:10px; color:#8a7a4a; padding:9px; }
  .c-grid { display:grid; gap:5px; } .c-grid .cell { background:#eef0f4; border:1px solid #e0e3ea; border-radius:6px; min-height:38px; display:flex; align-items:center; justify-content:center; font-size:9px; color:#7a8294; text-align:center; padding:3px; }
  .c-dialog-wrap { background:rgba(40,44,56,.12); border-radius:6px; padding:16px 12px; }
  .c-dialog { background:#fff; border:1px solid #cdd4e0; border-radius:8px; padding:10px; font-size:11px; box-shadow:0 3px 10px rgba(0,0,0,.12); } .c-dialog b { display:block; margin-bottom:3px; } .c-dialog span { color:#7a8294; }
  .c-unknown { border:1px dashed #b8bfcc; border-radius:6px; padding:8px; font-size:10px; color:#9aa2b1; text-align:center; }
</style>
</head>
<body>
<header class="top">
  <div class="titlerow">
    <h1>통합 기획 뷰어</h1>
    <button class="tbtn primary" id="pickBtn">프로젝트 폴더 선택</button>
    <button class="tbtn" id="reopenBtn" style="display:none"></button>
    <button class="tbtn" id="reloadBtn" disabled>재로드</button>
    <button class="tbtn" id="saveBtn" disabled>현재 탭 저장</button>
    <button class="tbtn" id="saveAllBtn" disabled>전체 저장</button>
    <span class="badges"><span class="badge prog" id="progBadge">진행률 –</span></span>
    <span class="status" id="status">폴더 미선택 — prd.json·fts.json·userflow.json·wire.json 가 있는 폴더를 선택</span>
  </div>
  <div class="tabbar" id="tabbar">
    <div class="tab on" data-go="prd">PRD <span class="dot-dirty" data-d="prd"></span></div>
    <div class="tab" data-go="fts">기능명세서 <span class="dot-dirty" data-d="fts"></span></div>
    <div class="tab" data-go="flow">메뉴구성도 <span class="dot-dirty" data-d="flow"></span></div>
    <div class="tab" data-go="wire">와이어프레임 <span class="dot-dirty" data-d="wire"></span></div>
  </div>
</header>

<main>
  <div class="gate" id="gate">
    <h2>프로젝트 폴더를 선택하세요</h2>
    <p>데이터 파일(<b>prd.json · fts.json · userflow.json · wire.json</b>)이 들어있는 폴더(예: <code>src/viewer/</code>)를 1회 선택하면, 4탭이 자동으로 로드됩니다. 편집 후 <b>저장</b>하면 같은 파일에 <b>제자리 덮어쓰기</b>됩니다(다운로드·백엔드 없음). 재로드로 반영 확인.</p>
    <p class="warn" id="gateWarn"></p>
  </div>
  <div id="tabsWrap" style="display:none;">
    <section data-tab="prd" class="on">
      <p class="hint">PRD 문단. ✎수정 / ×삭제 · <b>파일에 남은 항목 = 설계/개발 대상</b>(삭제=제외, 별도 승인 없음). <button class="addbtn" data-add="prd">+ 문단 추가</button></p>
      <div id="prdList"></div>
    </section>
    <section data-tab="fts">
      <p class="hint">메뉴 → 기능그룹 → 스팩. ✎수정 / ×삭제 · 남은 항목 = 개발 대상. 상태(읽기전용, agent 갱신): <span class="dot s-todo"></span>예정 <span class="dot s-prog"></span>진행중 <span class="dot s-done"></span>완료 · <button class="addbtn" data-add="fts-group">+ 기능그룹 추가</button></p>
      <div id="ftsTree"></div>
    </section>
    <section data-tab="flow">
      <p class="hint">메뉴 구성도(앱→탭→화면→하위). 드래그(⠿)로 순서·위치 이동 · +하위 / ✎수정 / ×삭제 · <button class="addbtn" data-add="menu-root">+ 최상위 메뉴</button></p>
      <div id="menuTree"></div>
    </section>
    <section data-tab="wire">
      <p class="hint">화면별 lo-fi UI(컴포넌트 스택, agent 생성). 검토·조정만: ↑↓순서 · ✎수정 · ×삭제 · 우상단 프레임(mobile/web) 토글.</p>
      <div class="wgrid" id="wireGrid"></div>
    </section>
  </div>
</main>

<script>
"use strict";
var FILES = { prd:"prd.json", fts:"fts.json", flow:"userflow.json", wire:"wire.json" };
var dirHandle = null;
var data = { prd:[], fts:[], flow:{root:"",tree:[]}, wire:[] };
var dirty = { prd:false, fts:false, flow:false, wire:false };
var curTab = "prd";
var esc = function(s){ return String(s==null?"":s).replace(/[&<>]/g,function(c){return ({"&":"&amp;","<":"&lt;",">":"&gt;"})[c];}); };
function $(id){ return document.getElementById(id); }
function setStatus(m){ $("status").textContent = m; }

/* ---- 폴더 핸들 기억 (IndexedDB) — 임의 경로 자동열기는 브라우저 보안상 불가, 핸들 재사용으로 1클릭 복원 ---- */
function idb(){ return new Promise(function(res,rej){ var r=indexedDB.open("pawpad-viewer",1); r.onupgradeneeded=function(){ r.result.createObjectStore("kv"); }; r.onsuccess=function(){ res(r.result); }; r.onerror=function(){ rej(r.error); }; }); }
async function idbSet(k,v){ var db=await idb(); return new Promise(function(res,rej){ var tx=db.transaction("kv","readwrite"); tx.objectStore("kv").put(v,k); tx.oncomplete=function(){res();}; tx.onerror=function(){rej(tx.error);}; }); }
async function idbGet(k){ var db=await idb(); return new Promise(function(res,rej){ var tx=db.transaction("kv","readonly"); var rq=tx.objectStore("kv").get(k); rq.onsuccess=function(){res(rq.result);}; rq.onerror=function(){rej(rq.error);}; }); }

/* ---- File System Access ---- */
$("pickBtn").addEventListener("click", async function(){
  if(!window.showDirectoryPicker){
    $("gateWarn").textContent = "이 브라우저는 File System Access API 미지원. Chrome/Edge 사용 권장. file://에서 막히면 localhost 정적 서빙(python -m http.server) 후 열기.";
    return;
  }
  var opts={ id:"pawpadViewer", mode:"readwrite" };
  try { var saved=await idbGet("dir"); if(saved) opts.startIn=saved; } catch(_){}   // 지난 폴더 근처에서 시작
  try { dirHandle = await window.showDirectoryPicker(opts); } catch(e){ return; }
  try { await idbSet("dir", dirHandle); } catch(_){}                                // 다음 세션 복원용 저장
  await loadAll();
});
$("reopenBtn").addEventListener("click", async function(){
  try {
    var saved=await idbGet("dir"); if(!saved){ $("reopenBtn").style.display="none"; return; }
    var perm=await saved.requestPermission({mode:"readwrite"});
    if(perm!=="granted"){ setStatus("폴더 권한 거부됨 — '프로젝트 폴더 선택'으로 다시 선택"); return; }
    dirHandle=saved; await loadAll();
  } catch(e){ setStatus("다시 열기 실패: "+e.message); }
});
$("reloadBtn").addEventListener("click", loadAll);
$("saveBtn").addEventListener("click", function(){ saveTab(curTab); });
$("saveAllBtn").addEventListener("click", async function(){ for(var k in FILES){ if(dirty[k]) await saveTab(k); } });

async function readJson(name, fallback){
  try {
    var fh = await dirHandle.getFileHandle(name);
    var f = await fh.getFile(); var t = await f.text();
    return t.trim() ? JSON.parse(t) : fallback;
  } catch(e){ return fallback; }
}
async function loadAll(){
  if(!dirHandle) return;
  data.prd  = await readJson(FILES.prd, []);
  data.fts  = await readJson(FILES.fts, []);
  data.flow = await readJson(FILES.flow, {root:"",tree:[]});
  data.wire = await readJson(FILES.wire, []);
  dirty = { prd:false, fts:false, flow:false, wire:false };
  $("gate").style.display = "none"; $("tabsWrap").style.display = "block";
  $("reloadBtn").disabled = false; $("saveBtn").disabled = false; $("saveAllBtn").disabled = false;
  renderAll(); updateDirty();
  setStatus("로드됨: " + dirHandle.name + " (prd " + data.prd.length + " · fts " + data.fts.length + "그룹 · flow " + countMenu(data.flow.tree) + "메뉴 · wire " + data.wire.length + ")");
}
async function saveTab(k){
  if(!dirHandle){ setStatus("폴더 먼저 선택"); return; }
  try {
    var fh = await dirHandle.getFileHandle(FILES[k], {create:true});
    var w = await fh.createWritable();
    await w.write(JSON.stringify(data[k], null, 2) + "\n");
    await w.close();
    dirty[k] = false; updateDirty();
    setStatus(FILES[k] + " 저장됨(제자리 덮어쓰기)");
  } catch(e){ setStatus("저장 실패: " + e.message + " — 쓰기 권한 허용 필요할 수 있음"); }
}
function mark(k){ dirty[k] = true; updateDirty(); }
function updateDirty(){
  var any = false;
  Object.keys(FILES).forEach(function(k){
    var d = document.querySelector('.dot-dirty[data-d="'+k+'"]');
    if(d) d.textContent = dirty[k] ? "●" : "";
    if(dirty[k]) any = true;
  });
  $("saveAllBtn").textContent = any ? "전체 저장 ●" : "전체 저장";
}

/* ---- 탭 ---- */
$("tabbar").addEventListener("click", function(e){
  var t = e.target.closest(".tab"); if(!t) return;
  curTab = t.getAttribute("data-go");
  Array.prototype.forEach.call(document.querySelectorAll(".tab"), function(x){ x.classList.toggle("on", x===t); });
  Array.prototype.forEach.call(document.querySelectorAll("section[data-tab]"), function(s){ s.classList.toggle("on", s.getAttribute("data-tab")===curTab); });
  if(curTab==="flow") renderMenu();
});

function renderAll(){ renderPRD(); renderFTS(); renderMenu(); renderWire(); }

/* ---- PRD ---- */
function renderPRD(){
  var html = data.prd.map(function(b,i){
    var sc = b.status==="done"?"s-done":b.status==="prog"?"s-prog":"s-todo";
    var sl = b.status==="done"?"완료":b.status==="prog"?"진행중":"예정";
    return '<div class="prd-block" data-i="'+i+'"><h3>'+esc(b.heading)+
      '<span class="pill '+sc+'" title="개발 진행 상태(agent 갱신, 읽기전용)">'+sl+'</span>'+
      '<span class="ctrls"><button data-act="edit" title="수정">✎</button><button data-act="del" title="삭제">×</button></span></h3>'+
      '<p>'+esc(b.body)+'</p></div>';
  }).join("");
  $("prdList").innerHTML = html || '<p class="hint">문단 없음 — 추가하세요.</p>';
  refreshProg();
}
$("prdList").addEventListener("click", function(e){
  var btn=e.target.closest("button[data-act]"); if(!btn) return;
  var blk=btn.closest(".prd-block"); var i=+blk.getAttribute("data-i"); var act=btn.getAttribute("data-act");
  if(act==="del"){ if(confirm("이 PRD 문단 삭제?")){ data.prd.splice(i,1); mark("prd"); renderPRD(); } }
  else if(act==="edit"){ editPRD(blk,i); }
});
function editPRD(blk,i){
  var h3=blk.querySelector("h3"); var p=blk.querySelector("p");
  h3.classList.add("editing");
  var hi=document.createElement("input"); hi.className="ed"; hi.value=data.prd[i].heading; hi.style.width="60%";
  var ta=document.createElement("textarea"); ta.className="ed"; ta.value=data.prd[i].body;
  h3.innerHTML=""; h3.appendChild(hi); p.innerHTML=""; p.appendChild(ta); hi.focus();
  function done(){ data.prd[i].heading=hi.value; data.prd[i].body=ta.value; mark("prd"); renderPRD(); }
  hi.addEventListener("blur",function(){ setTimeout(function(){ if(document.activeElement!==ta) done(); },100); });
  ta.addEventListener("blur",function(){ setTimeout(function(){ if(document.activeElement!==hi) done(); },100); });
}

/* ---- FTS 트리 ---- */
function renderFTS(){
  var html = data.fts.map(function(g,gi){
    var leaves = (g.nodes||[]).map(function(n,ni){
      var sc = n.status==="done"?"s-done":n.status==="prog"?"s-prog":"s-todo";
      return '<div class="fts-leaf" data-g="'+gi+'" data-n="'+ni+'"><span class="dot '+sc+'" title="개발 진행 상태(agent 갱신, 읽기전용)"></span>'+
        (n.new?'<span class="tag-new">신규</span>':'')+
        '<span class="lname">'+esc(n.label)+'</span><span class="lno">'+esc(n.hierNo)+'</span>'+
        '<span class="ctrls"><button data-act="edit" title="수정">✎</button><button data-act="del" title="삭제">×</button></span></div>';
    }).join("");
    var single = (g.nodes||[]).length===1 ? " single" : "";
    return '<div class="fts-group" data-g="'+gi+'"><div class="fts-gnode"><div class="gname">'+esc(g.label)+
      '<button class="gaddbtn" data-act="addnode" title="노드 추가">+</button></div><div class="gno">'+esc(g.group)+' · '+esc(g.gno)+'</div></div>'+
      '<div class="fts-branch"></div><div class="fts-leaves'+single+'">'+leaves+'</div></div>';
  }).join("");
  $("ftsTree").innerHTML = html || '<p class="hint">기능그룹 없음 — 추가하세요.</p>';
  refreshProg();
}
$("ftsTree").addEventListener("click", function(e){
  var btn=e.target.closest("button[data-act]"); if(!btn) return;
  var act=btn.getAttribute("data-act");
  if(act==="addnode"){ var gi=+btn.closest(".fts-group").getAttribute("data-g"); data.fts[gi].nodes.push({id:"NEW-"+Date.now(),label:"새 스팩",hierNo:"",new:true,status:"todo"}); mark("fts"); renderFTS(); return; }
  var leaf=btn.closest(".fts-leaf"); var gi=+leaf.getAttribute("data-g"); var ni=+leaf.getAttribute("data-n");
  if(act==="del"){ if(confirm("이 스팩 삭제?")){ data.fts[gi].nodes.splice(ni,1); mark("fts"); renderFTS(); } }
  else if(act==="edit"){ var ln=leaf.querySelector(".lname"); var n2=data.fts[gi].nodes[ni];
    var inp=document.createElement("input"); inp.className="ed"; inp.value=n2.label;
    ln.replaceWith(inp); inp.focus();
    inp.addEventListener("blur",function(){ n2.label=inp.value; mark("fts"); renderFTS(); });
    inp.addEventListener("keydown",function(ev){ if(ev.key==="Enter") inp.blur(); });
  }
});

/* ---- 메뉴구성도 (계층 트리 + 드래그앤드랍) ---- */
function countMenu(arr){ var c=0; (arr||[]).forEach(function(n){ c+=1+countMenu(n.children); }); return c; }
var menuUid=0;
function newMenuId(){ return "m-"+Date.now()+"-"+(menuUid++); }
function renderMenu(){
  if(!data.flow || typeof data.flow!=="object" || Array.isArray(data.flow)) data.flow={root:"",tree:[]};
  if(!data.flow.tree) data.flow.tree=[];
  var html='<div class="mroot" data-root="1">'+esc(data.flow.root||"(root)")+'</div>'+renderMenuList(data.flow.tree, []);
  $("menuTree").innerHTML=html;
}
function renderMenuList(arr, prefix){
  if(!arr || !arr.length) return prefix.length?'':'<p class="hint" style="margin:8px 0 0">메뉴 없음 — "+ 최상위 메뉴" 로 추가.</p>';
  var out='<ul class="mlist'+(prefix.length?'':' root')+'">';
  arr.forEach(function(n,i){
    var pid=prefix.concat(i).join("-");
    var dc="d"+Math.min(prefix.length,5);   // 현재 뎁스 색(렌더 시 재계산 → 이동하면 자동 갱신)
    out+='<li class="mli"><div class="mnode '+dc+'" draggable="true" data-path="'+pid+'">'+
      '<span class="mdrag" title="드래그로 이동">⠿</span>'+
      '<span class="mlabel">'+esc(n.label)+'</span>'+
      (n.tab?'<span class="mtab">'+esc(n.tab)+'</span>':'')+
      (n.feature?'<span class="mfeat">'+esc(n.feature)+'</span>':'')+
      '<span class="ctrls"><button data-mact="add" title="하위 추가">+</button><button data-mact="edit" title="수정">✎</button><button data-mact="del" title="삭제">×</button></span>'+
      '</div>'+renderMenuList(n.children||[], prefix.concat(i))+'</li>';
  });
  return out+'</ul>';
}
/* 객체 식별자 기반 이동(인덱스 시프트 회피) */
function menuNodeAt(p){ var arr=data.flow.tree, n=null; for(var i=0;i<p.length;i++){ n=arr[p[i]]; if(!n) return null; arr=n.children||[]; } return n; }
function menuFindParent(arr, node){ for(var i=0;i<arr.length;i++){ if(arr[i]===node) return {arr:arr,idx:i}; if(arr[i].children){ var r=menuFindParent(arr[i].children,node); if(r) return r; } } return null; }
function menuContains(parent, target){ if(parent===target) return true; return (parent.children||[]).some(function(c){ return menuContains(c,target); }); }
function menuMove(srcNode, dstNode, zone){
  if(!srcNode) return;
  if(dstNode && menuContains(srcNode,dstNode)) return; // 자기 후손으로 이동 금지
  var sp=menuFindParent(data.flow.tree, srcNode); if(!sp) return; sp.arr.splice(sp.idx,1);
  if(zone==="root-inside"){ data.flow.tree.push(srcNode); }
  else if(zone==="inside"){ dstNode.children=dstNode.children||[]; dstNode.children.push(srcNode); }
  else { var dp=menuFindParent(data.flow.tree, dstNode); if(!dp){ data.flow.tree.push(srcNode); } else { dp.arr.splice(zone==="after"?dp.idx+1:dp.idx,0,srcNode); } }
  mark("flow"); renderMenu();
}
/* DnD */
var menuDragPath=null;
function clearDropMarks(){ Array.prototype.forEach.call($("menuTree").querySelectorAll(".drop-before,.drop-after,.drop-inside"), function(x){ x.classList.remove("drop-before","drop-after","drop-inside"); }); }
function dropZone(nd, e){ var r=nd.getBoundingClientRect(); var y=e.clientY-r.top; if(y<r.height*0.4) return "before"; if(y>r.height*0.6) return "after"; return "inside"; }
$("menuTree").addEventListener("dragstart", function(e){ var nd=e.target.closest(".mnode"); if(!nd) return; menuDragPath=nd.getAttribute("data-path"); nd.classList.add("dragging"); e.dataTransfer.effectAllowed="move"; try{ e.dataTransfer.setData("text/plain",menuDragPath); }catch(_){} });
$("menuTree").addEventListener("dragend", function(){ menuDragPath=null; clearDropMarks(); var d=$("menuTree").querySelector(".dragging"); if(d) d.classList.remove("dragging"); });
$("menuTree").addEventListener("dragover", function(e){
  if(menuDragPath===null) return;
  var root=e.target.closest(".mroot"), nd=e.target.closest(".mnode");
  if(!root && !nd) return;
  e.preventDefault(); e.dataTransfer.dropEffect="move"; clearDropMarks();
  if(root){ root.classList.add("drop-inside"); return; }
  nd.classList.add("drop-"+dropZone(nd,e));
});
$("menuTree").addEventListener("drop", function(e){
  if(menuDragPath===null) return; e.preventDefault();
  var src=menuNodeAt(menuDragPath.split("-").map(Number));
  var root=e.target.closest(".mroot"), nd=e.target.closest(".mnode");
  clearDropMarks();
  if(root){ menuMove(src,null,"root-inside"); menuDragPath=null; return; }
  if(!nd){ menuDragPath=null; return; }
  var dst=menuNodeAt(nd.getAttribute("data-path").split("-").map(Number));
  if(src!==dst) menuMove(src,dst,dropZone(nd,e));
  menuDragPath=null;
});
/* 노드 액션 */
$("menuTree").addEventListener("click", function(e){
  var btn=e.target.closest("button[data-mact]"); if(!btn) return;
  var nd=btn.closest(".mnode"); var node=menuNodeAt(nd.getAttribute("data-path").split("-").map(Number));
  if(!node) return; var act=btn.getAttribute("data-mact");
  if(act==="add"){ var lb=prompt("하위 메뉴 라벨?","새 메뉴"); if(lb===null) return; var ft=prompt("Feature ID? (선택, 비우면 없음)","")||""; node.children=node.children||[]; node.children.push({id:newMenuId(),label:lb||"새 메뉴",feature:ft}); mark("flow"); renderMenu(); }
  else if(act==="del"){ if(confirm("이 메뉴와 하위 전체 삭제?")){ var dp=menuFindParent(data.flow.tree,node); if(dp){ dp.arr.splice(dp.idx,1); mark("flow"); renderMenu(); } } }
  else if(act==="edit"){ var ml=nd.querySelector(".mlabel"); var inp=document.createElement("input"); inp.className="ed"; inp.value=node.label; ml.replaceWith(inp); inp.focus();
    inp.addEventListener("blur",function(){ node.label=inp.value; mark("flow"); renderMenu(); });
    inp.addEventListener("keydown",function(ev){ if(ev.key==="Enter") inp.blur(); }); }
});

/* ---- 와이어프레임 (디바이스 프레임 + 컴포넌트 lo-fi) ---- */
/* 컴포넌트는 agent가 wire.json에 생성. 뷰어는 렌더 + 순서/수정/삭제만(추가 없음). */
var ARRAY_FIELD={tabbar:"items",segmented:"items",chip:"items",list:"rows",grid:"cells"};
function rowHtml(r){ if(r && typeof r==="object"){ return '<div class="row">'+(r.leading?'<span class="lead">'+esc(r.leading)+'</span>':'')+'<span>'+esc(r.label)+'</span>'+(r.trailing?'<span class="trail">'+esc(r.trailing)+'</span>':'')+'</div>'; } return '<div class="row">'+esc(r)+'</div>'; }
function compHtml(c){
  var t=c.type;
  if(t==="appbar") return '<div class="c-appbar"><span class="c-ic">'+esc(c.left||"‹")+'</span><span>'+esc(c.label||"")+'</span><span class="c-ic">'+esc(c.right||"")+'</span></div>';
  if(t==="tabbar") return '<div class="c-tabbar">'+(c.items||[]).map(function(x,i){return '<span class="'+(i===(c.active||0)?"on":"")+'">'+esc(x)+'</span>';}).join("")+'</div>';
  if(t==="segmented") return '<div class="c-seg">'+(c.items||[]).map(function(x,i){return '<span class="'+(i===(c.active||0)?"on":"")+'">'+esc(x)+'</span>';}).join("")+'</div>';
  if(t==="list") return '<div class="c-list">'+(c.rows||[]).map(rowHtml).join("")+'</div>';
  if(t==="card") return '<div class="c-card"><b>'+esc(c.label||"")+'</b>'+(c.body?'<span>'+esc(c.body)+'</span>':'')+'</div>';
  if(t==="button") return '<div class="c-btn v-'+(c.variant||"primary")+'">'+esc(c.label||"")+'</div>';
  if(t==="fab") return '<div class="c-fab">'+esc(c.label||"+")+'</div>';
  if(t==="input") return '<div class="c-input">'+esc(c.label||"입력")+'</div>';
  if(t==="progress") return '<div class="c-prog"><span>'+esc(c.label||"")+'</span><div class="bar"><i style="width:'+Math.max(0,Math.min(100,+c.value||0))+'%"></i></div></div>';
  if(t==="chip") return '<div class="c-chips">'+(c.items||[]).map(function(x){return '<span>'+esc(x)+'</span>';}).join("")+'</div>';
  if(t==="avatar") return '<div class="c-avatar"></div>';
  if(t==="image") return '<div class="c-img">'+esc(c.label||"")+'</div>';
  if(t==="text") return '<div class="c-text '+(c.role||"body")+'">'+esc(c.value||"")+'</div>';
  if(t==="banner") return '<div class="c-banner">'+esc(c.label||"")+'</div>';
  if(t==="grid") return '<div class="c-grid" style="grid-template-columns:repeat('+(c.cols||3)+',1fr)">'+(c.cells||[]).map(function(x){return '<div class="cell">'+esc(x)+'</div>';}).join("")+'</div>';
  if(t==="dialog") return '<div class="c-dialog-wrap"><div class="c-dialog"><b>'+esc(c.label||"")+'</b>'+(c.body?'<span>'+esc(c.body)+'</span>':'')+'</div></div>';
  return '<div class="c-unknown">?'+esc(t)+'</div>';
}
function compEditField(c){ if(ARRAY_FIELD[c.type]) return ARRAY_FIELD[c.type]; if(c.type==="text") return "value"; return "label"; }
function renderWire(){
  if(!Array.isArray(data.wire)) data.wire=[];
  var html=data.wire.map(function(s,si){
    var frame=s.frame==="web"?"web":"mobile";
    var comps=(s.components||[]).map(function(c,ci){
      return '<div class="comp" data-s="'+si+'" data-c="'+ci+'">'+compHtml(c)+
        '<span class="cctrls"><button data-wact="up" title="위로">↑</button><button data-wact="down" title="아래로">↓</button><button data-wact="cedit" title="수정">✎</button><button data-wact="cdel" title="삭제">×</button></span></div>';
    }).join("");
    return '<div class="wscreen '+frame+'" data-s="'+si+'"><div class="wbar"><span class="wtitle">'+esc(s.title)+'</span>'+
      (s.feature?'<span class="wfeat">'+esc(s.feature)+'</span>':'')+
      '<span class="navtag" data-wact="frame" title="프레임 토글">'+frame+'</span>'+
      '<span class="ctrls"><button data-wact="stitle" title="제목수정">✎</button><button data-wact="sdel" title="화면삭제">×</button></span></div>'+
      '<div class="wframe"><div class="device '+frame+'">'+(comps||'<div class="c-unknown">컴포넌트 없음</div>')+'</div></div></div>';
  }).join("");
  $("wireGrid").innerHTML=html||'<p class="hint">화면 없음 — "+ 화면" 으로 추가.</p>';
}
$("wireGrid").addEventListener("click", function(e){
  var btn=e.target.closest("[data-wact]"); if(!btn) return;
  var act=btn.getAttribute("data-wact");
  var sc=btn.closest(".wscreen"); var si=+sc.getAttribute("data-s"); var screen=data.wire[si]; if(!screen) return;
  if(act==="frame"){ screen.frame=(screen.frame==="web")?"mobile":"web"; mark("wire"); renderWire(); return; }
  if(act==="sdel"){ if(confirm("이 화면 삭제?")){ data.wire.splice(si,1); mark("wire"); renderWire(); } return; }
  if(act==="stitle"){ var tl=sc.querySelector(".wtitle"); var inp=document.createElement("input"); inp.className="ed"; inp.value=screen.title; tl.replaceWith(inp); inp.focus(); inp.addEventListener("blur",function(){ screen.title=inp.value; mark("wire"); renderWire(); }); inp.addEventListener("keydown",function(ev){ if(ev.key==="Enter") inp.blur(); }); return; }
  var comp=btn.closest(".comp"); if(!comp) return; var ci=+comp.getAttribute("data-c"); var comps=screen.components||[];
  if(act==="up"){ if(ci>0){ var x=comps.splice(ci,1)[0]; comps.splice(ci-1,0,x); mark("wire"); renderWire(); } }
  else if(act==="down"){ if(ci<comps.length-1){ var y=comps.splice(ci,1)[0]; comps.splice(ci+1,0,y); mark("wire"); renderWire(); } }
  else if(act==="cdel"){ if(confirm("이 컴포넌트 삭제?")){ comps.splice(ci,1); mark("wire"); renderWire(); } }
  else if(act==="cedit"){ editComp(screen, ci); }
});
function editComp(screen, ci){
  var c=screen.components[ci]; if(!c) return; var field=compEditField(c); var isArr=!!ARRAY_FIELD[c.type];
  var cur=isArr?((c[field]||[]).map(function(r){ return (r&&typeof r==="object")?r.label:r; }).join(", ")):(c[field]||"");
  var v=prompt(isArr?(c.type+" 항목(쉼표 구분):"):(c.type+" 텍스트:"), cur);
  if(v===null) return;
  if(isArr){ c[field]=v.split(",").map(function(s){ return s.trim(); }).filter(function(s){ return s!==""; }); }
  else { c[field]=v; }
  mark("wire"); renderWire();
}

/* ---- 추가 버튼(탭 상단) ---- */
document.addEventListener("click", function(e){
  var b=e.target.closest("button[data-add]"); if(!b) return;
  var kind=b.getAttribute("data-add");
  if(kind==="prd"){ data.prd.push({id:"PRD-"+Date.now(),heading:"새 문단",body:"",status:"todo"}); mark("prd"); renderPRD(); }
  else if(kind==="fts-group"){ data.fts.push({group:"NEW",label:"새 기능그룹",gno:String(data.fts.length+1),nodes:[]}); mark("fts"); renderFTS(); }
  else if(kind==="menu-root"){ var lb=prompt("최상위 메뉴 라벨?","새 메뉴"); if(lb===null) return; var ft=prompt("Feature ID? (선택)","")||""; data.flow.tree=data.flow.tree||[]; data.flow.tree.push({id:newMenuId(),label:lb||"새 메뉴",feature:ft}); mark("flow"); renderMenu(); }
});

/* ---- 진행률 ---- */
function refreshProg(){
  var total=0,done=0;
  data.fts.forEach(function(g){ (g.nodes||[]).forEach(function(n){ total++; if(n.status==="done") done++; }); });
  var pct=total?Math.round(done/total*100):0;
  $("progBadge").textContent="진행률 "+pct+"% ("+done+"/"+total+")";
}

/* ---- 시작 시: 지난 폴더 있으면 '다시 열기' 노출 ---- */
(async function initReopen(){
  if(!window.showDirectoryPicker || !window.indexedDB) return;
  try {
    var saved=await idbGet("dir");
    if(saved){ var b=$("reopenBtn"); b.textContent="↻ "+saved.name+" 다시 열기"; b.style.display=""; }
  } catch(_){}
})();
</script>
</body>
</html>
'@

# -- Skills: review (문서형 리뷰 라운드트립 게이트) --
Step-Begin "skill: review"
Write-FileContent ".claude\skills\review\SKILL.md" -NoBom @'
---
name: review
description: 문서형 크로스에이전트/세션 리뷰 라운드트립 게이트. 변경 내용을 review-request 문서로 정리해 다른 세션·에이전트(Codex↔Claude)가 직접 검증하며 리뷰하고, review-result 문서로 반환받아 수정한다. codex exec 자율 리뷰보다 저토큰(보완 관계). 커밋/완료 전 또는 사용자가 "리뷰"/"review"/"교차검증"을 언급할 때 사용.
---

# Review Skill - 문서형 리뷰 라운드트립 게이트

## 목적
교차 검증(리뷰)을 **문서 기반 라운드트립**으로 수행한다. 요청측이 review-request 문서를 쓰고 lane state로 핸드오프 → 다른 세션/에이전트가 읽고 **직접 검증**하며 리뷰 → review-result로 반환 → 요청측이 수정.

왜: `codex exec` 자율 리뷰는 repo 전체 재탐색으로 토큰 대량 소모(실측 1회 247k). review 스킬은 **큐레이트 scope + 직접 검증 체크리스트**로 저토큰이면서 독립성 유지.

## codex exec와의 관계 (보완, 대체 X)
- **기본 = review 스킬** (저비용 문서형, 크로스세션/에이전트).
- **에스컬레이션 = `codex exec` 자율 리뷰**: 다음 시 권장 — 배포본/설치 스크립트 변경, 저자 맹점 우려 큼, 영향 범위 광범위·불확실, request로 scope를 좁히기 어려움.

## 성격
Instruction skill. PowerShell command 아님. agent가 절차를 따라 문서를 읽고 쓴다.

## 트리거
/review [request|do] [feature-id]
- 인자 생략 시 **lane state 자동 분기**:
  - 대상 lane에 REVIEW_REQUESTED **없음** → **요청 작성 모드**(request).
  - REVIEW_REQUESTED **있음** → **리뷰 수행 모드**(do).
- `/review request` | `/review do` 로 명시도 가능.
- 리뷰측은 보통 별도 호출 없이 resume ON START가 REVIEW_REQUESTED를 발견해 진입.

## 산출물 위치 (기존 reviews/ 관례)
- request: `.claude/pawpad/reviews/{feature-id}-review-prompt-NN.md`
- result : `.claude/pawpad/reviews/{feature-id}-review-NN.md`
- NN = 라운드 번호(01, 02…). 재리뷰 시 증가.

## state / 소유권 (work owner 불변)
lane 필드: `reviewer`(리뷰 대상 에이전트), `review`(현재 review 문서 경로).
- 요청 모드: request 작성 → lane state=**REVIEW_REQUESTED** + reviewer 지정 + request 경로 기록. **work owner는 그대로 둔다.**
- 리뷰 모드: result 작성 → lane state=**REVIEW_DONE** + result 경로 기록.
- 리뷰어는 work lane을 점유하지 않는다(검토자일 뿐). work 내용 수정 금지, review state·경로만 갱신(HYBRID Lane Rule 예외).

## 요청 모드 절차 (요청측)
1. 리뷰 대상 결정(보통 현재 작업 lane의 feature-id) + reviewer 결정(Codex / Claude / 다음 세션).
2. review-request 문서 작성(아래 템플릿). **요약만 쓰지 말고 직접 검증 체크리스트 필수**.
3. lane: state=REVIEW_REQUESTED, reviewer=대상, review=request 경로 기록. _wip.md updated 갱신.
4. 사용자에게 "리뷰 대기" 안내(리뷰는 다른 세션/에이전트가 수행).

## 리뷰 모드 절차 (리뷰측)
1. lane state=REVIEW_REQUESTED 발견(ON START 또는 /review) → review-request 문서 read.
2. **요약을 맹신하지 말고** request의 체크리스트대로 **지정 파일을 직접 열고 명령을 직접 실행**해 검증.
3. review-result 문서 작성(아래 템플릿): verdict + 충족도 + findings.
4. lane: state=REVIEW_DONE, review=result 경로 기록. work owner·내용 미수정.

## 수정/라운드 (요청측)
1. REVIEW_DONE 발견 → result read.
2. findings 반영 수정.
3. 재리뷰 필요 시 다시 `/review`(request NN+1) → REVIEW_REQUESTED 토글.
4. **종결은 요청측 재량**: findings 0 또는 수용 가능 판단 시 리뷰 종료(work 계속/완료). 합의 무한 반복 강제 X.

## review-request 템플릿
```
# Review Request — {feature} (round NN)
- 요청자 / reviewer 대상 / 일자
## 범위·배경
## 변경 파일 (경로 목록)
## diff / 변경 요약
## 이미 한 검증 (결과)
## [필수] 직접 검증 — 요약 신뢰 말고 아래를 직접 확인
- [ ] 파일: {경로} — {무엇을 확인}
- [ ] 명령: {명령} — {기대 결과}
## 질문 / 우려 지점
## result 작성 위치: reviews/{feature}-review-NN.md
```

## review-result 템플릿
```
# Review — {feature} (review-NN)
- 리뷰어 / 일자
## 판정: PASS | PASS_WITH_FIXES | FAIL   |   충족도: NN%
## findings
| # | 심각도 H/M/L | 파일:라인 | 문제 | 수정 지시 |
|---|---|---|---|---|
## 검증 통과 (직접 확인한 항목)
```

## 원칙
- **직접 검증 강제**: request 체크리스트 없이 요약만 리뷰 금지(저자 맹점 상속 → 결함 누락).
- 리뷰어는 work lane 미점유(소유권 불변). review state·경로만 전이.
- 종결은 요청측 재량(수용 가능 finding 무한 반복 금지).
- 고위험은 codex exec로 에스컬레이션(위 기준).
- 선택지 질문은 AskUserQuestion(체크박스), 자유서술은 텍스트.

## handoff / security-check 와의 관계
- handoff = 작업 인계(owner 이전, snapshot). review = 검토만(owner 불변). 별개.
- security-check = 자동 스캔 게이트(DoD#8 필수). review = 사람/에이전트 판단(자동제안, 강제 X).
'@

# ── Skills: codebase-map (7축 고수준 코드베이스 맵) ────────────────────────────
Step-Begin "skill: codebase-map"
Write-FileContent ".claude\skills\codebase-map\SKILL.md" -NoBom @'
---
name: codebase-map
description: High-level codebase map (7 axes). Use to record or recall architecture, structure, conventions, testing, and cross-cutting concerns without reading the whole tree. Complements codemap (symbol registry) at a higher altitude. Refresh on structural change.
---
# CodeBase-Map Skill - High-Level Project Map

## 목적
코드베이스를 7축 고수준 문서로 관리. codemap이 "심볼 위치"(저고도)라면 codebase-map은 "아키텍처/구조/관례/관심사"(고고도).
신규 세션·신규 에이전트가 트리 전체를 읽지 않고 프로젝트 정신모델을 즉시 획득 -> 토큰 절약.
(codemap=심볼위치, codebase-map=아키텍처. 기록 대상별 선택은 하단 표 참조.)

## 위치 (canonical)
.claude/pawpad/codebase/{axis}.md — 축당 1파일.
digest: .ctxdb/L2/codebase-map-current.md — 주입용 압축본.
codemap _index.md: pointer 1줄만 (pawpad:codebaseMap  .claude/pawpad/codebase/  7-axis high-level map).

## 7축 (required 5 + optional 2)
| 축 | 파일 | required | budget(줄) | 내용 |
|----|------|:--------:|:----------:|------|
| ARCH    | architecture.md | Y | 220 | 시스템 아키텍처, 레이어, 주요 데이터 흐름, 핵심 설계 결정(ADR 링크) |
| STRUCT  | structure.md    | Y | 150 | 디렉토리/모듈 레이아웃, 각 모듈 책임 1줄 |
| CONV    | conventions.md  | Y | 150 | 명명/타입/로깅/상수/에러 정책, 코드 스타일 |
| TEST    | testing.md      | Y | 150 | 테스트 전략, 명령, 커버리지 영역, fixture 위치 |
| CONCERNS| concerns.md     | Y | 150 | cross-cutting: 인증, 에러처리, 설정, 보안, 성능, 로깅 |
| STACK   | stack.md        | optional | 150 | 기술 스택, 핵심 의존성+버전, 빌드 도구 |
| INTEG   | integrations.md | optional | 150 | 외부 API/서비스 연동, 인증방식, 엔드포인트 |

required 5축은 항상 존재. optional 2축은 해당 시만 생성(없으면 미생성, digest에 "n/a" 표기 금지 — 행 자체 생략).

## 각 문서 헤더 (stale guard, 필수)
모든 axis 파일 최상단:
```
<!-- axis: ARCH -->
Last refreshed: YYYY-MM-DD
Stale when: 핵심 구조/데이터흐름 변경
Budget: 220 lines
```
- Last refreshed: 마지막 갱신 날짜(YYYY-MM-DD).
- Stale when: 이 문서를 다시 손봐야 하는 트리거 조건(축별 상이).
- Budget: 위 표의 줄 수. 초과 시 압축 또는 codemap/ADR로 분리. 산문 누적 금지.

## digest (.ctxdb/L2/codebase-map-current.md, budget 120줄)
주입 전용 압축본. 축당 3~6줄 요약 + canonical 파일 pointer.
원칙: digest는 "무엇이 있는지 + 어디 읽을지"만. 세부는 full 문서 on-demand read.

## digest-only 주입
ctxdb-inject hook이 codebase-map 키워드(architecture/structure/convention/codebase-map 등) 매치 시:
- digest(.ctxdb/L2/codebase-map-current.md)만 주입.
- full 7축 docs는 자동주입 금지 — 에이전트가 필요 시 on-demand read.
- 근거: full inject(7파일 ~1000줄)는 토큰절약 목적 파괴. digest 120줄로 정신모델 제공 후 deep-dive만 read.
- INDEX.md 키워드행 + L1 pointer가 digest를 가리킴.

## 생성 절차 (최초)
1. required 5축 파일 생성, 각 stale-guard 헤더 박기.
2. 코드베이스 스캔 -> 축별 내용 작성(budget 내).
3. optional 2축은 해당 시만.
4. digest 작성(축당 3~6줄).
5. codemap _index.md에 pointer 1줄 추가.
6. .ctxdb/INDEX.md 키워드행 + L1 pointer 등록.

## 갱신 절차 (refresh)
- 트리거: 해당 축 Stale when 조건 충족, 또는 구조 변경 PR.
- 변경 축 파일만 수정 -> Last refreshed 갱신 -> digest 해당 섹션 동기 -> budget 재확인.
- code+doc 한 단위(atomic). 구조 바꾸고 map 안 고치면 stale.

## 권한 (codemap과 동일 모델)
| 작업 | 허용 |
|------|------|
| 신규 축 파일 추가 | 누구나 (lane 무관) |
| 기존 축 내용 수정 | lane owner만 (_wip.md Locks 확인) |
| digest 갱신 | owner만 (내용 동기 책임) |
| codemap pointer 추가 | 누구나 |

## codemap vs codebase-map 선택
| 기록 대상 | 위치 |
|----------|------|
| 심볼 위치/시그니처 | codemap _index.md |
| 아키텍처/레이어/데이터흐름 | codebase-map ARCH |
| 디렉토리 책임 | codebase-map STRUCT |
| 명명/타입/로깅 정책 | codebase-map CONV |
| 되돌리기 어려운 결정 | decisions/arch.md ADR (codebase-map ARCH에서 링크) |

중복 금지: codebase-map은 codemap 심볼을 복붙하지 않음(pointer/요약만). ADR rationale도 복붙 금지(링크).
'@

# ── Skills: security-check (보안 검증 게이트) ──────────────────────────────────
Step-Begin "skill: security-check"
Write-FileContent ".claude\skills\security-check\SKILL.md" -NoBom @'
---
name: security-check
description: Security verification gate. Use before commit, handoff, or task completion (or on /security-check) to scan changed files and PawPad artifacts for hardcoded secrets, vulnerabilities, and risky configs. Blocks completion on critical findings.
---
# Security Check Skill - 보안 검증 게이트

## 목적
변경 코드와 PawPad 산출물에서 secrets/민감정보, 취약점, 위험 설정을 검출. 🔴 검출 시 작업 완료 BLOCK + 조치 제안.

## 트리거
/security-check [scope]
- scope: secrets | vuln | deps | pawpad | all (미지정 시 all)
- DoD 게이트: 코드 변경 작업 완료 전 필수 (분석전용/문서전용 작업 면제)
- 권장 시점: 커밋 직전, /handoff 직전, lane done 이동 직전

## 검사 대상 결정
1. git repo: 변경 파일 (staged + unstaged + untracked)
2. 비-git: 세션 중 수정/생성 파일 + 사용자 명시 경로
3. scope=pawpad: .claude/pawpad/**, .ctxdb/**, .claude/codemap/** 전체 (변경 여부 무관)
4. 제외: .claude/pawpad/backup/**, <BUILD_OUTPUT_DIR>, <GENERATED_DIR>, lockfile

## 1. Secrets/민감정보 스캔 (scope: secrets, pawpad)
Grep 정규식, case-insensitive. 대상 파일 전체 적용.

| 패턴 (정규식) | 탐지 대상 | 심각도 |
|--------------|----------|--------|
| `AKIA[0-9A-Z]{16}` | AWS Access Key | 🔴 |
| `-----BEGIN [A-Z ]*PRIVATE KEY-----` | Private Key 블록 | 🔴 |
| `eyJ[A-Za-z0-9_-]{20,}\.eyJ` | JWT 토큰 | 🔴 |
| `(api[_-]?key|secret|token|passw(or)?d|credential)\s*[:=]\s*["'][^"']{8,}["']` | 자격증명 하드코딩 할당 | 🔴 |
| `(mongodb|mysql|postgres(ql)?|redis|amqps?|mssql)://[^/\s:]+:[^@\s]+@` | 자격증명 포함 연결 문자열 | 🔴 |
| `\b\d{6}-[1-4]\d{6}\b` | 주민등록번호 패턴 | 🔴 |
| `\b01[016789]-?\d{3,4}-?\d{4}\b` | 휴대전화번호 (다건 시) | 🟡 |
| `[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}` | 이메일 다건 (개인정보 목록 의심) | 🟡 |

False positive 제외 (검출에서 제거):
- placeholder: `<YOUR_*>`, `xxx`, `example`, `dummy`, `test`, `changeme`, `placeholder`
- env var 참조: `$env:`, `process.env`, `os.environ`, `${...}`, `{{...}}`
- 문서 내 패턴 설명 자체 (이 SKILL.md 등 정규식 정의부)

## 2. 취약점 체크리스트 (scope: vuln) — LLM 리뷰
변경 파일 read 후 항목별 점검:

| 항목 | 점검 내용 | 심각도 |
|------|----------|--------|
| Injection | SQL/command/eval에 외부 입력 직결합 (파라미터화 없음) | 🔴 |
| AuthN/AuthZ | 인증 누락 외부 노출 endpoint, 권한 검사 생략 | 🔴 |
| 경로 조작 | 사용자 입력 경로 직사용 (`../` 미검증, 절대경로 미차단) | 🔴 |
| Deserialization | 신뢰 불가 입력 unsafe parse (pickle, eval-JSON 등) | 🔴 |
| XSS | 미이스케이프 출력 (innerHTML, dangerouslySetInnerHTML, v-html) | 🟡 |
| 암호화 | 약한 해시(MD5/SHA1)로 비밀번호 저장, 하드코딩 IV/salt | 🟡 |
| 로깅 | 민감정보(토큰/비밀번호/개인정보) 로그 출력 | 🟡 |

## 3. 의존성/설정 점검 (scope: deps)
- 매니페스트/lockfile 변경 시: 신규 의존성 이름/출처/버전 확인 (typosquatting 의심 명칭 🔴)
- 위험 설정값:

| 패턴 | 심각도 |
|------|--------|
| `debug\s*[:=]\s*true` (운영 설정 파일) | 🟡 |
| CORS 전체 허용 (`*` origin + credentials) | 🔴 |
| TLS 검증 비활성 (`verify=false`, `rejectUnauthorized: false`, `InsecureSkipVerify`) | 🔴 |
| 과다 권한 (chmod 777, AllowAll, `0.0.0.0` 바인딩 의도 불명) | 🟡 |

## 4. PawPad 산출물 검증 (scope: pawpad)
- 1번 secrets 정규식을 .claude/pawpad/**, .ctxdb/** 전체에 적용
- 추가 점검: handoff/spec/lane/L2 파일에 실데이터 유입 여부 (고객 식별정보, 운영 로그 원문, 운영 DB 데이터) — 발견 시 🔴

## 출력 포맷
보안검증: {scope} | 파일 {N}개 | 🔴{n} 🟡{n} 🟢{n} | [PASS 또는 BLOCK]

| # | 심각도 | 파일:라인 | 항목 | 조치 |
|---|--------|----------|------|------|

마스킹 필수: 검출 값은 앞 4자 + `****`만 표시. 전체 값 출력/재인용 금지.

## 판정 규칙
- 🔴 ≥ 1 → **BLOCK**: 작업 완료 금지. 조치 제안 (env var 이관, 마스킹, .gitignore 추가, PawPad 파일 정화) → 조치 후 해당 scope 재검증
- 🟡 만 → PASS (경고 포함). gap + owner 결정을 lane에 기록
- 검출 0 → PASS

## DoD 연동
- lane `## Verification Evidence`에 1줄 기록:
  `security-check: {scope} {N}files 🔴0 🟡{n} → PASS`
- 분석전용/문서전용 작업: `not applicable: analysis-only` 면제 유지
- 🔴 발견 시 Escalation Rules (Credential required: STOP - use env var reference) 따름
- BLOCK 상태로 사용자 미응답 시: lane state=BLOCKED + reason 기록

## 원칙
- 검출 0 ≠ 안전 보장. 정규식+체크리스트 범위 내 검증임을 출력 말미에 명시
- 새 패턴 필요 시 이 SKILL.md 표에 행 추가 (단일 소스, 미러는 setup script 재생성)
- 의존성 취약점 DB 조회(CVE)는 범위 외 — 외부 도구(npm audit 등) 별도 안내만
'@

# ── Skills: code-delegate (코딩 서브에이전트 위임) ─────────────────────────────
Step-Begin "skill: code-delegate"
Write-FileContent ".claude\skills\code-delegate\SKILL.md" -NoBom @'
---
name: code-delegate
description: Coding-phase subagent delegation gate. Use when moving from design to coding to spawn a coding subagent on a user-chosen model, passing the written spec/lane by pointer, so the parent (Opus) context stays lean and token cost drops. Subagent returns a concise summary for parent feedback.
---
# Code-Delegate Skill - 코딩 서브에이전트 위임 게이트

## 목적
기획·구조 설계는 상위 에이전트(고추론·대용량 컨텍스트, 예: Opus 4.8)로 진행하고, 코딩은 사용자가 고른 모델의 서브에이전트에 위임한다. 코딩 반복이 서브에이전트의 독립 context에서 일어나 부모 컨텍스트는 린하게 유지되고 토큰 비용도 준다.

## 핵심 원리 (왜 절감되나)
- 서브에이전트는 독립 context window. 부모는 (전달 프롬프트 + 서브의 최종 메시지)만 흡수한다. 파일 read/write와 도구 호출 수십 회는 전부 서브 context에 격리된다.
- 모델 선택: 복잡 코딩은 상위 모델, 단순·반복 코딩은 하위 모델(Sonnet/Haiku)로 토큰·컨텍스트 절약.
- 효과: 부모가 30%선을 유지 → 코딩으로 60%까지 치솟는 것 방지 → checkpoint/handoff 빈도 감소.

## 트리거
/code-delegate [모델]  또는 구현 경계 자동제안
- 자동제안: 설계 완료 후 코딩 전환 경계(SPEC_READY 또는 written 설계 직후)에서 1회 위임 제안(강제 X). 거절 시 인라인 코딩.
- 수동: /code-delegate (모델 미지정 시 선택지 제공).

## 위임 적합성 게이트 (선행 판정)
아래 충족 시에만 위임 권장:
1. written 설계 존재 — 구현 계획이 spec(.claude/pawpad/specs/{feature}.md) 또는 lane에 적혀 있다. 대화에만 있으면 dump 필요 -> 이점 반감(경고).
2. 코딩 단계 — 기획/구조 결정 완료, 실제 파일 변경 단계.
3. 격리 가능 — 부모와 잦은 상호작용이 불필요한 독립 범위.
미충족 시(설계 미작성/탐색 단계/고도 상호작용) 위임 비권장, 인라인 진행 안내.

## 실행 절차 (Claude Code 주력)
1. 위임 적합성 게이트 판정. 부적합이면 사유 + 인라인 권장.
2. 모델 선택 — AskUserQuestion(체크박스), 작업 복잡도 기준 추천 1개 first:
   - 복잡/대규모 -> opus (추천 예시), 일반 코딩 -> sonnet, 단순/반복 -> haiku
   - 추천 1개 표시 + 근거(복잡도). 선택지 규칙은 CLAUDE.md 준수.
3. 서브에이전트 spawn — Agent 도구:
   - model = 선택 모델
   - 프롬프트 = (a) spec/lane/codemap 포인터 read 지시(경로 명시, 본문 dump 아님) + (b) 작업 범위·완료기준 + (c) 반환 형식 지시(4번)
4. 반환 형식 (서브에이전트에 명시) — 부모 린 유지:
   - 변경 파일 경로 목록
   - 핵심 구현 결정 요약
   - 검증 상태(analyze/test/security 결과)
   - 전체 코드 dump 금지. 부모가 필요 시 특정 파일만 요청.
5. 피드백 루프 — 결과 검토 후 수정 필요 시: SendMessage로 같은 서브 이어가기(context 유지) 또는 피드백 포함 신규 dispatch.
6. lane/DoD는 부모 소유 — 서브는 코딩만. lane 갱신·codemap·_meta·완료 판정은 부모가 한다.

## 런타임
- Claude Code (주력): Agent(Task) 도구 model 오버라이드 지원(opus/sonnet/haiku/fable). 위 절차 그대로.
- Codex (폴백): per-call 모델 선택 메커니즘이 달라 자동 모델-핀 미보장. 대안 안내 — 사용자가 원하는 모델로 별도 Codex 세션을 띄우고 spec/lane read 후 코딩. 스킬은 이 안내만 제공.

## 비용/컨텍스트 메모
- 컨텍스트 절감은 과금 방식과 무관하게 확실(서브 격리).
- 토큰 비용: API 과금이면 달러 직접 절감, 구독(Pro/Max)이면 rate-limit 여유로 환산.
- 한계: 부모는 매 반환을 흡수하므로 다회 피드백이면 부모도 누적 증가(단 코딩 본체가 격리되어 여전히 이득). 반환 요약 유지가 핵심.

## 기존 스킬과 관계
- handoff = 작업 인계(owner 이전, 다른 에이전트/세션). code-delegate = 부모 유지 + 코딩만 서브 위임(owner 불변). 별개.
- to-prd/SPEC_READY = 위임 전제(written 설계) 공급원.
- 목적은 checkpoint/handoff 빈도 감소.
'@

# -- Skills: viewer-apply (뷰어 결정 반영 게이트) --
Write-FileContent ".claude\skills\viewer-apply\SKILL.md" -NoBom @'
---
name: viewer-apply
description: 통합 기획 뷰어(spec-viewer)가 제자리 저장한 데이터 JSON(src/viewer/*.json)을 읽어 설계/스팩에 동기하는 게이트. 남은 항목으로 spec 생성/갱신, 삭제 항목 spec 제거. 사용자가 "뷰어 저장함"/"viewer-apply"/"스팩 동기"를 언급할 때 사용.
---

# Viewer-Apply Skill — 뷰어 데이터 → 스팩 동기

## 목적
범용 뷰어(`.claude/skills/mockup/spec-viewer.html`)가 제자리 저장한 데이터 JSON(`src/viewer/{prd,fts,userflow,wire}.json`)을 읽어 설계/스팩에 반영한다. **JSON에 남은 항목 = 설계/개발 대상**(존재=포함), 삭제된 항목 = 제외. 별도 승인/결정 단계 없음 — 저장된 JSON이 곧 SoT.

(뷰어가 File System Access API로 데이터 파일을 직접 제자리 저장하므로 별도 "결정 캡처·다운로드" 단계가 불필요 — 저장된 JSON이 곧 SoT.)

## 성격
Instruction skill. agent가 JSON read 후 spec/lane 동기. 삭제 반영(spec 제거)은 파괴적 → confirm 게이트.

## 트리거
/viewer-apply [feature-id]
- 사용자 "뷰어 저장함" / "스팩 동기" / "viewer 반영" 시.

## 입력 (고정명, on-demand)
`src/viewer/prd.json` · `fts.json`(기능그룹→스팩) · `userflow.json`(메뉴 계층 트리 `{root,tree:[{id,label,feature?,tab?,children?}]}`) · `wire.json`(화면별 `{frame,components:[{type,...}]}`).
**ON START/resume 자동 로드 금지** — 이 스킬 실행 시점에만 read(기획 강화·context 비대화 방지).

## 동기 절차
1. 4 JSON read. `fts.json`의 스팩 노드 = 설계/개발 단위, `prd.json` = 요구 문단, `userflow`/`wire` = 흐름·화면.
2. **신규/유지 항목** → 대응 `specs/{feature-id}.md` 생성(없으면 TEMPLATE 기반)/갱신. PRD-tree·prd/{area}·flow 정합 갱신.
3. **삭제된 항목**(직전 동기엔 있었으나 현 JSON에 없음) → 대응 spec **제거/아카이브**(물리 rm 금지 → done 이동 또는 status=removed), lane 있으면 done 이동. **confirm 게이트**(CLAUDE Escalation: DELETE→STOP).
4. **status(예정/진행중/완료)**는 개발 진행 표시 — agent가 구현하며 해당 JSON 항목 status 갱신(사용자 편집 X). 뷰어 재로드로 가시.
5. 변경 = 코드+문서 원자 단위(Doc Update Rules). lane `## Verification Evidence` 기록(DoD#7).

## 원칙
- **존재=대상, 삭제=제외** (승인 단계 없음).
- 삭제 반영 **비파괴**(done 이동/아카이브) + confirm.
- `src/viewer/*.json` context 자동로드 금지.
- status는 agent가 개발 진행 따라 JSON 갱신 → 뷰어 가시(사용자 불수정).

## 관계
- spec-viewer.html(범용 뷰어, 사용자 편집·제자리 저장) ↔ viewer-apply(저장 JSON → 스팩 동기). 짝.
- mockup viewer 모드(데이터 JSON 생성/갱신) → 사용자 뷰어 편집·저장 → viewer-apply(스팩 동기).
- to-prd(PRD→specs 초기 생성)와 보완: viewer-apply는 뷰어 편집분을 스팩에 반영.
'@

# ── Codex repo skill mirror (.claude/skills -> .agents/skills) ────────────────
Step-Begin "Codex skill mirror"
$sourceSkillRoot = ".claude\skills"
$codexSkillRoot = ".agents\skills"
if (Test-Path $sourceSkillRoot) {
    $skillDirs = @(Get-ChildItem -Path $sourceSkillRoot -Directory -ErrorAction SilentlyContinue)
    foreach ($skillDir in $skillDirs) {
        $sourceSkill = Join-Path $skillDir.FullName "SKILL.md"
        if (-not (Test-Path $sourceSkill)) { continue }
        $rawSkill = Get-Content -Path $sourceSkill -Encoding UTF8 -Raw
        $mirrorHeader = "# DO NOT EDIT: generated from .claude/skills/$($skillDir.Name)/SKILL.md by pawpad-setup.ps1.`n"
        if ($rawSkill -match "(?s)\A---\s*.*?\s*---\s*") {
            $frontmatter = $Matches[0]
            $body = $rawSkill.Substring($frontmatter.Length)
            $mirrorSkill = $frontmatter + $mirrorHeader + $body
        } else {
            $mirrorSkill = $mirrorHeader + $rawSkill
        }
        Write-FileContent (Join-Path (Join-Path $codexSkillRoot $skillDir.Name) "SKILL.md") $mirrorSkill -NoBom
    }
    $mirrorCount = 0
    if (Test-Path $codexSkillRoot) {
        $mirrorCount = @(Get-ChildItem -Path $codexSkillRoot -Directory -ErrorAction SilentlyContinue).Count
    }
    Write-InstallLog "  CODEX SKILLS mirror source=$($skillDirs.Count) mirror=$mirrorCount" Cyan
    if ($mirrorCount -lt $skillDirs.Count) {
        Write-InstallLog "  WARNING mirror 불완전 ($mirrorCount/$($skillDirs.Count)) - .agents/skills 쓰기 실패 여부 위 FAILED 라벨 확인" Yellow -Always
    }
}

# ── PawPad: _wip.md (SPEC_READY 추가) ────────────────────────────────────────────
Step-Begin "PawPad lanes/specs/handoffs"
Write-FileContent ".claude\pawpad\_wip.md" @"
# WIP ROUTER

## Active Lanes
(없음 - 새 작업 시작 시 .claude/pawpad/wip/{feature-id}.md 생성 후 여기 등록)

예시 (WIP 상태):
- feature-a: .claude/pawpad/wip/feature-a.md
  - owner: Claude Code
  - state: WIP
  - updated: 2026-05-29 14:30

예시 (SPEC_READY 상태, 기획 완료 -> 구현 대기):
- feature-b: .claude/pawpad/wip/feature-b.md
  - owner: Claude Code
  - state: SPEC_READY
  - updated: 2026-05-29 15:00

예시 (HANDOFF 상태):
- feature-c: .claude/pawpad/wip/feature-c.md
  - owner: Codex
  - state: HANDOFF_TO_CLAUDE
  - handoff: .claude/pawpad/handoffs/2026-05-29_2230_codex_to_claude_feature-c.md
  - updated: 2026-05-29 22:30

## Locks
(파일 경로/glob -> 에이전트 매핑. 병렬 작업 시 충돌 방지용)

예시:
- src/moduleA/** -> Claude Code
- src/moduleB/** -> Codex

## 사용법
1. 새 작업: .claude/pawpad/wip/{feature-id}.md 생성 + 여기 Active Lanes 등록
2. 작업 중: lane 파일에 상세 상태 기록 (이 router는 state/updated만 갱신)
3. spec 작성 완료: state=SPEC_READY (구현 agent 대기)
4. 핸드오프: /handoff 사용 -> state=HANDOFF_TO_* + handoff 필드 추가
5. 인수: state=WIP, owner=받는 agent (handoff 필드 제거)
6. 완료: lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동
7. 체크포인트: /checkpoint 사용 -> lane 파일 + updated 갱신

## Active Lanes 필드 명세
- {feature-id} : kebab-case 권장
- owner       : Claude Code | Codex (해당 lane을 수정할 권한 가진 에이전트)
- state       : WIP | SPEC_READY | HANDOFF_TO_CODEX | HANDOFF_TO_CLAUDE | HANDOFF_TO_NEXT_AGENT | REVIEW_REQUESTED | REVIEW_DONE | BLOCKED
- handoff     : state=HANDOFF_* 일 때만 필수. snapshot 파일 경로.
- reviewer    : state=REVIEW_REQUESTED 일 때. 리뷰 대상 에이전트 (Codex | Claude Code | 다음 세션).
- review      : 현재 review 문서 경로 (request 또는 result). review skill 참조.
- updated     : 마지막 lane 파일 또는 router 갱신 시각

## State 의미
| state | 의미 | 다음 행동 |
|-------|------|---------|
| WIP | 작업 진행 중 | owner가 계속 작업 |
| SPEC_READY | 기획 완료, 구현 대기 | 구현 agent가 spec read 후 인수 (state=WIP, owner=본인) |
| HANDOFF_TO_CODEX | Codex 인수 요청 | Codex가 snapshot read 후 인수 (state=WIP, owner=Codex) |
| HANDOFF_TO_CLAUDE | Claude 인수 요청 | Claude가 snapshot read 후 인수 (state=WIP, owner=Claude) |
| HANDOFF_TO_NEXT_AGENT | 미정 인수 요청 | 인수 agent가 snapshot read 후 인수 |
| REVIEW_REQUESTED | 리뷰 요청됨 (work owner 불변) | reviewer가 request read → 직접 검증 리뷰 → result 작성 → REVIEW_DONE |
| REVIEW_DONE | 리뷰 완료 | 요청측이 result read → 수정 → 필요시 재요청(REVIEW_REQUESTED) 또는 종결(요청측 재량) |
| BLOCKED | 외부 차단 | owner가 차단 해소 시 state=WIP 복귀 |
"@

# ── PawPad: _meta.md ─────────────────────────────────────────────────────────────
Write-FileContent ".claude\pawpad\_meta.md" @"
# SPRINT: - | PHASE: 0 | STACK: $($p.MetaStack)

## RECENT (newest first)
${today}: 프로젝트 초기 설정 완료. PawPad Agentic Engineering Toolkit v$ver 구조 적용. [setup]

## BLOCKED
- (없음)

## NEXT
- PRD-tree.md 작성
- Phase 1 기능 구현 시작
"@

# ── PawPad: decisions ────────────────────────────────────────────────────────────
Write-FileContent ".claude\pawpad\decisions\rejected.md" @"
# REJECTED APPROACHES
# 유사 작업 전 확인. 같은 실수 반복 방지.
# Format: 제목 -> 시도 -> 결과 -> 해결 -> 날짜 -> agent

(아직 기록 없음)
"@

Write-FileContent ".claude\pawpad\decisions\arch.md" @"
# ARCHITECTURE DECISIONS

$pAdr
"@

# ── PawPad: wip/ lane 디렉토리 (README) ──────────────────────────────────────────
Write-FileContent ".claude\pawpad\wip\README.md" @"
# WIP Lanes

기능별 작업 상태 파일 위치.

## 명명 규칙
.claude/pawpad/wip/{feature-id}.md

예: feature-auth.md, feature-club.md

## 사용
1. 작업 시작: 이 디렉토리에 {feature-id}.md 생성
2. _wip.md Active Lanes에 등록 (owner / state / updated)
3. 작업 중 lane 파일 갱신
4. 완료 시 lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 (audit 보존, timestamp 명명)

## 템플릿
.claude/skills/resume/SKILL.md "lane 파일 포맷" 참조

## 하위 디렉토리
- wip/done/ : 완료된 lane 보관 (audit 추적용, 삭제 금지, timestamp 명명으로 재작업 보존)
"@

# ── PawPad: wip/done/ 완료 lane 보관 디렉토리 ────────────────────────────────────
Write-FileContent ".claude\pawpad\wip\done\README.md" @"
# WIP - Done

완료된 lane 파일 보관소.

## 명명 규칙
.claude/pawpad/wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md

예:
- feature-auth_2026-05-29_143012.md   (첫 완료)
- feature-auth_2026-06-15_092044.md   (재작업 완료, 이전 보존)
- 초 단위(SS) 포함: 같은 분 2회 완료 충돌 방지

## 정책
- 작업 완료 시 wip/{feature-id}.md를 여기로 이동 (timestamp 추가)
- 같은 feature 재작업 시 이전 done 파일 보존 (덮어쓰기 방지)
- 삭제 절대 금지 (history audit)

## 정리 주기
- 분기별 검토 권장
- 오래된 항목 -> .claude/pawpad/sessions/archive-YYYY-Q{N}/로 압축 보관 가능
"@

# ── PawPad: handoffs/ snapshot 디렉토리 + 템플릿 ─────────────────────────────────
Write-FileContent ".claude\pawpad\handoffs\TEMPLATE.md" @"
# HANDOFF_TO_{CODEX|CLAUDE|NEXT_AGENT} - {feature-id}

## Context
- Agent From: {Claude Code | Codex}
- Agent To: {Claude Code | Codex | Next}
- Feature: {feature-id}
- Branch: {git branch}
- Commit: {short hash}
- Timestamp: YYYY-MM-DD HH:MM
- Reason: {token-limit | role-shift | shift-change | other}

## Goal
전체 작업 목표 1-3줄.

## Completed
- 완료된 항목 1
- 완료된 항목 2

## Remaining
- 남은 항목 1 (우선순위 H/M/L)
- 남은 항목 2

## Changed Files
- path/to/file1.dart : 수정중 / 미완성, 이유
- path/to/file2.dart : 완료, 미커밋

## Verification
- analyze: PASS / FAIL ({에러 수})
- test: PASS / FAIL ({실패 테스트})
- Last command run: {명령어}
- Last failure: {에러 메시지 요약}

## Known Issues
- 이슈 1 (해결법 알면 추가)
- 이슈 2

## Next Commands
즉시 실행할 명령 목록 (순서대로):
1. (Commands의 Analyze 명령)
2. (해당 기능 테스트)
3. {추가 작업 명령}

## Owner Transfer (수신 agent 액션)
인수 시 lane 파일에 적용:
- State: HANDOFF_TO_* -> WIP
- Owner: {송신자} -> {수신자 본인}
- _wip.md Active Lanes도 동일 갱신
- _meta.md RECENT에 "ACCEPT {feature} by {수신자}" 1줄 추가

## Notes
- 추가 컨텍스트
- 다음 에이전트가 알아야 할 비명시적 결정
"@

Write-FileContent ".claude\pawpad\handoffs\README.md" @"
# Handoffs

세션 간 / 에이전트 간 상태 전달 snapshot 위치.

## 명명 규칙
.claude/pawpad/handoffs/{YYYY-MM-DD_HHMM}_{from}_to_{to}_{feature}.md

예: 2026-05-29_2230_claude_to_codex_feature-auth.md

## 사용
agent가 /handoff skill (.claude/skills/handoff/SKILL.md) 따라 수동 작성.
템플릿: TEMPLATE.md 참조.

## 발견 방법
다음 에이전트가 ON START 시:
- _wip.md Active Lanes에서 state=HANDOFF_TO_* 발견
- 해당 lane의 handoff 필드 경로로 snapshot read

## 인수 시 owner 변경 필수
- lane 파일과 _wip.md의 owner를 수신 agent로 변경
- 자세한 절차: .claude/skills/handoff/SKILL.md "실행 절차 - 수신 측"

## 보존 정책
- 최근 30일 보존
- 30일 초과 -> .claude/pawpad/sessions/handoffs-archive/ 이동 권장
- 삭제 금지 (audit)
"@

# ── PawPad: specs/ feature spec 디렉토리 + 템플릿 ────────────────────────────────
Write-FileContent ".claude\pawpad\specs\TEMPLATE.md" @"
# Feature Spec - {feature-id}
> status: draft   <!-- draft | ready | implementing | done | removed — 진행률 SoT (unified-spec-viewer D7) -->

## Goal
이 기능이 해결하는 문제. 1-3줄.

## User Flow
사용자 시나리오. 단계별 명시.
1. ...
2. ...
3. ...

## Files To Touch
사전 식별. 수정/생성 예정 파일 목록.
- src/{feature}/{feature}.<ext> : 신규
- src/core/services/{feature}_service.<ext> : 신규
- src/models/{model}.<ext> : 수정

## APIs / Models
- 외부 API: {endpoint, method, payload}
- 내부 모델: {class, fields}

## Acceptance Criteria
완료 판단 기준. 체크박스로 작성.
- [ ] 조건 1
- [ ] 조건 2
- [ ] 조건 3

## Verification
- analyze (zero error)
- test (해당 기능)
- 수동 테스트 시나리오 (있으면)

## Implementation Notes For Next Agent
구현 에이전트가 알아야 할 사항:
- 비표준 패턴
- 우회한 제약
- 후속 작업 예정 항목
"@

Write-FileContent ".claude\pawpad\specs\README.md" @"
# Feature Specs

기획 단계 산출물 위치. Claude Code 또는 사용자가 작성, Codex가 구현 시 읽음.

## 명명 규칙
.claude/pawpad/specs/{feature-id}.md

## 사용 흐름 (기획->구현 분리)
1. 기획 agent (Claude Code 또는 Codex):
   - 이 디렉토리에 {feature-id}.md 작성
   - 필요 시 .claude/pawpad/decisions/arch.md ADR 추가
   - lane 생성 + _wip.md Active Lanes에 state=SPEC_READY 등록
2. 구현 agent:
   - ON START -> _wip.md 확인
   - state=SPEC_READY 발견 시 specs/{feature}.md read
   - 인수 시 state=WIP, owner=본인으로 변경
   - 구현 시작

## 템플릿
TEMPLATE.md 참조.
"@

# ── CodeMap 초기 파일 ────────────────────────────────────────────────────────
Step-Begin "codemap index"
Write-FileContent ".claude\codemap\_index.md" @"
<!-- .claude/codemap/_index.md -->
<!-- Format: domain:symbol    file_path    핵심시그니처: 역할(1줄) -->
<!-- 목적: 파일 안 열고 위치+시그니처+역할 파악 (토큰 절약). 핵심 심볼만 상세. -->
<!-- 성장: flat(~30KB/~80 이하) | trim-router(초과): _root.md+keywords.md+features/{id}.md, cap root2KB·그외4KB (skill 성장전략 참조) -->
<!-- 추가: 누구나 / 수정·삭제: lane owner만 -->

# MAP (data flow / 한눈 조망)
(주요 모듈 흐름. 예: ui --입력--> core --결과--> render)

# HOT (최근 접근 3~5개)
(없음)

# INDEX
pawpad:codebaseMap  .claude/pawpad/codebase/  7축 고수준 코드베이스 맵(ARCH/STRUCT/CONV/TEST/CONCERNS + opt STACK/INTEG); digest .ctxdb/L2/codebase-map-current.md; skill .claude/skills/codebase-map
(구현 시작 후: domain:symbol  file  시그니처: 역할)
"@

# ── HYBRID.md ─────────────────────────────────────────────────────────────────
Step-Begin "HYBRID.md"
Write-FileContent ".claude\HYBRID.md" @"
# Claude Code <-> Codex 하이브리드 협업

## 개요
같은 프로젝트를 Claude Code와 Codex 에이전트가 나누어 작업.
파일 시스템 기반 상태 공유로 핸드오프 지원.
역할은 상호 교체 가능 (대칭).

**중요**: 본 문서의 /handoff, /checkpoint, "ON START"는 agent instruction.
Claude Code는 `.claude/hooks/*`, Codex는 `.codex/hooks.json`이 trust된 경우 일부 절차를 자동 주입한다.
hook 미신뢰/비활성 시 agent가 SKILL.md를 따라 수동으로 파일을 읽고 쓴다.

---

## 역할 분담 (기본값, 교체 가능)

| 에이전트 | 주 역할 | 사용 시기 |
|---------|--------|---------|
| Claude Code | 기획, 설계, 의사결정, 복잡 로직 | 토큰 풍부, 사양 정리 필요 |
| Codex | 구현, 리팩토링, 반복 작업, 테스트 | 코딩 작업, Claude 토큰 부족 시 인수 |

상호 교체 가능. 반대 시나리오(Codex 기획 -> Claude 구현)도 동일 프로토콜.

---

## State Enum (5종 + BLOCKED)

| state | 의미 | 인수 방법 |
|-------|------|----------|
| WIP | 작업 진행 중 | owner만 작업 |
| SPEC_READY | 기획 완료, 구현 대기 | 구현 agent가 spec read, state=WIP, owner=본인 |
| HANDOFF_TO_CODEX | Codex 인수 요청 | Codex가 snapshot read, state=WIP, owner=Codex |
| HANDOFF_TO_CLAUDE | Claude 인수 요청 | Claude가 snapshot read, state=WIP, owner=Claude |
| HANDOFF_TO_NEXT_AGENT | 다음 agent 미정 | 인수 agent가 snapshot read, state=WIP, owner=본인 |
| BLOCKED | 외부 차단 | owner가 차단 해소 시 state=WIP 복귀 |

---

## 작업 흐름

### 흐름 1: Mid-task 핸드오프 (토큰/context 부족)

1. Context 50-60% 도달 추정 -> agent가 /checkpoint 절차 수행
2. lane 파일 (.claude/pawpad/wip/{feature}.md) 갱신
3. codemap/_index.md 갱신 (신규 심볼)
4. agent가 /handoff {to-agent} {feature} {reason} 절차 수행:
   - snapshot 작성: .claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md
   - _wip.md Active Lanes에 state=HANDOFF_TO_* + handoff 필드 추가
5. _meta.md RECENT에 1줄 추가
6. 다음 에이전트 세션 시작 -> ON START에서 _wip.md state/handoff 필드로 snapshot 위치 파악
7. 인수: state=WIP, owner=받는 agent로 변경 (handoff 필드 제거)

### 흐름 2: 병렬 기능 분담

- Feature A: .claude/pawpad/wip/feature-a.md (owner: Claude Code, state: WIP)
- Feature B: .claude/pawpad/wip/feature-b.md (owner: Codex, state: WIP)
- _wip.md Active Lanes에 둘 다 등록
- _wip.md Locks 섹션에 파일 경로 매핑:
  - src/moduleA/** -> Claude Code
  - src/moduleB/** -> Codex
- 각자 lane 파일만 수정. 타 에이전트 lane 읽기만 가능.
- codemap/_index.md:
  - 추가: 누구나
  - 수정/삭제: lane owner만

### 흐름 3: 기획 -> 구현 분리 (SPEC_READY)

1. 기획 agent:
   - .claude/pawpad/specs/{feature}.md 작성
   - 아키텍처 결정 있으면 decisions/arch.md ADR 추가
   - lane 파일 생성: state=SPEC_READY, owner=기획 agent
   - _wip.md Active Lanes에 등록
2. 구현 agent:
   - ON START -> _wip.md 확인
   - state=SPEC_READY 발견 -> specs/{feature}.md read
   - 인수: state=WIP, owner=구현 agent로 변경
   - 구현 시작

### 흐름 4: 60% 정리 후 새 세션 재개

1. agent가 /checkpoint 절차 수행
2. lane 파일 + codemap 갱신
3. (필요 시) /handoff 절차 (같은 에이전트면 self-handoff)
4. 새 세션 시작
5. ON START 절차 -> lane 파일 read -> 끊김 없이 이어 작업

### 흐름 5: Codex native adapter

1. Codex 시작 후 `/hooks`에서 project-local hooks review/trust
2. SessionStart hook:
   - `.ctxdb/.state/codex-turn-count` reset
   - `.ctxdb/.state/codex-loaded` reset
3. UserPromptSubmit hook:
   - 사용자 prompt keyword 추출
   - `.ctxdb/INDEX.md` -> L1<=1 -> L2<=2 로드 (session dedupe: 이미 로드한 ref 재주입 안 함)
   - `.claude/codemap/_index.md` HOT/keyword match 추가 (codemap.inject 토글 따름)
4. PreCompact hook:
   - native compaction 직전 `context-saver` 유도 + 중복 가드(`codex-last-compact`) 기록
5. Stop hook:
   - `.ctxdb/.state/codex-turn-count` 증가
   - 8턴(최근 compaction 저장 시 생략) 또는 L2 size 초과 시 `context-saver` continuation 요구
6. hook 미신뢰/비활성 시 기존 수동 ON START/ON STOP 절차 사용

> Claude Code도 동일 구조: `.claude/hooks/` SessionStart(state reset) + UserPromptSubmit(`ctxdb-inject.ps1` keyword 최소로드) + PreCompact + Stop. 토글은 공통 `.claude/pawpad-config.json`.

---

## 핸드오프 마크 (3종 + SPEC_READY)

| 마크 | 의미 |
|------|------|
| HANDOFF_TO_CODEX | Claude Code -> Codex |
| HANDOFF_TO_CLAUDE | Codex -> Claude Code |
| HANDOFF_TO_NEXT_AGENT | 다음 에이전트 미정 (일반 마크) |
| SPEC_READY | 기획 산출물 준비, 구현 agent 대기 (handoff 아님, snapshot 불필요) |

마커는 _wip.md Active Lanes의 state 필드에 명시.
snapshot 파일 경로는 같은 lane의 handoff 필드에 기록 (HANDOFF_TO_* 에만 해당).

---

## Context Window 토큰 임계값 (60% 기준)

| 상태 | Context % | agent 액션 |
|------|----------|-----------|
| 정상 | 0-50 | 계속 진행 |
| 체크포인트 | 50-60 | /checkpoint 절차 (lane/codemap 갱신) |
| 핸드오프 | 60-70 | /handoff 절차 (snapshot 작성) |
| 전환권장 | 70-85 | 새 세션 즉시 시작 |
| 임계 | 85+ | 즉시 STOP, 핸드오프 |

자세한 추정 휴리스틱: .claude/skills/checkpoint/SKILL.md

---

## 공유 파일 규칙

### 읽기/쓰기 (lane 규칙 따름)
- .claude/pawpad/_wip.md (router. lane 등록/해제/state 변경/owner 변경만)
- .claude/pawpad/wip/{feature}.md (각자 lane만 수정)
- .claude/pawpad/wip/done/{feature-id}_{timestamp}.md (완료 lane, 이동만, 삭제 금지)
- .claude/pawpad/_meta.md (완료/인수 1줄 추가만)
- .claude/pawpad/handoffs/ (snapshot 추가만)
- .claude/pawpad/specs/ (기획 산출물)
- .claude/codemap/_index.md (추가: 누구나 / 수정·삭제: owner만)
- .claude/pawpad/decisions/ (ADR 추가만)
- .codex/config.toml (Codex project config layer notes)
- .codex/hooks.json (Codex hook router)
- .codex/hooks/ (Codex hook scripts)
- .agents/skills/ (Codex repo skills)
- .claude/pawpad-config.json (codemap inject 토글 등 toolkit 런타임 설정)

### 읽기 전용
- CLAUDE.md / AGENTS.md
- .claude/settings.json (Claude Code hook)
- .codex/config.json (Codex 보조 설정)
- pubspec.yaml (변경 시 _wip.md Locks 명시 필수)

---

## 충돌 방지 규칙

1. 한 lane은 한 에이전트만 수정 (owner 명시).
2. _wip.md (router)는 lane 등록/해제/state/owner 변경만.
3. codemap/_index.md:
   - 추가: 누구나
   - 수정/삭제: lane owner만 (_wip.md Locks 확인)
4. pubspec.yaml 변경 시 _wip.md Locks에 명시 + _meta.md RECENT에 알림.
5. 동시 수정 충돌 시 양쪽 라인 보존 후 다음 세션에서 정리.
6. 완료 lane은 wip/done/{feature-id}_{timestamp}.md로 이동 (삭제 금지, 재작업 시 이전 보존).

---

## Verification Evidence

lane "## Verification Evidence" 섹션은 검증 근거(테스트/분석/리뷰 결과)를 기록한다. 무제한 누적 시 lane 파일이 비대해져 매 세션 ON START 로드 비용이 커지므로 경량 유지한다.

규칙:
1. lane 본문에는 최근 2건만 유지.
2. 검증 근거 추가로 2건을 초과하면, 가장 오래된 항목부터 .claude/pawpad/verifications/{feature-id}-archive.md 상단에 append (newest first) 후 lane에서 제거.
3. lane Verification Evidence 섹션 하단에 포인터 1줄 유지:
   "> 이전 검증 N건 -> .claude/pawpad/verifications/{feature-id}-archive.md"
4. 분석전용/소작업은 본문에 "not applicable: analysis-only"만 기록 (아카이브 불필요).

근거: 후속 세션은 lane의 state·next-steps·최근 검증만 참조하고, 과거 검증 근거는 audit 목적(미사용)이다. 핫패스에서 분리해도 정보 손실 없이 on-demand 복원 가능 (_meta.md RECENT 8줄 + sessions/ 이월과 동일 패턴). archive 파일은 추가만, 기존 내용 수정·삭제 금지(audit).

---

## Completed Task Log

lane의 작업추적 섹션(진행/그룹/Backlog/Next Steps 등)에 쌓이는 완료(✅) 작업항목은 상세 구현노트째 누적되어 세션 재개 시 매번 재read 비용을 키운다. Verification Evidence와 동일하게 경량 유지한다.

규칙:
1. 미완/진행 항목(⏳/⚠/🆕/무마커)은 항상 lane에 전수 유지.
2. 완료(✅) 항목은 "다음 세션 재개 포인트" 날짜(직전 checkpoint) 이후 것만 lane 유지, 그 이전 ✅는 .claude/pawpad/verifications/{feature-id}-tasklog.md 상단에 append (newest first) 후 lane에서 제거.
3. lane 완료 영역 말미에 포인터 1줄 유지:
   "> 완료 작업 M건 -> .claude/pawpad/verifications/{feature-id}-tasklog.md"
4. 이월 시점: ON checkpoint(/checkpoint·60% rollover) 및 ON TASK DONE 직전. handoff는 checkpoint 절차에 포함.

근거: 후속 세션은 미완/진행 + 최근 완료 맥락만 필요하고, 과거 완료 항목은 audit(미사용)이다. lane은 archive 2종을 둔다 — {feature-id}-archive.md(검증근거) + {feature-id}-tasklog.md(완료작업). 둘 다 추가만, 수정·삭제 금지(audit).

---

## Owner Transfer (인수 시 필수)

핸드오프 받는 agent는 작업 시작 전 owner 변경 필수:

1. lane 파일 (.claude/pawpad/wip/{feature}.md):
   - State: HANDOFF_TO_* -> WIP
   - Owner: {송신자} -> {수신자 본인}
2. _wip.md Active Lanes 동기화:
   - state: WIP
   - owner: 수신자
   - handoff: 필드 제거 (인수 완료)
   - updated: 현재 시각
3. _meta.md RECENT에 1줄:
   "YYYY-MM-DD: ACCEPT {feature} by {수신자}"

이 절차 누락 시 소유권 불명 -> 다음 에이전트가 잘못된 owner로 작업할 위험.

---

## 호출 방법

### Claude Code -> Codex
1. agent가 /checkpoint 절차 (60% 도달 시)
2. agent가 /handoff codex {feature} {reason} 절차 수행
   - snapshot 작성 + _wip.md state/handoff 갱신
3. 사용자가 Codex 세션 시작
4. Codex ON START -> HYBRID.md + _wip.md + handoffs/{지정} read
5. Codex가 owner 변경 후 작업 재개

### Codex -> Claude Code
1. agent가 /checkpoint 절차
2. agent가 /handoff claude {feature} {reason} 절차
3. 사용자가 Claude Code 세션 시작
4. Claude Code ON START -> 동일 절차
5. Claude Code가 owner 변경 후 작업 재개

### 자기 자신에게 (세션 전환)
1. agent가 /checkpoint 절차 (저장만, snapshot 없음, owner 유지)
2. 새 세션 시작
3. ON START -> lane 파일 read -> 재개 (owner 그대로)

---

## 주의사항

DO NOT
- 두 에이전트가 동시에 같은 lane 파일 수정 금지
- _wip.md 직접 작업 상세 작성 금지 (router는 메타 정보만)
- codemap/_index.md 기존 항목을 비owner가 수정/삭제 금지
- 완료 lane 삭제 금지 (wip/done/으로 이동, timestamp 명명)
- 같은 feature 재작업 시 done 파일 덮어쓰기 금지 (timestamp로 구분)
- 인수 시 owner 변경 누락 금지
- pubspec.yaml 의존성 충돌 (변경 시 알림)

DO
- 작업 전 ON START 절차 실행
- 작업 후 lane 파일 + codemap + _meta.md 갱신
- 60% 도달 추정 시 /checkpoint -> /handoff
- 핸드오프 시 Next Commands 명확히 작성
- 인수 시 owner를 본인으로 변경 (필수)
- 완료 lane은 wip/done/{feature-id}_{timestamp}.md로 이동

---

## Backup (안전장치)

setup script -Force 실행 시 사용자 작성 데이터 자동 백업:
- 백업 위치: .claude/pawpad/backup/{YYYY-MM-DD_HHmm}/
- 백업 대상:
- **PawPad**: _wip.md, _meta.md, decisions/, wip/ (done 포함), handoffs/, specs/, codemap/_index.md
- **Context files**: CLAUDE.md, AGENTS.md, .claude/HYBRID.md, .claude/settings.json, .codex/config.json, .gitignore, CONTEXT.md, .claude/SKILLS_MANIFEST.md
- **Codex adapter**: .codex/config.toml, .codex/hooks.json, .codex/hooks/, .agents/skills/
  - **Claude hooks/config**: .claude/hooks/, .claude/pawpad-config.json
- .gitignore에 .claude/pawpad/backup/ 자동 등록 (민감 정보 보호)
- 복구 필요 시 백업 디렉토리에서 수동 복원
"@

# ── docs/HOOK_TESTING.md (hook 회귀 방지 체크리스트) ─────────────────────────
Step-Begin "docs/HOOK_TESTING.md"
Write-FileContent "docs\HOOK_TESTING.md" @'
# Hook Testing Checklist

PawPad (Agentic Engineering Toolkit) hook 회귀 방지 체크리스트. v2.19 CP949 콘솔 UTF-8 stdin 버그(한글 username transcript_path -> JSON 파싱 실패 -> ctx 0% 영구표시) 재발 방지가 1차 동기.

대상: `.claude/hooks/*.ps1`, `.codex/hooks/*.ps1` (+ `.sh` wrapper). 양 에이전트 런타임 공통.

## 공통 (입력/안전성)
- stdin: JSON 1개 수신 (UTF-8). 인코딩: `[Console]::OpenStandardInput()` + UTF8 디코딩 (콘솔 코드페이지 비의존).
- 실패/예외: 해당 event 계약에 맞는 safe fallback + exit 0 (agent 실행 차단 금지).
- **주의: 출력은 일률적으로 JSON/`{}`가 아니다.** event/runtime별 계약이 다름 — 아래 표 기준으로 검증.

## 출력 계약 (event/runtime별)
| runtime | event | 정상 출력 | no-op / fallback |
|---------|-------|----------|------------------|
| Claude  | statusLine       | plain text (`ctx N% (...) \| model`)                         | (해당 없음)                       |
| Claude  | SessionStart     | plain text additional context (codemap/INDEX 라우터)         | 빈 출력 가능                      |
| Claude  | UserPromptSubmit | `{hookSpecificOutput:{hookEventName,additionalContext}}` JSON | `{}` (no-match/error)             |
| Claude  | PreCompact       | plain text reminder (`=== PawPad PreCompact ===...`)            | (항상 출력)                       |
| Claude  | Stop             | block 시 `{"decision":"block","reason":...}` JSON           | **무출력 + exit 0** (no-op, `{}` 아님) |
| Codex   | lifecycle (UserPromptSubmit/Stop) | `.codex/hooks.json` 계약대로 유효 JSON object. ctxdb-inject·pre-compact는 top-level `suppressOutput:true` + `systemMessage` 1줄 포함 (TUI 노이즈 저감 선반영; Codex측 suppressOutput 미구현, openai/codex#16933) | `{}`                              |
| Claude  | `.sh` wrapper    | 위 Claude event 계약과 동일                                  | pwsh/jq 부재 시: ctxdb-inject=`hookSpecificOutput` skip, statusLine=plain `ctx n/a`, SessionStart=plain\|빈 출력, PreCompact=빈 줄, Stop=무출력 (**`{}` 아님**) |
| Codex   | `.sh` wrapper    | 위 Codex lifecycle JSON 계약과 동일                          | pwsh 부재 시: ctxdb-inject=`hookSpecificOutput` skip, SessionStart·PreCompact·Stop=`{}` |

## 체크리스트 (변경 시 수동 점검; 추후 scripts/ runner)

| # | 케이스 | 기대 결과 | 관련 버그/규칙 |
|---|--------|----------|----------------|
| 1 | `.ps1` hook scriptblock syntax parse | 파싱 통과 | 전 hook |
| 2 | `.sh` wrapper, `pwsh`/`jq` 부재 환경 | runtime별 safe fallback + exit 0 (비차단). **Claude**: ctxdb-inject=`hookSpecificOutput` skip / statusLine=plain `ctx n/a` / SessionStart=plain\|빈출력 / PreCompact=빈 줄 / Stop=무출력. **Codex**: ctxdb-inject=`hookSpecificOutput` skip / SessionStart·PreCompact·Stop=`{}`. (일률 `{}` 아님) | Unix wrapper |
| 3 | UTF-8 stdin, 한글 prompt/path(예: `김민수`) | 깨짐 없이 파싱, ctx% 정상 | **v2.19 UTF-8 버그** |
| 4 | malformed JSON stdin | event/runtime별 safe fallback + exit 0 (예외 누출 금지) — 위 "출력 계약" 표 따름. **Claude**: ctxdb-inject=`{}`\|`hookSpecificOutput` / statusLine=무출력(return) / PreCompact·SessionStart=plain / Stop=계약대로. **Codex**: SessionStart·PreCompact·Stop=`{}` | safe fallback |
| 5 | no-match prompt (ctxdb-inject) | `{}` (전체 ctxdb 로드 금지) | keyword 최소로드 |
| 6 | 같은 session 같은 keyword 2회 | 2회차 `{}` (dedupe) | session dedupe |
| 7 | Stop hook 8턴 도달 | `decision:block` checkpoint 발화 | 정기저장 |
| 8 | Stop hook 1~7턴 (Claude) | 무출력 + exit 0 (no-op, `{}` 아님) | turn-count |
| 9 | PreCompact 직후 Stop(최근 8턴 내) | checkpoint 중복 생략 | 중복 가드(last-compact) |
| 10 | L2 파일 150줄/2000토큰 초과 | split 경고 (동일 sig 재경고 throttle) | L2 분할 규칙 |
| 11 | Claude(`turn-count`) vs Codex(`codex-turn-count`) state 분리 | 상호 간섭 없음 | state 키 분리 |
| 12 | 출력 계약 (event별) | 위 "출력 계약" 표대로 event/runtime별 유효 (일률 JSON 금지: statusLine/PreCompact=plain text, Stop no-op=무출력) | 런타임 호환 |
| 13 | Codex `commandWindows`에 큰따옴표 포함 금지 | `-EncodedCommand`(base64)만 사용. Codex는 hook을 `cmd.exe /C "<command>"`(Rust std가 내부 `"`→`\"`)로 실행 → 중첩 큰따옴표는 cmd 레이어에서 깨져 ps1 미실행/exit 1. 검증: Rust 동일 spawn(`cmd /C` + `\"` 이스케이프)으로 root/하위/외부 cwd 실행 → 계약 출력 + exit 0 | **v2.20 hook exited with code 1 버그** (2026-06-10) |
| 14 | Codex ctxdb-inject/pre-compact 정상 출력 | top-level `suppressOutput:true` + `systemMessage` 1줄 포함 (additionalContext 병행). no-op `{}`에는 미포함 | Codex TUI 노이즈 저감 선반영 (openai/codex#16933) |
| 15 | Codex ctxdb-inject injectMode (pawpad-config `ctxdb.injectMode`) | pointer(기본/키 부재/오타값): additionalContext에 본문 대신 `read: .ctxdb/...` 지시 수 줄만, status=`pointer` / full: 기존 본문 주입. 양 모드 dedupe 동일 | Codex TUI 노이즈 (pointer 모드) |
| 16 | explicit fallback needle (양 런타임 ctxdb-inject) | 재개 의도어(ctxdb/context-saver/resume/handoff/이어서/재개/세션저장 등)만 발화. 프로젝트·에이전트명(pawpad/claude/codex) 포함 일반 프롬프트는 `{}` | 과발화 -> stale L2 오주입 버그 (2026-06-11) |

## 실행 패턴 (참고)
PowerShell hook을 stdin 주입으로 단독 검증:
```powershell
'{"session_id":"t1","prompt":"테스트","transcript_path":"C:\\Users\\김민수\\x.jsonl"}' |
  & pwsh -NoProfile -File .\.claude\hooks\ctxdb-inject.ps1
```
- 한글 경로/프롬프트 포함해 #3 재현.
- 출력이 해당 event 계약(위 표)대로인지 확인 — ctxdb-inject(UserPromptSubmit)는 `hookSpecificOutput` JSON 또는 `{}`. 예외 누출 없는지 확인.
- stdin 닫힘(파이프 종료)까지 hang 없는지 확인.

## 크로스플랫폼 리스크
- Windows path separator(`\`) vs Unix(`/`).
- CP949/UTF-8 콘솔 코드페이지 — stdin은 항상 UTF8 디코딩.
- timeout/hang — stdin 미종료 시 무한대기 방지.
- background/detached 프로세스 — 부모 exit 비대기.
- temp 디렉토리 경로 차이.

## 위치/갱신
- 이 문서는 doc-only. 실제 자동 테스트 runner는 repo가 git/test 가능해지면 `scripts/`에 추가.
- hook 변경(신규 케이스/버그fix) 시 해당 행 추가. 양 에이전트 공통.
'@

# -- .claude/SKILLS_MANIFEST.md (스킬 카탈로그) --
Write-FileContent ".claude\SKILLS_MANIFEST.md" @'
# Skills Manifest

프로젝트에 설치된 모든 스킬 목록. (19개)

> **환경별 활성 방식**
> - Claude Code: `/skill` slash 호출 + description 자동 트리거 둘 다 지원.
> - Codex CLI: **slash 호출 미보장**. `.agents/skills/*/SKILL.md`의 `description` 기반 **자동 트리거 중심**. 명시 호출 필요 시 "use {skill} skill"처럼 자연어로 지시.
> - caveman/lean-code는 skill이 아니라 **CLAUDE.md/AGENTS.md가 매 응답 강제**한다(아래 참조 강등 참고).
> - feature-architecture도 참조 스킬 — 실제 강제는 CLAUDE.md/AGENTS.md `Architecture Principles (Feature-First)`(신규/변경 코드만).
> - statusline은 **Claude Code 전용**(`.claude/settings.json` statusLine). Codex CLI는 statusline 메커니즘이 없어 미적용.

---

## Skill 목록

### 📍 Core Skills (상태/코드 기반)

| 스킬 | 위치 | 용도 |
|------|------|------|
| **resume** | `.claude/skills/resume/` | WIP 상태 관리, 세션 재개(ON START) 프로토콜 |
| **codemap** | `.claude/skills/codemap/` | 심볼 위치 레지스트리, owner 분리 권한 |
| **codebase-map** | `.claude/skills/codebase-map/` | 7축 고수준 코드베이스 맵(아키텍처/구조/관례/관심사), digest-only 주입 |
| **caveman** | `.claude/skills/caveman/` | 압축 통신 모드 (참조). 실제 강제는 CLAUDE.md/AGENTS.md `Response Style` |
| **lean-code** | `.claude/skills/lean-code/` | LLM 코딩 안티패턴 (참조, 구 karpathy). 실제 강제는 CLAUDE.md/AGENTS.md `Coding Principles` |
| **feature-architecture** | `.claude/skills/feature-architecture/` | feature-first 구조 규율 (참조). 실제 강제는 CLAUDE.md/AGENTS.md `Architecture Principles` |
| **clarity** | `.claude/skills/clarity/` | 요청 모호도 분석 (5차원 스코어링) + PASS 후 접근법 게이트 (2-3 대안 + 추천 1개) |
| **design** | `.claude/skills/design/` | UI/UX 설계 게이트 (토큰+레이아웃+원칙, 반응형) |
| **ctxdb-navigator** | `.claude/skills/ctxdb-navigator/` | 키워드 depth 컨텍스트 최소 로드 (토큰 절약) |
| **security-check** | `.claude/skills/security-check/` | 보안 검증 게이트 (secrets/취약점/설정/PawPad 산출물, 🔴 시 BLOCK) |
| **context-saver** | `.claude/skills/context-saver/` | 세션 작업 .ctxdb/L2 저장 + AGENT SYNC 갱신 |

### 🔀 Workflow Skills (협업/기획)

| 스킬 | 위치 | 용도 |
|------|------|------|
| **handoff** | `.claude/skills/handoff/` | 세션/에이전트 인수인계 (PawPad snapshot + owner transfer) |
| **checkpoint** | `.claude/skills/checkpoint/` | 컨텍스트 60% 롤오버 게이트 (상태 보존) |
| **grill-me** | `.claude/skills/grill-me/` | 계획/설계 스트레스 테스트 (재귀적 질문 + 용어 canonical 좁힘 + 코드 모순 표면화) |
| **to-prd** | `.claude/skills/to-prd/` | 대화 → PRD (`.claude/pawpad/specs/` 저장 + SPEC_READY) |
| **mockup** | `.claude/skills/mockup/` | PRD-tree→단일 HTML 목업 시각화 (lo/hi-fi, Feature ID 태깅 + drift 경고) |
| **review** | `.claude/skills/review/` | 문서형 크로스에이전트/세션 리뷰 라운드트립 (codex exec 보완·저토큰, request 직접검증 체크리스트) |
| **code-delegate** | `.claude/skills/code-delegate/` | 코딩 단계 서브에이전트 위임 (사용자 선택 모델, spec/lane 포인터 전달, 요약 반환 — 부모 컨텍스트·토큰 절감) |
| **viewer-apply** | `.claude/skills/viewer-apply/` | 뷰어 데이터 JSON(src/viewer/*.json)을 읽어 스팩 동기 (남은 항목 spec 생성/갱신, 삭제 항목 제거/아카이브, confirm·비파괴, mockup viewer 모드와 짝) |

---

## 스킬 호출 패턴

### 기본 호출
```
/resume          # 세션 재개 프로토콜
/codemap         # 심볼 탐색
/caveman         # 압축 모드
/clarity         # 모호도 분석
/lean-code       # 원칙 확인
/design          # UI/UX 설계 게이트 (화면 구현 직전)
/security-check  # 보안 검증 게이트 (커밋/핸드오프/완료 직전)
```

### 협업/기획
```
/grill-me        # 설계 스트레스 테스트 (용어 좁힘·코드 모순 표면화 포함)
/to-prd          # 대화 → PRD + SPEC_READY 등록
/checkpoint      # 60% 컨텍스트 정리
/handoff         # 다음 에이전트 인수인계
```

---

## 스킬 체이닝 예시

### 예시 1: 기획 → 구현 (PawPad 흐름3)
```
1. /clarity 30          ← 기획 모호도 확인
2. /grill-me            ← 설계 스트레스 테스트
3. /to-prd              ← PRD를 PawPad specs/ 저장 + lane SPEC_READY 등록
4. (구현 agent) ON START ← SPEC_READY 발견 → spec+lane read → 인수 (state=WIP)
```
주의: SPEC_READY는 snapshot 불필요 → `/handoff` 아님. `/handoff`는 작업 중간에 snapshot이 필요한 인계(토큰 부족 등)에만 사용.

### 예시 2: 코드 작업
```
1. /lean-code           ← 원칙 검증 (요청된 것만)
2. /codemap             ← 영향 파일 위치 확인
3. /caveman             ← 압축 피드백
```

### 예시 3: 토큰 부족 핸드오프
```
1. /checkpoint          ← 60% 도달, lane/codemap 정리
2. /resume              ← _wip.md 상태 갱신
3. /handoff claude      ← 다른 에이전트로 인수 (state=HANDOFF_TO_*)
```

---

상세: 각 `.claude/skills/{skill}/SKILL.md` | 메타: `.codex/config.json` (skills 배열)
'@

# ── .codex/config.json (보조 설정, 동적 projectName) ──────────────────────────
Step-Begin "Codex config.json"
$tmplCodexConfigJson = @"
{
  "_comment": "보조 설정. Codex 자동 로드 보장 없음. 핵심 규칙은 AGENTS.md / .claude/HYBRID.md 참조.",
  "_projectRootNote": "이 파일은 .codex/ 디렉토리에 위치. 모든 경로는 프로젝트 루트 기준 상대 경로.",
  "projectName": "${projectName}",
  "stackInfo": {
$($p.StackInfo)
  },
  "contextFiles": {
    "agentGuide": "AGENTS.md",
    "claudeGuide": "CLAUDE.md",
    "hybridWorkflow": ".claude/HYBRID.md",
    "wipRouter": ".claude/pawpad/_wip.md",
    "wipLanes": ".claude/pawpad/wip/",
    "wipDone": ".claude/pawpad/wip/done/",
    "handoffs": ".claude/pawpad/handoffs/",
    "specs": ".claude/pawpad/specs/",
    "completionLog": ".claude/pawpad/_meta.md",
    "symbolRegistry": ".claude/codemap/_index.md",
    "architectureDecisions": ".claude/pawpad/decisions/arch.md",
    "rejectedApproaches": ".claude/pawpad/decisions/rejected.md",
    "glossary": "CONTEXT.md",
    "skillsManifest": ".claude/SKILLS_MANIFEST.md",
    "codexRuntimeConfig": ".codex/config.toml",
    "codexHooks": ".codex/hooks.json",
    "codexHookScripts": ".codex/hooks/",
    "codexRepoSkills": ".agents/skills/",
    "ctxdbIndex": ".ctxdb/INDEX.md",
    "pawpadConfig": ".claude/pawpad-config.json",
    "sessionStartHook": ".claude/hooks/session-start.ps1",
    "ctxdbInjectHook": ".claude/hooks/ctxdb-inject.ps1",
    "preCompactHook": ".claude/hooks/pre-compact.ps1",
    "stopHook": ".claude/hooks/stop-check.ps1"
  },
  "stateEnum": [
    "WIP",
    "SPEC_READY",
    "HANDOFF_TO_CODEX",
    "HANDOFF_TO_CLAUDE",
    "HANDOFF_TO_NEXT_AGENT",
    "REVIEW_REQUESTED",
    "REVIEW_DONE",
    "BLOCKED"
  ],
  "tokenManagement": {
    "normalUpTo": 50,
    "checkpointAt": 50,
    "handoffAt": 60,
    "transitionRecommendedAt": 70,
    "criticalAt": 85,
    "handoffMarkers": [
      "HANDOFF_TO_CODEX",
      "HANDOFF_TO_CLAUDE",
      "HANDOFF_TO_NEXT_AGENT"
    ],
    "markerLocation": ".claude/pawpad/_wip.md#ActiveLanes.state"
  },
  "verification": {
    "beforeHandoff": $($p.VerifyCmds),
    "afterWork": $($p.VerifyCmds),
    "failureAction": "stop"
  },
  "laneRules": {
    "wipFilePattern": ".claude/pawpad/wip/{feature-id}.md",
    "ownerExclusive": true,
    "fileLockMap": ".claude/pawpad/_wip.md#Locks",
    "codemapAppendAnyone": true,
    "codemapModifyOwnerOnly": true,
    "completedLaneDestination": ".claude/pawpad/wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md",
    "neverDelete": true,
    "ownerTransferOnHandoff": true
  },
  "skills": [
    "resume",
    "codemap",
    "codebase-map",
    "caveman",
    "lean-code",
    "feature-architecture",
    "clarity",
    "handoff",
    "checkpoint",
    "grill-me",
    "to-prd",
    "design",
    "mockup",
    "review",
    "code-delegate",
    "viewer-apply",
    "ctxdb-navigator",
    "context-saver",
    "security-check"
  ],
  "backup": {
    "trigger": "setup-script -Force",
    "location": ".claude/pawpad/backup/{YYYY-MM-DD_HHmm}/",
    "preservedItems": {
      "pawpad": ["_wip.md", "_meta.md", "decisions/", "wip/", "handoffs/", "specs/", "codemap/_index.md"],
      "contextFiles": ["CLAUDE.md", "AGENTS.md", ".claude/HYBRID.md", ".claude/settings.json", ".claude/pawpad-config.json", ".codex/config.json", ".gitignore", "CONTEXT.md", ".claude/SKILLS_MANIFEST.md"],
      "codexAdapter": [".codex/config.toml", ".codex/hooks.json", ".codex/hooks/", ".agents/skills/"],
      "claudeHooks": [".claude/hooks/", ".claude/pawpad-config.json"],
      "ctxdb": [".ctxdb"],
      "hooks": [".claude/hooks"]
    },
    "gitignored": true
  }
}
"@
Write-FileContent ".codex\config.json" $tmplCodexConfigJson -NoBom

# ── -Upgrade: 혼합 파일 병합 (툴킷 영역만 갱신, 사용자 영역 보존) ────────────────
if ($Upgrade -and $mergePending.Count -gt 0) {
    $mergePassFailBase = $script:failed
    Write-InstallLog "" Gray
    Write-InstallLog "Merging mixed files (toolkit sections/keys only)..." White
    $claudeToolkitSections = @(
        'Definition of Done', 'Escalation Rules', 'Coding Principles (Lean Code)',
        'Architecture Principles (Feature-First)',
        'Doc Update Rules', 'Session Protocol', 'Hybrid Lane Rule', 'Idea → PRD Routing', 'Response Style'
    )
    $agentsToolkitSections = $claudeToolkitSections + @(
        'Codex 주의 (native hook adapter)', 'Handoff Protocol',
        'Checkpoint (매 응답 종료 전 확인 - hooks 대체)'
    )
    # 구버전 섹션명 마이그레이션: '## Coding Principles (Karpathy)' -> '(Lean Code)' (v2.25 rename).
    # 치환 없이 병합하면 구 섹션 잔존 + 새 섹션 중복 추가되므로 병합 매칭 전 헤더만 치환.
    foreach ($mdFile in @('CLAUDE.md', 'AGENTS.md')) {
        if ($mergePending -notcontains $mdFile) { continue }
        $mdAbs = Join-Path (Get-Location) $mdFile
        $mdText = [System.IO.File]::ReadAllText($mdAbs)
        $mdNew = $mdText.Replace('## Coding Principles (Karpathy)', '## Coding Principles (Lean Code)')
        if ($mdNew -ne $mdText) {
            try { Set-Content -Path $mdFile -Value $mdNew -Encoding UTF8 -ErrorAction Stop }
            catch { Write-InstallLog "  MERGE-FAIL $mdFile (legacy 섹션명 치환 실패: $($_.Exception.Message))" Red -Always; $script:failed++ }
        }
    }
    if ($mergePending -contains 'CLAUDE.md') {
        Merge-MdToolkitSections "CLAUDE.md" $tmplClaudeMd $claudeToolkitSections
    }
    if ($mergePending -contains 'AGENTS.md') {
        Merge-MdToolkitSections "AGENTS.md" $tmplAgentsMd $agentsToolkitSections
    }
    if ($mergePending -contains '.claude\settings.json') {
        Merge-JsonToolkitKeys ".claude\settings.json" $tmplSettingsJson @('hooks', 'statusLine')
    }
    if ($mergePending -contains '.codex\config.json') {
        Merge-JsonToolkitKeys ".codex\config.json" $tmplCodexConfigJson @('_comment', '_projectRootNote', 'contextFiles', 'stateEnum', 'tokenManagement', 'laneRules', 'skills', 'backup')
    }
    # merge-q 단계 확정용: 병합 pass 중 실패 발생 여부 (체크리스트 ✓/✗ 판정)
    $script:mergePassHadFailure = ($script:failed -gt $mergePassFailBase)
}

# ── .gitignore 자동 갱신 ──────────────────────────────────────────────────────
Step-Begin ".gitignore"
Update-Gitignore

# ── Bundle prune (선택 번들 외 제거 + 정합, v2.39) ───────────────────────────────
# 전체 설치 후 미선택 번들 정리(가산적). docs/config/manifest dangling 0 유지.
if ($script:bundleMode -eq 'custom') {
    $bpCore = @('resume', 'ctxdb-navigator', 'checkpoint', 'context-saver', 'handoff', 'codemap', 'codebase-map', 'caveman', 'lean-code', 'feature-architecture', 'security-check')
    $bpMap = [ordered]@{ prd = @('clarity', 'grill-me', 'to-prd'); ui = @('design', 'mockup', 'viewer-apply'); delegate = @('code-delegate'); review = @('review') }
    $bpAll = @($bpCore); foreach ($k in $bpMap.Keys) { $bpAll += $bpMap[$k] }
    $bpDeps = @{ ui = @('prd'); delegate = @('prd') }
    $sel = @($script:bundleSelected)
    $chg = $true; while ($chg) { $chg = $false; foreach ($b in @($sel)) { if ($bpDeps.ContainsKey($b)) { foreach ($d in $bpDeps[$b]) { if ($sel -notcontains $d) { $sel += $d; $chg = $true } } } } }
    $bpKeep = @($bpCore); foreach ($b in $sel) { $bpKeep += $bpMap[$b] }; $bpKeep = $bpKeep | Select-Object -Unique
    $bpRemove = @($bpAll | Where-Object { $bpKeep -notcontains $_ })

    $root2 = (Get-Location).Path
    $utf8nb = New-Object System.Text.UTF8Encoding $false
    # 1) 미선택 스킬 디렉토리 제거 (.claude/skills + .agents/skills)
    foreach ($s in $bpRemove) { foreach ($base in @('.claude\skills', '.agents\skills')) { $d = Join-Path $root2 (Join-Path $base $s); if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue } } }
    # 2) config.json skills 배열 동기
    $cfgP = Join-Path $root2 '.codex\config.json'
    if (Test-Path $cfgP) {
        $cfg = [System.IO.File]::ReadAllText($cfgP, $utf8nb)
        $mm = [regex]::Match($cfg, '"skills":\s*\[(.*?)\]', 'Singleline')
        if ($mm.Success) {
            $on = @([regex]::Matches($mm.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
            $ko = @($on | Where-Object { $bpKeep -contains $_ })
            $at = ($ko | ForEach-Object { '    "' + $_ + '"' }) -join ",`r`n"
            $cfg = $cfg.Substring(0, $mm.Index) + "`"skills`": [`r`n$at`r`n  ]" + $cfg.Substring($mm.Index + $mm.Length)
            [System.IO.File]::WriteAllText($cfgP, $cfg, $utf8nb)
        }
    }
    # 3) SKILLS_MANIFEST.md 카운트 + 행 + 호출/체이닝 줄 동기
    $manP = Join-Path $root2 '.claude\SKILLS_MANIFEST.md'
    if (Test-Path $manP) {
        $man = [System.IO.File]::ReadAllText($manP, $utf8nb)
        $gae = [char]0xAC1C
        $man = [regex]::Replace($man, '\(\d+' + $gae + '\)', '(' + $bpKeep.Count + $gae + ')')
        foreach ($s in $bpRemove) {
            $man = [regex]::Replace($man, '(?m)^\|\s*\*\*' + [regex]::Escape($s) + '\*\*\s*\|.*\r?\n', '')
            $man = [regex]::Replace($man, '(?m)^.*/' + [regex]::Escape($s) + '(\b|\s).*\r?\n', '')
        }
        [System.IO.File]::WriteAllText($manP, $man, $utf8nb)
    }
    # 4) docs 트림 (CLAUDE.md / AGENTS.md / HYBRID.md)
    $mdc = [char]0xB7
    foreach ($doc in @('CLAUDE.md', 'AGENTS.md', '.claude\HYBRID.md')) {
        $p = Join-Path $root2 $doc
        if (-not (Test-Path $p)) { continue }
        $t = [System.IO.File]::ReadAllText($p, $utf8nb)
        if ($sel -notcontains 'prd') { $t = [regex]::Replace($t, '(?sm)^## Idea.*?(?=^## |\z)', '') }
        if ($bpRemove -contains 'mockup') { $t = [regex]::Replace($t, '(?m)^.*/mockup viewer.*\r?\n', '') }
        if ($bpRemove -contains 'review') { $t = [regex]::Replace($t, '(?m)^.*review skill.*\r?\n', '') }
        if ($bpRemove -contains 'design') { $t = [regex]::Replace($t, '(?m)^.*design\(.*\r?\n', '') }
        foreach ($s in $bpRemove) { $t = $t -replace ($mdc + [regex]::Escape($s)), ''; $t = $t -replace ([regex]::Escape($s) + $mdc), '' }
        $rmc = $bpRemove
        $t = [regex]::Replace($t, '\{[^}]*\}', { param($m) $parts = ($m.Value.Substring(1, $m.Value.Length - 2)) -split ','; $kept = @($parts | Where-Object { $rmc -notcontains $_.Trim() }); '{' + ($kept -join ',') + '}' })
        foreach ($s in $bpRemove) { $t = [regex]::Replace($t, '`' + [regex]::Escape($s) + '[^`]*`,?\s?', '') }
        [System.IO.File]::WriteAllText($p, $t, $utf8nb)
    }
    # 5) 가드 1줄 (설치 스킬만 추천)
    foreach ($gp in @('CLAUDE.md', 'AGENTS.md')) {
        $p = Join-Path $root2 $gp
        if (Test-Path $p) {
            $t = [System.IO.File]::ReadAllText($p, $utf8nb)
            if ($t -notmatch 'pawpad-bundles guard') {
                $t = $t.TrimEnd() + "`r`n`r`n> NOTE (pawpad-bundles guard): Only recommend or invoke skills installed under .claude/skills/. Do not suggest skills absent from this install.`r`n"
                [System.IO.File]::WriteAllText($p, $t, $utf8nb)
            }
        }
    }
    Write-Host ""
    $selTxt = if ($sel.Count -gt 0) { $L.corePlus + (($sel | Sort-Object) -join ', ') } else { $L.coreOnly }
    Write-Host ($L.bundleLine -f $selTxt, $bpKeep.Count, $bpRemove.Count, ($bpRemove -join ', ')) -ForegroundColor Cyan
}

# ── 완료 요약 ────────────────────────────────────────────────────────────────
Show-InstallChecklist
Write-Host ""
Write-Host "========================================================="
Write-Host "Setup Complete: $created created | $updated updated | $merged merged | $skipped skipped | $failed failed" -ForegroundColor Cyan
Write-Host ""

if ($failed -eq 0) {
    Write-Host ($L.complete -f $ver) -ForegroundColor Green
    Write-Host ""
    if ($Lang -eq 'ko') {
        Write-Host "v$ver 누적 (19 스킬 + hook + .ctxdb + codemap + codebase-map + security-check):" -ForegroundColor Cyan
        Write-Host "  - Stack 프리셋: $Stack (flutter|node|python|generic 중 -Stack로 선택)" -ForegroundColor Cyan
        Write-Host "  - 크로스플랫폼 hook: Windows=.ps1 / Unix=.sh (설치 OS 자동 선택)" -ForegroundColor Cyan
        Write-Host "  - statusLine: Claude Code 매 턴 컨텍스트 윈도우 사용량(%) 표시" -ForegroundColor Cyan
        Write-Host "  - Codex native adapter: .agents/skills mirror + .codex/hooks.json (/hooks trust 필요)" -ForegroundColor Cyan
        Write-Host "  - codemap: 위치+시그니처+역할 1줄 + MAP 조망 (파일 안 열고 파악)" -ForegroundColor Cyan
        Write-Host "  - .ctxdb 키워드 depth DB + context-saver 키워드 자동 갱신" -ForegroundColor Cyan
        Write-Host "  - codebase-map: 7축 고수준 맵(.claude/pawpad/codebase/) + digest-only 주입" -ForegroundColor Cyan
        Write-Host "  - security-check: 보안 검증 게이트(secrets/취약점/설정/PawPad, 🔴=BLOCK, DoD#8)" -ForegroundColor Cyan
        Write-Host "  - -Upgrade: 기존 설치 업그레이드(툴킷 파일만 갱신, 사용자 데이터 보존, 혼합 병합)" -ForegroundColor Cyan
        Write-Host "  - 구조 경로: .claude/pawpad/ (구 KMS — v2.21 이하 설치본은 -Upgrade 시 자동 마이그레이션)" -ForegroundColor Cyan
        Write-Host "  - 설치 UI: paw 배너 + 진행 바 live 1줄 갱신 + 실측 체크리스트 (-ShowLog로 파일 상세 로그)" -ForegroundColor Cyan
        Write-Host "  - lean-code: 과설계/범위이탈 방지 원칙 스킬 (구 karpathy, v2.25 rename + 병합 마이그레이션)" -ForegroundColor Cyan
        Write-Host "  - feature-architecture: feature-first 구조 규율 스킬 (CLAUDE/AGENTS Architecture Principles 강제)" -ForegroundColor Cyan
        Write-Host "  - 번들 선택: -Preset lean|standard|full 또는 -Bundles prd,ui,delegate,review (미지정 시 대화형, Enter=full)" -ForegroundColor Cyan
        Write-Host "  - 안내 언어: -Lang en|ko (사람 안내 메시지만, 스킬/문서는 단일 소스 무변경)" -ForegroundColor Cyan
        Write-Host "  - codemap trim-router: 대규모 codemap을 _root+keywords+features leaf로 분할(cap 2/4KB, 통째읽기 사고 봉쇄, grep 성능 불변)" -ForegroundColor Cyan
        Write-Host "  - analyze hook fix (v2.40 보강): -File 스크립트(analyze.ps1/analyze.sh) 실행 → Git Bash 디스패치 호환 + 진단 결과 stderr 재전송(exit 2/0 정규화)로 agent가 실제 분석 내용 수신" -ForegroundColor Cyan
        Write-Host "  - retrieval 표시 (v2.41): 응답 내 📡 Retrieval 선언(codemap/ctxdb hit·full-scan 사유) + statusline 📡 cmap/ctx/src 실측 카운터(read-track hook) — 전체 소스 스캔 토큰 사고 관측" -ForegroundColor Cyan
        Write-Host "  - retrieval 시각화 (v2.42): statusline에 색상(라우팅=초록/소스직행=노랑) + route% + hit%(codemap·ctxdb 선언 hit·miss율, stop-check 파싱) — PawPad 코어 동작 가시화, 모델 토큰 0" -ForegroundColor Cyan
        Write-Host "  - 상세: docs/CHANGELOG_v2.42.md" -ForegroundColor Cyan
    } else {
        Write-Host "v${ver}: 19 skills + hooks + .ctxdb + codemap + codebase-map + security-check." -ForegroundColor Cyan
        Write-Host "  - Stack: $Stack  |  bundles: -Preset lean|standard|full  or  -Bundles prd,ui,delegate,review" -ForegroundColor Cyan
        Write-Host "  - cross-platform hooks (.ps1/.sh), statusLine, Codex adapter, -Upgrade (preserves user data)" -ForegroundColor Cyan
        Write-Host "  - codemap / codebase-map / .ctxdb context DB / security-check gate (DoD)" -ForegroundColor Cyan
        Write-Host "  - analyze hook now runs via -File script + forwards diagnostics to stderr (exit 2/0 normalized)" -ForegroundColor Cyan
        Write-Host "  - retrieval indicator (v2.41): in-response 📡 Retrieval declaration + statusline 📡 cmap/ctx/src measured counters (read-track hook)" -ForegroundColor Cyan
        Write-Host "  - retrieval viz (v2.42): statusline color (routed=green/src-only=yellow) + route% + hit% (codemap·ctxdb declared hit·miss rate, parsed by stop-check) — core-behavior visibility, 0 model tokens | details: docs/CHANGELOG_v2.42.md" -ForegroundColor Cyan
    }
    Write-Host ""
} else {
    Write-Host ($L.failed -f $failed) -ForegroundColor Yellow
}

if ($Stack -eq 'generic') {
    Write-Host $L.genericNote1 -ForegroundColor Magenta
    Write-Host $L.genericNote2 -ForegroundColor Magenta
    Write-Host ""
}
Write-Host $L.nextSteps -ForegroundColor Yellow
Write-Host $L.step1 -ForegroundColor Yellow
Write-Host $L.step2 -ForegroundColor Yellow
Write-Host $L.step3 -ForegroundColor Yellow
Write-Host $L.step4 -ForegroundColor Yellow
Write-Host ""

if (-not $Force -and -not $Upgrade) {
    Write-Host $L.forceHint1 -ForegroundColor DarkGray
    Write-Host $L.forceHint2 -ForegroundColor DarkGray
    Write-Host $L.forceHint3 -ForegroundColor DarkGray
    Write-Host "options: -Preset lean|standard|full  -Bundles prd,ui,delegate,review  -Lang en|ko" -ForegroundColor DarkGray
    Write-Host ""
}

# ── 전역 Codex 스킬 섀도잉 감지 (비파괴 경고, 모든 모드 공통) ─────────────────────
$globalSkillRoot = Join-Path $env:USERPROFILE ".codex\skills"
if (Test-Path $globalSkillRoot) {
    $localSkillNames = @(Get-ChildItem ".claude\skills" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $shadowedSkills = @(Get-ChildItem $globalSkillRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $localSkillNames -contains $_.Name } | ForEach-Object { $_.Name })
    if ($shadowedSkills.Count -gt 0) {
        Write-Host ($L.shadow1 -f $shadowedSkills.Count) -ForegroundColor Yellow
        Write-Host "  ($($shadowedSkills -join ', '))" -ForegroundColor Yellow
        Write-Host $L.shadow3 -ForegroundColor Yellow
        Write-Host ($L.shadow4 -f $globalSkillRoot) -ForegroundColor Yellow
        Write-Host ""
    }
}

# 쓰기 실패가 있으면 비정상 종료 (자동화/CI에서 실패를 성공으로 보고하지 않음)
if ($failed -gt 0) { exit 1 }
