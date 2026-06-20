---
name: resume
description: Hybrid session resume protocol. Use at session start (ON START) to read HYBRID/_wip/lane/handoff/meta/codemap and resume cross-agent (Claude<->Codex) work without losing context.
---
# DO NOT EDIT: generated from .claude/skills/resume/SKILL.md by pawpad-setup.ps1.
# Resume Skill - Session Resume Protocol (Hybrid)

## 파일 역할
| 파일/경로 | 역할 | 읽는 시점 |
|----------|------|---------|
| .claude/HYBRID.md                 | 협업 프로토콜               | ON START - active lane 시(없으면 skip) |
| .claude/pawpad/_wip.md               | active lane router          | ON START - 1번째     |
| .claude/pawpad/wip/{feature}.md      | 기능별 lane 상세            | active lane 있을 때  |
| .claude/pawpad/wip/done/             | 완료된 lane 보관 (audit)    | 히스토리 조회 시     |
| .claude/pawpad/handoffs/             | 핸드오프 snapshot           | state=HANDOFF_TO_* 시 |
| .claude/pawpad/specs/{feature}.md    | feature spec (기획 산출물) | state=SPEC_READY 또는 구현 직전 |
| .claude/pawpad/_meta.md              | Sprint/BLOCKED/NEXT(상단)+RECENT 완료이력(하단) | ON START 상단만 / RECENT on-demand |
| .claude/pawpad/sessions/             | 세션 상세 (온디맨드)         | 필요 시만            |
| .claude/pawpad/decisions/rejected.md | 실패 기록                   | 유사 작업 전         |
| .claude/pawpad/decisions/arch.md     | ADR                         | 아키텍처 결정 전     |
| .claude/pawpad/backup/               | -Force 시 자동 백업          | 복구 필요 시         |

## ON START 절차 (agent가 순차 실행 — CLAUDE.md/AGENTS.md Session Protocol과 동일 순서)
1. read .claude/pawpad/_wip.md (active lane router)
   -> Active Lanes 비어있음: 새 작업 시작 (이후 HYBRID 등 skip)
   -> Active Lanes 존재: assigned lane 읽기
2. Active Lanes 있으면 read .claude/HYBRID.md (협업 프로토콜). 없으면 skip -> 신규 lane 생성/핸드오프/인수 시점에 read
3. lane 파일 있으면: read .claude/pawpad/wip/{feature}.md
4. lane state=HANDOFF_TO_* : _wip.md의 handoff 필드 경로로 snapshot read
5. lane state=SPEC_READY 또는 spec 있으면: read .claude/pawpad/specs/{feature}.md
6. read .claude/pawpad/_meta.md 상단만 (헤더 SPRINT/PHASE/STACK + BLOCKED + NEXT). RECENT(완료 이력)는 파일 하단·재개 불요 -> 생략, history 필요 시 on-demand
7. read .claude/codemap/_index.md (코드 수정 작업 시점만; 질문/분석 세션 skip)

## _wip.md (Router) 포맷
# WIP ROUTER

## Active Lanes
- {feature-id}: .claude/pawpad/wip/{feature-id}.md
  - owner: {Claude Code | Codex}
  - state: WIP | SPEC_READY | HANDOFF_TO_CODEX | HANDOFF_TO_CLAUDE | HANDOFF_TO_NEXT_AGENT | BLOCKED
  - handoff: .claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md   (state=HANDOFF_* 일 때만)
  - updated: YYYY-MM-DD HH:MM

## Locks
- {파일 경로 glob} -> {owner agent}

## State Enum 명세
| state | 의미 | 추가 필드 | 후속 agent 행동 |
|-------|------|---------|--------------|
| WIP | 작업 진행 중 | - | 본인 lane이면 계속 |
| SPEC_READY | 기획 완료, 구현 대기 | - | specs/{feature}.md read 후 구현 시작 |
| HANDOFF_TO_CODEX | Codex로 인수 요청 | handoff | Codex가 snapshot read, state=WIP, owner=Codex로 변경 |
| HANDOFF_TO_CLAUDE | Claude로 인수 요청 | handoff | Claude가 snapshot read, state=WIP, owner=Claude로 변경 |
| HANDOFF_TO_NEXT_AGENT | 다음 agent 미정 | handoff | 인수 agent가 snapshot read, state=WIP, owner=자기로 변경 |
| BLOCKED | 외부 의존 대기 | - | 차단 해소 시 owner가 state=WIP로 복귀 |

## lane 파일 (.claude/pawpad/wip/{feature}.md) 포맷
# LANE - {feature-id} - YYYY-MM-DD HH:MM

## Owner
{Claude Code | Codex}

## State
WIP | SPEC_READY | HANDOFF_TO_* | BLOCKED

## 작업 중
- [domain:feature] [설명] ([진행률 %])
  - 완료: [한 것]
  - 미완: [남은 것]

