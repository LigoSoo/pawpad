---
name: task-done
description: Task completion gate. Use on ON TASK DONE or when user says a task/issue is finished ("작업 종료", "이슈 종료", "마무리해줘", "task done") to execute the full lane closure checklist - verify DoD, move lane to wip/done, remove from _wip, append _meta RECENT, carry tasklog, update codemap, git commit.
---
# DO NOT EDIT: generated from .claude/skills/task-done/SKILL.md by pawpad-setup.ps1.
# Task-Done Skill - ON TASK DONE 실행 게이트

## 목적
ON TASK DONE(Session Protocol)은 선언적 지시라 자연어 종료 요청("이번 이슈 종료 작업 해줘")에서 부분 실행/누락이 발생한다.
누락된 lane은 다음 세션 resume이 완료 작업을 다음 작업으로 재제안한다(stale lane 사고). 이 스킬은 종결 절차를 체크리스트로 강제한다.

## 발동
- 사용자 자연어: "작업 종료", "이슈 종료", "이번 작업 마무리", "task done", "close this task" 등 작업 종결 요청
- agent 자체: 태스크 완료(DoD 충족) 판단 시점 = ON TASK DONE
- Stop hook의 [lane-close] 리마인더 수신 시 (완료 선언했는데 Active Lanes 잔존)

## 전제 게이트 (미충족 시 종결 중단 + 사유 보고)
- DoD 확인(CLAUDE.md/AGENTS.md Definition of Done): Analyze 0 에러 / Test green / scope 준수 / lane Verification Evidence 기록 / 코드 변경 시 security-check 빨강 0
- 대상 특정: _wip.md Active Lanes에서 닫을 lane 확인. 본인 owner lane만. 여러 lane 완료 시 각 lane에 대해 반복.

## 종결 체크리스트 (순서 고정, 전항 실행 — 일부만 하고 끝내기 금지)
1. lane Verification Evidence 최근 2건 유지 — 초과분은 .claude/pawpad/verifications/{feature-id}-archive.md 상단 append + lane에 포인터 1줄
2. lane 파일 이동: .claude/pawpad/wip/{feature-id}.md -> .claude/pawpad/wip/done/{feature-id}_{YYYY-MM-DD_HHMMSS}.md (timestamp=완료 시각, 삭제 절대 금지)
3. _wip.md Active Lanes에서 해당 lane 제거 (남은 lane 없으면 "(없음)")
4. _meta.md RECENT 최상단 1줄 append ([agent] 명시, 2문장 이내 + 커밋 해시 — RECENT는 타임라인, 상세는 L2/lane 1벌만) — 8줄 초과분은 sessions/{YYYY-MM}.md 상단 이동 (newest first)
5. 완료(v) 작업항목 누적 시 verifications/{feature-id}-tasklog.md 이월 (HYBRID Completed Task Log)
6. codemap 갱신: 신규/변경 심볼 반영 (해당 없으면 "codemap skip" 선언)
7. git commit (git repo일 때만). 비-git이면 _meta RECENT에 "git unavailable" 기록 — 완료 차단 안 함

## 보고 형식 (체크리스트 후 1줄)
task-done: {feature-id} -> wip/done/{파일명} | _meta 기록 | codemap {갱신|skip} | commit {hash|unavailable}

## 주의
- 중간 실패 시: 실패 항목 + 사유 보고 후 중단 (이미 수행한 항목은 명시 — 재실행 시 이어서)
- lane이 없거나 이미 done 이관됨: 상태 그대로 보고, 중복 이관 금지. _wip Active Lanes에 잔존 항목만 있으면 제거로 정합 회복
- 이 스킬은 종결 절차만 담당 — 구현/검증 잔여 작업이 발견되면 종결 중단하고 lane WIP 유지

