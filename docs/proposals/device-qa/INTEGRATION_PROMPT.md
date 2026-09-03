# 통합 프롬프트 — device-qa 스킬을 PawPad 툴킷에 녹이기

> 아래 블록을 **pawpad-toolkit 레포에서 여는 에이전트에게 그대로 붙여넣는다**.
> 참고: 이 문서의 파일·라인 정보는 **v2.51 기준 grep 결과**다. 반드시 현재 파일에서 재확인할 것.

---

## 붙여넣을 프롬프트

```
docs/proposals/device-qa/ 아래 3개 파일을 먼저 읽어라.
- INTENT.md   : 왜 이 스킬을 만들었는지(측정된 사건·메커니즘·설계 결정·미검증 항목)
- SKILL.md    : 편입 대상 스킬 본문(외부 프로젝트에서 작성·사용 중)
- 이 문서      : 통합 체크리스트

목표: device-qa 스킬을 PawPad 배포본에 정식 편입한다.
단, INTENT.md 7절의 "판단이 필요한 지점"을 먼저 결정하고 시작해라 —
(1) 새 번들 `qa`로 게이트해 그대로 편입할지, (2) 플랫폼 중립 골격 + references/android.md로 일반화할지.
원저자 권고는 (1)이다. 결정을 바꿀 근거가 있으면 그 근거를 먼저 말하고 진행해라.

작업 전 반드시 확인할 것:
- pawpad-setup.ps1은 STATUS: FROZEN 헤더를 가진 단일 배포 스크립트이고, 스킬 본문을 스크립트 안에
  임베드한다(Write-FileContent ".claude\skills\<name>\SKILL.md" -NoBom @'...'@).
  즉 .claude/skills/ 에 파일만 떨어뜨리면 live != embed 가 되어 배포본이 어긋난다.
  live(.claude/skills)와 embed(ps1) 두 곳을 같은 내용으로 맞추고, byte-equal 검증까지 해라.
- .agents/skills/ 는 Codex용 미러다. .claude/skills 단일 소스에서 재생성되는 경로를 그대로 따라라.
- 스킬 개수·목록이 여러 곳에 문자열로 박혀 있다. 하나라도 빠지면 설치 UI와 실제가 어긋난다.

편입 체크리스트(각 항목은 현재 파일에서 위치를 직접 확인한 뒤 수정):
1. 스킬 본체
   - .claude/skills/device-qa/SKILL.md 생성(SKILL.md 내용 그대로. frontmatter name/description 유지)
   - .agents/skills/device-qa/SKILL.md 미러 생성(기존 미러 생성 규칙과 동일 방식)
   - pawpad-setup.ps1에 임베드 블록 추가(다른 스킬 블록의 Step-Begin/Write-FileContent 패턴 그대로)
2. 목록·개수 동기화 (v2.51 기준 위치 — 재확인 필수)
   - ps1 상단 주석의 스킬 나열(약 33행 "- .claude/skills/* (…)")
   - 번들 정의: $validBundles / $bundlePresets (약 784~785행), $bpMap·$bpDeps (약 8562~8564행)
   - 설치 UI 문구의 스킬 개수: bundleOpts 의 "lean (Core 12) / standard (… 17) / full (전체 20)" ko·en 양쪽 (약 694·718행)
   - 그 외 "스킬 21" 같은 개수 표기가 STATUS 헤더·README·GUIDE·USAGE에 있으면 함께 갱신
3. 템플릿(설치처 CLAUDE.md / AGENTS.md) 반영 — ps1 안에 임베드된 템플릿 문자열
   - 자동제안 대상이 아니다. "추천 대상 한정: clarity·grill-me·to-prd·design·mockup·brainstorming" 목록은 건드리지 말고,
     그 뒤 "나머지(…)는 Session Protocol/DoD/hook이 트리거 → 자동제안 제외" 나열에 device-qa를 추가해라(약 1771행 및 AGENTS 대응 위치)
   - 트리거는 "기기 연결 상태에서 QA 착수" + 사용자 요청이다. Session Protocol ON START 순서에는 넣지 마라(매 세션 로드 대상이 아니다)
   - DoD에 새 항목을 추가하지 마라. 기존 DoD 7번(Verification Evidence)의 산출물 형식을 이 스킬이 채우는 구조다
4. 문서
   - docs/CHANGELOG_v<다음버전>.md 작성 — INTENT.md의 측정 수치(스크린샷 98장 생성·약 50장 read·5시간 한도 소진)와
     "위임은 해법이 아니다"라는 판단 근거를 반드시 남겨라. 이게 이 스킬의 존재 이유다
   - PAWPAD_VERSIONS.md 에 행 1줄 추가(기존 표 형식 유지)
   - README/GUIDE/USAGE 의 스킬 소개 목록에 1줄 추가
5. 검증
   - live == embed byte-equal (기존 배포 검증 방식 그대로. .claude/skills 와 .agents/skills 미러 포함)
   - PowerShell 파서 오류 0 (스킬 본문에 작은따옴표 here-string을 깨는 문자가 없는지 확인 —
     SKILL.md 안에 '@ 로 시작하는 줄이 없어야 한다)
   - 임시 폴더에 -Upgrade 설치를 한 번 돌려 device-qa 스킬이 실제로 떨어지는지 확인
   - 번들 게이트로 넣었다면 lean/standard/full 각각에서 설치 여부가 의도대로인지 확인

주의:
- SKILL.md 본문의 명령 중 `uiautomator dump` 는 원저자 환경(Galaxy Note 8/Android 9)에서 실증되지 않았다.
  가능하면 아무 안드로이드 기기/에뮬에서 1회 실행해 보고, 출력이 비면 스킬의 폴백 문구를 실제 동작에 맞게 다듬어라.
  실증하지 못하면 미검증 표시를 스킬에 남긴 채로 편입해라(지우지 마라).
- 커밋은 임의로 하지 말고, 변경 목록과 검증 결과를 보고한 뒤 사용자 승인을 받아라.
```

---

## 통합 담당자를 위한 부연 (프롬프트 밖 메모)

- 이 스킬은 **Android/adb 전제**라 툴킷의 기존 스킬들과 성격이 다르다. 번들·stack 게이트 없이 full 설치에 무조건 넣으면
  웹·백엔드 프로젝트 설치처에 쓸 수 없는 스킬이 하나 늘어난다. INTENT.md 7절 참고.
- 스킬 본문이 참조하는 외부 규칙 파일은 없다(자기 완결). `design` 스킬처럼 `references/`로 쪼갤 필요는 아직 없다 —
  일반화(안 2)를 택할 때만 필요하다.
- 원 프로젝트(TodayQuest)에는 이미 다음이 반영돼 있어 참고 사례로 쓸 수 있다:
  - `.claude/skills/device-qa/SKILL.md` (동일 내용)
  - `.claude/pawpad/device-qa-queue.md` 헤더에 실행 규칙 포인터 1줄
  - 커밋 `a5ee139`(스킬 신설), `72f3bf6`(그 QA 세션의 결과 기록), `6b13860`(그 QA가 잡은 결함 2건 수정)
