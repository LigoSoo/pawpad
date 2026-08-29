# Godot + PawPad 모바일 2D 게임 개발환경 구성

> 최종 갱신: 2026-08-29
> 대상: Godot 4.x + GDScript, Android/iOS 2D 모바일게임, Claude Code / Codex 병행
> 전제: PawPad v2.50 · **`-Stack generic` 설치 + 수기 세팅**(godot 전용 스택 프로파일은 아직 없음)
> 관련 lane: `.claude/pawpad/wip/godot-stack-support.md`

---

## 0. 이 문서의 범위 (먼저 읽을 것)

게임 개발환경 구성은 3개 층으로 나뉘고, **PawPad가 담당하는 층은 하나뿐**이다.

| 층 | 내용 | 누가 하나 |
|---|---|---|
| A. 에이전트 규약 | Commands / Boundaries / Directories / Conventions / ADR | **PawPad** (프로파일 또는 수기 세팅) — §5 |
| B. 머신 사전조건 | Godot 본체, Export Templates, JDK, Android SDK/NDK, Xcode | **사용자** (1회) — §2 |
| C. 프로젝트 코드 | 씬, 스크립트, 테스트 러너, 빌드 스크립트, 어댑터 | **개발 중 생성** — PawPad는 파일을 만들지 않음 |

PawPad는 **프로젝트 파일 설치기**지 환경 설치기가 아니다. `-Stack`을 고르면 에이전트가 그 스택에서 올바르게 일하도록 규약과 자동검사를 배선할 뿐, SDK를 깔거나 소스 디렉터리를 만들지 않는다(flutter/node/python 전부 동일).

### 버전 무핀 원칙

이 문서는 **엔진·SDK 버전을 고정하지 않는다.** 설치 시점의 최신 stable을 쓰고, 실제 설치된 버전을 `_meta.md` STACK과 ADR에 기록한다. Android 빌드 요구사항(JDK/build-tools/NDK 버전)은 Godot 버전마다 달라지므로 **설치한 버전의 공식 export 문서 표를 그대로 따른다**(§11 링크). 문서에 숫자를 박으면 반드시 노화한다.

---

## 1. 개발환경 선택

| 항목 | 선택 | 근거 |
|---|---|---|
| 엔진 | Godot 4.x 최신 stable | |
| 배포판 | Standard (.NET 아님) | C#의 Android/iOS 지원은 실험 단계 |
| 언어 | GDScript + **정적 타입** | |
| 렌더러 | `gl_compatibility` | iOS Simulator가 Compatibility만 지원 → 처음부터 통일 |
| 주 개발 | Windows + Claude Code CLI | |
| Android 빌드 | Windows에서 직접 | |
| iOS 빌드 | macOS + Xcode 전용 머신 | Windows에서 불가 |
| 버전 관리 | Git (씬/스크립트는 텍스트) | |
| 광고 | Godot AdMob 플러그인 | services 어댑터 뒤로 격리 (§7) |
| 결제 | Android: Google Play Billing / iOS: StoreKit 2 | 동일하게 어댑터 격리 |
| 테스트 | headless 러너 + 실기기 | §6.2 |

---

## 2. 머신 사전조건 (사용자 1회 작업)

### 2.1 Windows 개발 PC

- Claude Code CLI, Git
- **Godot 4.x Standard** + **정확히 같은 버전의 Export Templates**
- OpenJDK, Android SDK(platform-tools / build-tools / platform / cmdline-tools / CMake / NDK)
- 실제 Android 기기 또는 에뮬레이터
- 릴리스 서명용 Keystore

패키지 버전은 **설치한 Godot 버전의 공식 문서**에서 확인한다. 설치 명령 형태만 적어둔다.

