# Handoffs

세션 간 / 에이전트 간 상태 전달 snapshot 위치.

## 명명 규칙
.claude/pawpad/handoffs/{YYYY-MM-DD_HHMM}_{from}_to_{to}_{feature}.md

예: 2026-05-29_2230_claude_to_codex_feature-auth.md

## 사용
agent가 /handoff skill (.claude/skills/handoff/SKILL.md) 따라 수동 작성.
템플릿: TEMPLATE.md 참조.

## 발견 방법
다음 에이전트가 ON START 시:
- _wip.md Active Lanes에서 state=HANDOFF_TO_* 발견
- 해당 lane의 handoff 필드 경로로 snapshot read

## 인수 시 owner 변경 필수
- lane 파일과 _wip.md의 owner를 수신 agent로 변경
- 자세한 절차: .claude/skills/handoff/SKILL.md "실행 절차 - 수신 측"

## 보존 정책
- 최근 30일 보존
- 30일 초과 -> .claude/pawpad/sessions/handoffs-archive/ 이동 권장
- 삭제 금지 (audit)
