---
name: device-qa
description: 실기기/에뮬 QA 실행 프로토콜. 화면을 이미지로 읽지 않고 텍스트(uiautomator dump·dumpsys·앱 DB)로 검증해 토큰 폭증을 막는다. 기기를 연결해 QA를 돌릴 때, device-qa-queue 항목을 소진할 때, "실기기 테스트"/"기기 QA" 요청 시 사용. 긴 QA는 선택적으로 서브에이전트에 위임.
---
# Device-QA Skill - 기기 QA 실행 프로토콜

## 목적
기기 QA를 **싸게, 재현 가능하게, 사고 없이** 돌린다. 결과는 lane `Verification Evidence`에 바로 붙는 형식으로 낸다.

## 핵심 원리 (왜 토큰이 타나)
- 스크린샷 1장 = 텍스트 수천 자 상당. 게다가 **읽은 이미지는 이후 모든 도구 호출에 다시 실려 나간다** → 비용이 `이미지 수 × 남은 호출 수`로 누적된다.
- 화면→탭→화면 루프를 50회 돌리면 이 항이 세션 비용의 거의 전부가 된다. (2026-09-02 노트8 QA 실측: PNG 98장 생성·약 50장 read → 5시간 한도 소진)
- 🔴 **서브에이전트 위임은 이 항을 줄이지 않는다** — 부모 컨텍스트에서 치울 뿐, 같은 양이 서브 안에서 탄다. 위임은 이 프로토콜을 지킨 뒤의 선택지다.
- 진짜 지렛대: **검증을 bash에서 끝내고 결과 줄만 컨텍스트에 들이는 것**. `grep -q "2/4단계" dump.xml && echo PASS` = 수십 토큰.

## 트리거
/device-qa [항목]  또는 기기 연결 상태에서 QA 착수 시
- 코드 변경 후 검증: 먼저 `adb devices`. 붙어 있으면 직접 빌드·설치·QA, 없으면 `device-qa-queue.md`에 적재.
- queue 소진 세션, 사용자 "실기기 테스트/기기 QA" 요청.

## 검증 채널 우선순위 (위에서부터 시도)
| 순위 | 채널 | 쓰는 곳 | 비용 |
|---|---|---|---|
| 1 | `uiautomator dump` + grep | 화면 라벨·값·버튼 활성/비활성·요소 좌표(bounds) | 매우 낮음 |
| 2 | `dumpsys` / `logcat --pid` + grep | 진동·알림·네트워크 요청·광고 로드 실패 코드·예외 | 매우 낮음 |
| 3 | 앱 DB 직접 조회(Drift sqlite) | 지급/차감·카운터·상태 행 | 낮음 |
| 4 | 스크린샷 | **글자로 환원 안 되는 것만** — 잘림·색·시각적 어긋남·처음 보는 화면 구조 파악 | 매우 높음 |

🔴 1~3으로 판정 가능한 것을 4로 하지 않는다. "라벨이 맞는지"는 1번, "그 라벨이 잘렸는지"는 4번이다.

## 절차
### 1) 어서션 먼저 (화면 보기 전)
검증 항목을 **기대 문자열/조건 목록**으로 적는다. QA는 이 목록을 채우는 일이 된다.
```
[ ] 홈 카드 배지  == "2/4단계"        (dump)
[ ] 설명 줄       == "구구단 2·3·4단"  (dump)
[ ] 보정 캡션     스테퍼 + 후 없음     (dump)
[ ] 정답 진동     OneShot{40}          (dumpsys vibrator)
[ ] 마지막 항목 삭제버튼 ∩ FAB == 없음  (dump bounds 교차)
```

### 2) 기기 준비 (매번)
```sh
D=<serial>                                   # adb devices -l 로 확인, 이후 모든 명령에 -s $D
adb -s $D shell settings put system screen_off_timeout 1800000   # 화면 꺼지면 탭이 통째로 유실된다
adb -s $D shell getprop persist.sys.timezone; adb -s $D shell date  # 2기기 QA면 양쪽 시각 정렬
adb -s $D shell am force-stop <pkg>          # 콜드 스타트로 시작(resume이면 router redirect 미적용)
```
빌드·설치는 **명시적으로**: `flutter build apk --debug [--dart-define=...]` → `adb -s $D install -r -t <apk>`
(`flutter install`은 재컴파일을 건너뛰고 옛 apk를 깔 수 있다)