```powershell
$androidSdk = "$env:LOCALAPPDATA\Android\Sdk"
$sdkManager = "$androidSdk\cmdline-tools\latest\bin\sdkmanager.bat"

# <> 안은 공식 문서 표에서 확인한 값으로 대체
& $sdkManager --sdk_root="$androidSdk" "platform-tools" "build-tools;<VERSION>" "platforms;android-<API>" "cmdline-tools;latest" "cmake;<VERSION>" "ndk;<VERSION>"
```

환경변수:

```powershell
[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "User")
[Environment]::SetEnvironmentVariable("JAVA_HOME", "<JDK 설치 경로>", "User")
```

#### `godot`이 PATH에 없다 (중요)

Godot 공식 배포본은 `Godot_v4.x-stable_win64.exe` **단일 실행파일**이고 PATH에 등록되지 않는다. flutter/node/dotnet과 다른 지점이다. 이 문서의 모든 명령이 `godot`으로 시작하므로 둘 중 하나를 먼저 한다.

```powershell
# 방법 1: PATH에 잡히는 위치로 심볼릭 링크 (권장, 관리자 권한 필요)
New-Item -ItemType SymbolicLink -Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\godot.exe" -Target "<Godot exe 전체 경로>"

# 방법 2: 환경변수로 두고 명령마다 & $env:GODOT_BIN 사용
[Environment]::SetEnvironmentVariable("GODOT_BIN", "<Godot exe 전체 경로>", "User")
```

#### 설치 확인 (= 버전 실측)

```powershell
godot --version      # 여기서 나온 값을 _meta.md STACK / ADR에 기록
claude --version
git --version
java -version
adb version
adb devices
```

Godot 에디터가 Android SDK를 자동 감지하지 못하면 Editor Settings에서 **Java SDK Path**와 **Android SDK Path** 두 개를 1회 지정한다. CLI 전용 환경이면 `JAVA_HOME`/`ANDROID_HOME`을 먼저 설정하고 export 명령으로 감지 여부를 확인한다.

### 2.2 iOS 빌드용 Mac (해당 시점에 준비)

iOS 빌드는 Windows에서 불가능하다. 별도 Mac이 필요하다.

- macOS + Xcode + Command Line Tools
- Claude Code CLI, Git
- **Windows와 동일한 Godot 버전 + 동일한 Export Templates**
- Apple Developer 계정, 실기기, Provisioning Profile/인증서

```bash
godot --version && claude --version && git --version
xcodebuild -version
xcode-select -p        # 경로가 틀리면: sudo xcode-select --switch /Applications/Xcode.app
xcrun simctl list devices
```

Windows와 Mac은 **같은 Git 저장소를 각각 체크아웃**한다. 빌드 산출물과 서명 파일은 커밋하지 않는다(§4).

---

## 3. 프로젝트 구조

PawPad Architecture Principles(feature-first: colocation + 단일 public boundary + 횡단 import 금지)를 Godot 관례 안에서 적용한다.

```text
game-project/
├─ project.godot            # 등록 전용 (autoload/input map/layer) - 로직 금지
├─ export_presets.cfg       # 커밋 (단 머신별 경로 diff 주의, §8)
├─ CLAUDE.md / AGENTS.md    # PawPad - §5에서 수기 세팅
├─ .claude/                 # PawPad (skills/hooks/pawpad/codemap/settings)
├─ .ctxdb/                  # PawPad 컨텍스트 DB
├─ .codex/                  # Codex 어댑터
├─ addons/                  # 플러그인 - 버전 고정 커밋, 수정 금지
├─ ios/plugins/             # iOS 플러그인 - 동일
├─ core/                    # 도메인 비소속 공통 (events / save / state / util)
├─ features/                # 기능 단위 colocation (씬+스크립트+에셋 동거)
│  └─ player/ { player.gd, player.tscn, assets/ }
├─ services/                # 외부 경계 어댑터 (ads / purchases / analytics / platform)
├─ ui/                      # 공용 UI 컴포넌트 + Theme 리소스
├─ data/                    # balance / localization / tables
├─ tests/                   # unit / integration / smoke + test_runner.gd
├─ tools/                   # (선택) 빌드·캡처 스크립트
├─ artifacts/               # 로그·스크린샷 (커밋 X)
└─ builds/                  # 빌드 산출물 (커밋 X)
```

