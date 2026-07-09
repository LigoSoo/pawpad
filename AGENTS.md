# AGENTS.md
# Tool: OpenAI Codex Agent | Stack: <YOUR_STACK>
# Edit Commands / Directories / Conventions to match your project.

## Setup / Commands
- Install:     <YOUR_INSTALL_CMD>
- Dev:         <YOUR_DEV_CMD>
- Test:        <YOUR_TEST_CMD>
- Test single: <YOUR_TEST_SINGLE_CMD>
- Analyze:     <YOUR_ANALYZE_CMD>
- Lint:        <YOUR_LINT_CMD>
- Build:       <YOUR_BUILD_CMD>

## Definition of Done
Task complete when ALL pass:
1. Analyze (Commands의 Analyze) - zero errors
2. Test (Commands의 Test) - all green
3. No files outside stated scope modified
4. lane 파일 갱신 또는 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동
5. .claude/codemap/_index.md updated for new/changed symbols
6. 핸드오프 발생 시 .claude/pawpad/handoffs/ snapshot 작성
7. lane `## Verification Evidence`에 검증 근거 기록 — 최근 2건만 lane 유지, 초과분은 .claude/pawpad/verifications/{feature-id}-archive.md 상단 append + 포인터 1줄 (분석전용/소작업은 `not applicable: analysis-only`). 규칙: .claude/HYBRID.md Verification Evidence.
8. 코드 변경 시 /security-check 🔴 zero (분석전용/문서전용 면제). 규칙: .agents/skills/security-check/SKILL.md
9. 코드 변경 시 신규/변경 코드가 Architecture Principles (Feature-First) 준수 (분석/문서전용 면제). 규칙: .agents/skills/feature-architecture/SKILL.md

## Escalation Rules
- Stuck > 3 attempts same error: STOP, report findings
- Scope unclear: ASK before touching new files
- Destructive op (DROP/DELETE/rm -rf): STOP, confirm
- Credential required: STOP - use env var reference

## Boundaries
NEVER modify:
- <BUILD_OUTPUT_DIR>      (예: dist/, build/, target/)
- <LOCKFILE> (without instruction)
- <GENERATED_DIR>

NEVER run without confirm:
- Production deploy / release
- Database migration or deletion scripts
- Destructive data scripts

## Directories
<YOUR_PROJECT_STRUCTURE>
(예시:)
src/
├── ...
└── ...

## Conventions
- <YOUR_CODE_CONVENTIONS>
- (예: 파일 명명 규칙, 타입 정책, 로깅 정책, 상수 정책)

