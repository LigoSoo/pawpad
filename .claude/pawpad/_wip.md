# WIP ROUTER

## Active Lanes
(없음 - 새 작업 시작 시 .claude/pawpad/wip/{feature-id}.md 생성 후 여기 등록)

예시 (WIP 상태):
- feature-a: .claude/pawpad/wip/feature-a.md
  - owner: Claude Code
  - state: WIP
  - updated: 2026-05-29 14:30

예시 (SPEC_READY 상태, 기획 완료 -> 구현 대기):
- feature-b: .claude/pawpad/wip/feature-b.md
  - owner: Claude Code
  - state: SPEC_READY
  - updated: 2026-05-29 15:00

예시 (HANDOFF 상태):
- feature-c: .claude/pawpad/wip/feature-c.md
  - owner: Codex
  - state: HANDOFF_TO_CLAUDE
  - handoff: .claude/pawpad/handoffs/2026-05-29_2230_codex_to_claude_feature-c.md
  - updated: 2026-05-29 22:30

## Locks
(파일 경로/glob -> 에이전트 매핑. 병렬 작업 시 충돌 방지용)

예시:
- src/moduleA/** -> Claude Code
- src/moduleB/** -> Codex

## 사용법
1. 새 작업: .claude/pawpad/wip/{feature-id}.md 생성 + 여기 Active Lanes 등록
2. 작업 중: lane 파일에 상세 상태 기록 (이 router는 state/updated만 갱신)
3. spec 작성 완료: state=SPEC_READY (구현 agent 대기)
4. 핸드오프: /handoff 사용 -> state=HANDOFF_TO_* + handoff 필드 추가
5. 인수: state=WIP, owner=받는 agent (handoff 필드 제거)
6. 완료: lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동
7. 체크포인트: /checkpoint 사용 -> lane 파일 + updated 갱신

## Active Lanes 필드 명세
- {feature-id} : kebab-case 권장
- owner       : Claude Code | Codex (해당 lane을 수정할 권한 가진 에이전트)
- state       : WIP | SPEC_READY | HANDOFF_TO_CODEX | HANDOFF_TO_CLAUDE | HANDOFF_TO_NEXT_AGENT | BLOCKED
- handoff     : state=HANDOFF_* 일 때만 필수. snapshot 파일 경로.
- updated     : 마지막 lane 파일 또는 router 갱신 시각

## State 의미
| state | 의미 | 다음 행동 |
|-------|------|---------|
| WIP | 작업 진행 중 | owner가 계속 작업 |
| SPEC_READY | 기획 완료, 구현 대기 | 구현 agent가 spec read 후 인수 (state=WIP, owner=본인) |
| HANDOFF_TO_CODEX | Codex 인수 요청 | Codex가 snapshot read 후 인수 (state=WIP, owner=Codex) |
| HANDOFF_TO_CLAUDE | Claude 인수 요청 | Claude가 snapshot read 후 인수 (state=WIP, owner=Claude) |
| HANDOFF_TO_NEXT_AGENT | 미정 인수 요청 | 인수 agent가 snapshot read 후 인수 |
| BLOCKED | 외부 차단 | owner가 차단 해소 시 state=WIP 복귀 |