- **PawPad는 이 디렉터리들을 만들지 않는다.** CLAUDE.md의 `## Directories`에 관례로 기록될 뿐이고, 실제 생성은 개발하면서 한다.
- `features/` 간 내부 직접 참조 금지. 공유가 필요하면 `core/` 또는 `services/`로 승격(Rule of Three: 3곳째에 추출).
- `tools/`의 스크립트는 프로젝트 자산이지 PawPad 산출물이 아니다. 없어도 §6 명령을 직접 치면 된다.

---

## 4. Git 관리

### 4.1 Godot이 이미 해주는 것

Godot 4는 프로젝트 생성 시 **Version Control Metadata = Git**(기본값)이면 `.gitignore`와 `.gitattributes`를 자동 생성한다. `.gitignore`에 `.godot/`이 포함되므로 **엔진 캐시와 `export_credentials.cfg`는 기본적으로 이미 제외**된다.

`.gitattributes`에는 `* text=auto eol=lf`가 들어가는데, PawPad `Update-Gitattributes`는 이 패턴을 이미 커버된 것으로 보고 SKIP한다 — 충돌 없음.

### 4.2 직접 추가해야 하는 것

Godot 기본 `.gitignore`에 **없는** 항목들이다. 서명 자산이 여기 해당한다.

```gitignore
# Signing / credentials
*.keystore
*.jks
*.p12
*.mobileprovision
secrets.cfg
.env
.env.*

# Build outputs
builds/
artifacts/
```

PawPad 자체 항목(`.claude/pawpad/backup/`, `.claude/settings.local.json`, `.ctxdb/.state/`)은 setup이 자동 추가한다.

### 4.3 반드시 커밋해야 하는 것 — `*.gd.uid`

Godot 4.4부터 스크립트마다 `xxx.gd.uid` 파일이 생성된다. **커밋 대상이다.**

빼먹으면 다른 머신에서 UID가 재발급되면서 **씬의 스크립트 참조가 끊긴다.** 1인 개발에서는 증상이 전혀 안 보이고 2인째부터 터진다. `.gitignore`에 `*.uid`를 넣는 실수를 하지 말 것.

### 4.4 포함/제외 정리

| 대상 | 커밋 |
|---|---|
| `project.godot`, `export_presets.cfg` | 포함 |
| `addons/`, `ios/plugins/` | 포함 (버전 고정) |
| `*.gd.uid` | **포함 (필수)** |
| `.claude/`, `.ctxdb/`, `.codex/` | 포함 (단 `.state/`, `settings.local.json` 제외) |
| `.godot/` | 제외 (Godot 기본) |
| `.godot/export_credentials.cfg` | 제외 — 키스토어 비밀번호·암호화 키 저장 위치 |
| Keystore·인증서·프로비저닝 | 제외 |
| `builds/`, `artifacts/` | 제외 |

---

## 5. PawPad 연동 — 설치 + 수기 세팅 6곳

### 5.1 왜 수기인가

현재 PawPad에 **godot 스택 프로파일은 없다**(flutter/node/python/wpf/tauri/electron/avalonia/generic 8종). 프로파일 신설은 실사용 데이터가 쌓인 뒤로 미룬 상태다 — 검증되지 않은 규약을 툴킷에 박으면 이후 모든 godot 설치처에 복제되기 때문(판단 근거는 lane 참조).

`-Stack generic`으로 설치하면 CLAUDE.md 등에 `<YOUR_*>` 플레이스홀더가 남는다. **아래 6곳을 채우면 프로파일과 결과가 동일하다.** 이 파일들은 `-Upgrade` 병합 대상이 아니므로(사용자 소유) 나중에 툴킷을 올려도 덮이지 않는다.

```powershell
# 게임 repo 루트에서
.\pawpad-setup.ps1 -Stack generic
```

