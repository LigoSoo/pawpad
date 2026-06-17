# 프로젝트 설계→완성 워크플로 가이드

이 문서는 PawPad — Agentic Engineering Toolkit(v2.30 FROZEN)를 설치한 프로젝트에서, **하나의 기능/프로젝트를 기획부터 완성·배포까지** 진행하는 전체 절차와 각 단계의 스킬 사용 예시를 설명한다.

> 설치/배포 방법은 [`README.md`](README.md) 참조. 이 문서는 설치 후 **작업 워크플로** 중심이다.
> 대상 스택: 프리셋(flutter/node/python/generic) — 다른 스택도 `CLAUDE.md`의 `<YOUR_*>`만 채우면 동일 절차 적용
> 협업 모델: Claude Code ⇄ Codex 하이브리드 (파일 시스템 기반 상태 공유, 단독 사용도 가능)
> v2.20: 양 런타임 hook(SessionStart/UserPromptSubmit/PreCompact/Stop + Claude statusLine), `.ctxdb` 키워드 토큰절약 DB, **codebase-map 7축 고수준 맵**, 단일 통합 배포본
> v2.21: **security-check 보안 검증 게이트**(DoD#8, 🔴=완료 BLOCK), **-Upgrade 설치 모드**(사용자 데이터 보존 업그레이드), 전역 Codex 스킬 섀도잉 경고
> v2.22: **구조 코드명 KMS 완전 제거** — `.claude/pawpad/` + `pawpad-config.json` + codemap `pawpad:` 접두. v2.21 이하 설치본은 `-Upgrade`가 자동 마이그레이션 (ADR-002)
> v2.23: **설치 UI** — paw 배너 + 28단계 실시간 진행 바 + 실측 결과 체크리스트 (설치 내용물 무변경, Codex 교차 리뷰 PASS)
> v2.24: **설치 UI live 모드** — 진행 바 1줄 제자리 갱신 + 파일 로그 숨김(`-ShowLog`로 복원, 실패/경고는 항상 표시) + 배너 아트 보정
> v2.25: **lean-code rename** — 코딩 원칙 스킬 karpathy → lean-code(인물명 제거, `-Upgrade` 병합 시 구 섹션명 자동 마이그레이션) + 임베디드 템플릿 동기화(session-token-slim ON START 조건부 read·RECENT 8줄 로테이션, statusline ctx-accuracy)
> v2.26: **feature-architecture 구조 방법론** — feature-first 구조 규율 추가. CLAUDE/AGENTS `## Architecture Principles (Feature-First)` 항시 코어4(신규/변경 코드만) + DoD#9, 신규 `feature-architecture` 스킬(결정트리/anti-pattern/스택별 public boundary/프레임워크 관례 우선). `lean-code`(억제)와 소유권 분리. `-Upgrade` 병합 대상 섹션 포함
> v2.27: **Idea → PRD Routing + Active Skills 표시** — CLAUDE/AGENTS 항시 섹션. 아이디어→PRD 구체화 시 다음 스킬 추천(규모 판단→분해 / clarity 정보게이트 / grill-me 설계판단 조건부 / to-prd 문서화, 강제 X). 매 응답 `🐾 Active Skills` 라인으로 현재 스킬 표시. 동시에 doc/스킬 군살 제거(hook 내부설명·중복 프로토콜 포인터화, 출처장식/복붙 삭제 — actionable 무손실). `-Upgrade` 병합 대상 섹션 포함
> v2.28: **mockup 스킬 + 흐름 자동제안** — PRD-tree를 단일 HTML 목업(lo-fi 와이어프레임 / hi-fi 디자인)으로 시각화. 화면별 `Feature ID` 태깅 + 단방향 drift 경고(누락/고아), `src/mockups/` 출력. CLAUDE/AGENTS `Idea → PRD Routing`에 design/mockup 추천 + 단계경계 자동제안(거절 시 다음경계 침묵) + 선택지 질문=체크박스 추가. 신규 `mockup` 스킬(16→17). `-Upgrade` 병합 대상 섹션 포함
> v2.29: **review 스킬** — 문서형 크로스에이전트/세션 리뷰 라운드트립. /review로 request 작성→REVIEW_REQUESTED→다른 세션/에이전트가 직접 검증→result→REVIEW_DONE→수정. codex exec 자율 리뷰의 저토큰 보완. state 2종 추가, work owner 불변+reviewer 필드.
> v2.30: **Verification Evidence 아카이브 분리** — lane `## Verification Evidence`는 최근 2건만 유지, 초과분은 `.claude/pawpad/verifications/{feature-id}-archive.md` 상단 append(newest first) + 포인터 1줄. 소형 작업 ON START lane 비대 토큰 절감(audit-only 검증근거 핫패스 분리, 무손실 on-demand). DoD#7·Doc Update Rules 갱신 + HYBRID.md "Verification Evidence" 섹션 신설(기존 dangling 포인터 해소).

---

## 0. 한눈에 — 전체 라이프사이클

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ 0. 시작   │ → │ 1. 기획   │ → │ 2. 설계   │ → │ 3. 구현   │ → │ 4. 완료   │ → │ 5. 배포   │
│ 세션 재개 │   │ 모호도   │   │ UI/목업  │   │ 코드+상태 │   │ DoD+동결  │   │ freeze   │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
   /memory       /clarity       /design        /lean-code     DoD 8개        STATUS
                 /grill-me      /grill-me      /codemap       _wip→done      FROZEN
                 /to-prd        /to-prd        /caveman       _meta 기록     git tag
                                              /checkpoint
                                              /handoff
```

핵심 원리: **모든 상태는 파일에 산다.** 대화가 끊겨도, 에이전트가 바뀌어도(`Claude ⇄ Codex`), 컨텍스트가 가득 차도 — `.claude/pawpad/` 파일을 읽으면 정확히 이어서 작업할 수 있다.

---

## 1. 스킬 카탈로그 (18개)

### Core — 상태/코드 기반
| 스킬 | 언제 |
|------|------|
| `/memory` | **세션 시작마다**. `_wip.md`/lane/handoff/meta/codemap 읽고 작업 재개 |
| `/codemap` | 심볼(클래스/함수/위젯) **위치**를 검색 없이 조회. owner 분리 권한 |
| `/codebase-map` | **7축 고수준 맵**(아키텍처/구조/관례/테스트/관심사). codemap=위치, codebase-map=구조·관례. digest-only 주입 |
| `/ctxdb-navigator` | 세션시작 **키워드 매칭으로 최소 컨텍스트(L1≤1/L2≤2)만 로드** (토큰 절약) |
| `/context-saver` | 세션 작업을 `.ctxdb/L2`에 저장 + `INDEX.md` AGENT SYNC 갱신 |
| `/clarity` | 구현 전 **요청 모호도**를 5차원 스코어링, 명확해질 때까지 재질문 |
| `/design` | 화면/컴포넌트 구현 직전 **UI/UX 설계 게이트** (토큰→레이아웃→원칙) |
| `/mockup` | PRD-tree→단일 HTML 목업 시각화 (lo/hi-fi, Feature ID 태깅 + drift 경고). 화면이 어느 메뉴에 있는지 코딩 전 확인 |
| `/review` | 변경을 review-request 문서로 정리 → 다른 세션/에이전트(Codex↔Claude)가 직접 검증 리뷰 → result 반환. codex exec보다 저토큰 |
| `/lean-code` | 코드 작성 시 **과설계/범위 이탈 방지** 가드레일 (구 karpathy) |
| `/feature-architecture` | feature-first 구조 규율 (참조). 강제는 CLAUDE/AGENTS `Architecture Principles` |
| `/caveman` | 응답 압축 모드 (토큰 절감). 기본 ON, `normal mode`로 해제 |
| `/security-check` | **커밋/핸드오프/완료 직전 보안 검증** — secrets/취약점/위험 설정/PawPad 산출물 스캔. 🔴 검출 시 완료 BLOCK + 조치 제안 (DoD#8, 검출값 마스킹) |

### Workflow — 협업/기획
| 스킬 | 언제 |
|------|------|
| `/grill-me` | 계획/설계를 **재귀 심문**으로 스트레스 테스트 |
| `/grill-with-docs` | 위와 같되 **프로젝트 용어집 + ADR**(`decisions/arch.md`) 갱신 |
| `/to-prd` | 대화를 **PRD로 변환** → `specs/`에 저장 + lane `SPEC_READY` 등록 |
| `/checkpoint` | 컨텍스트 **50~60% 도달** 시 lane/codemap/meta 저장 (롤오버 게이트) |
| `/handoff` | 다른 에이전트/세션으로 **인수인계** (snapshot + owner 이전) |

> ⚠️ 이 스킬들은 PowerShell 명령이 아니라 **instruction**이다. 에이전트가 SKILL.md 절차를 따라 파일을 읽고 쓴다.

---

## 2. 단계별 절차 + 스킬 사용 예시

아래는 가상의 기능 **"클럽 멤버 목록 화면"**(`feature-id: club-member-list`)을 처음부터 끝까지 진행하는 실전 워크스루다.

---

### 단계 0 — 세션 시작 (ON START)

새 세션을 열면 **무조건 먼저** 상태를 읽는다.

```
사용자: /memory
```

에이전트가 순차 수행:
0. `.ctxdb/INDEX.md` — 첫 메시지 키워드 매칭 → L1≤1/L2≤2만 로드 (Claude는 SessionStart hook이 codemap+INDEX 자동 주입; Codex는 직접 read)
1. `.claude/HYBRID.md` (협업 프로토콜)
2. `.claude/pawpad/_wip.md` (active lane router)
3. 배정된 lane 있으면 `.claude/pawpad/wip/{lane}.md`
4. `state=HANDOFF_TO_*` 발견 시 → `handoff` 경로 read
5. `state=SPEC_READY` 또는 spec 있으면 → `specs/{feature}.md`
6. `.claude/pawpad/_meta.md` (최근 이력)
7. `.claude/codemap/_index.md` (심볼 위치)

> 결과: "지난 세션에 club-member-list가 SPEC_READY 상태로 남아있음. spec 읽고 구현 인수하겠음" 처럼 **끊김 없이 재개**.

---

### 단계 1 — 기획: 요청을 명확하게

막연한 요청("멤버 목록 보여줘")을 구현 가능한 사양으로 좁힌다.

```
사용자: 클럽 멤버 목록 화면 만들어줘
사용자: /clarity
```

`/clarity`가 5차원(범위/입출력/엣지케이스/의존성/완료기준)으로 모호도를 점수화하고, 점수가 낮은 차원을 재질문한다.

```
에이전트(clarity):
  모호도 62/100. 아래 확인 필요:
  - 정렬 기준? (가입일 / 이름 / 역할)
  - 페이지네이션 vs 무한스크롤?
  - 탭/검색 필요?
  - 멤버 클릭 시 동작?
```

답이 모이면 큰 플로우는 `/grill-me`로 의사결정을 끝까지 심문한다.

```
사용자: /grill-me
에이전트: 무한스크롤이라면 — 페이지 크기? 스크롤 위치 복원? 오프라인 캐시?
          각 분기에 권장안 제시하며 끝까지 추궁
```

> 도메인 용어/아키텍처 결정이 얽히면 `/grill-with-docs`를 써서 용어집과 `decisions/arch.md` ADR을 **그 자리에서 갱신**한다.

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

`/design` 3단계 출력:
```
디자인 계획: 클럽 멤버 목록
1. 토큰   : AppColors.surface / spacing 16 / Theme.textTheme.titleMedium  [추가 제안: 없음]
2. 위젯트리: Scaffold > AppBar > RefreshIndicator > ListView.builder > MemberCard
3. 반응형 : mobile=1열 / tablet=2열 Grid / web=3열 (LayoutBuilder)
4. 원칙체크: 시각위계 ✓ / 여백 ✓ / 대비 ✓ / 접근성 ✓(48dp,Semantics) / 일관성 ✓ / 상태 ⚠
5. 미해결 : 빈 상태 일러스트 필요 여부
```

규칙:
- 색상/간격/타이포 **하드코딩 금지** → 토큰 사용, 누락 시 **추가 제안 후 승인 받고** 진행
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

---

### 단계 3 — 구현

구현 agent(같은 세션이거나 Codex)가 인수한다.

```
사용자(구현 세션): /memory
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
  /clarity → /grill-me → /to-prd → /mockup → (구현세션) /memory 인수 → 코딩 → /security-check → /review(고위험) → DoD → done

■ UI 화면 작업
  /clarity → /design → /to-prd → /mockup(lo→hi) → 구현(/lean-code /codemap) → /security-check → /review(고위험) → DoD

■ 순수 코드 작업 (사양 명확)
  /memory → /lean-code → /codemap → /caveman → /security-check → /review(고위험) → DoD

■ 토큰 부족 / 에이전트 전환
  /checkpoint → /handoff {agent} {feature} {reason} → (새세션) /memory 인수

■ 세션 그냥 이어가기 (같은 owner)
  /checkpoint → 새 세션 → /memory → 재개
```

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
□ 18개 스킬이 인식되는지 확인 (/memory 등 호출)
□ 코드 변경 작업의 완료 전 /security-check 🔴 zero 확인 습관화 (DoD#8)
□ Codex 사용 시: /hooks 실행 → project-local hooks trust (1회)
□ 첫 작업: /clarity 부터 시작
```

설치 검증:
- `.claude/skills/*/SKILL.md` 18개 — no-BOM, `---` frontmatter로 시작해야 등록됨
- `.codex/config.json` skills 배열 18개
- `pawpad-setup.ps1` STATUS: FROZEN (v2.30 Unified Claude + Codex Distribution)
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
├── SKILLS_MANIFEST.md     # 스킬 카탈로그 (18)
├── settings.json          # Claude hooks 5종 (run-hook.ps1 경유, 절대+forward-slash)
├── pawpad-config.json        # 런타임 토글 (codemap.inject)
├── hooks/
│   ├── run-hook.ps1       # root-aware wrapper (하위 cwd에서도 repo root 실행)
│   ├── session-start.ps1  # state reset + codemap/.ctxdb INDEX 주입
│   ├── ctxdb-inject.ps1   # UserPromptSubmit: 키워드 L1/L2 최소주입 (dedupe)
│   ├── pre-compact.ps1    # PreCompact: compaction 직전 context-saver 유도
│   ├── stop-check.ps1     # Stop: 8턴 체크포인트 + L2 분할 품질강제
│   └── statusline.ps1     # ctx 사용%(+ .sh wrapper들)
├── skills/{18개}/SKILL.md  # 스킬 정의
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
.agents/skills/{18}/       # Codex repo skill mirror (DO NOT EDIT)
docs/HOOK_TESTING.md       # hook 회귀 체크리스트
pawpad-setup.ps1  # 통합 단일 설치 스크립트 (FROZEN v2.30)
```

상세는 각 `.claude/skills/{skill}/SKILL.md` 참조.
