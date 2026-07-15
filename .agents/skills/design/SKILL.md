---
name: design
description: Framework-neutral UI/UX design gate. Use before or while building a screen/component to lock design-system tokens, enforce visual consistency (spacing/size/shape scales derived from tokens only, anti-slop), structure the responsive layout, and review against UI principles with quantitative checks. Use when user mentions UI, layout, screen design, styling, visual polish, or "design this".
---

# DO NOT EDIT: generated from .claude/skills/design/SKILL.md by pawpad-setup.ps1.
# Design Gate Skill - UI/UX 설계·시각 품질 게이트 (프레임워크 중립)

## 목적
화면/컴포넌트 구현 전·중에 한 번에:
(1) 디자인 방향·토큰 고정, (2) 반응형 레이아웃 구조 설계, (3) 시각 일관성 시스템 강제, (4) anti-slop·UI 원칙 검토.
clarity가 "무엇을 만드나"를 좁힌다면, design은 "어떻게 보이고 배치되나"를 좁힌다.
핵심 인식: **"AI 티"는 화려함이 아니라 불일치에서 온다.** 간격이 제각각(13px, 17px…)이고 radius가 섞이고 버튼 높이가 화면마다 다르면 아마추어·AI 결과물로 읽힌다. 일관성이 이 스킬의 1순위 품질 지표.
프레임워크(Flutter/React/Vue/네이티브/웹 등)는 프로젝트의 것을 따른다 — 이 스킬은 도구 중립.

## 최상위 3원칙
1. **Consistency First** — 모양(shape)·크기(size)·간격(spacing)은 정의된 스케일 토큰에서만 파생. 임의값(arbitrary value) 금지.
2. **Intentional Direction** — 코드 전에 디자인 방향을 명시적으로 선택하고 사유를 기술.
3. **Anti-slop** — 제네릭 기본값·과용 폰트·불일치 패턴 차단.

## 성격
Instruction skill. PowerShell command 아님. 에이전트가 절차를 따라 설계안을 출력.

## 트리거
/design [화면/컴포넌트 설명]
- 예: /design 로그인 화면
- 예: /design 회원 목록 카드
- 자동 진입: 외부 문서 구현 진입 게이트에서 문서가 UI/화면을 포함하면 1회 추천됨 (CLAUDE.md/AGENTS.md). mockup hi-fi는 이 스킬의 토큰을 재사용.

## 워크플로우 (2-pass: 계획 → 자기비평 → 구현 → 재비평)

### 1단계 — 방향 + 토큰 시스템 확정
- **방향 선언 1줄 + 사유** (Intentional Direction). 아래 anti-slop 경계 기본값과 겹치면 브리프 명시 여부 확인 후 진행.
- **기존 프로젝트**: 토큰 소스 확인/고정 (하드코딩 금지) — 색상 토큰/팔레트(raw hex 금지), 문자열/i18n 리소스, 스페이싱 스케일, 타이포 토큰, 기존 공용 컴포넌트 재사용(codemap/_index.md 확인). 누락 토큰은 임의 하드코딩 말고 **토큰 추가 제안** 후 진행.
- **토큰 없음(신규 프로젝트)**: 부트스트랩 초안 제안 — spacing scale(4px 베이스: 4·8·12·16·24·32·48·64), 컨트롤 높이(sm 32/md 40/lg 48), radius scale, shadow elevation(e1~e3), 색상 4~6 named hex(neutral + accent 1), 타입 스케일(1.25 모듈러), 시그니처 요소 1개.
- **자기비평**: 초안을 브리프와 대조 — 스케일 단계 과다·혼용·제네릭 기본값 겹침이 있으면 수정하고 사유 기술.

