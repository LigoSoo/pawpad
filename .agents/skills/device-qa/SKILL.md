---
name: device-qa
description: 실기기/에뮬 QA 실행 프로토콜. 화면을 이미지로 읽지 않고 텍스트(자동화 테스트·logcat/dumpsys·앱 DB·uiautomator dump)로 검증해 토큰 폭증을 막는다. 기기를 연결해 QA를 돌릴 때, device-qa-queue 항목을 소진할 때, "실기기 테스트"/"기기 QA" 요청 시 사용. 긴 QA는 선택적으로 서브에이전트에 위임.
---
# DO NOT EDIT: generated from .claude/skills/device-qa/SKILL.md by pawpad-setup.ps1.
# Device-QA Skill — 기기 QA 실행 프로토콜

## 목적
기기 QA를 **싸게, 재현 가능하게, 사고 없이** 돌린다. 결과는 lane `Verification Evidence`에 바로 붙는 형식으로 낸다.

## 왜 토큰이 타나
- 읽은 이미지 1장은 **그 뒤의 모든 도구 호출에 다시 실려 나간다** → 비용이 `이미지 수 × 남은 호출 수`로 누적. 캐시는 단가를 낮출 뿐 이 형태를 바꾸지 않는다.
- 화면→탭→화면 루프 50회면 이 항이 세션 비용의 거의 전부다. (2026-09-02 노트8 QA 실측: PNG 98장 생성·약 50장 read → 5시간 한도 소진)
- 🔴 **서브에이전트 위임은 이 항을 줄이지 않는다** — 부모 컨텍스트에서 치울 뿐 같은 양이 서브 안에서 탄다. 위임은 프로토콜을 지킨 뒤의 선택지다.
- 진짜 지렛대: **판정을 셸에서 끝내고 결과 줄만 컨텍스트에 들이는 것**.

### 실측 단가 (2026-09-03, emulator 1080x2400)
| 컨텍스트에 들이는 것 | 실측 | 추정 토큰 |
|---|---|---|
| `grep -c` 어서션 1건 | 1줄 | ~10 |
| dump에서 text만 필터 | 479 B / 21줄 | ~250 |
| 스크린샷 **32% 축소**(346x768) | 84 KB | ~354 |
| 스크린샷 원본(→706x1568로 리사이즈됨) | 217 KB | ~1,476 |
| 🔴 dump **원문** 투입 | 29,356 B | ~8,000 |

→ 절감은 dump를 쓰는 행위가 아니라 **걸러내는 행위**에서 나온다. XML 원문을 들이면 스크린샷보다 **5배 비싸다**.

## 트리거
/device-qa [항목]  또는 기기 연결 상태에서 QA 착수 시
- 코드 변경 후 검증: 먼저 `adb devices`. 붙어 있으면 직접 빌드·설치·QA, 없으면 `device-qa-queue.md`에 적재.
- queue 소진 세션, 사용자 "실기기 테스트/기기 QA" 요청.

## 검증 채널 우선순위 (위에서부터 시도)
| 순위 | 채널 | 쓰는 곳 | 비용 | 신뢰도 |
|---|---|---|---|---|
| 1 | **기기 자동화 테스트** (`flutter test integration_test/`, `am instrument`) | 흐름·상태·계산 결과. 반복 실행이 필요한 회귀 | 매우 낮음 | 높음(결정적) |
| 2 | `logcat --pid` / `dumpsys` + grep | 진동·알림·네트워크·광고 로드 실패 코드·예외 | 매우 낮음 | 높음 |
| 3 | 앱 DB 직접 조회 | 지급/차감·카운터·상태 행 | 낮음 | 높음 |
| 4 | `uiautomator dump` + grep | 화면 라벨·값·활성 여부·요소 좌표(bounds) | 매우 낮음 | **가변 — 프로브 필요** |
| 5 | **축소 스크린샷**(기본 32%) | 위로 판정 안 되는 것 전부 | 중간 | 높음 |
| 6 | 원본 스크린샷 | 색 정밀·1px 잘림 등 축소본으로 못 보는 것만 | 매우 높음 | 높음 |

🔴 1~4로 판정 가능한 것을 5·6으로 하지 않는다. "라벨이 맞는지"는 4번, "그 라벨이 잘렸는지"는 5번, "색이 맞는지"는 6번.

### 4번(dump)은 무조건 되는 채널이 아니다 — 첫 화면에서 프로브 1회
```sh
# 대상 화면에서 3회까지. 3회 다 실패하면 이 앱에서 dump는 포기하고 5번으로 간다.
for i in 1 2 3; do adb -s <serial> shell uiautomator dump //sdcard/ui.xml 2>&1 | tail -1; sleep 3; done
```
- 실측(2026-09-03, Flutter 앱 홈): `ERROR: could not get idle state.` **12/12 실패**(plain 6 + `--compressed` 6, 애니메이션 스케일 0에서도). 같은 기기의 네이티브 설정 앱·런처는 **성공**.
- 원인 계열: 화면에 **상시 애니메이션**이 있으면 UiAutomator가 idle을 못 잡는다(Flutter/Compose/게임 UI에서 흔하다). `--compressed`도 해결 못 한다.
- 성공해도 **Flutter는 Text 위젯이 안 올라올 수 있다** — 실측에서 25노드 중 앱 문자열 0건, `content-desc`의 내비 라벨만 나왔다. **얻은 노드에 기대 문자열이 없으면 dump가 성공해도 판정 근거로 쓰지 않는다.**
- 판정 결과는 `device-qa-queue.md` 헤더에 1줄로 남긴다(`dump: 사용가능 | 불가(사유)`). 매 화면 재시도 금지.

