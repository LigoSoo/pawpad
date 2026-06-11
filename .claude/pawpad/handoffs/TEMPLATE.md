# HANDOFF_TO_{CODEX|CLAUDE|NEXT_AGENT} - {feature-id}

## Context
- Agent From: {Claude Code | Codex}
- Agent To: {Claude Code | Codex | Next}
- Feature: {feature-id}
- Branch: {git branch}
- Commit: {short hash}
- Timestamp: YYYY-MM-DD HH:MM
- Reason: {token-limit | role-shift | shift-change | other}

## Goal
전체 작업 목표 1-3줄.

## Completed
- 완료된 항목 1
- 완료된 항목 2

## Remaining
- 남은 항목 1 (우선순위 H/M/L)
- 남은 항목 2

## Changed Files
- path/to/file1.dart : 수정중 / 미완성, 이유
- path/to/file2.dart : 완료, 미커밋

## Verification
- analyze: PASS / FAIL ({에러 수})
- test: PASS / FAIL ({실패 테스트})
- Last command run: {명령어}
- Last failure: {에러 메시지 요약}

## Known Issues
- 이슈 1 (해결법 알면 추가)
- 이슈 2

## Next Commands
즉시 실행할 명령 목록 (순서대로):
1. (Commands의 Analyze 명령)
2. (해당 기능 테스트)
3. {추가 작업 명령}

## Owner Transfer (수신 agent 액션)
인수 시 lane 파일에 적용:
- State: HANDOFF_TO_* -> WIP
- Owner: {송신자} -> {수신자 본인}
- _wip.md Active Lanes도 동일 갱신
- _meta.md RECENT에 "ACCEPT {feature} by {수신자}" 1줄 추가

## Notes
- 추가 컨텍스트
- 다음 에이전트가 알아야 할 비명시적 결정
