# codebase/ — High-Level CodeBase Map (7 axes)

Canonical 7축 고수준 코드베이스 맵. 스킬 정의: .claude/skills/codebase-map/SKILL.md.

## 파일
| 축 | 파일 | required | budget |
|----|------|:--------:|:------:|
| ARCH    | architecture.md | Y | 220 |
| STRUCT  | structure.md    | Y | 150 |
| CONV    | conventions.md  | Y | 150 |
| TEST    | testing.md      | Y | 150 |
| CONCERNS| concerns.md     | Y | 150 |
| STACK   | stack.md        | optional | 150 |
| INTEG   | integrations.md | optional | 150 |

## 규칙
- 각 파일 stale-guard 헤더 필수(Last refreshed / Stale when / Budget).
- digest: .ctxdb/L2/codebase-map-current.md (주입 전용, budget 120).
- 주입은 digest-only. full docs는 on-demand read.
- 갱신: code+doc atomic. 구조 변경 시 해당 축만 수정 + digest 동기.
- 권한: 추가=누구나, 수정=lane owner.