### 5.2 CLAUDE.md — 4개 섹션 교체

헤더 1줄도 같이 바꾼다: `# Tool: Claude Code | Stack: Godot 4 (GDScript, Android/iOS 2D)`

**`## Commands`**

```text
- Install:     (n/a - 에디터가 프로젝트 열 때 임포트)
- Dev:         godot --path .
- Test:        godot --headless --path . --script res://tests/test_runner.gd
- Test single: (n/a - 러너가 -- --test=<name> 인자를 받도록 구현하면 지원)
- Analyze:     godot --headless --path . --import   # 로그의 SCRIPT ERROR 0 확인
- Lint:        gdlint .                             # gdtoolkit 설치 시에만
- Build:       godot --headless --path . --export-debug "Android Debug" builds/android/game-debug.apk
# godot이 PATH에 없으면 $env:GODOT_BIN 사용 (§2.1)
```

**`## Boundaries`**

```text
NEVER modify:
- .godot/                 (엔진 캐시 - 편집·커밋 금지)
- addons/ , ios/plugins/  (플러그인 원본 - 버전 고정, 수정 시 업데이트로 소실)
- builds/ , artifacts/    (산출물)
- *.gd.uid                (엔진 발급 - 편집 금지. 단 커밋은 필수)

NEVER run without confirm:
- 릴리스 export (AAB/IPA) 및 스토어 업로드
- Keystore 생성/교체, Xcode Archive
- addons 플러그인 버전 업데이트
- adb uninstall / 기기 데이터 초기화
```

**`## Directories`** — §3의 트리를 붙여넣는다(주석 포함).

**`## Code Conventions`**

```text
- GDScript 정적 타입 필수 (var hp: int / func take(dmg: int) -> void). 추론은 := 사용
- 렌더러 gl_compatibility 고정 (iOS Simulator 제약)
- 씬 1개 = 기능 1개. 거대 .tscn 금지 - 텍스트지만 사실상 머지 불가
- project.godot 편집은 등록만 (autoload / input map / layer). 로직 금지
- *.gd.uid 반드시 커밋 (누락 시 타 머신에서 스크립트 참조 끊김)
- 광고·결제 플러그인 직접 호출 금지 - services/ 인터페이스 경유만
- 실 광고 ID·결제 인증정보 하드코딩 금지 - 로컬 설정 또는 환경변수 주입
- 파일 snake_case.gd / class_name PascalCase / 상수 UPPER_SNAKE
- print() 금지 - 로깅 래퍼 경유
```

### 5.3 AGENTS.md — 위 4개 섹션 동일 반영

Codex 미러다. 안 맞추면 두 에이전트가 서로 다른 규약으로 일한다.

### 5.4 `.claude/pawpad/_meta.md`

헤더의 `STACK: <YOUR_STACK>` → `STACK: Godot<실측버전>+GDScript+Android/iOS`
(`godot --version` 실측값 사용. 예: `Godot4.4+GDScript+Android/iOS`)

### 5.5 `.codex/config.json`

```json
"stackInfo": {
  "framework": "Godot 4",
  "language": "GDScript",
  "stateManagement": "-",
  "database": "-"
}
```

`verifyCommands`의 `<YOUR_ANALYZE_CMD>` / `<YOUR_TEST_CMD>` 2곳:

```json
["godot --headless --path . --import",
 "godot --headless --path . --script res://tests/test_runner.gd"]
```

### 5.6 `.claude/pawpad/decisions/arch.md`

ADR-001 예시를 실제 결정으로 교체한다.

