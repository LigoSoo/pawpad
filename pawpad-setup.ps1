# PawPad — Agentic Engineering Toolkit | Setup Script v2.25 (Unified Claude + Codex Distribution, PowerShell)
# STATUS: FROZEN (v2.25. v2.24 기반 + (1) skill rename: karpathy -> lean-code (인물명 제거. 문서/매니페스트/config 동기, -Upgrade 병합 시 구 섹션명 'Coding Principles (Karpathy)' 자동 마이그레이션) + (2) 이연 동기화: 임베디드 $tmplClaudeMd/$tmplAgentsMd에 session-token-slim(ON START 조건부 read + _meta RECENT 8줄 로테이션), 임베디드 statusline.ps1/.sh에 ctx-accuracy(context_window 1순위 + model.id 한도 폴백). 보고서: docs/CHANGELOG_v2.25.md).
#         이전: v2.24 설치 UI live 모드(진행 바 1줄 제자리 갱신(`r) + 파일 로그 숨김(-ShowLog 복원) + 배너 발바닥 아트 보정. 설치 내용물 변경 없음. 보고서: docs/CHANGELOG_v2.24.md).
#         이전: v2.23 설치 UI 도입(paw 배너 + 28단계 진행 바 + 실측 체크리스트, Codex 리뷰 PASS. 보고서: docs/CHANGELOG_v2.23.md).
#         - Stack 프리셋: flutter | node | python | generic (생략 시 대화형 선택)
#         - hooks/statusline: Windows=.ps1 / Unix=.sh, settings.json이 설치 OS 감지해 자동 선택
#         - Codex native hooks: /hooks trust 후 ctxdb/codemap 최소 로드 + checkpoint continuation.
#         이전: v2.17 statusLine/ctxdb/codemap(FROZEN). 보고서: docs/CHANGELOG_v2.17.md.
#         변경 시 새 버전 번호 + 변경 보고서 + Codex 리뷰 절차 따를 것.
# Usage: .\pawpad-setup.ps1 [-Stack <flutter|node|python|generic>] [-Force | -Upgrade] [-ShowLog]
#        -Stack 생략 시 대화형 프롬프트. pwsh로 Mac/Linux에서도 실행 가능.
#
# 한 번에 모든 것을 세팅합니다:
# - CLAUDE.md, AGENTS.md (Context files, 하이브리드 프로토콜 반영)
# - .claude/settings.json (Claude Code hooks: SessionStart 자동주입 + Stop decision:block)
# - .claude/hooks/* (session-start.{ps1,sh}, stop-check.{ps1,sh}, statusline.{ps1,sh} - 크로스플랫폼 자동화/상태줄)
# - .claude/skills/* (memory, codemap, caveman, lean-code, clarity, handoff, checkpoint, grill-me, grill-with-docs, to-prd, design, ctxdb-navigator, context-saver, security-check)
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

param([switch]$Force, [switch]$Upgrade, [string]$Stack = "", [switch]$ShowLog)

if ($Force -and $Upgrade) {
    Write-Host "ERROR: -Force와 -Upgrade는 동시 지정 불가. 하나만 선택하세요." -ForegroundColor Red
    exit 1
}

$ver = "2.25"
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
    Write-Host "  설치 체크리스트 (✓ 설치/갱신/병합 · - 기존 유지 · ✗ 실패):" -ForegroundColor White
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

