# CHANGELOG v2.43 — task-done 종결 게이트 3종 (A+B+C)

날짜: 2026-07-09 | 기반: v2.42 (retrieval 계측 시각화) | 스킬 19→20 (task-done 신규, Core)

## 배경
사용자 실관측 사고: 다른 프로젝트에서 "이번 이슈 종료 작업 해줘"로 작업을 마감해 왔으나, 이후 `/resume`가 **이미 종료한 작업을 다음 작업으로 재제안** — 확인 결과 lane→done 이관 안 된 항목 다수. 근본 원인: ON TASK DONE은 CLAUDE/AGENTS의 **선언적 지시**(훅·검증 없음)라 자연어 종료 요청에서 모델이 부분 실행(state만 갱신, 이동 생략 등)하거나 통째 누락. 남은 stale lane은 세션마다 재작업을 유도. v2.43은 완료 시점(A·B)과 다음 세션(C)에 계층 방어를 깐다.

## A — 신규 `task-done` 스킬 (19→20, Core 번들)
- ON TASK DONE 6단계를 **순서 고정 체크리스트로 강제**: ① Verification Evidence 최근 2건 cap(초과분 archive 이월) ② lane→wip/done/{id}_{ts}.md 이동(삭제 금지) ③ _wip Active Lanes 제거 ④ _meta RECENT 1줄 append+8줄 cap 이월 ⑤ tasklog 이월(HYBRID Completed Task Log) ⑥ codemap 갱신(없으면 skip 선언) ⑦ git commit(비-git이면 "git unavailable" 기록, 완료 차단 안 함).
- 발동: "작업 종료"/"이슈 종료"/"마무리"/"task done" 자연어 + agent 자체 ON TASK DONE + Stop hook `[lane-close]` 리마인더.
- 전제 게이트: DoD 미충족 시 종결 중단·사유 보고. 중간 실패 시 수행/미수행 항목 명시(재실행 이어가기). 이미 done이면 중복 이관 금지(잔존 _wip 항목만 정합 회복).
- 자동제안 제외 목록(task-done 추가) — Session Protocol/hook 트리거라 이중 추천 방지.

## B — stop-check lane-close 백스톱 (Claude 훅, ps1+sh)
- Stop 시: **마지막 assistant text 엔트리**(v2.42 다중 엔트리 스캔 방식 재사용)가 완료/종료 선언 매칭 `(작업|이슈|태스크|task|lane).{0,10}(완료|종료|마무리|done)` + `_wip.md` Active Lanes 잔존(`## Active Lanes` 섹션 위치 분해 후 `- ` 항목 검사) → `decision:block` 1회.
- 오탐 감쇄: ① 스킬명 `task-done` 문자열 제거 후 매칭(스킬 언급≠완료 선언) ② `claude-taskdone-warned` uuid dedupe(동일 응답 재경고 방지, `stop_hook_active` 루프가드는 기존) ③ 리마인더 문구에 "미완료면 무시" 명시.
- reason tail 분기: lane-close 포함 시 "If closing, execute task-done fully before stopping" (기존 "Report one line, then stop."이 종결 실행을 막지 않도록).
- bash 포트: awk 섹션 분해 + jq(라인 관용 slurp, v2.42 #3 방식) — jq 부재 시 graceful skip. 정규식 바이트 길이 보정 `{0,30}`(한글 3byte).
- Codex 훅 미적용(선례: v2.41/42 계측도 Claude 전용) — Codex는 A 스킬 미러+AGENTS 프로토콜로 커버.

## C — resume Lane 신뢰성 게이트 (스킬 + Session Protocol step 3)
- 원리: **lane은 계획의 SoT지만 무검증 신뢰 금지** — 다음 작업 제안 전 실상태 1회 대조.
- 3단 신호(신뢰도 순): ① _meta RECENT에 해당 feature-id DONE 기록 + lane 잔존 = **확정 누락** → 통지 후 task-done 즉시 종결 ② next steps 전항 체크/완료 선언 = 완료 의심 → 종결 제안(사용자 확인) ③ updated 오래됨 + next steps 첫 항목 실코드 spot-check 결과 이미 반영 = stale 의심 → 재개 전 사용자 확인.
- 확정 누락 외 자동 이관 금지(오판 시 파괴적). _meta 상단 부분읽기 호환: RECENT 대조는 feature-id Grep on-demand(통째 read 불요).
- CLAUDE/AGENTS Session Protocol step 3에 stale 게이트 1줄 + ON TASK DONE 줄에 task-done 실행 포인터.

## 표면
- 신규: `.claude/skills/task-done/SKILL.md` (+`.agents` 미러는 setup 재생성, resume 설치 단계 동거 — stepTotal 28 불변, v2.36 viewer-apply 선례)
- live: resume SKILL(게이트 섹션+타이밍 표), stop-check.ps1/.sh, CLAUDE.md(4)·AGENTS.md(2), SKILLS_MANIFEST(카운트+행+호출), .codex/config.json skills
- `pawpad-setup.ps1`: $ver 2.43 / line1·STATUS(+v2.42 강등) / task-done 임베드 신규(literal) / resume·stop-check×2·$tmplClaudeMd·$tmplAgentsMd 임베드 동기 / manifest·config 임베드 / $bpCore 11→12 / TR bundleOpts ko·en(12/17/20) / 완료요약 ko·en
- docs: README(8)·GUIDE(10, **v2.42 변경이력 bullet 누락 발견→v2.42+v2.43 동시 추가**)·USAGE(3)·PAWPAD_VERSIONS(제목+행+누적 20)·본 보고서 / codemap
- 신규 state 파일: `.ctxdb/.state/claude-taskdone-warned`(런타임)

## 검증 (2026-07-09)
- PSParser 0 errors (setup + live stop-check.ps1), bash -n OK (stop-check.sh)
- stop-check.ps1 실호출 fixture: 완료 선언+lane 잔존 → `[lane-close]` block / 재실행 dedupe 무발화 / lane 없음 → 무발화 / 'task-done' 언급만 → 무발화
- `-Upgrade` 실행: exit 0·0 failed, 미러 재생성 source=20 mirror=20, emitted==live(설치 후 live 불변 = embed==live)
- 카운트 grep: "19개/19 스킬/19 skills" 활성 잔재 0 (역사 기록 제외)

## 한계 (명시)
- B의 완료 선언 감지는 휴리스틱 — 선언 없는 완료(무언 종료)는 미포착(C가 다음 세션서 회수). 오탐은 1회 리마인더+무시 가능으로 수용.
- B는 이 머신처럼 org 정책이 hooks 차단이면 무효 — A(스킬)·C(resume 규율)는 훅 무관 동작.
- C의 ③단 신호는 모델 판단 의존(spot-check 규율) — 강제는 A·B가 담당, C는 회수망.
