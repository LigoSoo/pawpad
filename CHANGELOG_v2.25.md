# CHANGELOG v2.25 - 스킬 rename: karpathy → lean-code + 이연 템플릿 동기화

Date: 2026-06-12
Status: FROZEN
Base: v2.24 (`docs/CHANGELOG_v2.24.md`, Codex 리뷰 PASS_WITH_FIXES 96% → fix 반영 종료)
Lane: `v2.25-lean-code-rename`

## Summary
코딩 원칙 스킬 `karpathy`를 **`lean-code`로 rename** (특정 인물명 제거, 사용자 요청). CLAUDE.md/AGENTS.md 섹션명 `Coding Principles (Karpathy)` → `Coding Principles (Lean Code)`, `-Upgrade` 병합 시 구버전 설치본의 구 섹션명을 **자동 마이그레이션**. 추가로 v2.24 동결 보존 때문에 live 선반영만 하고 이연했던(_meta NEXT) **임베디드 템플릿 동기화 2건** 반영: `$tmplClaudeMd`/`$tmplAgentsMd` session-token-slim, 임베디드 `statusline.ps1`/`.sh` ctx-accuracy. 스킬 내용(4 Core Rules) 무변경 — 이름/경로/참조만 변경.

## Changed
- **skill rename: karpathy → lean-code** (`.claude/skills/lean-code/`, `.agents/skills/lean-code/` mirror):
  - SKILL.md: `name: lean-code`, 제목 `# Lean Code Principles - LLM Coding Anti-patterns`, 강등 안내 참조 갱신. 본문 체크리스트 무변경.
  - CLAUDE.md/AGENTS.md 템플릿+live: 섹션 `## Coding Principles (Lean Code)` (원칙 4줄 무변경).
  - SKILLS_MANIFEST.md(템플릿+live): 표/호출 패턴/체이닝 예시 `/lean-code`.
  - `.codex/config.json`(템플릿+live): skills 배열 `"lean-code"`.
  - clarity/design SKILL.md(템플릿+live+mirror): "karpathy 원칙/적용" → "lean-code".
  - README.md/GUIDE.md/USAGE.md: `/karpathy` 참조 전부 `/lean-code` (+ "구 karpathy" 병기).
  - 비대상(보존): `.claude/pawpad/backup/`, `wip/done/`, `sessions/`, `reviews/`, `docs/CHANGELOG_v2.19.md` (audit/historical).
- **-Upgrade 병합 마이그레이션**: `$claudeToolkitSections`의 `'Coding Principles (Karpathy)'` → `'(Lean Code)'`. 구버전 설치본은 섹션명이 안 맞아 구 섹션 잔존+새 섹션 중복 추가되므로, `Merge-MdToolkitSections` 호출 전에 CLAUDE.md/AGENTS.md의 구 헤더 `## Coding Principles (Karpathy)`를 신 헤더로 치환하는 pre-pass 추가 (쓰기 실패 시 `MERGE-FAIL` `-Always` + `$failed++`, v2.24 F1 정책 동일).
- **이연 동기화 1 — 템플릿 session-token-slim** (_meta NEXT 2026-06-12 항목): `$tmplClaudeMd`/`$tmplAgentsMd` Session Protocol을 live와 동기 — ON START 1↔2 순서 교체(_wip.md 선행, HYBRID.md는 Active Lanes 있을 때만), step 7 codemap은 코드 수정 시작 시점 read(질문/분석 세션 skip), ON TASK DONE에 _meta RECENT 8줄 로테이션(초과분 `sessions/{YYYY-MM}.md` 상단 이동) 명시.
- **이연 동기화 2 — 임베디드 statusline ctx-accuracy** (_meta NEXT 2026-06-12 항목): 임베디드 `statusline.ps1`/`.sh`를 live와 동기 — stdin `context_window` 필드 1순위(모델별 실제 한도, CC v2.1.132+), 구버전 폴백 transcript usage + `model.id` 한도 테이블(fable/mythos/`[1m]`/opus-4-6+=1M, 기본 200k), UTF-8 stdin 디코딩(CP949 한글 경로 가드) 주석 포함.
- `$ver` 2.24 → 2.25, 헤더 STATUS, 완료 요약(lean-code 항목 + CHANGELOG 참조), README/GUIDE 버전 표기·이력.

## 비변경 (보증)
- 스킬 본문(4 Core Rules + Orphan Cleanup) 자구 무변경 — 이름/제목/참조만.
- 설치 단계 수(Step-Begin 28 = $stepTotal) 무변경 — `skill: karpathy` 라벨만 `skill: lean-code`.
- live `.claude/hooks/statusline.ps1`/`.sh`, live CLAUDE.md/AGENTS.md Session Protocol은 이미 선반영분 — 이번엔 임베디드 쪽만 동기 (내용 동일해짐).
- 병합/백업/마이그레이션(v2.22 KMS)/설치 UI(v2.23-24) 로직 무변경.

## Verification
- (lane `## Verification Evidence` 참조 — parse / Step-Begin 카운트 / 병합 마이그레이션 단위 테스트 / stale grep / 임베디드=live diff)

## Notes
- 구버전(≤v2.24) 설치본 업그레이드 경로: `-Upgrade` 실행 시 CLAUDE.md/AGENTS.md 구 섹션명 자동 치환 후 병합. `-Force`는 전체 재생성이라 무관. 기존 `.claude/skills/karpathy/` 폴더는 설치 스크립트가 삭제하지 않음(툴킷은 생성만) — 잔존해도 무해하나 수동 삭제 권장 안내는 GUIDE 이력 줄 참조.
- 신규 이름 후보 중 `lean-code` 선정: 쉬운 단어 + "군더더기 없는 코드" 의미가 스킬 목적(과설계/범위이탈 방지)과 일치.
