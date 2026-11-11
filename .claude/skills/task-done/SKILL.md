---
name: task-done
description: Task completion gate. Use on ON TASK DONE or when user says a task/issue is finished ("작업 종료", "이슈 종료", "마무리해줘", "task done") to execute the full lane closure checklist - verify DoD, move lane to wip/done, remove from _wip, append _meta RECENT, carry tasklog, update codemap, save ctxdb, git commit.
---
# Task-Done Skill - ON TASK DONE 실행 게이트

## 목적
ON TASK DONE(Session Protocol)은 선언적 지시라 자연어 종료 요청("이번 이슈 종료 작업 해줘")에서 부분 실행/누락이 발생한다.
누락된 lane은 다음 세션 resume이 완료 작업을 다음 작업으로 재제안한다(stale lane 사고). 이 스킬은 종결 절차를 체크리스트로 강제한다.

## 발동
- 사용자 자연어: "작업 종료", "이슈 종료", "이번 작업 마무리", "task done", "close this task" 등 작업 종결 요청
- agent 자체: 태스크 완료(DoD 충족) 판단 시점 = ON TASK DONE
- Stop hook의 [lane-close] 리마인더 수신 시 (완료 선언했는데 Active Lanes 잔존)
- **선행 규율**: "완료/정상 확인/끝났다"를 보고하기 전에 _wip.md Active Lanes를 먼저 확인한다.
  잔존하면 보고와 같은 턴에 이 스킬을 실행 — hook 리마인더를 기다리지 않는다.

## 전제 게이트 (미충족 시 종결 중단 + 사유 보고)
- DoD 확인(CLAUDE.md/AGENTS.md Definition of Done): Analyze 0 에러 / Test green / scope 준수 / lane Verification Evidence 기록 / 코드 변경 시 security-check 빨강 0
- 대상 특정: _wip.md Active Lanes에서 닫을 lane 확인. 본인 owner lane만. 여러 lane 완료 시 각 lane에 대해 반복.

## 종결 체크리스트 (순서 고정, 전항 실행 — 일부만 하고 끝내기 금지)
1. lane Verification Evidence 최근 2건 유지 — 초과분은 .claude/pawpad/verifications/{feature-id}-archive.md 상단 append + lane에 포인터 1줄
2. lane 파일 이동: .claude/pawpad/wip/{feature-id}.md -> .claude/pawpad/wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md (timestamp=완료 시각, 삭제 절대 금지)
3. _wip.md Active Lanes에서 해당 lane 제거 (남은 lane 없으면 "(없음)")
   - **종결 메모 줄("({feature-id} … 종결 — …)")을 남기지 않는다.** 종결 기록의 자리는 wip/done 파일과 _meta RECENT다. _wip.md는 매 세션 통째로 읽히므로 진행 중 lane과 Locks만 둔다.
   - 이전 세션이 남긴 종결 메모가 쌓여 있으면 이번에 함께 지운다 — 지우기 전 그 feature-id의 wip/done 파일이 있는지 확인하고, 없는 것만 _meta RECENT(또는 sessions/)에 1줄로 옮긴 뒤 지운다.
4. _meta.md RECENT 최상단 1줄 append ([agent] 명시, 2문장·300자 이내 + 커밋 해시 — RECENT는 타임라인, 상세는 L2/lane 1벌만)
   - RECENT 8줄 초과 또는 _meta.md 전체 8KB 초과 시 오래된 줄부터 sessions/{YYYY-MM}.md 상단 이동 (newest first). 줄 수와 byte를 둘 다 잰다. RECENT 최신 1줄은 남긴다.
   - 끝난 NEXT 항목은 취소선으로 남기지 말고 sessions/{YYYY-MM}.md로 옮긴다 (_meta 상단은 매 세션 읽힌다).
   - 그래도 8KB를 넘으면 원인은 상단이다 — 남은 NEXT 항목을 1줄로 줄이고 상세는 lane/spec 포인터로 둔다.
5. 완료(v) 작업항목 누적 시 verifications/{feature-id}-tasklog.md 이월 (HYBRID Completed Task Log)
6. codemap 갱신: 신규/변경 심볼 반영 (해당 없으면 "codemap skip" 선언)
   - 건드린 codemap 파일의 byte 수를 잰다 — cap(_root.md 2048 / _index.md 30720 / 그외 4096) 초과면 분할 후 진행. 훅이 돌지 않는 환경에서는 이 단계가 유일한 집행이다. 규칙: .claude/skills/codemap/SKILL.md
7. context-saver 실행: .ctxdb/L2 세션 블록 + INDEX.md AGENT SYNC
   - 같은 세션에서 이 작업을 이미 /checkpoint로 저장했으면 L2 블록은 생략할 수 있다("ctxdb skip(L2)" 선언). 그래도 INDEX AGENT SYNC 상태 셀은 종결 상태로 덮어쓴다 — checkpoint 때 적은 "진행 중"이 남으면 안 된다.
   - 이 단계를 빼면 끝낸 작업이 다음 세션에서 키워드로 회수되지 않는다. 8턴 자동 저장은 Stop hook 전용이라 훅이 없으면 여기가 마지막 기회다. 규칙: .claude/skills/context-saver/SKILL.md
8. git commit (git repo일 때만). 비-git이면 _meta RECENT에 "git unavailable" 기록 — 완료 차단 안 함

## 보고 형식 (체크리스트 후 1줄)
task-done: {feature-id} -> wip/done/{파일명} | _meta 기록 | codemap {갱신|skip} | ctxdb {저장|skip} | commit {hash|unavailable}

## 주의
- 중간 실패 시: 실패 항목 + 사유 보고 후 중단 (이미 수행한 항목은 명시 — 재실행 시 이어서)
- 이미 done 이관됨: 상태 그대로 보고, 중복 이관·중복 기록 금지. _wip Active Lanes에 잔존 항목만 있으면 제거로 정합 회복
- lane 없이 진행한 작업(연속 개선·소작업)을 종결할 때: 전제 게이트의 lane 항목과 1·2·3·5번은 not applicable, 4·6·7·8번은 실행한다 — lane이 없다고 기록·저장까지 건너뛰지 않는다. 보고는 "task-done: (lane 없음) | _meta 기록 | codemap ... | ctxdb ... | commit ..."
- 이 스킬은 종결 절차만 담당 — 구현/검증 잔여 작업이 발견되면 종결 중단하고 lane WIP 유지
