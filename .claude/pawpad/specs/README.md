# Feature Specs

기획 단계 산출물 위치. Claude Code 또는 사용자가 작성, Codex가 구현 시 읽음.

## 명명 규칙
.claude/pawpad/specs/{feature-id}.md

## 사용 흐름 (기획->구현 분리)
1. 기획 agent (Claude Code 또는 Codex):
   - 이 디렉토리에 {feature-id}.md 작성
   - 필요 시 .claude/pawpad/decisions/arch.md ADR 추가
   - lane 생성 + _wip.md Active Lanes에 state=SPEC_READY 등록
2. 구현 agent:
   - ON START -> _wip.md 확인
   - state=SPEC_READY 발견 시 specs/{feature}.md read
   - 인수 시 state=WIP, owner=본인으로 변경
   - 구현 시작

## 템플릿
TEMPLATE.md 참조.
