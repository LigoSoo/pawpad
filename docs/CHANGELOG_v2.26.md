# CHANGELOG v2.26 - feature-architecture 구조 개발 방법론 추가

Date: 2026-06-13
Status: FROZEN
Base: v2.25 (`docs/CHANGELOG_v2.25.md`, Codex 리뷰 PASS_WITH_FIXES 97% + post-freeze BOM hotfix 반영)
Lane: `feature-architecture`

## Summary
스택 중립 **구조 개발 방법론**(feature-first)을 toolkit에 추가. 추후 기능 추가·수정 효율 + codemap 색인 친화 + 사람의 구조 가독성(Screaming Architecture)이 목표. 기존 `lean-code`(억제 규율)와 **소유권 분리**: lean-code는 "할지/범위", feature-architecture는 "하기로 한 코드를 어디 둘지". 강제 방식은 `caveman`/`lean-code` 선례 복제 — 코어 규칙은 CLAUDE.md/AGENTS.md 항시 섹션(신규/변경 코드만), 상세는 신규 스킬. brainstorming → spec → Codex 리뷰(PASS_WITH_FIXES 82%, findings 6건 반영) → writing-plans → subagent-driven 구현.

## Added
- **신규 스킬 `feature-architecture`** (`.claude/skills/feature-architecture/SKILL.md` + `.agents/skills/` 미러):
  - 상세 규칙 5(파일 1책임)·6(codemap 도메인 명명 정렬)·7(anti-pattern: god-module/순환참조/premature 추상화/layer-first 회귀/shared-dump 회귀)·8(public boundary 스택별 예시)
  - 신규 기능 위치 결정트리(기존 도메인 하위/새 도메인/도메인 비소속 shared + registration-only edit 허용)
  - 공통 코드 승격 규칙(사용 범위 따라, Rule of Three 모순 없이)
  - 업계 근거(Feature-based, Colocation, Vertical Slice, Rule of Three, Screaming Architecture) + 프레임워크 관례 우선 단서
- **CLAUDE.md / AGENTS.md `## Architecture Principles (Feature-First)` 항시 섹션** (코어 규칙 4 + 새 기능 위치 1줄, 신규/변경 코드만 강제). live + 임베디드 `$tmplClaudeMd`/`$tmplAgentsMd` 양쪽. AGENTS는 스킬 경로 `.agents/skills/` 현지화.
- **Definition of Done #9** (코드 변경 시 Architecture Principles 준수, 분석/문서전용 면제). live + 템플릿 양쪽.

## Changed
- `.claude/SKILLS_MANIFEST.md`(live+템플릿): 스킬 수 15 → 16, `feature-architecture` 카탈로그 행 + 강등 안내 note.
- `.codex/config.json`(live+템플릿 `$tmplCodexConfigJson`): skills 배열에 `"feature-architecture"`. live 파일 선행 BOM 제거(Codex serde 정책 부합, JSON valid).
- `.claude/codemap/_index.md`: `pawpad:featureArchSkill` 심볼 등록(INDEX + HOT).
- `pawpad-setup.ps1`: 스킬 임베드 블록(리터럴 `@'...'@` here-string — 코드펜스 백틱 보존), 헤더 주석 스킬 목록, 완료 요약 Write-Host, `$claudeToolkitSections`(-Upgrade 병합 대상)에 `'Architecture Principles (Feature-First)'` 추가(기존 설치본 업그레이드 시 신규 섹션 병합).
- `README.md`/`GUIDE.md`/`USAGE.md`: `/feature-architecture` 스킬 목록 추가, 버전 표기.
- `$ver` 2.25 → 2.26, 헤더 STATUS(이전 v2.25 줄 보존), README/GUIDE 버전·이력.

## 비변경 (보증)
- 기존 스킬/규칙/병합/백업/설치 UI 로직 무변경 — feature-architecture는 가산적 추가.
- lean-code 본문 무변경(소유권 분리, 접점은 Rule of Three뿐).

## Verification
- `pawpad-setup.ps1` PSParser tokenize parse-ok(0 에러), 리터럴 here-string 무결성 확인
- skill count parity `.claude/skills`=16 == `.agents/skills`=16
- 임베디드 `$tmplClaudeMd`/`$tmplAgentsMd` `## Architecture Principles (Feature-First)` 섹션 + DoD#9 == live (각 2회)
- `.codex/config.json` JSON.parse ok, BOM 없음(첫 바이트 7b), skills.length=16
- SKILLS_MANIFEST (16개) 1회, README/GUIDE/USAGE feature-architecture 포함
- security-check: all 12files 🔴0 🟡0 → PASS (문서/설정 전용)
- 파일 원형 보존: UTF-8 BOM + LF

## Codex 교차 리뷰
- **Spec review-01** (`.claude/pawpad/reviews/feature-architecture-spec-review-01.md`): **PASS_WITH_FIXES 82%**. findings 6건 전부 spec 반영 후 구현:
  - H1: "형제 불변" → additive + 최소 integration edit(route/menu registry 등) 허용
  - H2: Codex 런타임 표면(`.agents/skills` 미러 + `.codex/config.json` skills) Files To Touch 추가
  - M1: `index 하나` → 스택 중립 `public boundary`
  - M2: cross-menu 승격 기준 Rule of Three 모순 제거
  - L1: lean-code "겹침 없음" → 소유권 분리 + 접점 명시
  - L2: 코어 섹션은 압축 1줄 branch, 전체 트리는 skill
- **Codex CLI 스모크** (`.claude/pawpad/reviews/feature-architecture-codex-smoke.md`): **PASS 4/4** — AGENTS.md 섹션+DoD#9(.agents 경로), 미러+헤더, config skills+BOM 없음, c-export 시나리오에서 규율이 실제 행동 유도 확인. slash 없이 항시 규칙+스킬 트리거로 인식.

## Notes
- 이 방법론은 toolkit의 **방법론 레이어**(스킬+규칙)다. 실제 프로젝트에서 발동하려면 해당 프로젝트 CLAUDE.md `Code Conventions`에 그 스택의 feature-first 레이아웃을 1회 선언하면, 이후 신규/변경 코드가 규칙 + codemap 색인으로 관리됨.
- Claude Code ↔ Codex CLI 양쪽 동일 강제. 차이는 호출 UX(slash vs 자연어/자동트리거)뿐.
