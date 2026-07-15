# 프로젝트 설계→완성 워크플로 가이드

이 문서는 PawPad — Agentic Engineering Toolkit(v2.46 FROZEN)를 설치한 프로젝트에서, **하나의 기능/프로젝트를 기획부터 완성·배포까지** 진행하는 전체 절차와 각 단계의 스킬 사용 예시를 설명한다.

> 설치/배포 방법은 [`README.md`](README.md) 참조. 이 문서는 설치 후 **작업 워크플로** 중심이다.
> 대상 스택: 프리셋(flutter/node/python/wpf/tauri/electron/avalonia/generic) — 다른 스택도 `CLAUDE.md`의 `<YOUR_*>`만 채우면 동일 절차 적용
> 협업 모델: Claude Code ⇄ Codex 하이브리드 (파일 시스템 기반 상태 공유, 단독 사용도 가능)
> 버전 이력: 전체 표는 [PAWPAD_VERSIONS.md](PAWPAD_VERSIONS.md), 버전별 상세는 docs/CHANGELOG_v{N}.md. 아래는 최근 3개만.
> v2.44: **외부 문서 구현 진입 게이트 + 선택지 체크박스 전면화 + 데스크탑 스택 4종** — ① 외부 md/spec 문서를 첨부해 "참조해서 구현"을 요청하면 clarity/design/code-delegate 게이트가 우회되던 사고(실관측) 대응: CLAUDE/AGENTS `### 외부 문서 구현 진입 게이트` 신설 — clarity 채점 **의무**(문서 기준 모호도 블록 1회, PASS=무질문 통과라 마찰 최소·BLOCK=재질문) + UI 포함 시 design 추천 + 코딩 진입 시 code-delegate 권장(외부 문서 = written 설계 인정), phase 분해·task 저장만으로 게이트 건너뛰기 금지. clarity SKILL에 "외부 문서 모드" 섹션. ② 선택지 질문 체크박스 규칙을 기획 스킬 한정 → **스킬 무관 전면**으로 확장: 추천 1개 "(추천)" 첫 옵션 + 선택지 밖 답은 "Other" 자유 입력(선택지 생략·산문 대체 금지). ③ `-Stack` 데스크탑 프리셋 4종 추가: **wpf**(.NET 8 MVVM)/**tauri**(2, IPC 최소권한)/**electron**(contextIsolation 보안 고정)/**avalonia**(크로스플랫폼 XAML) — 대화형 1~8(Enter=generic). 스킬 수(20) 불변. 상세: docs/CHANGELOG_v2.44.md.
> v2.45: **brainstorming 스킬 신규**(20→21, prd 번들) — clarity 이전 발산 단계 공백 해소. 막연한 아이디어 또는 초안 기획문서를 받아 ①발산(방향 후보 2-3개+추천 1개, 방향 3요소[무엇을/누구에게/왜] 확정) ②누락 스윕(인접기능·저니 워크스루 + 비해피패스 8축 체크리스트[빈 상태/에러/권한/CRUD 대칭/데이터 수명주기/알림/설정/운영]) ③MoSCoW 스코프 게이트(**Won't 명시 의무** — 삭제 churn 차단)를 단일 스킬로 수행. 진입 판정으로 구체화된 문서는 스윕 직행(+오버라이드). 파이프라인 brainstorming→clarity→grill-me→to-prd→mockup. 구현 후반 기능 추가/삭제 churn(누락형) 기획 단계 차단(실관측 pain). 상세: docs/CHANGELOG_v2.45.md.
> v2.46: **design 스킬 시각 품질 재설계**(스킬 21 불변) — 기존 절차 게이트(토큰 확인+레이아웃+UI 원칙)를 **시각 품질 게이트**로 확장. 핵심 프레임 "**AI 티는 화려함이 아니라 불일치에서 온다**": 간격 임의값 혼재·radius 혼용·버튼 높이 제각각이 아마추어/AI 결과물로 읽히게 함. ①최상위 3원칙(Consistency First — 모양·크기·간격은 스케일 토큰에서만 파생 / Intentional Direction — 코드 전 방향 명시+사유 / Anti-slop) ②2-pass 워크플로우(계획→자기비평→구현→재비평) ③일관성 5축(간격/크기/모양/정렬/상태)+Token-first(토큰 정의 후 raw 값 금지) ④anti-slop 체크(과용 폰트는 신규 선택 시 한정, 경계 기본값 3종, 이모지 아이콘·목적 없는 그라디언트 금지) ⑤정량 체크(spacing 임의값 0·radius 고유값<=4·컨트롤 높이<=3) ⑥신규 프로젝트 토큰 부트스트랩(spacing/높이/radius/elevation/색 4~6/타입 1.25 모듈러/시그니처 1개). 적용 전/후 비교 검증(구현 전 사용자 확인). 상세: docs/CHANGELOG_v2.46.md.

---

## 0. 한눈에 — 전체 라이프사이클

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ 0. 시작   │ → │ 1. 기획   │ → │ 2. 설계   │ → │ 3. 구현   │ → │ 4. 완료   │ → │ 5. 배포   │
│ 세션 재개 │   │ 모호도   │   │ UI/목업  │   │ 코드+상태 │   │ DoD+동결  │   │ freeze   │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
   /resume       /brainstorming /design        /lean-code     DoD 8개        STATUS
                 /clarity       /grill-me      /codemap       /task-done     FROZEN
                 /grill-me      /to-prd        /caveman       _meta 기록     git tag
                 /to-prd
                                              /checkpoint
                                              /handoff
```

핵심 원리: **모든 상태는 파일에 산다.** 대화가 끊겨도, 에이전트가 바뀌어도(`Claude ⇄ Codex`), 컨텍스트가 가득 차도 — `.claude/pawpad/` 파일을 읽으면 정확히 이어서 작업할 수 있다.

---

## 1. 스킬 카탈로그 (21개)

### Core — 상태/코드 기반
| 스킬 | 언제 |
|------|------|
| `/resume` | **세션 시작마다**. `_wip.md`/lane/handoff/meta/codemap 읽고 작업 재개 + **Lane 신뢰성 게이트**(stale lane 감지 — 다음 작업 제안 전 실코드 1회 대조) |
| `/task-done` | **작업 종결마다**. ON TASK DONE 체크리스트 강제 실행(lane→done 이관+_wip 제거+_meta+tasklog+codemap+commit). "작업/이슈 종료" 자연어로도 발동, Stop hook lane-close 백스톱과 짝 |
| `/codemap` | 심볼(클래스/함수/위젯) **위치**를 검색 없이 조회. owner 분리 권한 |
| `/codebase-map` | **7축 고수준 맵**(아키텍처/구조/관례/테스트/관심사). codemap=위치, codebase-map=구조·관례. digest-only 주입 |
| `/ctxdb-navigator` | 세션시작 **키워드 매칭으로 최소 컨텍스트(L1≤1/L2≤2)만 로드** (토큰 절약) |
| `/context-saver` | 세션 작업을 `.ctxdb/L2`에 저장 + `INDEX.md` AGENT SYNC 갱신 |
| `/clarity` | 구현 전 **요청 모호도**를 5차원 스코어링, 명확해질 때까지 재질문 → PASS 후 **접근법 게이트**(실질 대안 ≥2면 2-3 대안 + 추천 1개) |
| `/design` | 화면/컴포넌트 구현 직전 **UI/UX 설계·시각 품질 게이트** (방향→토큰→레이아웃→일관성 5축→anti-slop·정량 체크) |
| `/mockup` | PRD-tree→단일 HTML 목업 시각화 (lo/hi-fi, Feature ID 태깅 + drift 경고). 화면이 어느 메뉴에 있는지 코딩 전 확인 |
| `/review` | 변경을 review-request 문서로 정리 → 다른 세션/에이전트(Codex↔Claude)가 직접 검증 리뷰 → result 반환. codex exec보다 저토큰 |
| `/lean-code` | 코드 작성 시 **과설계/범위 이탈 방지** 가드레일 (구 karpathy) |
| `/feature-architecture` | feature-first 구조 규율 (참조). 강제는 CLAUDE/AGENTS `Architecture Principles` |
| `/caveman` | 응답 압축 모드 (토큰 절감). 기본 ON, `normal mode`로 해제 |
| `/security-check` | **커밋/핸드오프/완료 직전 보안 검증** — secrets/취약점/위험 설정/PawPad 산출물 스캔. 🔴 검출 시 완료 BLOCK + 조치 제안 (DoD#8, 검출값 마스킹) |

### Workflow — 협업/기획
| 스킬 | 언제 |
|------|------|
| `/brainstorming` | **아이디어 발산 게이트** (clarity 이전). 막연한 아이디어→방향 발산(2-3 대안+추천 1개), 구체화된 기획문서→누락 스윕 직행(인접기능+비해피패스 8축)→MoSCoW 스코프 확정(Won't 명시) |
| `/grill-me` | 계획/설계를 **재귀 심문**으로 스트레스 테스트 (모호 용어 canonical 좁힘·엣지케이스 시나리오·진술 vs 코드 모순 표면화 포함) |
| `/to-prd` | 대화를 **PRD로 변환** → `specs/`에 저장 + lane `SPEC_READY` 등록 |
| `/checkpoint` | 컨텍스트 **50~60% 도달** 시 lane/codemap/meta 저장 (롤오버 게이트) |
| `/handoff` | 다른 에이전트/세션으로 **인수인계** (snapshot + owner 이전) |
| `/code-delegate` | 코딩 단계 **서브에이전트 위임** — 모델 선택 → spec/lane 포인터 → 서브 코딩 → 요약 반환 (부모 컨텍스트·토큰 절감, Claude Code 주력) |
| `/viewer-apply` | 통합 뷰어(spec-viewer)가 제자리 저장한 `src/viewer/*.json`을 읽어 **스팩 동기** — 남은 항목→spec 생성/갱신, 삭제 항목→제거/아카이브 (비파괴·confirm, `mockup` viewer 모드와 짝) |

> ⚠️ 이 스킬들은 PowerShell 명령이 아니라 **instruction**이다. 에이전트가 SKILL.md 절차를 따라 파일을 읽고 쓴다.

---

## 2. 단계별 절차 + 스킬 사용 예시

아래는 가상의 기능 **"클럽 멤버 목록 화면"**(`feature-id: club-member-list`)을 처음부터 끝까지 진행하는 실전 워크스루다.

---

### 단계 0 — 세션 시작 (ON START)

새 세션을 열면 **무조건 먼저** 상태를 읽는다.

```
사용자: /resume
```

에이전트가 순차 수행:
0. `.ctxdb/INDEX.md` — 첫 메시지 키워드 매칭 → L1≤1/L2≤2만 로드 (Claude는 SessionStart hook이 codemap+INDEX 자동 주입; Codex는 직접 read)
1. `.claude/pawpad/_wip.md` (active lane router)
2. Active Lanes 있으면 `.claude/HYBRID.md` (협업 프로토콜), 없으면 skip
3. 배정된 lane 있으면 `.claude/pawpad/wip/{lane}.md`
4. `state=HANDOFF_TO_*` 발견 시 → `handoff` 경로 read
5. `state=SPEC_READY` 또는 spec 있으면 → `specs/{feature}.md`
6. `.claude/pawpad/_meta.md` 상단(SPRINT/PHASE/BLOCKED/NEXT; RECENT 완료이력은 하단·재개 불요 → 생략, history 시 on-demand)
7. `.claude/codemap/_index.md` (심볼 위치, 코드 작업 시)

> 결과: "지난 세션에 club-member-list가 SPEC_READY 상태로 남아있음. spec 읽고 구현 인수하겠음" 처럼 **끊김 없이 재개**.

---

### 단계 1 — 기획: 발산 → 수렴

기획은 두 방향으로 진행된다: **펼치기**(빠진 기능이 없는지 — brainstorming) → **좁히기**(모호함이 없는지 — clarity/grill-me).

#### 1a. 아이디어 발산·누락 스윕 — `/brainstorming` (clarity 이전, 막연할 때)

```
사용자: 클럽 커뮤니티 기능 만들고 싶어
사용자: /brainstorming
```

`/brainstorming`이 3단계로 "완전한 기능 후보 목록"을 만든다:
1. **발산** — 방향 후보 2-3개(트레이드오프 + 추천 1개) 제시 → 체크박스 선택으로 "무엇을/누구에게/왜" 확정. 이미 구체화된 기획문서(.md)를 주면 이 단계는 건너뛰고 스윕 직행
2. **누락 스윕** — 인접기능(사용자 여정 전/후, 관리자 관점, 데이터 입출력 짝) + 비해피패스 8축(빈 상태/에러/권한/CRUD 대칭/데이터 수명주기/알림/설정/운영) 점검 → "생각 못 한 기능"을 지금 찾음
3. **MoSCoW 스코프** — Must/Should/Could/**Won't** 확정. Won't("이번엔 안 만듦") 명시가 구현 후반 기능 추가/삭제로 갈아엎는 사고를 차단

```
에이전트(brainstorming) 산출 — 기능 목록 완전판:
  | 기능              | 출처            | MoSCoW |
  | 멤버 목록/검색     | 발산            | M |
  | 멤버 상세 프로필   | 인접(여정 후)    | S |
  | 강퇴/차단         | 체크리스트(권한) | C |
  | 멤버 초대 링크     | 인접            | W (이번 스코프 제외, 근거 병기) |
```

→ Must 항목("멤버 목록")을 들고 `/clarity`로 넘어간다. 방향이 이미 확실하면 이 단계는 건너뛰고 바로 1b.

#### 1b. 요청을 명확하게 — `/clarity`

막연한 요청("멤버 목록 보여줘")을 구현 가능한 사양으로 좁힌다.

```
사용자: 클럽 멤버 목록 화면 만들어줘
사용자: /clarity
```

`/clarity`가 5차원(범위/입출력/엣지케이스/의존성/완료기준)으로 모호도를 점수화하고, 점수가 낮은 차원을 재질문한다. 모호도 PASS 후 구현 경로가 갈리면(실질 대안 ≥2) 2-3 접근법을 트레이드오프와 함께 제시하고 **추천 1개**를 표시해 선택받은 뒤 구현계획을 낸다(자명 단일이면 생략).

```
에이전트(clarity):
  모호도 62/100. 아래 확인 필요:
  - 정렬 기준? (가입일 / 이름 / 역할)
  - 페이지네이션 vs 무한스크롤?
  - 탭/검색 필요?
  - 멤버 클릭 시 동작?
```

#### 1c. 설계 의사결정 심문 — `/grill-me` (큰 플로우일 때)

답이 모이면 큰 플로우는 `/grill-me`로 의사결정을 끝까지 심문한다.

```
사용자: /grill-me
에이전트: 무한스크롤이라면 — 페이지 크기? 스크롤 위치 복원? 오프라인 캐시?
          각 분기에 권장안 제시하며 끝까지 추궁
```

> 도메인 용어가 모호하거나 진술이 코드와 어긋나면 `/grill-me`가 canonical 용어로 좁히고 모순을 그 자리에서 표면화한다. 아키텍처 결정 기록(ADR)은 Decision Placement Matrix 경로(`decisions/arch.md`)를 따른다.

---

### 단계 2 — 사양 확정: PRD + 설계 게이트

#### 2a. PRD 생성 → PawPad 등록

```
사용자: /to-prd
```

`/to-prd`가 대화를 PRD로 합성하고 다음을 자동 수행 (PawPad 흐름3):
- `.claude/pawpad/specs/club-member-list.md` 작성
- `.claude/pawpad/wip/club-member-list.md` lane 생성 (owner=기획 agent, **state=SPEC_READY**)
- `.claude/pawpad/_wip.md` Active Lanes 등록
- `.claude/pawpad/_meta.md` RECENT 1줄 추가

> `SPEC_READY`는 snapshot이 필요 없으므로 **`/handoff`가 아니다.** 구현 agent가 ON START에서 발견해 인수한다.

#### 2b. UI/UX 설계 게이트 (화면 작업이면 필수)

```
사용자: /design 클럽 멤버 목록 카드
```

`/design` 출력 (2-pass 워크플로우: 계획→자기비평→구현→재비평):
```
디자인 계획: 클럽 멤버 목록
0. 방향   : 정보밀도 우선 리스트형 — 사유: 스캔 속도 > 시각 임팩트 / 시그니처: 멤버 등급 액센트 배지
1. 토큰   : AppColors.surface / spacing 16 / Theme.textTheme.titleMedium / radius 8 / 높이 md 40  [추가 제안: 없음]
2. 위젯트리: Scaffold > AppBar > RefreshIndicator > ListView.builder > MemberCard
3. 반응형 : mobile=1열 / tablet=2열 Grid / web=3열 (LayoutBuilder)
4. 일관성 : 간격 ✓ / 크기 ✓ / 모양 ✓ / 정렬 ✓ / 상태 ✓
5. 원칙체크: 시각위계 ✓ / 여백 ✓ / 대비 ✓ / 접근성 ✓(48dp,Semantics) / 일관성 ✓ / 상태 ⚠
6. 미해결 : 빈 상태 일러스트 필요 여부
```

규칙:
- 색상/간격/타이포 **하드코딩 금지** → 토큰 사용, 누락 시 **추가 제안 후 승인 받고** 진행
- **모양·크기·간격은 스케일 토큰에서만 파생** (임의값 금지) — 정량 체크: spacing 임의값 0건·radius 고유값 <=4·같은 위계 컨트롤 높이 <=3. "AI 티=불일치" 차단
- 로딩/빈/에러/성공 **4상태 모두** 다룸 (정적 컴포넌트는 N/A 허용)
- 장기 디자인시스템 결정(새 token/breakpoint/재사용 widget/nav pattern)만 `decisions/arch.md`에 ADR로 기록. per-screen 배치는 spec에만.

#### 2c. 화면 시각화 — `/mockup` (메뉴 구조 확인, 코딩 전 재작업 방지)

```
사용자: /mockup all lo
```

`/mockup`이 PRD-tree를 **단일 HTML 목업**으로 투영한다:
- 화면별 `Feature ID` 라벨 + 메뉴/내비 위치 표현 → "이 기능이 **어느 메뉴에** 있는지" 코딩 전 확인
- **drift 검사**: PRD-tree ID 집합 ↔ 목업 화면 집합 비교 → 누락/고아 경고 (기획에 빠진 화면 발견)
- 기본 **lo-fi**(와이어프레임). 구조 확정되면 `/mockup all hi`로 **hi-fi**(design 토큰 적용)
- 산출물: `src/mockups/{feature-id}-mockup.html` — 브라우저로 비개발자도 검토

> PRD-tree가 SoT. 변경은 **트리 수정 후 목업 재생성**(목업→트리 역반영 X). 기획 단계에서 구조를 잡아 코딩 재작업을 줄인다.

#### 2d. 통합 4탭 검토 — `/mockup viewer` + `/viewer-apply` (PRD/명세/메뉴/와이어 한 화면)

```
사용자: /mockup viewer
        (브라우저에서 src/viewer/*.json 4탭 검토·편집·제자리 저장)
사용자: /viewer-apply
```

`/mockup`의 **viewer 모드**는 PRD-tree/spec을 `src/viewer/{prd,fts,userflow,wire}.json`으로 투영하고, 범용 `spec-viewer.html`(File System Access API)이 4탭(PRD / 기능명세서 / 메뉴구성도 / 와이어프레임)으로 띄운다:
- 폴더 1회 선택 → 자동 로드 → 편집(수정/삭제/추가) → **같은 파일 제자리 저장**(다운로드·백엔드 없음) → 재로드. 폴더 핸들은 IndexedDB에 기억되어 `↻ 다시 열기` 1클릭 복원
- **메뉴구성도** = 계층 트리 드래그앤드랍(순서·뎁스 재배치, 뎁스별 색), **와이어프레임** = 디바이스 프레임(mobile/web) + 컴포넌트 lo-fi
- 브라우저에서 결정을 마치면 `/viewer-apply`가 저장된 JSON을 읽어 **스팩에 동기** — JSON에 남은 항목은 spec 생성/갱신, 삭제한 항목은 spec에서 제거/아카이브(비파괴·confirm)

> PRD/명세가 바뀌면 agent는 **JSON만 수정**(뷰어 HTML 불변 → 토큰 절감). `src/viewer/*.json`은 ON START/resume 자동 로드 안 함(해당 작업 시점에만 on-demand).

---

### 단계 3 — 구현

구현 agent(같은 세션이거나 Codex)가 인수한다.

```
사용자(구현 세션): /resume
에이전트: club-member-list SPEC_READY 발견 → spec+lane read
          → 인수: state=WIP, owner=본인 으로 변경
```

코딩 중 사용하는 스킬:

```
/lean-code  ← 요청된 것만. 추가 추상화·범위 밖 파일 수정 금지 확인
/codemap    ← MemberCard / memberListProvider 위치 조회 (검색 없이)
/caveman    ← 압축 피드백 (기본 ON)
```

`/codemap`은 새 심볼을 등록하기도 한다:
```
ADD lib/features/club/widgets/member_card.dart : MemberCard (멤버 1명 카드)
ADD lib/features/club/providers/member_list_provider.dart : memberListProvider
```
> codemap 항목 **추가는 누구나**, 수정/삭제는 **lane owner만**.

#### 컨텍스트가 차오르면 (50~60%)

```
사용자: /checkpoint
에이전트: lane 파일 next-steps 갱신 + codemap 갱신 + _meta 1줄
```

토큰이 더 부족하거나 다른 에이전트로 넘길 때:

```
사용자: /handoff codex club-member-list "ListView 페이지네이션 구현 남음"
에이전트:
  - snapshot 작성: .claude/pawpad/handoffs/2026-05-29_1430_claude_to_codex_club-member-list.md
  - _wip.md: state=HANDOFF_TO_CODEX + handoff 필드
  - _meta.md RECENT 1줄
```
다음 세션(Codex)은 ON START에서 이 snapshot을 읽고 owner를 본인으로 바꿔 이어간다.

---

### 단계 4 — 완료 (Definition of Done)

CLAUDE.md의 DoD 8개가 **전부** 통과해야 완료:

```
1. analyze (스택의 analyze 명령)  → 에러 0
2. test (스택의 test 명령)        → 전부 green
3. 명시 범위 밖 파일 미수정
4. lane → wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md 이동
5. codemap/_index.md 신규/변경 심볼 갱신
6. (핸드오프 발생 시) handoffs/ snapshot 작성
7. lane `## Verification Evidence` 섹션에 검증 근거 기록 (분석전용/소작업은 `not applicable: analysis-only`)
8. 코드 변경 시 /security-check 🔴 zero (분석전용/문서전용 면제) — 검출 시 조치(env var 이관/마스킹) 후 재검증
```

완료 처리:
```
- lane 파일을 .claude/pawpad/wip/done/club-member-list_2026-05-29_153012.md 로 이동 (삭제 금지)
- .claude/pawpad/_wip.md Active Lanes에서 제거 + 완료 주석
- .claude/pawpad/_meta.md RECENT 1줄: "완료 club-member-list. [agent]"
- git commit (git repo일 때만; 비-git이면 _meta RECENT에 "git unavailable" 기록, 완료 차단 안 함)
```

---

### 단계 5 — 배포/동결 (Freeze)

기능/마일스톤이 리뷰까지 통과해 더 이상 변경하지 않을 때 **동결**한다. (이 하네스 자체도 버전별 STATUS: FROZEN으로 동결되는 방식과 동일)

```
1. 리뷰 통과 확인 (필요 시 교차 에이전트 리뷰 → handoffs/에 리뷰 보고서)
2. STATUS 마커를 FROZEN으로 전환 (해당 산출물의 버전/상태 헤더)
3. _meta.md RECENT에 "FREEZE 확정" 1줄 (충족도/근거 포함)
4. 완료 lane을 wip/done/에 보존
5. git commit + (권장) git tag {버전} (git repo일 때만)
```

> 동결 후 변경이 필요하면 **새 버전 번호 + 변경 보고서 + 리뷰**를 거친다. 동결본을 직접 고치지 않는다.

---

## 3. 스킬 체이닝 치트시트

```
■ 기획 → 구현 (가장 흔한 흐름)
  /brainstorming(막연한 아이디어면 — 발산·누락 스윕·스코프) → /clarity → /grill-me → /to-prd → /mockup → (통합 4탭 검토: /mockup viewer → /viewer-apply 로 스팩 동기) → (구현세션) /resume 인수 → /code-delegate(코딩 위임, 선택) → 코딩 → /security-check → /review(고위험) → DoD → /task-done(종결)

■ UI 화면 작업
  /brainstorming(신규 기능이면) → /clarity → /design → /to-prd → /mockup(lo→hi) → /code-delegate(코딩 위임, 선택) → 구현(/lean-code /codemap) → /security-check → /review(고위험) → DoD → /task-done(종결)

■ 순수 코드 작업 (사양 명확)
  /resume → /lean-code → /codemap → /caveman → /security-check → /review(고위험) → DoD → /task-done(종결)

■ 토큰 부족 / 에이전트 전환
  /checkpoint → /handoff {agent} {feature} {reason} → (새세션) /resume 인수

■ 세션 그냥 이어가기 (같은 owner)
  /checkpoint → 새 세션 → /resume → 재개

■ 작업 완료 후 세션 정리
  /task-done(lane 종결) → 새 세션 → /resume
  ※ task-done이 lane을 이미 닫았으면 /checkpoint 불필요 — checkpoint는 "작업 도중" 전용
```

### checkpoint vs handoff — 선택 기준

| 상황 | 선택 | 이유 |
|------|------|------|
| 같은 agent가 새 세션에서 계속 | `/checkpoint` | 저장만 (snapshot 없음, owner 유지, 저렴) |
| 다른 agent(Claude↔Codex)가 인수 | `/handoff {agent} {feature}` | snapshot + owner 이전 |
| 같은 agent지만 상태 복잡 (검증 실패 중·Known Issues 다수) | `/handoff next {feature}` | lane만으론 부족 — snapshot의 Next Commands가 가치 |
| 기능이 실제로 끝남 | `/task-done` | checkpoint/handoff 아님 — 종결 게이트 |
| 기획 완료 → 구현 대기 | (`/to-prd`가 `SPEC_READY` 설정) | handoff 아님 — snapshot 불필요, 구현 세션이 인수 |

> 인수 측 주의: handoff 수신 후 **owner를 본인으로 변경**(lane + `_wip.md`) + `_meta.md`에 ACCEPT 기록. 누락하면 다음 세션 Owner Mismatch 게이트가 복구하지만 대조 비용이 든다.

---

## 4. 협업(하이브리드) 핵심 규칙

| 규칙 | 내용 |
|------|------|
| 한 lane = 한 owner | 본인 lane만 수정. 타 lane은 읽기만. |
| `_wip.md`는 router | lane 등록/해제/state/owner 변경만. 작업 상세 금지. |
| codemap 권한 | 추가는 누구나 / 수정·삭제는 owner만 |
| 완료 lane | `wip/done/`로 **이동**(삭제 금지), timestamp로 재작업 보존 |
| 인수 시 | owner를 **반드시** 본인으로 변경 (누락 시 소유권 불명) |
| 파일 락 | `pubspec.yaml` 등 공유 파일 변경 시 `_wip.md` Locks 명시 |

State enum: `WIP` · `SPEC_READY` · `HANDOFF_TO_CODEX` · `HANDOFF_TO_CLAUDE` · `HANDOFF_TO_NEXT_AGENT` · `REVIEW_REQUESTED` · `REVIEW_DONE` · `BLOCKED`

---

## 5. 배포 체크리스트

이 하네스를 새 프로젝트에 적용할 때:

```
□ 프로젝트 루트에서  .\pawpad-setup.ps1 -Stack generic   실행
   (기존 파일 덮어쓰기: -Force / 기존 설치 업그레이드: -Upgrade — 둘 다 사용자 데이터 자동 백업됨.
    -Upgrade는 툴킷 파일만 갱신하고 PawPad·커스텀 영역 보존, CLAUDE/AGENTS/settings/config는 툴킷 섹션·키만 병합)
□ CLAUDE.md / AGENTS.md 의 Stack·Commands·Boundaries 를 실제 프로젝트에 맞게 수정
□ .claude/pawpad/_meta.md 의 STACK 줄 수정
□ .ctxdb/INDEX.md 키워드→L1 매핑 테이블을 프로젝트 도메인에 맞게 작성
□ .claude/HYBRID.md 읽고 협업 프로토콜 숙지
□ 기존 코드 있으면: "codemap/_index.md 초기값 만들어줘" / "codebase-map 7축 작성해줘" 요청
□ 21개 스킬이 인식되는지 확인 (/resume 등 호출)
□ 코드 변경 작업의 완료 전 /security-check 🔴 zero 확인 습관화 (DoD#8)
□ Codex 사용 시: /hooks 실행 → project-local hooks trust (1회)
□ 첫 작업: /clarity 부터 시작
```

설치 검증:
- `.claude/skills/*/SKILL.md` 21개 — no-BOM, `---` frontmatter로 시작해야 등록됨
- `.codex/config.json` skills 배열 21개
- `pawpad-setup.ps1` STATUS: FROZEN (v2.46 Unified Claude + Codex Distribution)
- setup 종료 시 전역 섀도잉 경고(⚠ ~/.codex/skills 동일 이름 스킬) 안 뜨는지 확인 — 뜨면 안내대로 백업 이동
- Claude hook: `.claude/settings.json` 에 SessionStart/UserPromptSubmit/PreCompact/Stop + statusLine 등록 (run-hook.ps1 경유, 다음 세션부터 동작)
- Codex hook: `.codex/hooks.json` (`/hooks` trust 후 동작)
- `docs/HOOK_TESTING.md` hook 회귀 체크리스트 동봉

> 상세 설치/검증은 [`README.md`](README.md) 참조.

---

## 부록 — 디렉토리 구조

```
.claude/
├── HYBRID.md              # 협업 프로토콜 (Decision Placement Matrix · Verification Evidence)
├── SKILLS_MANIFEST.md     # 스킬 카탈로그 (21)
├── settings.json          # Claude hooks 5종 (run-hook.ps1 경유, 절대+forward-slash)
├── pawpad-config.json        # 런타임 토글 (codemap.inject)
├── hooks/
│   ├── run-hook.ps1       # root-aware wrapper (하위 cwd에서도 repo root 실행)
│   ├── session-start.ps1  # state reset + codemap/.ctxdb INDEX 주입
│   ├── ctxdb-inject.ps1   # UserPromptSubmit: 키워드 L1/L2 최소주입 (dedupe)
│   ├── pre-compact.ps1    # PreCompact: compaction 직전 context-saver 유도
│   ├── stop-check.ps1     # Stop: 8턴 체크포인트 + L2 분할 품질강제
│   └── statusline.ps1     # ctx 사용%(+ .sh wrapper들)
├── skills/{21개}/SKILL.md  # 스킬 정의
├── codemap/_index.md      # 심볼 위치 레지스트리
└── pawpad/
    ├── _wip.md            # active lane router
    ├── _meta.md           # 이력 + STACK/SPRINT
    ├── specs/             # PRD 산출물
    ├── codebase/          # codebase-map 7축 (ARCH/STRUCT/CONV/TEST/CONCERNS + opt STACK/INTEG)
    ├── wip/{feature}.md   # 진행 중 lane
    ├── wip/done/          # 완료 lane (timestamp 보존)
    ├── handoffs/          # 인수인계 snapshot
    ├── reviews/           # 교차 에이전트 리뷰 보고서
    ├── verifications/     # 긴 검증 근거
    ├── decisions/arch.md  # ADR (장기 결정)
    └── backup/            # -Force/-Upgrade 시 자동 백업 (gitignore)
.ctxdb/                    # 키워드 depth 컨텍스트 DB (토큰 절약)
├── INDEX.md               # 키워드 → L1 매핑 + AGENT SYNC
├── L1/domain-*.md         # 도메인별 L2 포인터
├── L2/*.md                # 상세 (작업 내러티브/결정/codebase-map digest)
└── .state/                # turn-count/codex-turn-count/loaded/last-compact (gitignore)
CLAUDE.md / AGENTS.md      # 에이전트 컨텍스트 (read-only)
.codex/{config.json,config.toml,hooks.json,hooks/}  # Codex 어댑터 (native hooks)
.agents/skills/{21}/       # Codex repo skill mirror (DO NOT EDIT)
docs/HOOK_TESTING.md       # hook 회귀 체크리스트
pawpad-setup.ps1  # 통합 단일 설치 스크립트 (FROZEN v2.46)
```

상세는 각 `.claude/skills/{skill}/SKILL.md` 참조.