### 3) 화면 읽기 = 텍스트 덤프
```sh
dump() { adb -s $D shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb -s $D shell cat /sdcard/ui.xml; }
dump > /tmp/ui.xml                                  # 파일로 받고
grep -o 'text="[^"]*"' /tmp/ui.xml | sed 's/text="//;s/"$//' | grep -v '^$'   # 화면의 글자만
grep -c '2/4단계' /tmp/ui.xml                        # 어서션 1건 = 출력 1줄
```
- 탭 좌표도 여기서 나온다: 해당 노드의 `bounds="[x1,y1][x2,y2]"` 중심을 쓴다 → 스크린샷 없이 정확한 탭.
- 겹침 판정은 두 노드의 bounds 사각형 교차로 계산한다(눈대중보다 엄밀).
- ⚠️ **첫 사용 시 1회 검증**: 기기·앱에 따라 `uiautomator dump`가 빈 계층을 내거나 애니메이션 중 실패할 수 있다. 실패하면 잠깐 뒤 재시도, 그래도 안 되면 그 화면만 스크린샷으로 내리고 사유를 기록한다.

### 4) 시스템 사실은 dumpsys/logcat로
```sh
adb -s $D shell dumpsys vibrator | sed -n '/Previous vibrations/,/Extra/p' | grep <pkg>   # 삼성 One UI
adb -s $D shell dumpsys vibrator_manager | grep -i vibration                              # 최신 AOSP
adb -s $D logcat -d --pid=$(adb -s $D shell pidof <pkg> | tr -d '\r') -t 200 | grep -iE "exception|overflow|failed"
```
(진동은 에뮬에서 관측 불가, 실기기에서는 길이·시각까지 로그로 확정된다)

### 5) 데이터는 앱 DB로
Drift DB를 직접 읽고/심는다. push는 `/data/local/tmp` 경유. 심은 QA 행은 **검증 후 원복**하고, 실제 발생분은 보존한다.
타이머·제한이 판독 왕복보다 짧으면 DB에서 값을 늘려 QA하고 원복한다.

### 6) 스크린샷은 예산제
- **세션당 상한 8장**(초과하려면 사유를 남긴다). 매 스텝 확인용으로 찍지 않는다.
- 찍을 땐 필요한 영역만 크롭·축소해서 읽는다.
- 쓰는 경우: 처음 들어가는 화면의 구조 파악 / 잘림·overflow / 색·그래픽 / 텍스트 덤프 실패.
- QA 종료 시 스크린샷 파일 삭제(근거는 문서에 글로 남긴다).

## 안전 가드 (사고 이력 반영)
- 🔴 **블라인드 연속 탭 금지.** 한 번에 여러 탭을 쏘려면 그 사이에 다이얼로그가 뜰 수 없음이 확실해야 한다.
- 🔴 **탭 금지 라벨**: `계정 삭제`, `데이터 초기화`, `로그아웃`, `전체 삭제`, 결제/구독 확정 — 좌표가 겹칠 수 있는 화면에서는 dump로 라벨을 먼저 확인하고 누른다.
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
- 🟢 {항목}: {근거 문자열 또는 로그 한 줄}
- 🔴 {항목}: {관측값} ≠ {기대값} → {후속}
- 🔧 QA 데이터: 심은 행 {N}건 원복 완료 / 스크린샷 {N}장(사유)
```
queue 항목은 `device-qa-queue.md`에서 `[x] + 날짜`로 마감한다.

## DoD 연동
- 코드 변경 QA면 lane `## Verification Evidence`에 위 형식 1블록. 분석전용은 `not applicable`.
- QA가 결함을 잡으면 그 자리에서 고치지 말고 **결함 목록을 먼저 남긴다**(수정은 별도 사이클, 재검증 포함).
- 관련: `.claude/pawpad/device-qa-queue.md`(항목 적재) · `task-done`(마감) · `security-check`(코드 변경 시).
