# WIP - Done

완료된 lane 파일 보관소.

## 명명 규칙
.claude/pawpad/wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md

예:
- feature-auth_2026-05-29_143012.md   (첫 완료)
- feature-auth_2026-06-15_092044.md   (재작업 완료, 이전 보존)
- 초 단위(SS) 포함: 같은 분 2회 완료 충돌 방지

## 정책
- 작업 완료 시 wip/{feature-id}.md를 여기로 이동 (timestamp 추가)
- 같은 feature 재작업 시 이전 done 파일 보존 (덮어쓰기 방지)
- 삭제 절대 금지 (history audit)

## 정리 주기
- 분기별 검토 권장
- 오래된 항목 -> .claude/pawpad/sessions/archive-YYYY-Q{N}/로 압축 보관 가능