```markdown
## ADR-001: 언어 - GDScript 고정
결정: C# 사용 안 함. 모든 로직 GDScript + 정적 타입.
이유: C#의 Android/iOS 지원이 실험 단계. 모바일 출시가 목표라 위험 회피.
날짜: 2026-08-29

## ADR-002: 렌더러 - gl_compatibility 통일
결정: Android/iOS/에디터 전부 gl_compatibility.
이유: iOS Simulator가 Compatibility만 지원. 나중에 바꾸면 셰이더·라이팅 전면 재작업.
날짜: 2026-08-29

## ADR-003: 씬 단위 = 기능 단위
결정: 화면 하나를 한 .tscn에 몰지 않고 기능별로 분리.
이유: .tscn은 텍스트지만 노드 이동 시 파일 전체가 재배치돼 머지가 사실상 불가능하다.
      2인 이상 협업에서 한쪽 작업이 통째로 유실되는 것을 막는 유일한 구조적 방어.
날짜: 2026-08-29

## ADR-004: 광고·결제 - services 어댑터 격리
결정: 게임 코드는 services/ 인터페이스만 호출. 플러그인 직접 호출 금지.
      Windows 개발 실행은 Mock 구현으로 동작.
이유: 플러그인 API가 불안정하고 플랫폼별로 다르다. 직접 호출이 퍼지면
      광고 추가·플러그인 교체 시 코드 전체를 뒤져야 한다.
날짜: 2026-08-29
```

### 5.7 `.gitignore`

§4.2 블록을 추가한다.

### 5.8 수기로 채울 수 없는 것 — analyze 훅

`generic` 설치는 `.claude/hooks/analyze.ps1`을 만들지 않고 `settings.json` PostToolUse에도 배선하지 않는다.

**godot에서는 어차피 넣지 않는 게 맞다.** PostToolUse는 파일을 편집할 때마다 실행되는데:

- `--import`: 엔진 기동에 수 초 + `.godot/` 재생성 + 에디터를 켜둔 상태면 충돌
- `gdlint`: gdtoolkit(pip) 외부 의존. 미설치 환경에서 매 편집 오탐

그래서 **DoD 1번(Analyze zero errors)은 "수동 `--import` 로그에 SCRIPT ERROR 0"으로 해석**한다. Commands에 이미 그렇게 적어뒀다. 실질 손실 없음.

---

## 6. CLI 검증 명령

### 6.1 리소스 임포트

```bash
godot --headless --path . --import
```

임포트가 끝날 때까지 기다렸다가 종료한다. 사용하는 Godot 버전에 `--import`가 없으면 `godot --headless --path . --editor --quit`로 대체한다. **출력 로그에서 `ERROR` / `SCRIPT ERROR`를 확인하는 것이 이 명령의 목적**이다.

### 6.2 테스트

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

`test_runner.gd`는 `SceneTree`를 상속하고 **실패 시 0이 아닌 종료 코드**를 반환하도록 구현한다. 종료 코드가 없으면 CI에서도 DoD에서도 판정이 불가능하다.

GUT / GdUnit4 같은 기성 프레임워크를 쓸 수도 있다. 다만 addon 의존이 하나 늘어나므로 도입은 테스트가 실제로 늘어난 뒤에 판단한다.

### 6.3 Android 디버그 빌드

```bash
godot --headless --path . --export-debug "Android Debug" builds/android/game-debug.apk
```

`export_presets.cfg`에 해당 preset이 정의돼 있어야 하고 출력 디렉터리가 미리 존재해야 한다.

### 6.4 실행 결과 확인

```powershell
adb install -r builds/android/game-debug.apk

# 액티비티 이름 확인 후 실행
adb shell cmd package resolve-activity --brief <PACKAGE_NAME>
adb shell am start -n <PACKAGE_NAME>/com.godot.game.GodotApp

adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png artifacts/screenshots/android.png
adb logcat -d > artifacts/logs/android.log
```

### 6.5 스토어 빌드 (AAB)

Google Play 신규 앱은 AAB가 필요하다. **Gradle Build가 활성화된** Release preset을 따로 둔다.

```bash
godot --headless --path . --export-release "Android Release" builds/android/game-release.aab
```

### 6.6 iOS (Mac)

```bash
godot --headless --path . --export-debug "iOS Debug" builds/ios/game-debug.zip
xcrun simctl io booted screenshot artifacts/screenshots/ios.png
```