## Coding Principles (Lean Code)
1. Implement only what is asked. No extra abstractions.
2. Do not modify files outside stated scope.
3. Read existing code before writing new code.
4. When scope is unclear, ask before implementing.

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
| 검증 결과        | lane `## Verification Evidence` 최근 2건, 초과분 → .claude/pawpad/verifications/{feature-id}-archive.md (상단 append) |
PRD 상세 read: PRD-tree(인덱스) → lane feature-id 접두로 영역 해석 → 해당 src/prd/{area}.md만 (✓완료 영역 skip, 부족 시 on-demand). PRD-tree 영역 행에 상태 마커 ✓완료/🔨진행/⬜예정.
뷰어 데이터(src/viewer/*.json: prd/fts/userflow/wire)는 ON START/resume 자동 로드 금지 — /mockup viewer·/viewer-apply 등 해당 작업 시점에만 on-demand read(초기 기획 강화로 후속 수정 최소화·context 절감). 항목 존재=설계/개발 대상, status(예정/진행중/완료)는 agent가 구현하며 갱신.
Code + doc update = one atomic unit. Keep * markers accurate.

## Session Protocol
ON START (agent가 순차 실행):
  0. read .ctxdb/INDEX.md -> 첫 메시지 키워드 매칭 -> L1<=1 / L2<=2개만 로드 (전체 로드 금지)
     (첫 응답 최상단에 검증 1줄: 📂 ctxdb: {project} | {last-date} | {loaded L2} | {status})
  1. read .claude/pawpad/_wip.md (active lane router)
  2. Active Lanes 있으면 read .claude/HYBRID.md (협업 프로토콜). 없으면 skip -> 신규 lane 생성/핸드오프/인수 시점에 read
  3. assigned lane 있으면 read .claude/pawpad/wip/{lane}.md + stale 게이트(다음 작업 제안 전 완료 흔적·실상태 1회 대조 -> 종결/확인 제안. 규칙: resume SKILL Lane 신뢰성 게이트)
  4. _wip.md Active Lanes에 state=HANDOFF_TO_* 발견 시 -> handoff 필드 경로 read
  5. state=SPEC_READY 또는 spec 있으면 read .claude/pawpad/specs/{feature}.md
  6. read .claude/pawpad/_meta.md 상단만 (헤더 SPRINT/PHASE/STACK + BLOCKED + NEXT; RECENT 완료이력은 하단·재개 불요 -> 생략, history 시 on-demand)
  7. .claude/codemap/_index.md는 코드 수정 작업 시작 시점에 read — MAP+HOT(조망)만 부분읽기(상단), INDEX(전체 심볼표)는 심볼 필요 시 Grep on-demand (질문/분석 전용 세션은 skip)
ON SUBTASK DONE: agent가 lane 파일 next steps 갱신
ON TASK DONE:    agent가 lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 + _meta.md 1줄 append (RECENT 8줄 초과 시 초과분을 sessions/{YYYY-MM}.md 상단으로 이동, newest first 유지) + 완료(✅) 작업항목 누적 시 verifications/{feature-id}-tasklog.md 이월(HYBRID Completed Task Log) + _index.md 갱신 + git commit (git repo일 때만; 비-git이면 _meta RECENT에 "git unavailable" 기록, 완료 차단 안 함) — 실행은 task-done 스킬 체크리스트로(부분 실행/누락 방지; "작업/이슈 종료" 자연어 요청 = task-done 발동)
ON STOP:         agent가 lane 파일 (state + reason) 갱신
ON 8턴/60% CONTEXT:
  - Claude Code: Stop hook이 8턴마다 checkpoint block -> context-saver(.ctxdb/L2 저장) + codemap 갱신.
  - Codex: `.codex/hooks.json` Stop hook이 trust된 경우 8턴마다 checkpoint continuation -> context-saver + codemap 갱신.
           hook 미신뢰/비활성 시 수동 수행.
  - 공통: 60% 시 /checkpoint -> 필요시 /handoff {to-agent} {feature}

## Codex 주의 (native hook adapter)
- `.agents/skills/*/SKILL.md` = Codex skill mirror (Claude `.claude/skills/*`와 동일 절차). hook은 `.codex/hooks.json` 정의, `/hooks`로 review/trust해야 자동 실행. `.codex/config.toml`은 안내 주석만.
- SessionStart: `.ctxdb/.state/codex-turn-count`·`codex-loaded` reset.
- UserPromptSubmit: INDEX keyword 매칭 → L1<=1/L2<=2 로드(session dedupe). injectMode(pawpad-config.json ctxdb): pointer(기본)=read 지시만 주입→**agent 즉시 read 필수**, full=본문. codemap HOT/match 추가(codemap.inject auto/on/off). explicit fallback(progress-current)은 재개 의도어만.
- PreCompact: compaction 직전 context-saver + `codex-last-compact` 기록(Stop 8턴과 중복 방지). Stop: `codex-turn-count` 카운트, 8턴/L2 초과 시 context-saver 요구.
- `.codex/hooks/*.sh`는 `pwsh` 필요; 부재 시 ctxdb-inject skip·나머지 `{}` 반환. `turn-count`=Claude 전용, Codex=`codex-turn-count`.
- hook 미신뢰/비활성 시 수동: ctxdb 로드(step0 INDEX read) + 저장(8턴/종료/60% context-saver) + codemap(read+갱신).

## Hybrid Lane Rule
- 신규 작업: .claude/pawpad/wip/{feature-id}.md 생성 + _wip.md Active Lanes 등록
- 본인 lane만 수정. 타 에이전트 lane 읽기 가능, 수정 금지.
- _wip.md Locks 섹션에서 파일 경로 매핑 확인.
- codemap/_index.md: 추가는 누구나, 수정/삭제는 lane owner만.
- 완료 lane: wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 (삭제 금지, audit 보존, timestamp로 재작업 보존)
- 핸드오프 수신 시: state HANDOFF_TO_* -> WIP, owner -> 받는 agent로 변경
- 리뷰(review skill): state REVIEW_REQUESTED(요청, work owner 불변·`reviewer` 지정) ↔ REVIEW_DONE(완료). 리뷰어는 work lane 미점유 — review state·result 경로만 갱신, work 내용 수정 X. 종결은 요청측 재량.

## Handoff Protocol
60% context 추정 시 정리. snapshot: `.claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md` (TEMPLATE.md 따름). 절차 상세: handoff skill / HYBRID.md.
state 마커: HANDOFF_TO_CODEX(Claude→Codex), HANDOFF_TO_CLAUDE(Codex→Claude), HANDOFF_TO_NEXT_AGENT(미정), SPEC_READY(기획 완료, 구현 대기), REVIEW_REQUESTED/REVIEW_DONE(리뷰 라운드트립, work owner 불변 — review skill).
다음 agent는 _wip.md Active Lanes state/handoff로 snapshot 위치 파악. 인수 시: state→WIP, owner→받는 agent.

## Response Style
한글로 답변. 기술 용어 코드 원문 유지.
Terse. Drop: a/an/the, filler, pleasantries, hedging.
Pattern: [대상] [동작] [이유]. [다음 단계].
ACTIVE EVERY RESPONSE.

### Active Skills 표시 (매 응답 최상단 1줄)
형식: `🐾 Active Skills: {활성 스킬 | 구분}` (🐾=pawpad, Codex는 statusLine 없어 라인 표시). 단계 첨자: `clarity r2/5`, `grill-me`, `to-prd`, `brainstorming`, `design`, `mockup lo/hi`, `review`.
스킬 없으면 생략 가능. ON START는 📂 ctxdb 라인 아래.

### Retrieval 표시 (탐색 수행 응답만, Active Skills 라인 아래 1줄)
형식: `📡 Retrieval: codemap {hit(경로)|miss|미사용} | ctxdb {hit(파일)|miss|미사용} | src {read N (codemap 경유)|full-scan N (사유)}`
- 소스 탐색 전 codemap lookup 의무. miss여도 곧장 full-scan 금지 — keywords/INDEX 의미매칭 재시도 후에도 miss면 **사유와 함께 full-scan 선언**.
- 코드/컨텍스트 탐색이 없는 응답(순수 문답·이미 아는 파일 재편집)은 라인 생략.

## Checkpoint (매 응답 종료 전 확인 - hooks 대체)
자세한 운영은 .claude/HYBRID.md 참조.
- [ ] lane 파일 (또는 _wip.md) 현재 상태 반영됐나?
- [ ] 신규 파일 생성 시 _index.md 심볼 추가됐나?
- [ ] 태스크 완료 시 lane을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 + _meta.md 1줄 append + git commit(git repo일 때만; 비-git이면 _meta RECENT에 "git unavailable" 기록) 됐나?
- [ ] context 60% 추정 초과 시 /handoff 또는 /checkpoint 실행했나?
- [ ] 핸드오프 인수 시 owner를 자기 이름으로 변경했나?
## Architecture Principles (Feature-First)
신규/변경 코드만 적용(레거시 강제 리팩토링 X). 상세·결정트리: .agents/skills/feature-architecture/SKILL.md
1. 모듈 경계: 기능 폴더 응집(colocation) + 단일 public boundary(스택 관례). 내부 직접 import 금지.
2. 횡단 import 금지: 기능 간 내부 참조 X (public boundary 의존은 OK). 공통은 소속 범위 따라 hoist.
3. Rule of Three: 2곳 중복 유지, 3곳째 추출.
4. 신규 = 가산적: feature 내부 추가 중심 + route/menu registry 등 최소 integration edit 허용. integration 파일에 로직 늘면 경계 재검토.
새 기능 위치: 기존 도메인 하위 / 새 도메인 폴더 / 도메인 비소속 shared 중 하나. 결정트리는 skill 참조.

## Idea → PRD Routing
아이디어→PRD 구체화 시 agent가 다음 스킬 추천(강제 X, 명시 호출 우선). skill mirror: `.agents/skills/{clarity,grill-me,to-prd,design,mockup}/`.
판정: 정보 부족→clarity / 설계 결정 어려움→grill-me / 둘 다 충족→to-prd.
- 큰 덩어리: clarity 전 "분해 권장"(굵은 조각+순서, 조각별 반복).
- clarity PASS 후: grill-me 신호(결정 상호의존·트레이드오프 연쇄·스택/아키텍처/스키마 비가역) 있으면 →grill-me, 없으면 →to-prd.
- grill-me 종결 후: →to-prd.
- UI/화면 기획 시: design(토큰/레이아웃 게이트) + mockup(PRD-tree→단일 HTML 시각화, lo/hi-fi) 추천.
### 자동제안 (단계 경계)
다음 시점에 다음 스킬 또는 목업 1회 추천(강제 X): PRD/PRD-tree 갱신 직후→mockup(통합 4탭=/mockup viewer; 뷰어 결정 저장 통지 시 /viewer-apply 반영), clarity/grill-me/to-prd 종료 시→다음 스킬. 매 응답 판단 X. 거절 시 다음 단계 경계까지 침묵. 대상 한정: clarity·grill-me·to-prd·design·mockup·brainstorming(나머지는 Checkpoint/hook 트리거 → 제외). 리뷰 제안(구현완료 경계): 코드/배포본 변경 완료 직전 고위험·배포본 영향이면 /review 권장(강제 X); 광범위·맹점우려·설치 스크립트는 codex exec 에스컬레이션. 코딩 위임 제안(구현 진입 경계): SPEC_READY/written 설계 직후 코딩 진입 시 /code-delegate 1회 권장(강제 X, 선택 모델 서브에이전트 위임으로 부모 컨텍스트·토큰 절감; 설계 미작성 시 제안 X).
### 선택지 질문 = 체크박스
기획/설계 스킬 진행 중 선택지 N개 질문은 AskUserQuestion(체크박스)로, 자유서술·수치는 텍스트로.