## 절차
### 1) 어서션 먼저 (화면 보기 전)
검증 항목을 **기대 문자열/조건 목록**으로 적는다. QA는 이 목록을 채우는 일이 된다.
```
[ ] 홈 카드 배지  == "2/4단계"        (dump | 축소샷)
[ ] 정답 진동     OneShot{40}          (dumpsys vibrator)
[ ] 보상 지급     points +15           (앱 DB)
[ ] 그룹 완료 흐름                     (integration_test)
```
채널을 항목마다 미리 적는다. 적을 채널이 5·6밖에 없는 항목이 절반을 넘으면 **자동화 테스트로 내릴 수 있는지 먼저 검토**한다.

### 2) 기기 준비 (매번)
```sh
adb devices -l                                   # serial 확인
adb -s <serial> shell settings put system screen_off_timeout 1800000   # 화면 꺼지면 탭이 통째로 유실된다
adb -s <serial> shell getprop persist.sys.timezone; adb -s <serial> shell date   # 2기기면 시각 정렬
adb -s <serial> shell settings put global window_animation_scale 0      # 전이 애니메이션만 꺼진다(앱 내부 애니메이션은 안 꺼짐)
adb -s <serial> shell am force-stop <pkg>        # 콜드 스타트(resume이면 router redirect 미적용)
```
빌드·설치는 **명시적으로**: `flutter build apk --debug [--dart-define=...]` → `adb -s <serial> install -r -t <apk>`
(`flutter install`은 재컴파일을 건너뛰고 옛 apk를 깔 수 있다)

### 3) 셸 규율 (이걸 어기면 절감이 사라지거나 오탐이 난다)
- 🔴 **스니펫은 자기완결로 쓴다.** 에이전트 Bash 도구는 호출 간에 **변수·함수를 보존하지 않는다**(cwd만 유지). serial·패키지는 매 호출에 다시 쓴다. `D=...`/`dump()` 같은 헬퍼 정의는 다음 호출에서 소멸한다.
- 🔴 **Windows(Git Bash) 기기 경로는 `//` 로 시작한다.** `/sdcard/x.xml`은 `/Files/Git/sdcard/x.xml`로 변환돼 **다른 경로에 쓰인다**(실측). 그 뒤 `cat /sdcard/x.xml`은 **이전 세션이 남긴 옛 파일**을 읽어 **다른 화면으로 PASS**가 난다. 로컬 경로는 그대로 두고 **기기 경로만** `//`.
- 🔴 **덤프 원문을 컨텍스트에 넣지 않는다.** `cat`·Read 금지. 파일로 받아 `grep`/`grep -c`/`grep -q`만 통과시킨다.
- 매 dump 전 **옛 파일을 지운다**(`adb shell rm -f //sdcard/ui.xml`). 파일이 남아 있으면 실패가 성공으로 위장된다.

### 4) 화면 읽기 = 텍스트 덤프 (프로브 통과 시)
```sh
adb -s <serial> shell rm -f //sdcard/ui.xml
adb -s <serial> shell uiautomator dump //sdcard/ui.xml 2>&1 | tail -1     # "dumped to" 확인 필수
adb -s <serial> exec-out cat //sdcard/ui.xml > ui.xml                     # 로컬로만 내린다
grep -c '2/4단계' ui.xml                                                   # 어서션 1건 = 출력 1줄
grep -o 'text="[^"]*"' ui.xml | sed 's/text="//;s/"$//' | grep -v '^$'     # 화면 글자만 (필요할 때만)
grep -o 'content-desc="[^"]*"' ui.xml | sed 's/content-desc="//;s/"$//' | grep -v '^$'   # Flutter는 여기 있는 경우가 많다
```
- 탭 좌표도 여기서 나온다: 해당 노드의 `bounds="[x1,y1][x2,y2]"` 중심 → 스크린샷 없이 정확한 탭.
- 겹침 판정은 두 노드의 bounds 사각형 교차로 계산한다(눈대중보다 엄밀).

### 5) 시스템 사실은 logcat/dumpsys로
```sh
adb -s <serial> shell dumpsys vibrator | sed -n '/Previous vibrations/,/Extra/p' | grep <pkg>   # 삼성 One UI
adb -s <serial> shell dumpsys vibrator_manager | grep -i vibration                              # 최신 AOSP
adb -s <serial> logcat -d --pid=$(adb -s <serial> shell pidof <pkg> | tr -d '\r') -t 200 | grep -icE "exception|failed"
```
(진동은 에뮬에서 관측 불가, 실기기에서는 길이·시각까지 로그로 확정된다)

