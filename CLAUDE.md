# CLAUDE.md
# Tool: Claude Code | Stack: <YOUR_STACK>
# Edit Commands / Directories / Conventions to match your project.

## Commands
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
7. lane `## Verification Evidence` 섹션에 검증 근거 기록 (분석전용/소작업은 `not applicable: analysis-only`). 규칙: .claude/HYBRID.md Verification Evidence.
8. 코드 변경 시 /security-check 🔴 zero (분석전용/문서전용 면제). 규칙: .claude/skills/security-check/SKILL.md
9. 코드 변경 시 신규/변경 코드가 Architecture Principles (Feature-First) 준수 (분석/문서전용 면제). 규칙: .claude/skills/feature-architecture/SKILL.md

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

## Code Conventions
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
| Feature/UX       | src/PRD-tree.md                          |
| New feature      | src/PRD-tree.md + src/PRD.md             |
| New screen/route | Feature ID in PRD-tree.md                |
| 결정 기록 위치    | .claude/HYBRID.md Decision Placement Matrix 참조 |
| 검증 결과        | lane `## Verification Evidence` (길면 .claude/pawpad/verifications/{feature-id}_{ts}.md) |
Code + doc update = one atomic unit. Keep * markers accurate.

## Session Protocol
ON START (agent가 순차 실행):
  0. read .ctxdb/INDEX.md -> 첫 메시지 키워드 매칭 -> L1<=1 / L2<=2개만 로드 (전체 로드 금지)
     (hook 가용 시 자동 최소로드/checkpoint 주입; 상세: .ctxdb/L1/domain-codex-adapter.md. 첫 응답 최상단 검증 1줄: 📂 ctxdb: {project} | {last-date} | {loaded L2} | {status})
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

### Active Skills 표시 (매 응답 최상단 1줄)
형식: `🐾 Active Skills: {활성 스킬 | 구분}` (🐾=pawpad). 단계 첨자: `clarity r2/5`, `grill-me`, `to-prd`, `brainstorming`.
caveman 항상 포함(normal mode 제외). 스킬 없으면 caveman만. ON START는 📂 ctxdb 라인 아래.
## Idea → PRD Routing
아이디어→PRD 구체화 시 agent가 다음 스킬 추천(강제 X, 명시 호출 우선).
판정: 정보 부족→clarity / 설계 결정 어려움→grill-me / 둘 다 충족→to-prd.
- 큰 덩어리: clarity 전 "분해 권장"(굵은 조각+순서, 조각별 반복).
- clarity PASS 후: grill-me 신호(결정 상호의존·트레이드오프 연쇄·스택/아키텍처/스키마 비가역) 있으면 →grill-me, 없으면 →to-prd.
- grill-me 종결 후: →to-prd.

## Architecture Principles (Feature-First)
신규/변경 코드만 적용(레거시 강제 리팩토링 X). 상세·결정트리: .claude/skills/feature-architecture/SKILL.md
1. 모듈 경계: 기능 폴더 응집(colocation) + 단일 public boundary(스택 관례). 내부 직접 import 금지.
2. 횡단 import 금지: 기능 간 내부 참조 X (public boundary 의존은 OK). 공통은 소속 범위 따라 hoist.
3. Rule of Three: 2곳 중복 유지, 3곳째 추출.
4. 신규 = 가산적: feature 내부 추가 중심 + route/menu registry 등 최소 integration edit 허용. integration 파일에 로직 늘면 경계 재검토.
새 기능 위치: 기존 도메인 하위 / 새 도메인 폴더 / 도메인 비소속 shared 중 하나. 결정트리는 skill 참조.


