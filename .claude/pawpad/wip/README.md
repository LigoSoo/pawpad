# WIP Lanes

기능별 작업 상태 파일 위치.

## 명명 규칙
.claude/pawpad/wip/{feature-id}.md

예: feature-auth.md, feature-club.md

## 사용
1. 작업 시작: 이 디렉토리에 {feature-id}.md 생성
2. _wip.md Active Lanes에 등록 (owner / state / updated)
3. 작업 중 lane 파일 갱신
4. 완료 시 lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 (audit 보존, timestamp 명명)

## 템플릿
.claude/skills/memory/SKILL.md "lane 파일 포맷" 참조

## 하위 디렉토리
- wip/done/ : 완료된 lane 보관 (audit 추적용, 삭제 금지, timestamp 명명으로 재작업 보존)
