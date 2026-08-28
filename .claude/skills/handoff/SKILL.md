---
name: handoff
description: Cross-agent state transfer. Use when handing work to another agent (Claude<->Codex) or a new session due to token/context limits — writes a snapshot and transfers lane ownership.
---
# Handoff Skill - Cross-Agent State Transfer (Instruction)

## 목적
세션 토큰 만료 / context window 한계 / 역할 전환 시 다음 에이전트가 끊김 없이 작업을 재개할 수 있도록 상태 snapshot 작성.

## 성격
**Instruction skill**. PowerShell command 아님. agent가 이 SKILL.md를 보고 수동으로 절차를 따라 파일을 생성/수정.

## 트리거
/handoff {to-agent} {feature-id} [reason]
- /handoff codex feature-a token-limit
- /handoff claude feature-b need-design
- /handoff next feature-c shift-change

## 마커 매핑
| {to-agent} | HANDOFF marker (state 필드에 기록) |
|-----------|-----------------------------------|
| codex     | HANDOFF_TO_CODEX                  |
| claude    | HANDOFF_TO_CLAUDE                 |
| next      | HANDOFF_TO_NEXT_AGENT             |

별도: spec 완료 후 구현 대기는 SPEC_READY (handoff 아닌 state 직접 설정).

## 실행 절차 - 송신 측 (agent가 순차 수행)
1. snapshot 파일 생성 (agent가 직접 작성):
   .claude/pawpad/handoffs/{YYYY-MM-DD_HHMM}_{from}_to_{to}_{feature}.md
2. 템플릿(.claude/pawpad/handoffs/TEMPLATE.md) 복사 후 채움
3. 필수 항목:
   - Context (from/to/feature/branch/commit/timestamp)
   - Goal (전체 목표)
   - Completed (완료된 것)
   - Remaining (남은 것)
   - Changed Files (path, status, reason)
   - Verification (Commands의 Analyze / Test 결과)
   - Known Issues
   - Next Commands (다음 에이전트가 즉시 실행할 명령)
4. lane 파일 (.claude/pawpad/wip/{feature}.md) 갱신:
   - State 섹션: HANDOFF_TO_{to}
5. _wip.md Active Lanes에 state + handoff 필드 갱신:
   - state: HANDOFF_TO_{to}
   - handoff: .claude/pawpad/handoffs/{snapshot 경로}
   - owner: 현재 그대로 유지 (송신자 = 현재 owner)
   - updated: YYYY-MM-DD HH:MM
6. codemap 갱신 (.claude/codemap/_index.md):
   - 이번 작업에서 만들거나 옮긴 심볼 반영 + HOT 최신화 (해당 없으면 "codemap skip" 선언)
   - 인수 agent는 새 세션이라, codemap이 구본이면 심볼을 못 찾고 소스를 통째로 뒤진다.
7. context-saver 실행 (.ctxdb/L2 저장 + INDEX.md AGENT SYNC 갱신):
   - snapshot은 이 작업 한 건의 인계장이고, ctxdb는 인수 agent가 **키워드로 과거를 부르는 경로**다. 둘은 대체재가 아니다.
   - "snapshot에 다 썼으니 생략"은 안 된다 — 인수 agent의 ON START는 snapshot을 읽기 전에 ctxdb부터 탄다.
   - 규칙: .claude/skills/context-saver/SKILL.md (승격 임계 초과 시 이월 + 포인터 갱신까지)
8. _meta.md RECENT에 1줄 추가:
   "YYYY-MM-DD: HANDOFF {feature} {from}->{to}. {reason}"
9. (선택) git commit

## 실행 절차 - 수신 측 (인수 agent, ON START 후)
1. _wip.md Active Lanes에서 state=HANDOFF_TO_(자기) 발견
2. handoff 필드 경로로 snapshot read
3. Next Commands 우선 실행
4. Known Issues 확인 후 작업 재개
5. **lane 파일 갱신** (소유권 이전):
   - State: HANDOFF_TO_* -> WIP
   - Owner: 송신자 -> 본인 (받는 agent)
6. **_wip.md Active Lanes 갱신**:
   - state: HANDOFF_TO_* -> WIP
   - owner: 받는 agent
   - handoff: 필드 제거 (인수 완료)
   - updated: 현재 시각
7. _meta.md RECENT에 인수 기록:
   "YYYY-MM-DD: ACCEPT {feature} by {receiving-agent}"

## Owner Mismatch 감지/복구 (인수 누락 복구)
가장 흔한 운영 실수: 인수 후 owner 변경 누락. ON START 시 다음 점검:
1. lane state=WIP 인데 owner가 송신 agent(=본인 아님)이면 -> 인수 누락 의심
2. 직전 _meta.md RECENT에 해당 feature ACCEPT 기록 없으면 -> 미인수 확정
3. 복구: 본인이 작업 중이면 owner를 본인으로 수정 (lane + _wip.md 동기화)
4. _meta.md RECENT에 복구 기록:
   "YYYY-MM-DD: FIX_OWNER {feature} -> {본인} (인수 시 owner 변경 누락 복구)"
5. 판단 불가 시 (양 agent 모두 작업 가능) STOP, 사용자에게 owner 확인 요청

## Verification 실패 시
- analyze 실패 / test 실패 발견 시
- snapshot에 명시 + Next Commands 첫 항목으로 수정 작업 등록
- 다음 에이전트가 정상화 작업 우선 처리

## SPEC_READY 케이스 (기획 -> 구현)
- handoff와 다름. snapshot 불필요.
- 기획 agent: lane 파일 생성 (state=SPEC_READY, owner=기획 agent) + specs/{feature}.md 작성 + _wip.md 등록
- 구현 agent: ON START -> state=SPEC_READY 발견 -> spec read -> 기존 SPEC_READY lane 인수 (state=WIP, owner=본인). 새 lane 생성 아님.

## /handoff-list (참고)
agent가 .claude/pawpad/handoffs/ 디렉토리 최근 5개 snapshot 출력.