### 2단계 — 레이아웃 구조 설계
- 컴포넌트 트리 스케치: 루트 컨테이너 > 헤더/본문 > 핵심 컴포넌트 계층 (각 노드 책임 한 줄)
- 반응형: 고정 breakpoint 세트(예: mobile < 600 / tablet 600-1024 / desktop > 1024), 뷰포트/컨테이너 쿼리 필요 여부
- 그리드: 명시적 컬럼(예: 12컬럼) + gutter 통일. 반복 카드/리스트는 동일 정렬·동일 간격.
- 상태 연결: 프로젝트 상태관리(store/provider/hook) 연결점 (codemap 참조, read/write 구분)

### 3단계 — 일관성 시스템 (5축, 토큰 파생 강제) ★
| 축 | 규칙 |
|----|------|
| 간격 | 단일 spacing scale만 사용 — margin/padding/gap에 임의값(13px, p-[17px]) 금지. 컴포넌트 내부 < 요소 간 < 섹션 간 단계 구분 + 수직 리듬 일정 |
| 크기 | 컨트롤 높이 스케일 고정 — 같은 위계의 버튼·인풋·셀렉트는 같은 높이. 아이콘 크기 스케일(16/20/24) 고정. 폰트 크기는 모듈러 타입 스케일에서만 파생. 터치 타깃 >=44px |
| 모양 | radius 단일 체계 — 카드/버튼/인풋/모달 혼용 금지. border 두께 1값. shadow는 elevation 단계(e1/e2/e3)만 — 매번 새 값 금지. 아이콘 outline/filled·stroke width 통일 |
| 정렬 | 그리드/베이스라인 정렬, 광학 정렬 고려. 반복 요소는 동일 정렬·동일 간격 |
| 상태 | 같은 컴포넌트는 어디서나 같은 모양. hover/focus/active/disabled를 전 인터랙티브 요소에 동일 규칙. transition 150~300ms·easing 통일 |

**토큰 우선(Token-first)**: 위 값 전부(spacing/size/radius/border/shadow/duration) 먼저 토큰으로 정의(CSS 변수 / Tailwind theme / Flutter ThemeData 등 스택 관례) → 이후 raw 값 작성 금지. 새 값 필요 시 토큰 추가 후 그 토큰 참조.

### 4단계 — 검토 (anti-slop + UI 원칙 + 정량)

#### anti-slop 체크
- **불일치 = AI 티 (최우선 차단)**: 임의 간격 혼재·radius 혼용·컨트롤 높이 제각각·그림자 매번 새 지정 → 발견 즉시 스케일로 정규화.
- 과용 폰트 회피(신규 선택 시): Inter/Roboto/Arial/Space Grotesk. 기존 프로젝트가 이미 채택한 폰트는 존중(토큰 우선).
- 경계 기본값 3종(브리프가 명시하지 않는 한 회피): ①크림 배경+고대비 serif+테라코타 액센트 ②near-black+단일 acid 액센트 ③broadsheet(hairline·radius 0·밀집 컬럼).
- 금지 패턴: 서사 없는 캐러셀 / 제네릭 SaaS 카드 그리드 첫인상 / 실제 시퀀스 아닌 numbered marker(01/02/03) / 이모지 아이콘(SVG 사용) / 목적 없는 그라디언트·보라 남발 / 과도한 애니메이션.

#### UI 원칙 체크 (6항목)
| 원칙 | 확인 |
|------|------|
| 시각 위계 | 주요 액션/정보가 크기·색·위치로 우선 표현되나 |
| 여백·정렬 | 스페이싱 스케일 일관, 정렬 그리드 준수 |
| 대비·가독성 | 텍스트 대비 WCAG AA(4.5:1) 충족 (라이트/다크 양쪽) |
| 접근성 | 터치 타깃 충분(>=44~48px), 접근성 라벨, focus ring 가시성, 폰트 스케일 대응 |
| 일관성 | 기존 화면 패턴과 일치, 컴포넌트 재사용 |
| 상태 표현 | 로딩 / 빈 / 에러 / 성공 4상태 모두 다룸 |

