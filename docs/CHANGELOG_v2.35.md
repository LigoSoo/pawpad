# CHANGELOG v2.35 — resume 최소로드 (ON START 토큰 절감)

> PawPad — Agentic Engineering Toolkit. v2.34 기반. 기능·스킬 수(19) 불변, ON START가 읽는 범위만 축소(재개 품질 동일).

## 요약
`/resume`(ON START) 세션 재개 시 읽는 컨텍스트를 성능 손실 없이 줄임. 접근법 A(#1+#2). codemap HOT-only(#3)는 on-demand 복원 리스크로 제외.

## 측정 (Bash wc, 보정 0.477 tok/char)
| 파일 | ≈토큰 | 비고 |
|------|------|------|
| HYBRID.md | 5.8k | #1 대상 |
| _meta.md | 6.5k | RECENT 5.5k + 헤더/BLOCKED/NEXT 1.0k |
| codemap _index | 9.9k | 제외(코드세션 한정·이미 조건부) |

## 변경
### #1 HYBRID 조건부화 (불일치 정정 + ~5.8k 절감)
- `resume` SKILL의 ON START 절차가 HYBRID.md를 **무조건 step1**로 읽던 것을 CLAUDE.md/AGENTS.md Session Protocol과 동일하게 **_wip 먼저 → active lane 있을 때만 HYBRID**로 변경.
- CLAUDE.md/AGENTS.md는 이미 조건부였음(resume SKILL만 비최적) → **toolkit 내부 불일치 정정** 겸함.
- 효과: 솔로/신규/분석 세션(active lane 없음)에서 HYBRID 미로드.

### #2 _meta RECENT skip (~5.5k 절감)
- `_meta.md` 섹션 순서를 **헤더 → BLOCKED → NEXT → RECENT(하단)** 로 재정렬.
- ON START는 _meta **상단(SPRINT/PHASE/STACK + BLOCKED + NEXT)만** 부분 읽기. RECENT(완료 이력)는 하단·재개 불요 → 생략, history 필요 시 on-demand.
- "읽되 무시"는 Read가 전체를 context에 올려 무효 → **물리적 부분읽기(RECENT 하단 배치)**가 핵심.
- 부수: _meta 롤오버 임계 표기 통일(resume SKILL 일부 "RECENT > 10줄" → CLAUDE/AGENTS 기준 "8줄").

## 변경 표면
- `.claude/skills/resume/SKILL.md` (ON START 절차·파일역할표·_meta 포맷 재정렬·업데이트 규칙·Session Rollover) + `.agents/skills/resume/SKILL.md` 미러
- `pawpad-setup.ps1` 임베드 resume 블록 + `$tmplClaudeMd`/`$tmplAgentsMd` Session Protocol step6 + `$ver`/STATUS
- `CLAUDE.md`·`AGENTS.md` Session Protocol step6 (_meta 부분읽기 주석; step2 HYBRID는 이미 조건부=무변경)
- `.claude/pawpad/_meta.md` 실파일 재정렬 (RECENT 하단)
- `GUIDE.md` ON START 예시
- `docs/CHANGELOG_v2.35.md`(신규) · `README/GUIDE/USAGE` 버전 · codemap

## 비변경
ctxdb 최소로드 · lane Verification Evidence cap(v2.30) · Completed Task Log(v2.31) · spec/handoff/codemap 조건부 — 이미 최적, 무변경. codemap HOT-only(#3) 미채택.

## 검증
- PSParser 0
- resume SKILL ON START 단계 == CLAUDE.md/AGENTS.md Session Protocol (HYBRID 조건부 정합)
- _meta 재정렬: 헤더→BLOCKED→NEXT→RECENT, RECENT 8엔트리 보존
- embed == live (resume 블록·$tmpl step6) / 미러 EOF 0a0a / 스킬 19 불변
- **ON START 토큰 재측정(전/후)**: #2 ~5.5k 항상 절감, #1 ~5.8k 솔로 절감 (Bash wc, EDR-safe)
- security 🔴0

## 리뷰 (2026-06-19)
- **PASS 100%, findings 0** — Claude 서브에이전트(Read/Grep/Glob + Bash[EDR-safe], PowerShell 미사용) 문서형 /review. 9항목 직접 검증(ON START 3중 정합·_meta 재정렬·step6 5곳·stale 0·live==mirror·token 절감 구조·버전·스킬19·회귀 없음). char/EOF byte 정밀 2건만 PowerShell-only NOT-VERIFIABLE(요청자 선측정 인용).
- request: `.claude/pawpad/reviews/resume-minimal-load-review-prompt-01.md` / result: `.claude/pawpad/reviews/resume-minimal-load-review-01.md`
- codex exec 미사용(이 머신 EDR이 codex powershell.exe 버스트→소켓 차단; CHANGELOG_v2.34 참조). 크로스모델 독립 리뷰 필요 시 WSL/EDR-free 머신.

## 미검증 — Codex 행동 갭 (다른 머신에서 재리뷰 예정)
- 리뷰는 **구조적 Codex parity**만 확인: AGENTS.md Session Protocol + `.agents/skills/resume` 미러 + setup 임베드가 Claude 표면과 동일하게 갱신·정합됨(Codex가 같은 ON START 지시를 받음).
- **Codex 행동(behavioral) 미검증**: 실제 Codex 세션을 띄워 ON START가 _meta 상단만 읽고 HYBRID를 조건부 skip하는지 실행 확인 안 함(이 머신 EDR이 Codex 차단 → 행동 테스트 불가).
- **#2 절감의 Codex 실현 행동 의존**: Claude는 Read 도구 limit/offset로 부분 로드 확정. Codex는 파일 읽기=`powershell Get-Content`(기본 전체 읽기) → "_meta 상단만" 절감이 실현되려면 Codex가 경계 읽기(`-TotalCount`/RECENT 전 stop)를 해야 함. _meta RECENT 하단 재정렬이 이를 **가능케** 하나, Codex 에이전트가 실제 경계 읽기하는지는 미검증(전체 read 시 Codex 쪽 절감 0). #1 HYBRID 조건부는 AGENTS.md가 원래 조건부라 Codex 구조 안전.
- **TODO(다른 머신)**: EDR-free 머신/WSL에서 Codex ON START 행동 smoke — ① _meta 경계 읽기(상단만) 실현 여부 ② HYBRID 조건부 skip 여부. + 가능 시 codex exec 크로스모델 재리뷰.
