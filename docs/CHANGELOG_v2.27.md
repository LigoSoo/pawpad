# CHANGELOG v2.27 - Idea→PRD Routing + Active Skills 표시 + doc/스킬 군살 제거

Date: 2026-06-14
Status: FROZEN (재동결 2026-06-15: 라벨 USED Skills → Active Skills 정정 — 현재진행 의미 명확화. 버전 유지, 표면 재동기)
Base: v2.26 (`docs/CHANGELOG_v2.26.md`, Codex 리뷰 PASS_WITH_FIXES 82% + 스모크 PASS 4/4)
Lane: `idea-prd-routing`

## Summary
아이디어를 개발 가능한 PRD.md로 구체화하는 **스킬 라우팅**을 항시 규칙으로 추가하고, 매 응답에 **현재 사용 중인 스킬**을 표시하는 라인을 도입. 동시에 CLAUDE/AGENTS doc과 일부 스킬의 **군살(중복·불필요 문구)을 제거**(actionable 지시는 무손실). 사용자 요구: clarity↔grill-me 사용 시점 혼동 해소 + pawpad 브랜드 표시(🐾). 강제 아님 — 추천만(다음 스킬 자동 실행하지 않음, 명시 호출 우선).

## Added
- **CLAUDE.md / AGENTS.md `## Idea → PRD Routing` 항시 섹션**: 아이디어 성숙도 단계 라우팅(규모 판단→분해 / clarity 정보게이트 / grill-me 설계판단 조건부 / to-prd 문서화). 판정 한 줄: 정보 부족→clarity / 설계 결정 어려움→grill-me / 둘 다 충족→to-prd. grill-me 신호(결정 상호의존·트레이드오프 연쇄·비가역 선택) 명시. live + 임베디드 `$tmplClaudeMd`/`$tmplAgentsMd` 양쪽. AGENTS는 skill mirror 경로 `.agents/skills/` 현지화.
- **`### Active Skills 표시`** (Response Style 하위): 매 응답 최상단 `🐾 Active Skills: {활성 스킬}` 라인. 단계 첨자(`clarity r2/5` 등). 🐾=pawpad 브랜드. statusLine은 이 머신 org 정책 차단/Codex 미지원이라 응답 라인 방식 채택. live + 템플릿 양쪽.

## Changed
- **doc 군살 제거** (CLAUDE.md/AGENTS.md, live + 템플릿):
  - Session Protocol step0 hook 내부동작 4줄 설명 → 1줄(adapter doc 포인터). hook 행동은 agent가 직접 쓰지 않는 참조.
  - AGENTS `Codex 주의` hook 구현 상세 24줄 → 7줄(중첩 불릿 조밀화, 사실 무손실).
  - AGENTS `Handoff Protocol` 11줄 → 4줄(마커/경로 유지, 절차는 handoff skill/HYBRID 포인터).
- **스킬 슬림** (`.claude/skills/` + 임베디드 `@'...'@` 블록):
  - `feature-architecture`: 업계 근거 출처표 삭제(코드 배치 행동 무관 장식). 코어규칙·결정트리·anti-pattern·boundary표 전부 보존.
  - `design`: PawPad 등록 절차 복붙 → to-prd 포인터(design 맥락 _meta 예시 1줄 보존). 3단계 게이트·UI원칙·출력포맷 보존.
  - `codebase-map`: 목적과 중복된 "codemap과의 분리" 3줄 → 1줄. 7축/digest/권한 보존.
- `pawpad-setup.ps1`: `$claudeToolkitSections`(-Upgrade 병합 대상)에 `'Idea → PRD Routing'` 추가(기존 설치본 업그레이드 시 신규 섹션 병합). 헤더 STATUS(v2.26 줄 보존).
- `README.md`/`GUIDE.md`/`USAGE.md`: 버전 표기·이력·변경 이력 링크.
- `$ver` 2.26 → 2.27.

## 비변경 (보증)
- 신규 스킬 없음(스킬 수 16 유지). 라우팅/Active Skills는 항시 규칙·표시이지 스킬 추가 아님.
- 기존 스킬의 actionable 로직(게이트/결정트리/체크리스트/출력포맷) 무변경 — 제거는 출처인용·중복·복붙뿐.
- 병합/백업/설치 UI 로직 무변경. SKILLS_MANIFEST/config.json skills 무변경(스킬 수 동일).

## Verification
- `pawpad-setup.ps1` PSParser tokenize parse-ok(0 에러, tokens=4701). 템플릿 `@"..."@` backtick 이중화 + 스킬 임베드 `@'...'@` 단일 backtick 무결성 확인
- 임베디드 `$tmplClaudeMd`/`$tmplAgentsMd` `## Idea → PRD Routing` + `### Active Skills` == live
- `$claudeToolkitSections`에 `'Idea → PRD Routing'` 포함(-Upgrade 병합)
- `.agents/skills` 미러: setup `@'...'@` 임베드와 다음 `pawpad-setup.ps1` 실행 시 자동 동기(미러 헤더 `# DO NOT EDIT` 준수, 수동 미편집)
- security-check: 문서/설정 전용 → 면제(분석/문서전용)

## Codex 교차 리뷰
- **review-01** (`.claude/pawpad/reviews/idea-prd-routing-v2.27-review-01.md`): **PASS_WITH_FIXES 86%**, 코드 결함 0. findings 2건(🟡) 전부 반영:
  - **F1**: `$tmplAgentsMd` Session Protocol ON 8턴 줄의 `.codex/hooks.json` single-backtick — `@"..."@`에서 소비돼 생성 AGENTS.md code span 소실(잠복 버그). double-backtick 교정.
  - **F2**: README/setup 스킬 수 표기 15 → 16(실제 16). setup 헤더 스킬 목록에 `codebase-map` 추가. 완료 요약 CHANGELOG 링크 v2.26 → v2.27.
- 재검증: PSParser 0 errors / L956 backtick 이중화 확인 / README·GUIDE·USAGE stale "15" 0건 / skill count `.claude`==`.agents`==16.
- 질문 7건 답변: backtick(F1 외 정상), 임베디드==live, -Upgrade 병합(`### Active Skills`는 Response Style 하위라 별도 불필요 확인), actionable 무손실, PS5.1 호환, 범프 체크리스트 정합, `.agents` 미러 미편집 판단 — 전부 확인.

## Notes
- 라우팅/Active Skills는 **doc 기반**이라 hook 정책 차단 머신에서도 작동(hook 비의존). Claude/Codex 양쪽 동일.
- `.agents/skills` 미러는 setup 자동 생성물 — **2026-06-15 `pawpad-setup.ps1 -Upgrade` 실행으로 동기 완료**(source=16==mirror=16, 슬림 3종 반영, F1 backtick 단일 렌더 확인). 부수: 완료요약 Write-Host(L4687) stale "15 스킬" → 16 교정.
