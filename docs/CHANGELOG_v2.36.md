# CHANGELOG v2.36 — 통합 기획 뷰어 (데이터-구동, no-backend)

> 날짜: 2026-06-23 | 이전: v2.35 (resume 최소로드) | feature-id: unified-spec-viewer
> 프로세스: 멀티에이전트 분석 2R → grill-me(Q1–Q8) → to-prd → code-delegate → 반복 구현·사용자 피드백 → /review.
> (단일 기능을 만드는 과정에서 설계가 여러 번 다듬어졌고, 최종 결과를 v2.36 한 버전으로 통합 릴리스.)

## 요약
기획 문서(PRD / 기능명세서 / 유저플로우 / 와이어프레임)를 **한 HTML의 4탭**으로 보고 편집하는 통합 뷰어. 뷰어는 **데이터 비종속**(HTML에 데이터 안 박음) — 외부 JSON 파일을 읽어 띄우고, 편집을 같은 파일에 **제자리 저장**한다. 백엔드 없음. 스킬 19→20(viewer-apply).

## 뷰어 — `.claude/skills/mockup/spec-viewer.html`
- 범용·고정·데이터 비종속. setup 임베드로 배포(프로젝트마다 HTML 재생성 없음).
- **File System Access API**: Chrome/Edge로 열고 **폴더 1회 선택** → 고정명 JSON 4개 자동 로드 → 편집 → 제자리 저장(덮어쓰기, 다운로드·서버 없음) → 재로드.
- (file://에서 FS API 막히면 localhost 정적 서빙 — 저장은 브라우저가, 커스텀 백엔드 아님.)
- 4탭 렌더: PRD(문단) · 기능명세서(CSS 수평 트리, 그룹──트렁크┬─leaf 연결선) · **메뉴구성도**(메뉴 계층 트리 + 드래그앤드랍으로 순서·뎁스 재배치, 뎁스별 색·사이클 가드) · **와이어프레임**(화면별 디바이스 프레임 mobile/web + 컴포넌트 lo-fi UI, 검토·조정 전용).
- 폴더 핸들 IndexedDB 기억 → `↻ 다시 열기` 1클릭 복원 + `startIn` 마지막 폴더 시작 + readwrite 권한 일괄(임의 절대경로 자동열기는 브라우저 보안상 불가).

## 데이터 — `src/viewer/{prd,fts,userflow,wire}.json` (고정명, JSON, 프로젝트 로컬)
- agent가 읽고/쓰는 SoT. PRD/명세 변경 = agent가 **JSON만 수정**(HTML 불변 → 토큰 절감).
- `/mockup viewer`가 프로젝트 PRD-tree/spec에서 4 JSON 생성·갱신.
- **ON START/resume 자동 로드 금지** — 기획/구현 작업 시점에만 on-demand read(초기 기획 강화로 후속 수정 최소화 + context 비대화 방지).

## 편집 의미
- **항목 존재 = 설계/개발 대상**. 사용자가 불필요한 항목을 **삭제**하면 제외. 별도 "승인" 액션 없음(사용자 액션 = 수정/삭제/추가).
- **상태(예정/진행중/완료)**: 실제 개발 진행 가시화 전용. agent가 구현하며 status 갱신, 사용자 편집 X(읽기전용 표시).

## 신규/변경 스킬
- **viewer-apply(신규, 19→20)**: 뷰어가 저장한 JSON(src/viewer/*.json)을 읽어 스팩 동기 — 남은 항목→spec 생성/갱신, 삭제 항목→spec 제거/아카이브(confirm·비파괴). 저장된 JSON이 곧 SoT.
- **mockup viewer 모드**: `/mockup viewer` → 데이터 JSON 생성/갱신(뷰어 HTML 불변).

## 전파 표면
- `.claude/skills/mockup/spec-viewer.html`(live + setup 임베드) · `src/viewer/*.json`(데모 데이터).
- `mockup`·`viewer-apply` SKILL(live + setup 임베드 + `.agents` 미러).
- CLAUDE.md/AGENTS.md: 읽기 규율(src/viewer/*.json 자동로드 금지 + 존재=대상 + status 3값) + Doc Rules 유저플로우 행(src/viewer/userflow.json) — live + setup `$tmpl` 임베드.
- `.claude/SKILLS_MANIFEST.md`(20) · `.codex/config.json`(20) · codemap.
- 버전 v2.36(setup `$ver`/헤더/STATUS · PAWPAD_VERSIONS · README·GUIDE·USAGE).

## 검증
- PSParser(setup) 0 · embed==live(spec-viewer·mockup·viewer-apply) · live==mirror(mockup·viewer-apply) · 스킬 20 · spec-viewer self-contained(외부참조 0)·JS parse OK · 4 JSON valid·무BOM(status done/prog/todo만) · secrets 0.
- 리뷰: Claude 독립 서브에이전트(EDR-safe) PASS — findings(데모 JSON approved 잔재) 반영 완료(`reviews/viewer-data-driven-review-01.md`, `unified-spec-viewer-review-01.md`).
- 사용자 브라우저 확인: 로드·편집(수정/삭제/추가)·제자리 저장 동작 OK.

## 워크플로우 내 위치 (아이디어 → 코딩)
```
아이디어 → [분해] → clarity → [grill-me/grill-with-docs] → to-prd → [design]
        → /mockup viewer (PRD-tree/spec → src/viewer/*.json 생성)
        → 🖥 spec-viewer 4탭 시각 확정(메뉴구성도 드래그 재배치·와이어 검토) → /viewer-apply (JSON → 스팩 동기)
        → code-delegate(구현, status 갱신) → [review] → DoD → done
```
- 핵심: 문서만으론 안 보이던 메뉴 구성·화면 UI를 **코딩 전에 4탭으로 시각 확정** → 재작업 방지. 비개발자도 브라우저로 검토.

## 재설계 (동일 v2.36 통합)
- 초기 v2.36은 유저플로우=자체 SVG 그래프 / 와이어=기능 목록이었으나, 사용자 검토 결과 **엣지 그래프는 흐름 파악이 어렵고 와이어는 실제 UI가 아니라** 의도와 어긋남.
- 재설계: 유저플로우 → **메뉴구성도(계층 트리 + 드래그앤드랍 재배치 + 뎁스 색)**, 와이어 → **컴포넌트 스키마 기반 디바이스 lo-fi UI**. 스키마 전환: `userflow.json` {nodes,edges}→{root,tree[]}, `wire.json` {screens}→{frame,components[]}. 데모 데이터 신스키마 재생성. 스킬 수 불변(20).
- 설계 문서: `.claude/pawpad/specs/spec-viewer-v2.md`.

## 비고
- 빌드 과정 audit(중간 단계 lane/review)는 `.claude/pawpad/wip/done/`·`reviews/`에 보존.
