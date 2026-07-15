# CHANGELOG v2.45 — brainstorming 스킬 신규 (발산 + 누락 스윕 + 스코프 게이트, 20→21)

Date: 2026-07-15
Base: v2.44 (FROZEN)
Lane: `brainstorming-skill`
Spec: `.claude/pawpad/specs/brainstorming-skill.md`

## Summary

신규 스킬 `brainstorming`(스킬 20→21, **prd 번들**) — clarity 이전 발산 단계 공백 해소. 막연한 아이디어 또는 초안 기획문서를 받아 ①방향 발산·확정 ②기능 누락 스윕 ③MoSCoW 스코프 확정까지 단일 스킬로 수행하고 산출물(기능 목록 완전판)을 clarity로 인계한다.

배경(사용자 실관측 pain): 구현 후반에 기능 추가/삭제가 다발해 불필요 작업이 누적. 원인은 모호함(clarity 영역)이 아니라 ①커버리지 부재(인접기능·비해피패스 누락) ②스코프 미결정(Won't 미명시). 기존 파이프라인(clarity→grill-me→to-prd)은 전부 수렴 도구 — "생각 못 한 기능을 찾아주는 단계"가 없었다. CLAUDE/AGENTS 자동제안·Active Skills 첨자에 `brainstorming` 이름만 존재(실체 없음)하던 dangling 참조도 이 스킬로 실체화. v2.32 결정(superpowers brainstorming 통째 도입 회피)과 무충돌 — 이식이 아닌 PawPad 자체 설계.

파이프라인: **brainstorming → clarity → grill-me → to-prd → mockup**

## Added

- **신규 스킬 `brainstorming`** (`.claude/skills/brainstorming/SKILL.md` + `.agents/skills/` 미러 + setup 임베드):
  - **진입 판정(방향 확정도)**: 입력에서 방향 3요소(무엇을/누구에게/왜) 확인 — 모두 명시(구체화된 기획문서 등)면 스윕 직행, 하나라도 누락이면 발산부터. 판정 1줄 선언(`진입 판정: {발산|스윕} — {근거}`) + 사용자 오버라이드("발산부터"/"스윕부터"). clarity 외부 문서 모드와 동일한 마찰 최소 정신.
  - **1단계 발산**: 핵심 1줄 재진술 → 방향 후보 2-3개(트레이드오프+추천 정확히 1개, clarity 접근법 게이트 원칙 재사용 — 가짜 대안 금지, 4개 이상 발산 시 상위 3 shortlist — Codex 질문 도구 최대 3옵션 계약) → AskUserQuestion 선택 → 3요소 요약. 세부 사양 파고들기 금지(clarity/grill-me 영역 침범 방지).
  - **2단계 스윕(누락 감사)**: 2a 인접기능 스윕(사용자 여정 전/후, 관리자/운영자, 데이터 입출력 짝, 주 페르소나 저니 워크스루) + 2b 비해피패스 8축 고정 체크리스트(빈 상태/에러·실패/권한·인증/CRUD 대칭/데이터 수명주기/알림·피드백/설정·개인화/운영·관측). 8축 초과 확장 금지(lean). 스윕은 후보 나열만 — 즉석 탈락 금지.
  - **3단계 스코프 게이트(MoSCoW)**: 전체 후보 Must/Should/Could/Won't 분류 제안 → AskUserQuestion 경계 확정. **Won't 명시 없이 종료 금지**(삭제 churn 차단이 존재 이유). 산출: 기능 목록 완전판 표(기능|출처|MoSCoW).
  - 종결 시 /clarity 1회 추천(자동제안 규칙). Active Skills 첨자: `brainstorming`(발산) / `brainstorming sweep`(스윕·스코프).

## Changed

- `pawpad-setup.ps1` (v2.44 → **v2.45**):
  - 헤더 STATUS 갱신 + 스킬 목록에 brainstorming, `$ver = "2.45"`.
  - brainstorming SKILL 임베드 블록(literal `@'...'@`, grill-me 단계 동거 설치 — stepTotal 29 불변, v2.43 task-done 선례).
  - `$bpMap` prd 번들: `@('brainstorming', 'clarity', 'grill-me', 'to-prd')` — lean 12 / standard 18 / full 21. prd 미선택 시 스킬 dir·config·manifest·docs(`## Idea` 섹션 통째) 프룬 경로에 자동 포함, 신규 prune 규칙 불요(신규 doc 문구 전부 `## Idea → PRD Routing` 섹션 내부 한정).
  - `$tmplClaudeMd`/`$tmplAgentsMd` Idea → PRD Routing: 판정 라인에 brainstorming 추가(`방향 미정(무엇을/누구에게/왜 미충족)·기능 누락/스코프 점검 필요→brainstorming(발산+스윕) / ...`) + `- brainstorming 종결 후: →clarity.` + 자동제안 종료 트리거에 brainstorming + AGENTS skill mirror 목록.
  - SKILLS_MANIFEST 임베드: 21개 + brainstorming 행 + `/brainstorming` 호출 줄. `$tmplCodexConfigJson` skills 배열 21.
  - 완료 요약 ko/en: 21 스킬 + v2.45 bullet + 상세 링크 v2.45.
- live 동기(fresh install 외 1회 수동, 체크리스트 항목 6): `CLAUDE.md` / `AGENTS.md`(판정·종결 체인·자동제안·mirror 목록) / `.claude/SKILLS_MANIFEST.md` / `.codex/config.json` skills.
- `README.md` / `GUIDE.md` / `USAGE.md`: 제목·버전·스킬 카운트 21·스킬 표 행·파이프라인 다이어그램·설치 검증 예시·변경 이력 bullet·CHANGELOG 링크 범위(+1). GUIDE 잔존 stale 카운트 2건(`SKILLS_MANIFEST (19)`, `.agents/skills/{19}`) 동시 보정. README 설치 검증 주석 stale `# 19` 보정.
- `PAWPAD_VERSIONS.md`: v2.45 행 + 제목 범위 + 누적 현황(스킬 21).
- `.claude/codemap/_index.md`: brainstorming 스킬 항목 + setupScript 갱신.

## Verification

- PSParser tokenize: parse errors 0 (편집 후 전수).
- live SKILL.md == setup 임베드(+CRLF 규약) == `.agents` 미러(frontmatter+DO NOT EDIT 헤더+body, EOF 0d0a0d0a — 기존 미러와 동일 패턴, setup writer 로직 PowerShell 재생성으로 byte-exact).
- 번들 회귀 4조합(lean/standard/prd-only/full): 스킬 dir·config·manifest·docs dangling 검증 (v2.44 교훈 — lean/standard만 smoke 금지).
- stale grep: `20개`·`20 스킬`·`20 skills`·`v2.44`(이력 제외) 라이브 0.
- security-check: 신규/변경 파일 secrets·자격증명 0 (텍스트/instruction 변경만, 실행 로직 신규 없음 — bpMap 배열 1원소 추가 제외).

## Notes

- brainstorming vs clarity 접근법 게이트: 게이트는 "구현 접근법"(HOW) 대안, brainstorming 발산은 "제품 방향"(WHAT) 대안 — 층위가 다름. 동일 원칙(2-3개·추천 1개·가짜 대안 금지)만 공유.
- 산출물 저장은 기본 대화 출력(PRD 저장은 to-prd 몫). 대형 목록만 사용자 요청 시 `specs/{feature-id}-ideation.md`.
- 100% 사전 확정은 목표 아님 — 누락형 churn 제거가 목표, 학습형(만들어 봐야 아는) churn은 수용.