# ── Stack 선택 (v2.15) ─────────────────────────────────────────────────────────
$validStacks = @('flutter', 'node', 'python', 'generic')
if (-not $Stack) {
    Write-Host ""
    Write-Host "스택 선택 (Enter=generic):" -ForegroundColor Cyan
    Write-Host "  1) flutter   2) node   3) python   4) generic"
    try { $sel = Read-Host "번호 또는 이름" } catch { $sel = "" }
    switch -Regex ($sel.Trim().ToLower()) {
        '^(1|flutter)$' { $Stack = 'flutter' }
        '^(2|node)$'    { $Stack = 'node' }
        '^(3|python)$'  { $Stack = 'python' }
        default         { $Stack = 'generic' }
    }
}
$Stack = $Stack.Trim().ToLower()
if ($validStacks -notcontains $Stack) {
    Write-Host "알 수 없는 스택 '$Stack' -> generic 사용" -ForegroundColor Yellow
    $Stack = 'generic'
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
        $em = [regex]::Match($existing, $pattern)
        if ($em.Success) {
            $existing = $existing.Substring(0, $em.Index) + $tm.Value + $existing.Substring($em.Index + $em.Length)
        } else {
            if (-not $existing.EndsWith("`n")) { $existing += "`r`n" }
            $existing += "`r`n" + $tm.Value
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
}

# -Force/-Upgrade 시 자동 백업 (PawPad + Context files)
if ($Force -or $Upgrade) {
    Write-Host "Backing up existing project data (PawPad + Context files)..." -ForegroundColor White
    $backupPath = Backup-ProjectData
    if ($backupPath) {
        Write-Host "  BACKUP  $backupPath" -ForegroundColor Yellow
    } else {
        Write-Host "  (백업할 데이터 없음)" -ForegroundColor DarkGray
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
7. lane ``## Verification Evidence`` 섹션에 검증 근거 기록 (분석전용/소작업은 ``not applicable: analysis-only``). 규칙: .claude/HYBRID.md Verification Evidence.
8. 코드 변경 시 /security-check 🔴 zero (분석전용/문서전용 면제). 규칙: .claude/skills/security-check/SKILL.md

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

## Doc Update Rules
| Change           | Update target                            |
|------------------|------------------------------------------|
| Feature spec     | .claude/pawpad/specs/{feature-id}.md        |
| Feature/UX       | src/PRD-tree.md                          |
| New feature      | src/PRD-tree.md + src/PRD.md             |
| New screen/route | Feature ID in PRD-tree.md                |
| 결정 기록 위치    | .claude/HYBRID.md Decision Placement Matrix 참조 |
| 검증 결과        | lane ``## Verification Evidence`` (길면 .claude/pawpad/verifications/{feature-id}_{ts}.md) |
Code + doc update = one atomic unit. Keep * markers accurate.

## Session Protocol
ON START (agent가 순차 실행):
  0. read .ctxdb/INDEX.md -> 첫 메시지 키워드 매칭 -> L1<=1 / L2<=2개만 로드 (전체 로드 금지)
     (SessionStart hook이 INDEX 라우터 주입 + session state reset, codemap은 pawpad-config.json 토글.
      UserPromptSubmit hook(ctxdb-inject.ps1)이 prompt keyword로 L1/L2 자동 최소로드(session dedupe).
      PreCompact hook이 compaction 직전 context-saver 유도. 첫 응답 최상단에 검증 1줄:
      📂 ctxdb: {project} | {last-date} | {loaded L2} | {status})
  1. read .claude/pawpad/_wip.md (active lane router)
  2. Active Lanes 있으면 read .claude/HYBRID.md (협업 프로토콜). 없으면 skip -> 신규 lane 생성/핸드오프/인수 시점에 read
  3. assigned lane 있으면 read .claude/pawpad/wip/{lane}.md
  4. _wip.md Active Lanes에 state=HANDOFF_TO_* 발견 시 -> handoff 필드 경로 read
  5. state=SPEC_READY 또는 spec 있으면 read .claude/pawpad/specs/{feature}.md
  6. read .claude/pawpad/_meta.md
  7. .claude/codemap/_index.md는 코드 수정 작업 시작 시점에 read (질문/분석 전용 세션은 skip)
ON SUBTASK DONE: agent가 lane 파일 next steps 갱신
ON TASK DONE:    agent가 lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 + _meta.md 1줄 append (RECENT 8줄 초과 시 초과분을 sessions/{YYYY-MM}.md 상단으로 이동, newest first 유지) + _index.md 갱신 + git commit (git repo일 때만; 비-git이면 _meta RECENT에 "git unavailable" 기록, 완료 차단 안 함)
ON STOP:         agent가 lane 파일 (state + reason) 갱신
ON 8턴/60% CONTEXT: Stop hook이 8턴마다 checkpoint block -> context-saver(.ctxdb/L2 저장) + codemap 갱신. PreCompact hook이 native compaction 직전 동일 저장 유도(최근 8턴 내 발생 시 Stop checkpoint 중복 생략). 60% 시 /checkpoint -> 필요시 /handoff
-> Detail: .claude/skills/memory/SKILL.md | .claude/skills/codemap/SKILL.md | .claude/skills/ctxdb-navigator/SKILL.md | .claude/skills/context-saver/SKILL.md | .claude/skills/handoff/SKILL.md | .claude/skills/checkpoint/SKILL.md

## Hybrid Lane Rule
- 신규 작업: .claude/pawpad/wip/{feature-id}.md 생성 + _wip.md Active Lanes 등록
- 본인 lane만 수정. 타 에이전트 lane 읽기 가능, 수정 금지.
- 파일 충돌 위험 시 _wip.md Locks 섹션에 경로 매핑.
- codemap/_index.md: 추가는 누구나, 수정/삭제는 lane owner만.
- 완료 lane: wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 (삭제 금지, audit 보존, timestamp로 재작업 보존)
- 핸드오프 수신 시: state HANDOFF_TO_* -> WIP, owner -> 받는 agent로 변경

## Response Style
한글로 답변. 기술 용어 코드 원문 유지.
Terse. Drop: a/an/the, filler, pleasantries, hedging.
Pattern: [대상] [동작] [이유]. [다음 단계].
ACTIVE EVERY RESPONSE. Off: "normal mode"
-> Full rules: .claude/skills/caveman/SKILL.md
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
7. lane ``## Verification Evidence`` 섹션에 검증 근거 기록 (분석전용/소작업은 ``not applicable: analysis-only``). 규칙: .claude/HYBRID.md Verification Evidence.
8. 코드 변경 시 /security-check 🔴 zero (분석전용/문서전용 면제). 규칙: .agents/skills/security-check/SKILL.md

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

## Doc Update Rules
| Change           | Update target                            |
|------------------|------------------------------------------|
| Feature spec     | .claude/pawpad/specs/{feature-id}.md        |
| Feature/UX       | src/PRD-tree.md                          |
| New feature      | src/PRD-tree.md + src/PRD.md             |
| New screen/route | Feature ID in PRD-tree.md                |
| 결정 기록 위치    | .claude/HYBRID.md Decision Placement Matrix 참조 |
| 검증 결과        | lane ``## Verification Evidence`` (길면 .claude/pawpad/verifications/{feature-id}_{ts}.md) |
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
  6. read .claude/pawpad/_meta.md
  7. .claude/codemap/_index.md는 코드 수정 작업 시작 시점에 read (질문/분석 전용 세션은 skip)
ON SUBTASK DONE: agent가 lane 파일 next steps 갱신
ON TASK DONE:    agent가 lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 + _meta.md 1줄 append (RECENT 8줄 초과 시 초과분을 sessions/{YYYY-MM}.md 상단으로 이동, newest first 유지) + _index.md 갱신 + git commit (git repo일 때만; 비-git이면 _meta RECENT에 "git unavailable" 기록, 완료 차단 안 함)
ON STOP:         agent가 lane 파일 (state + reason) 갱신
ON 8턴/60% CONTEXT:
  - Claude Code: Stop hook이 8턴마다 checkpoint block -> context-saver(.ctxdb/L2 저장) + codemap 갱신.
  - Codex: `.codex/hooks.json` Stop hook이 trust된 경우 8턴마다 checkpoint continuation -> context-saver + codemap 갱신.
           hook 미신뢰/비활성 시 수동 수행.
  - 공통: 60% 시 /checkpoint -> 필요시 /handoff {to-agent} {feature}

## Codex 주의 (native hook adapter)
- `.agents/skills/*/SKILL.md`는 Codex repo skill mirror. Claude용 `.claude/skills/*`와 같은 절차 유지.
- Codex lifecycle hook은 `.codex/hooks.json`에 정의. `.codex/config.toml`은 project config layer 안내 주석만 유지.
- Codex에서 `/hooks` 실행 후 project-local hooks를 review/trust해야 자동 실행됨.
- SessionStart hook:
  - `.ctxdb/.state/codex-turn-count`, `.ctxdb/.state/codex-loaded` reset
- UserPromptSubmit hook:
  - `.ctxdb/INDEX.md` keyword matching
  - L1<=1 / L2<=2 로드 (같은 session 이미 로드한 ref는 재주입 안 함)
  - 주입 모드 (`.claude/pawpad-config.json` ctxdb.injectMode): pointer(기본) = `read: .ctxdb/...` 지시만 주입 -> **agent는 지시된 파일을 즉시 read 후 작업 시작 (필수)**; full = 본문 직접 주입
  - codemap HOT/keyword match 추가 주입 (`.claude/pawpad-config.json` codemap.inject 토글: auto/on/off, auto는 대형 repo opt-in; pointer 모드에서는 read 지시로 대체)
  - explicit fallback(L2/progress-current.md)은 재개 의도어(이어서/재개/resume/ctxdb 등)에만 발화 — 프로젝트명 포함 일반 프롬프트는 무주입
- PreCompact hook:
  - native compaction 직전 context-saver 유도 + `codex-last-compact`에 turn 기록
  - Stop 8턴 checkpoint와 중복 발화 방지(최근 8턴 내 compaction 저장 시 생략)
- Stop hook:
  - session별 `.ctxdb/.state/codex-turn-count` 카운트
  - 8턴 또는 L2 크기 초과 시 context-saver continuation 요구
- Unix `.codex/hooks/*.sh` wrapper는 현재 `pwsh` 필요. pwsh 부재 시 ctxdb-inject는 `hookSpecificOutput` skip context, SessionStart/PreCompact/Stop은 `{}` 반환.
- Claude Code도 동일 구조: `.claude/hooks/` SessionStart(state reset)+UserPromptSubmit(ctxdb-inject)+PreCompact+Stop. 토글은 공통 `.claude/pawpad-config.json`.
- `.ctxdb/.state/turn-count`는 Claude Stop hook 전용. Codex는 `codex-turn-count` 사용.
- hook 미신뢰/비활성 시 기존 수동 절차 유지:
  - ctxdb 로드: ON START step0에서 `.ctxdb/INDEX.md` 직접 read
  - ctxdb 저장: 8턴/세션종료/context 60% 추정 시 context-saver 절차 직접 수행
  - codemap: ON START 직접 read + 작업 후 직접 갱신

## Hybrid Lane Rule
- 신규 작업: .claude/pawpad/wip/{feature-id}.md 생성 + _wip.md Active Lanes 등록
- 본인 lane만 수정. 타 에이전트 lane 읽기 가능, 수정 금지.
- _wip.md Locks 섹션에서 파일 경로 매핑 확인.
- codemap/_index.md: 추가는 누구나, 수정/삭제는 lane owner만.
- 완료 lane: wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 (삭제 금지, audit 보존, timestamp로 재작업 보존)
- 핸드오프 수신 시: state HANDOFF_TO_* -> WIP, owner -> 받는 agent로 변경

## Handoff Protocol
- 60% context 도달 추정 시 정리.
- snapshot 파일: .claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md (agent가 템플릿 따라 작성)
- 템플릿: .claude/pawpad/handoffs/TEMPLATE.md
- 마커 4종 (state 필드에 기록):
  - HANDOFF_TO_CODEX (Claude -> Codex)
  - HANDOFF_TO_CLAUDE (Codex -> Claude)
  - HANDOFF_TO_NEXT_AGENT (미정)
  - SPEC_READY (기획 산출물 준비 완료, 구현 agent 대기)
- 다음 에이전트는 _wip.md Active Lanes의 state/handoff 필드로 snapshot 위치 파악
- 인수 시: state -> WIP, owner -> 받는 agent로 변경 (인수 사실 명시)

## Response Style
한글로 답변. 기술 용어 코드 원문 유지.
Terse. Drop: a/an/the, filler, pleasantries, hedging.
Pattern: [대상] [동작] [이유]. [다음 단계].
ACTIVE EVERY RESPONSE.

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
$analyzeCmd = if ($isWin) { $p.AnalyzePS } else { $p.AnalyzeBash }
$statusCmd  = if ($isWin) { "powershell -NoProfile -ExecutionPolicy Bypass -File $claudeRunHook statusline.ps1" } else { "bash $claudeHookRoot/statusline.sh" }

# JSON 하드빌드 (5.1 ConvertTo-Json 단일요소 배열 unwrap 회피). analyzeCmd 없으면 PostToolUse 생략.
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
if ($analyzeCmd) {
    $sl += '    "PostToolUse": ['
    $sl += '      {'
    $sl += '        "matcher": "Write|Edit|MultiEdit",'
    $sl += '        "hooks": ['
    $sl += '          {'
    $sl += '            "type": "command",'
    $sl += "            ""command"": ""$analyzeCmd"""
    $sl += '          }'
    $sl += '        ]'
    $sl += '      }'
    $sl += '    ],'
}
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

# ── Skills: memory ────────────────────────────────────────────────────────────
Step-Begin "skill: memory"
Write-FileContent ".claude\skills\memory\SKILL.md" -NoBom @"
---
name: memory
description: Hybrid session resume protocol. Use at session start (ON START) to read HYBRID/_wip/lane/handoff/meta/codemap and resume cross-agent (Claude<->Codex) work without losing context.
---
# Memory Skill - Session Resume Protocol (Hybrid)

## 파일 역할
| 파일/경로 | 역할 | 읽는 시점 |
|----------|------|---------|
| .claude/HYBRID.md                 | 협업 프로토콜               | ON START - 0번째     |
| .claude/pawpad/_wip.md               | active lane router          | ON START - 1번째     |
| .claude/pawpad/wip/{feature}.md      | 기능별 lane 상세            | active lane 있을 때  |
| .claude/pawpad/wip/done/             | 완료된 lane 보관 (audit)    | 히스토리 조회 시     |
| .claude/pawpad/handoffs/             | 핸드오프 snapshot           | state=HANDOFF_TO_* 시 |
| .claude/pawpad/specs/{feature}.md    | feature spec (기획 산출물) | state=SPEC_READY 또는 구현 직전 |
| .claude/pawpad/_meta.md              | 완료 이력 + Sprint 상태     | ON START             |
| .claude/pawpad/sessions/             | 세션 상세 (온디맨드)         | 필요 시만            |
| .claude/pawpad/decisions/rejected.md | 실패 기록                   | 유사 작업 전         |
| .claude/pawpad/decisions/arch.md     | ADR                         | 아키텍처 결정 전     |
| .claude/pawpad/backup/               | -Force 시 자동 백업          | 복구 필요 시         |

## ON START 절차 (agent가 순차 실행)
1. read .claude/HYBRID.md (협업 프로토콜 확인)
2. read .claude/pawpad/_wip.md (active lane router)
   -> Active Lanes 비어있음: 새 작업 시작
   -> Active Lanes 존재: assigned lane 읽기
3. lane 파일 있으면: read .claude/pawpad/wip/{feature}.md
4. lane state=HANDOFF_TO_* : _wip.md의 handoff 필드 경로로 snapshot read
5. lane state=SPEC_READY 또는 spec 있으면: read .claude/pawpad/specs/{feature}.md
6. read .claude/pawpad/_meta.md (Sprint / Phase / Blocked)
7. read .claude/codemap/_index.md (수정 대상 위치)

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

## _meta.md 포맷
# SPRINT: [W번호] | PHASE: [번호] | STACK: {프로젝트 스택}

## RECENT (newest first)
YYYY-MM-DD: [완료 내용]. [영향 파일]. [agent]

## BLOCKED
- [항목] -> [이유]

## NEXT
- [다음 예정 작업]

## _meta.md 업데이트 규칙
- 태스크 완료 시: RECENT 최상단 1줄 추가 (agent 명시)
- RECENT > 10줄: 오래된 항목 -> .claude/pawpad/sessions/YYYY-MM.md 이동
- BLOCKED / NEXT: 상태 변화 시 즉시 갱신

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
- _meta.md RECENT > 10줄 -> sessions/YYYY-MM.md로 이동
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

## 성장 전략
Phase A (<=80 entries): 플랫 리스트
Phase B (>80): 도메인 라우터로 전환
  # DOMAINS
  auth -> .claude/codemap/auth.md  (N entries)
  # HOT (inline)
  auth:login  src/.../login.<ext>  Login
Phase C (도메인 >30): 서브도메인 분리
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
- 임계값 미지정 시 기본값: 40
- 예: /clarity       -> 임계값 40
- 예: /clarity 30    -> 임계값 30 (엄격)
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

### 통과 블록 (PASS 시)
모호도: {총점}/100 ✅ PASS (임계값 {N})

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
5. 총점 <= 임계값 -> 통과 블록 출력 -> 종료

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
   - 완료/미완 정리
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
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.
"@

Step-Begin "skill: grill-with-docs"
Write-FileContent ".claude\skills\grill-with-docs\SKILL.md" -NoBom @'
---
name: grill-with-docs
description: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates project documentation (glossary + PawPad ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan against the project's language and documented decisions.
---

## What to Do

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

## Domain awareness

During codebase exploration, also look for existing documentation.

### 문서 위치 (이 프로젝트 / PawPad 규약)

- 용어집(glossary): `CONTEXT.md` (프로젝트 루트). 없으면 첫 용어 확정 시 생성.
- 아키텍처 결정(ADR): `.claude/pawpad/decisions/arch.md` (append, ADR-NNN 형식).
- 거부된 접근: `.claude/pawpad/decisions/rejected.md`
- 기능 spec: `.claude/pawpad/specs/{feature-id}.md`

주의: Matt Pocock 원본의 `docs/adr/`, `CONTEXT-MAP.md` 다중 컨텍스트 구조는 이 프로젝트에서 쓰지 않는다. ADR은 PawPad `decisions/arch.md` 단일 위치로 통일.

## During the session

### Challenge against the glossary

용어가 `CONTEXT.md` 기존 정의와 충돌하면 즉시 지적한다. "용어집은 '취소'를 X로 정의했는데 지금 Y를 의미하는 것 같다 — 어느 쪽인가?"

### Sharpen fuzzy language

모호하거나 중의적인 용어 → 정확한 canonical 용어 제안. "'account'라고 했는데 Customer인가 User인가? 둘은 다른 개념이다."

### Discuss concrete scenarios

도메인 관계를 논의할 때 구체 시나리오로 stress-test 한다. 엣지 케이스를 만들어 개념 경계를 명확히 하도록 강제한다.

### Cross-reference with code

사용자가 동작을 설명하면 코드와 일치하는지 확인한다. 모순 발견 시 표면화: "코드는 Order 전체를 취소하는데 방금 부분 취소가 가능하다고 했다 — 어느 게 맞나?"

### Update CONTEXT.md inline

용어가 확정되면 즉시 `CONTEXT.md`를 갱신한다. 모아두지 말고 그때그때 기록한다.

`CONTEXT.md`는 구현 세부를 일절 담지 않는다. spec, 스크래치패드, 구현 결정 저장소로 쓰지 말 것. 용어집(glossary)일 뿐이다.

### Offer ADRs sparingly

다음 세 가지가 모두 참일 때만 ADR을 제안한다:

1. **되돌리기 어려움** — 나중에 바꾸는 비용이 큼
2. **맥락 없이는 의외** — 미래 독자가 "왜 이렇게 했지?" 의문을 가짐
3. **실제 트레이드오프 결과** — 진짜 대안이 있었고 특정 이유로 선택함

하나라도 빠지면 ADR을 생략한다. ADR 작성 시 `.claude/pawpad/decisions/arch.md`에 append 한다 (별도 `docs/adr/` 생성 금지).
'@

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
   - 구현 agent가 ON START에서 SPEC_READY 발견 → spec + lane read → 인수 (state=WIP, owner=본인). memory skill 참조. snapshot 불필요하므로 `/handoff` 아님.

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
design 통과 후 spec이 필요하면 to-prd와 동일한 PawPad 절차로 인계 (SPEC_READY는 snapshot 불필요 — `/handoff` 아님):
- spec 작성: `.claude/pawpad/specs/{feature-id}.md` (디자인 계획 포함)
- lane 파일 생성/갱신: `.claude/pawpad/wip/{feature-id}.md` (owner=기획 agent, state=SPEC_READY, spec 경로, 다음 단계, updated). 기존 lane 있으면 갱신, 중복 생성 금지.
- `.claude/pawpad/_wip.md` Active Lanes 등록: state=SPEC_READY, owner=기획 agent, lane 경로
- `.claude/pawpad/_meta.md` RECENT에 1줄: "YYYY-MM-DD: SPEC_READY {feature-id}. 디자인 계획 작성 완료. [agent]"
- 구현 agent가 ON START에서 SPEC_READY 발견 → spec + lane read → 인수 (state=WIP, owner=본인)

### 디자인 ADR 기준
- per-screen 배치 결정 → spec에만 기록 (ADR 아님)
- 장기 디자인 시스템 결정(새 token / breakpoint / 재사용 공용 컴포넌트 / navigation pattern)만 `.claude/pawpad/decisions/arch.md`에 append

## clarity / grill 과의 관계
- clarity : 요청 모호도(기능 정의) 게이트 — design 앞 단계.
- grill-me : 설계 의사결정 심문 — 큰 화면/플로우 설계 시 병행.
- design  : 시각·레이아웃·토큰 게이트 — 화면 구현 직전.
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

codemap과의 분리:
- codemap: domain:symbol -> file:role 1줄 레지스트리. "어디 있나".
- codebase-map: 축별 산문 문서. "어떻게 구성/동작/약속".

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
- state       : WIP | SPEC_READY | HANDOFF_TO_CODEX | HANDOFF_TO_CLAUDE | HANDOFF_TO_NEXT_AGENT | BLOCKED
- handoff     : state=HANDOFF_* 일 때만 필수. snapshot 파일 경로.
- updated     : 마지막 lane 파일 또는 router 갱신 시각

## State 의미
| state | 의미 | 다음 행동 |
|-------|------|---------|
| WIP | 작업 진행 중 | owner가 계속 작업 |
| SPEC_READY | 기획 완료, 구현 대기 | 구현 agent가 spec read 후 인수 (state=WIP, owner=본인) |
| HANDOFF_TO_CODEX | Codex 인수 요청 | Codex가 snapshot read 후 인수 (state=WIP, owner=Codex) |
| HANDOFF_TO_CLAUDE | Claude 인수 요청 | Claude가 snapshot read 후 인수 (state=WIP, owner=Claude) |
| HANDOFF_TO_NEXT_AGENT | 미정 인수 요청 | 인수 agent가 snapshot read 후 인수 |
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
.claude/skills/memory/SKILL.md "lane 파일 포맷" 참조

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
<!-- Phase A (<=80): flat | Phase B (>80): domain routing -->
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

프로젝트에 설치된 모든 스킬 목록. (15개)

> **환경별 활성 방식**
> - Claude Code: `/skill` slash 호출 + description 자동 트리거 둘 다 지원.
> - Codex CLI: **slash 호출 미보장**. `.agents/skills/*/SKILL.md`의 `description` 기반 **자동 트리거 중심**. 명시 호출 필요 시 "use {skill} skill"처럼 자연어로 지시.
> - caveman/lean-code는 skill이 아니라 **CLAUDE.md/AGENTS.md가 매 응답 강제**한다(아래 참조 강등 참고).
> - statusline은 **Claude Code 전용**(`.claude/settings.json` statusLine). Codex CLI는 statusline 메커니즘이 없어 미적용.

---

## Skill 목록

### 📍 Core Skills (상태/코드 기반)

| 스킬 | 위치 | 용도 |
|------|------|------|
| **memory** | `.claude/skills/memory/` | WIP 상태 관리, 세션 재개(ON START) 프로토콜 |
| **codemap** | `.claude/skills/codemap/` | 심볼 위치 레지스트리, owner 분리 권한 |
| **codebase-map** | `.claude/skills/codebase-map/` | 7축 고수준 코드베이스 맵(아키텍처/구조/관례/관심사), digest-only 주입 |
| **caveman** | `.claude/skills/caveman/` | 압축 통신 모드 (참조). 실제 강제는 CLAUDE.md/AGENTS.md `Response Style` |
| **lean-code** | `.claude/skills/lean-code/` | LLM 코딩 안티패턴 (참조, 구 karpathy). 실제 강제는 CLAUDE.md/AGENTS.md `Coding Principles` |
| **clarity** | `.claude/skills/clarity/` | 요청 모호도 분석 (5차원 스코어링) |
| **design** | `.claude/skills/design/` | UI/UX 설계 게이트 (토큰+레이아웃+원칙, 반응형) |
| **ctxdb-navigator** | `.claude/skills/ctxdb-navigator/` | 키워드 depth 컨텍스트 최소 로드 (토큰 절약) |
| **security-check** | `.claude/skills/security-check/` | 보안 검증 게이트 (secrets/취약점/설정/PawPad 산출물, 🔴 시 BLOCK) |
| **context-saver** | `.claude/skills/context-saver/` | 세션 작업 .ctxdb/L2 저장 + AGENT SYNC 갱신 |

### 🔀 Workflow Skills (협업/기획)

| 스킬 | 위치 | 용도 |
|------|------|------|
| **handoff** | `.claude/skills/handoff/` | 세션/에이전트 인수인계 (PawPad snapshot + owner transfer) |
| **checkpoint** | `.claude/skills/checkpoint/` | 컨텍스트 60% 롤오버 게이트 (상태 보존) |
| **grill-me** | `.claude/skills/grill-me/` | 계획/설계 스트레스 테스트 (재귀적 질문) |
| **grill-with-docs** | `.claude/skills/grill-with-docs/` | 문서 기반 그릴링 (`.claude/pawpad/decisions/arch.md` ADR 갱신) |
| **to-prd** | `.claude/skills/to-prd/` | 대화 → PRD (`.claude/pawpad/specs/` 저장 + SPEC_READY) |

---

## 스킬 호출 패턴

### 기본 호출
```
/memory          # 세션 재개 프로토콜
/codemap         # 심볼 탐색
/caveman         # 압축 모드
/clarity         # 모호도 분석
/lean-code       # 원칙 확인
/design          # UI/UX 설계 게이트 (화면 구현 직전)
/security-check  # 보안 검증 게이트 (커밋/핸드오프/완료 직전)
```

### 협업/기획
```
/grill-me        # 설계 스트레스 테스트
/grill-with-docs # 문서 기반 그릴링 (용어집 + ADR)
/to-prd          # 대화 → PRD + SPEC_READY 등록
/checkpoint      # 60% 컨텍스트 정리
/handoff         # 다음 에이전트 인수인계
```

---

## 스킬 체이닝 예시

### 예시 1: 기획 → 구현 (PawPad 흐름3)
```
1. /clarity 40          ← 기획 모호도 확인
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
2. /memory              ← _wip.md 상태 갱신
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
    "memory",
    "codemap",
    "codebase-map",
    "caveman",
    "lean-code",
    "clarity",
    "handoff",
    "checkpoint",
    "grill-me",
    "grill-with-docs",
    "to-prd",
    "design",
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
        'Doc Update Rules', 'Session Protocol', 'Hybrid Lane Rule', 'Response Style'
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

# ── 완료 요약 ────────────────────────────────────────────────────────────────
Show-InstallChecklist
Write-Host ""
Write-Host "========================================================="
Write-Host "Setup Complete: $created created | $updated updated | $merged merged | $skipped skipped | $failed failed" -ForegroundColor Cyan
Write-Host ""

if ($failed -eq 0) {
    Write-Host "프로젝트 초기화 완료 (PawPad v$ver)" -ForegroundColor Green
    Write-Host ""
    Write-Host "v$ver 누적 (15 스킬 + hook + .ctxdb + codemap + codebase-map + security-check):" -ForegroundColor Cyan
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
    Write-Host "  - 상세: docs/CHANGELOG_v2.25.md" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "$failed 개 항목 실패. 권한 확인 후 다시 시도하세요." -ForegroundColor Yellow
}

if ($Stack -eq 'generic') {
    Write-Host "[generic] CLAUDE.md / AGENTS.md / config.json 의 <YOUR_*> 플레이스홀더를 실제 값으로 채우세요." -ForegroundColor Magenta
    Write-Host "          (analyze 명령 미지정 -> PostToolUse 자동검사 hook은 생략됨)" -ForegroundColor Magenta
    Write-Host ""
}
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "  1. CLAUDE.md / AGENTS.md 의 Stack(Commands/Boundaries) 정보 확인 및 수정" -ForegroundColor Yellow
Write-Host "  2. .claude/pawpad/_meta.md 의 STACK 정보 확인" -ForegroundColor Yellow
Write-Host "  3. .claude/HYBRID.md 읽기 (협업 프로토콜 숙지)" -ForegroundColor Yellow
Write-Host "  4. 기존 코드 있으면: '.claude/codemap/_index.md 초기값 만들어줘' 요청" -ForegroundColor Yellow
Write-Host ""

if (-not $Force -and -not $Upgrade) {
    Write-Host "기존 파일 덮어쓰려면: .\pawpad-setup.ps1 -Force" -ForegroundColor DarkGray
    Write-Host "기존 설치 업그레이드: .\pawpad-setup.ps1 -Upgrade (사용자 데이터 보존, 툴킷 파일만 갱신)" -ForegroundColor DarkGray
    Write-Host "(둘 다 PawPad + Context files 자동 백업됩니다)" -ForegroundColor DarkGray
    Write-Host ""
}

# ── 전역 Codex 스킬 섀도잉 감지 (비파괴 경고, 모든 모드 공통) ─────────────────────
$globalSkillRoot = Join-Path $env:USERPROFILE ".codex\skills"
if (Test-Path $globalSkillRoot) {
    $localSkillNames = @(Get-ChildItem ".claude\skills" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $shadowedSkills = @(Get-ChildItem $globalSkillRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $localSkillNames -contains $_.Name } | ForEach-Object { $_.Name })
    if ($shadowedSkills.Count -gt 0) {
        Write-Host "⚠ 전역 Codex 스킬 섀도잉 감지: ~/.codex/skills/ 에 동일 이름 스킬 $($shadowedSkills.Count)개" -ForegroundColor Yellow
        Write-Host "  ($($shadowedSkills -join ', '))" -ForegroundColor Yellow
        Write-Host "  Codex는 전역을 repo mirror(.agents/skills)보다 우선 조회 -> 구버전 섀도잉 위험." -ForegroundColor Yellow
        Write-Host "  정리 권장(삭제 아닌 백업 이동): Move-Item '$globalSkillRoot\{skill}' '$globalSkillRoot.pawpad-backup\'" -ForegroundColor Yellow
        Write-Host ""
    }
}

# 쓰기 실패가 있으면 비정상 종료 (자동화/CI에서 실패를 성공으로 보고하지 않음)
if ($failed -gt 0) { exit 1 }