최초 Bundle ID는 Xcode에서 1회 빌드해 Provisioning Profile을 생성하거나 Apple Developer 계정에서 미리 만들어 둔다.

---

## 7. 광고·결제 경계

게임 코드가 플러그인을 직접 호출하지 않는다. 어댑터로 격리한다(ADR-004).

```text
services/
├─ ads/       { ad_service.gd, admob_adapter.gd, mock_ad_adapter.gd }
└─ purchases/ { purchase_service.gd, google_play_adapter.gd,
                storekit_adapter.gd, mock_purchase_adapter.gd }
```

| 실행 환경 | 구현 |
|---|---|
| Windows 개발 실행 | Mock 광고 · Mock 결제 |
| Android 테스트 | AdMob + Google Play Billing |
| iOS 테스트 | AdMob + StoreKit 2 |

원칙:

- 테스트 중에는 **Google 테스트 광고 ID만** 사용
- 실 광고 ID는 로컬 설정/환경변수로 주입 (커밋 금지 — PawPad `/security-check` 검출 대상)
- 보상 지급은 **광고 완료 신호 확인 후**
- 구매 트랜잭션 ID 기준으로 중복 지급 방지
- `PENDING` 결제에는 아이템을 지급하지 않음
- 구매 복원 기능 구현
- 출시 버전은 **서버에서 구매 검증**
- StoreKit 2 플러그인은 교체 가능하도록 어댑터 뒤에 둔다

---

## 8. 2인 이상 협업 규약

혼자 할 때는 "권장"이던 것이 2인부터 **작업 유실로 직결**된다.

| 항목 | 규약 |
|---|---|
| `.tscn` | 씬 1개 = 기능 1개. 한 씬을 둘이 건드리면 머지 해결이 불가능해 한쪽을 버리게 된다 |
| `project.godot` | 등록만. 동시 편집이 잦으므로 autoload/input map 추가는 한 번에 한 사람 |
| `*.gd.uid` | 반드시 커밋 (§4.3) |
| `export_presets.cfg` | 커밋하되 **머신별 경로 필드 diff는 커밋에서 제외**(키스토어 경로·템플릿 경로) |
| `addons/` | 버전 고정. 한 명이 올리면 상대 머신에서 조용히 다른 동작 |
| 바이너리 에셋 | 규모가 커지면 Git LFS 검토 (도입 기준은 스토리지 정책 문제라 여기서 정하지 않음) |

### PawPad 파일 충돌

| 파일 | 위험 | 대응 |
|---|---|---|
| `.ctxdb/L2/progress-current.md` | 양쪽이 세션 저장 시 충돌 | 저장 전 pull. 충돌 시 블록 단위 수동 병합 |
| `.claude/codemap/_index.md` | 동시 갱신 | HYBRID 규율: 추가는 누구나, 수정·삭제는 lane owner만 |
| `.claude/pawpad/wip/*.md` | 낮음 | lane 소유권으로 분리. `_wip.md` Locks에 경로 매핑 |
| `.ctxdb/.state/`, `settings.local.json` | 없음 | 이미 gitignore (머신별) |

Windows(Android)와 Mac(iOS)을 병행하는 경우도 같은 규약이 적용된다. 같은 저장소를 각각 체크아웃하고 lane으로 작업을 분리한다.

---

## 9. 진행 순서

목표는 **테스트용 게임 개발 → 광고 부착 → 출시**다. 플러그인을 한꺼번에 넣지 않고 단계마다 원인을 분리한다.

**1단계 — 빈 프로젝트로 파이프라인 검증**

1. Godot에서 빈 프로젝트 생성 (Version Control Metadata = Git 유지)
2. Android 빈 APK 빌드 → **실기기 실행 확인**
3. `godot --version` 실측

**2단계 — PawPad 세팅**