## 수정한 파일 (미커밋)
- src/path/to/file.<ext>    <- [수정중 / 미완성]

## 다음 단계
1. [액션]
2. [액션]

## 중단 이유 (중단 시만)
- [이유]

## 업데이트 타이밍
| 시점 | agent 액션 |
|------|----------|
| 서브태스크 완료       | lane 파일 "다음 단계" 갱신                            |
| 세션 중단 예상       | lane 전체 상태 + 중단 이유 작성                       |
| 60% context 도달    | /checkpoint -> 필요시 /handoff                       |
| spec 작성 완료      | state=SPEC_READY, _wip.md 갱신                       |
| 핸드오프 발생       | state=HANDOFF_TO_*, handoff 필드 추가                |
| 인수 시            | state=WIP, owner=받는 agent로 변경                   |
| 전체 태스크 완료     | lane 파일을 wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md로 이동 |

## 완료 lane 처리 (audit 보존, timestamp 명명)
- 작업 완료 시: .claude/pawpad/wip/{feature-id}.md -> .claude/pawpad/wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md
  - timestamp는 완료 시각
  - 같은 feature 재작업 시 이전 done 파일 보존 (덮어쓰기 방지)
- _wip.md Active Lanes에서 해당 lane 제거
- _meta.md RECENT에 1줄 추가
- 삭제 절대 금지 (history 추적 불가능 방지)

예시:
- 첫 완료: wip/done/feature-auth_2026-05-29_143012.md
- 재작업 완료: wip/done/feature-auth_2026-06-15_092044.md (이전 파일 그대로 보존)
- 초 단위(SS)까지 명명: 같은 분 2회 완료 시 충돌 방지

## _meta.md 포맷 (재개 비용 최적화: RECENT를 하단에 둬 ON START가 상단만 부분읽기)
# SPRINT: [W번호] | PHASE: [번호] | STACK: {프로젝트 스택}

## BLOCKED
- [항목] -> [이유]

## NEXT
- [다음 예정 작업]

## RECENT (newest first)
YYYY-MM-DD: [완료 내용]. [영향 파일]. [agent]

## _meta.md 업데이트 규칙
- 태스크 완료 시: RECENT(하단 섹션) 최상단에 1줄 추가 (agent 명시)
- RECENT > 8줄: 초과분 -> .claude/pawpad/sessions/YYYY-MM.md 상단 이동 (newest first)
- BLOCKED / NEXT: 상태 변화 시 즉시 갱신
- ON START는 헤더+BLOCKED+NEXT만 읽음 (RECENT 하단 = 재개 불요, history 시 on-demand)

## Handoff Rules
- 60% context 도달 추정 시 agent가 snapshot 작성 (handoff skill 참조)
- snapshot 경로: .claude/pawpad/handoffs/YYYY-MM-DD_HHMM_from_to_feature.md
- agent는 _wip.md Active Lanes의 state와 handoff 필드를 동시에 갱신
- HANDOFF marker:
  - HANDOFF_TO_CODEX : Claude -> Codex
  - HANDOFF_TO_CLAUDE : Codex -> Claude
  - HANDOFF_TO_NEXT_AGENT : 미정
  - SPEC_READY : 기획 산출물 준비 완료
- **인수 절차** (HANDOFF 받는 agent):
  1. _wip.md state/handoff 필드로 snapshot 위치 파악
  2. snapshot read + Next Commands 우선 실행
  3. lane 파일 State: HANDOFF_TO_* -> WIP 변경
  4. lane 파일 Owner: 받는 agent (자기 이름)로 변경
  5. _wip.md Active Lanes: state=WIP, owner=받는 agent, handoff 필드 제거, updated 갱신

## Session Rollover
- 세션 종료 시 lane 파일 + _wip.md + codemap 갱신 강제
- _meta.md RECENT > 8줄 -> sessions/YYYY-MM.md 상단 이동 (newest first)
- 새 세션 시 ON START 절차 그대로 실행 -> 끊김 없는 재개

## Backup
- -Force 실행 시 자동 백업: .claude/pawpad/backup/{timestamp}/
- 백업 대상:
  - **PawPad**: _wip.md, _meta.md, decisions/, wip/ (done 포함), handoffs/, specs/, codemap/_index.md
  - **Context files**: CLAUDE.md, AGENTS.md, .claude/HYBRID.md, .claude/settings.json, .codex/config.json, .gitignore, CONTEXT.md, .claude/SKILLS_MANIFEST.md
- 복구 필요 시 백업 디렉토리에서 수동 복원
- .gitignore에서 .claude/pawpad/backup/ 자동 제외 (민감 정보 보호)

## rejected.md 포맷
## [제목]
시도: [무엇을]
결과: [왜 실패]
해결: [올바른 방법]
날짜: YYYY-MM-DD
agent: [Claude Code | Codex]