#### 정량 체크 (검증 가능 assertion)
- spacing 임의값 0건 (전부 스케일 소속)
- radius 고유값 <=4 / 같은 위계 컨트롤 높이 고유값 <=3
- 폰트 크기 전부 타입 스케일 파생 / shadow는 elevation 토큰 외 0건
- 구현 후 **재비평(2nd pass)**: 정렬 어긋남·간격 불규칙·radius 혼용·버튼 높이 차이를 우선 점검 + 품질 플로어(반응형·focus·prefers-reduced-motion) 확인.

## 출력 포맷
```
디자인 계획: {화면명}
0. 방향   : {1줄} — 사유: {1줄} / 시그니처: {요소 1개}
1. 토큰   : 색상/간격/타이포/radius/높이/elevation [사용 토큰], [추가 제안]
2. 컴포넌트트리: 루트 > ... (계층 + 책임)
3. 반응형 : [breakpoint별 레이아웃 변화]
4. 일관성 : 간격 ✓ / 크기 ✓ / 모양 ✓ / 정렬 ✓ / 상태 ✓ (위반 시 항목 + 정규화 방안)
5. 원칙체크: 시각위계 ✓ / 여백 ✓ / 대비 ⚠ / 접근성 ✓ / 일관성 ✓ / 상태 ⚠
6. 미해결 : [확인 필요 항목]
```

## 원칙
- 새 색상/간격/타이포 임의 도입 금지 → 토큰 추가는 명시적 제안 후.
- 모양·크기·간격은 토큰에서만 파생 — 임의값 0건이 완료 조건.
- 기존 공용 컴포넌트 재사용 우선 (codemap/_index.md 확인).
- 4상태(로딩/빈/에러/성공) 누락 금지.
- 페이지당 시그니처 요소 1개 집중. 목적 있는 모션만, prefers-reduced-motion 존중.
- lean-code 적용: 요청된 화면만, 과한 애니메이션/추상화 금지. 스케일 단계 수도 필요 이상 늘리지 않는다.
- 모든 플랫폼 공통: 반응형 breakpoint 명시. 고정 px 레이아웃 지양.

## 선택지 질문 규칙
방향·토큰 부트스트랩·레이아웃 등 사용자 결정 선택지는 AskUserQuestion(체크박스)로 받는다 — 추천 1개 첫 배치 + 라벨 끝 "(추천)" + 근거. 옵션 최대 3개(초과 발산 시 추천 근거로 상위 3개 shortlist). 자유서술·수치 입력은 텍스트.

## 후속 산출물 / PawPad 등록
design 통과 후 spec 필요 시 **to-prd와 동일한 PawPad 등록 절차** 따름 (specs 작성 + lane SPEC_READY + _wip/_meta 등록 + 구현 agent 인수). 상세: to-prd skill. spec에 디자인 계획 포함. SPEC_READY는 snapshot 불필요(`/handoff` 아님).
- _meta.md RECENT 예시(design 맥락): "YYYY-MM-DD: SPEC_READY {feature-id}. 디자인 계획 작성 완료. [agent]"

### 디자인 ADR 기준
- per-screen 배치 결정 → spec에만 기록 (ADR 아님)
- 장기 디자인 시스템 결정(새 token / scale / breakpoint / 재사용 공용 컴포넌트 / navigation pattern)만 `.claude/pawpad/decisions/arch.md`에 append

## 파이프라인 관계
- brainstorming : 기능 발산·스코프 확정 — 기획 최상류 (brainstorming → clarity → grill-me → to-prd)
- clarity : 요청 모호도(기능 정의) 게이트 — design 앞 단계.
- grill-me : 설계 의사결정 심문 — 큰 화면/플로우 설계 시 병행.
- design : 방향·토큰·레이아웃·일관성 게이트 — 화면 구현 직전.
- mockup : PRD-tree 시각 투영(단일 HTML) — hi-fi는 design 토큰 재사용. 신규 토큰 임의 도입 금지(design 절차 경유).