4. `.\pawpad-setup.ps1 -Stack generic`
5. §5의 6곳 수기 세팅 + `.gitignore` 보강
6. headless 테스트 러너 구현 → `--script` 실행 및 종료 코드 확인

**3단계 — 게임 기능**

7. PRD/PRD-tree 작성 → lane 생성 → 기능 구현
8. 각 작업은 DoD 9항목 충족 후 종결 (§5.8의 Analyze 해석 적용)

**4단계 — 수익화**

9. AdMob 플러그인만 추가 → 테스트 광고 확인 (Android)
10. 필요 시 Google Play Billing 추가 → Sandbox 결제·복원 확인
11. 플러그인 버전 고정 + 커밋

**5단계 — 출시**

12. Keystore 생성 (커밋 금지 확인)
13. Gradle Build 활성 Release preset → AAB
14. `/security-check` 🔴 0 확인 후 스토어 업로드

**iOS 분기**: iOS가 필요해지는 시점에 §2.2를 준비하고, 빈 프로젝트 단계(2번)부터 Mac에서 한 번 통과시킨 뒤 합류한다. 게임을 완성한 다음 마지막에 iOS 결제를 붙이지 않는다.

### 완료 체크리스트

- [ ] `--import` 성공 (SCRIPT ERROR 0)
- [ ] headless 테스트 러너 성공 (종료 코드 정상 반환)
- [ ] Android APK 빌드 + 실기기 실행
- [ ] 스크린샷·로그 수집
- [ ] PawPad 6곳 세팅 완료 (플레이스홀더 0)
- [ ] `*.gd.uid` 커밋됨 / 서명 자산 gitignore됨
- [ ] AdMob 테스트 광고 동작
- [ ] `/security-check` 🔴 0
- [ ] (다인) 두 머신의 Godot·플러그인 버전 동일

---

## 10. 미확정 / 확인 필요 항목

이 문서는 아래를 **의도적으로 고정하지 않는다.** 진행 시점에 실측·확인할 것.

| 항목 | 상태 |
|---|---|
| Godot 버전 | 설치 시점 최신 stable. `godot --version` 실측값을 `_meta.md`/ADR에 기록 |
| JDK / build-tools / platform / NDK / CMake 버전 | **설치한 Godot 버전의 공식 export 문서 표**를 따름 |
| AdMob·Billing·StoreKit2 플러그인 | 저장소명·버전·API 안정성을 도입 시점에 확인. StoreKit2는 특히 빈 프로젝트에서 먼저 검증 |
| 기준 해상도 / 화면 방향 | 장르·UI 설계 확정 후 (세로 1080×1920 / 가로 1920×1080이 출발점) |
| 테스트 프레임워크 | 자체 러너로 시작. GUT/GdUnit4 도입은 테스트가 늘어난 뒤 |
| godot 스택 프로파일 (PawPad v2.51) | 1~2주 실사용 후 **실측된 규약만** 승격 판단 |
| 게임 UI/디자인 스킬 | 기존 `design`(토큰·일관성 5축)의 Godot Theme 적용성 판정 후 확장 vs 신설 결정 |

---

## 11. 공식 자료

- [Godot Android 내보내기](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot iOS 내보내기](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [Godot 명령줄 사용법](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [프로젝트 내보내기와 자격증명 파일](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)
- [프로젝트 구성 권장사항](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)
- [GDScript 정적 타입](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [Android 인앱결제](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html)
- [godot-google-play-billing](https://github.com/godot-sdk-integrations/godot-google-play-billing)
- [godot-storekit2](https://github.com/godot-sdk-integrations/godot-storekit2)
- [godot-admob](https://github.com/godot-sdk-integrations/godot-admob)
- [Claude Code 프로젝트 메모리](https://docs.anthropic.com/en/docs/claude-code/memory)
- [Claude Code 권한 설정](https://code.claude.com/docs/en/permissions)

> 문서 링크는 `/en/stable/` 기준이다. 특정 버전 문서가 필요하면 `stable`을 `4.x`로 바꿔 읽는다.
