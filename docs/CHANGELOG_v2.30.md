# CHANGELOG v2.30 — Verification Evidence 아카이브 분리

## 변경: lane `## Verification Evidence` 경량 유지 규칙

### 배경
소형 보강 작업 세션에서 PawPad ON START 오버헤드가 실작업 컨텍스트를 초과하는 케이스 확인(token-analysis 보고서). 단일 최대 소비 = 장수(長壽) lane 파일의 `## Verification Evidence` 섹션 무제한 누적(예: 18KB lane의 ~85%). 후속 세션은 lane의 state·next-steps·최근 검증만 참조하고 과거 검증 근거는 audit 목적(미사용)인데, Protocol #3이 lane 전체를 매 세션 강제 로드 → audit-only 데이터가 핫패스를 점유.

### 규칙 (무손실)
- lane `## Verification Evidence` 본문에는 **최근 2건만 유지**.
- 검증 근거 추가로 2건을 초과하면, 가장 오래된 항목부터 `.claude/pawpad/verifications/{feature-id}-archive.md` **상단에 append**(newest first) 후 lane에서 제거.
- lane 섹션 하단에 **포인터 1줄** 유지: `> 이전 검증 N건 -> .claude/pawpad/verifications/{feature-id}-archive.md`.
- 분석전용/소작업은 본문에 `not applicable: analysis-only`만(아카이브 불필요).
- archive 파일은 추가만, 기존 내용 수정·삭제 금지(audit).

무손실 근거: 분리 대상은 후속 세션 의사결정에 미사용인 audit-only 검증 근거 → 핫패스에서 빼도 능력 손실 0, on-demand recall만 유지. `_meta.md` RECENT 8줄 + `sessions/` 이월과 동일 패턴(검증된 메커니즘 재사용, 신규 메커니즘 없음).

### dangling 포인터 해소
DoD#7과 `verifications/README.md`가 "`.claude/HYBRID.md` Verification Evidence 섹션"을 참조하나 해당 섹션이 부재(pre-existing). v2.30에서 HYBRID.md에 `## Verification Evidence` 섹션 신설로 포인터 정상화.

### 변경 표면
- `CLAUDE.md`/`AGENTS.md`: DoD#7 문구(2건 cap + archive + 포인터) · Doc Update Rules "검증 결과" 행 경로(`{feature-id}-archive.md`).
- `.claude/HYBRID.md`: `## Verification Evidence` 섹션 신설(운영 규칙 단일 소스).
- `verifications/README.md`: 명명/사용 규칙을 신규 `-archive.md`(2건 cap) 규약으로 갱신.
- `pawpad-setup.ps1`: $ver 2.30 · 헤더/STATUS · 임베디드 `$tmplClaudeMd`/`$tmplAgentsMd`(DoD#7·Doc Rules) · 임베디드 HYBRID.md(섹션 신설).
- README/GUIDE/USAGE 버전·이력 동기. codemap setupScript 엔트리 갱신.

### 범위 외(의도)
- 작업 규모 감지 적응형 Protocol(보고서 8.2)은 오분류 시 재탐색 리스크 → "무손실" 아님, 별도 lane 보류.
- security-check 경량화(8.4)는 보안 리스크 대비 이득 작음 → 폐기.
- 기존 비대 lane 마이그레이션 자동화 없음 — 신규 규칙은 이후 작업부터 적용.
- 스킬 수 18 불변(신규 스킬 없음, 규칙 변경).

### 검증
PSParser parse-ok / embed==live(DoD#7·Doc Rules·HYBRID 섹션) / stale 버전 grep 0 / security-check 🔴0.

### 프로세스
clarity PASS(26/100, 3 결정: 트리거 2건·포인터 유지·toolkit only) → lane 직접 구현. lane: `.claude/pawpad/wip/verification-evidence-archive.md`.