### 6) 데이터는 앱 DB로
DB를 직접 읽고/심는다. push는 `/data/local/tmp` 경유(Git Bash면 `//data/local/tmp`). 심은 QA 행은 **검증 후 원복**하고 실제 발생분은 보존한다. 타이머·제한이 판독 왕복보다 길면 DB에서 값을 조정해 QA하고 원복한다.

### 7) 스크린샷은 예산제 + 축소 필수
- **세션당 상한 8장**(초과하려면 사유를 남긴다). 매 스텝 확인용으로 찍지 않는다.
- 🔴 **읽기 전에 축소한다.** 기본 32%(1080x2400 → 346x768). 실측 1,476 → 354 토큰이고 화면 글자는 그대로 읽힌다. 원본 read는 색 정밀·미세 잘림 확인에만.
```sh
adb -s <serial> exec-out screencap -p > shot.png
```
```powershell
# 축소 (ImageMagick 없이, .NET)
Add-Type -AssemblyName System.Drawing
$i=[System.Drawing.Image]::FromFile("$PWD\shot.png"); $w=[int]($i.Width*0.32); $h=[int]($i.Height*0.32)
$b=New-Object System.Drawing.Bitmap $w,$h; $g=[System.Drawing.Graphics]::FromImage($b)
$g.InterpolationMode='HighQualityBicubic'; $g.DrawImage($i,0,0,$w,$h)
$b.Save("$PWD\shot_s.png",[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose(); $i.Dispose()
```
- 축소본만 read한다. 특정 영역만 필요하면 그 영역만 crop해서 더 줄인다.
- QA 종료 시 스크린샷 파일 삭제(근거는 문서에 글로 남긴다).

## 안전 가드 (사고 이력 반영)
- 🔴 **블라인드 연속 탭 금지.** 한 번에 여러 탭을 쏘려면 그 사이에 다이얼로그가 뜰 수 없음이 확실해야 한다.
- 🔴 **탭 금지 라벨**: `계정 삭제`, `데이터 초기화`, `로그아웃`, `전체 삭제`, 결제/구독 확정 — 좌표가 겹칠 수 있는 화면에서는 라벨을 먼저 확인하고 누른다.
- 사용자 데이터를 지우는 조작(`pm clear`, 계정 전환, DB 삭제)은 **먼저 물어본다**. 무엇이 사라지는지 한 줄로 알린다.
- 화면이 꺼진 채 쏜 탭은 전부 유실된다 → 긴 루프 전후로 `dumpsys power | grep mWakefulness` 확인.
- 에뮬은 AdMob 자동 테스트 기기(등록 불필요)이고 진동 관측이 불가하다 → 광고 스킵 5초·진동 체감은 실기기 전용.

## 위임 모드 (선택)
QA가 길고(20스텝+) 부모 컨텍스트를 지켜야 할 때만. **위 프로토콜을 지킨다는 전제**로만 의미가 있다.
1. 서브에이전트에 넘길 것 = (a) 어서션 목록 (b) 기기 serial·패키지·빌드 명령 (c) 이 SKILL 경로 (d) 안전 가드 요약
2. 반환 형식 = 항목별 `PASS/FAIL + 근거 문자열 1줄`. 스크린샷·XML 원문 반환 금지.
3. lane 기록·DoD 판정은 부모가 한다.
- ⚠️ 위임해도 총 토큰은 크게 안 준다. 파괴적 조작 권한은 서브에 주지 않는다(사용자 확인이 필요한 조작은 부모로 올린다).

## 산출물 (lane Verification Evidence 형식)
```
### {날짜} — {기기 모델·serial 앞 6자}, {빌드 종류/플래그}
- 🟢 {항목}: {근거 문자열 또는 로그 한 줄} ({채널})
- 🔴 {항목}: {관측값} ≠ {기대값} → {후속}
- 🔧 QA 데이터: 심은 행 {N}건 원복 완료 / 스크린샷 {N}장(축소 {N}·원본 {N}, 사유)
```
queue 항목은 `device-qa-queue.md`에서 `[x] + 날짜`로 마감한다.

## DoD 연동
- 코드 변경 QA면 lane `## Verification Evidence`에 위 형식 1블록. 분석전용은 `not applicable`.
- QA가 결함을 잡으면 그 자리에서 고치지 말고 **결함 목록을 먼저 남긴다**(수정은 별도 사이클, 재검증 포함).
- 관련: `.claude/pawpad/device-qa-queue.md`(항목 적재) · `task-done`(마감) · `security-check`(코드 변경 시).

## 다른 플랫폼
명령은 Android/adb 전제지만 **구조는 플랫폼 무관**이다 — 자동화 테스트 우선 → 로그/시스템 → 데이터 → 접근성 트리 → 축소 이미지. iOS는 `xcrun simctl` + accessibility, 웹은 DOM 텍스트/셀렉터, 데스크톱은 접근성 트리로 같은 순서가 성립한다. 다른 플랫폼에서 실사용이 생기면 그때 채널 표만 갈아 끼운다.

