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
7. lane `## Verification Evidence` 섹션에 검증 근거 기록 (분석전용/소작업은 `not applicable: analysis-only`). 규칙: .claude/HYBRID.md Verification Evidence.
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
| Feature/UX       | src/PRD-tree.md                          |
| New feature      | src/PRD-tree.md + src/PRD.md             |
| New screen/route | Feature ID in PRD-tree.md                |
| 결정 기록 위치    | .claude/HYBRID.md Decision Placement Matrix 참조 |
| 검증 결과        | lane `## Verification Evidence` (길면 .claude/pawpad/verifications/{feature-id}_{ts}.md) |
Code + doc update = one atomic unit. Keep * markers accurate.

## Session Protocol
ON START (agent가 순차 실행):
  0. read .ctxdb/INDEX.md -> 첫 메시지 키워드 매칭 -> L1<=1 / L2<=2개만 로드 (전체 로드 금지)
     (첫 응답 최상단에 검증 1줄: 📂 ctxdb: {project} | {last-date} | {loaded L2} | {status})
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

## Handoff Protocol
60% context 추정 시 정리. snapshot: `.claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md` (TEMPLATE.md 따름). 절차 상세: handoff skill / HYBRID.md.
state 마커 4종: HANDOFF_TO_CODEX(Claude→Codex), HANDOFF_TO_CLAUDE(Codex→Claude), HANDOFF_TO_NEXT_AGENT(미정), SPEC_READY(기획 완료, 구현 대기).
다음 agent는 _wip.md Active Lanes state/handoff로 snapshot 위치 파악. 인수 시: state→WIP, owner→받는 agent.

## Response Style
한글로 답변. 기술 용어 코드 원문 유지.
Terse. Drop: a/an/the, filler, pleasantries, hedging.
Pattern: [대상] [동작] [이유]. [다음 단계].
ACTIVE EVERY RESPONSE.

### Active Skills 표시 (매 응답 최상단 1줄)
형식: `🐾 Active Skills: {활성 스킬 | 구분}` (🐾=pawpad, Codex는 statusLine 없어 라인 표시). 단계 첨자: `clarity r2/5`, `grill-me`, `to-prd`, `brainstorming`.
스킬 없으면 생략 가능. ON START는 📂 ctxdb 라인 아래.

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
아이디어→PRD 구체화 시 agent가 다음 스킬 추천(강제 X, 명시 호출 우선). skill mirror: `.agents/skills/{clarity,grill-me,to-prd}/`.
판정: 정보 부족→clarity / 설계 결정 어려움→grill-me / 둘 다 충족→to-prd.
- 큰 덩어리: clarity 전 "분해 권장"(굵은 조각+순서, 조각별 반복).
- clarity PASS 후: grill-me 신호(결정 상호의존·트레이드오프 연쇄·스택/아키텍처/스키마 비가역) 있으면 →grill-me, 없으면 →to-prd.
- grill-me 종결 후: →to-prd.


