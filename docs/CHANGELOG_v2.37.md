# CHANGELOG v2.37 — grill-with-docs → grill-me 흡수

> PawPad — Agentic Engineering Toolkit. v2.36 기반. 죽은 중복 스킬 1개 제거 + 고유가치 일부를 grill-me에 흡수(스킬 20→19).

## 요약
`grill-with-docs`를 `grill-me`에 흡수하고 제거. grill-with-docs는 grill-me의 상위집합이었으나 고유가치(`CONTEXT.md` 용어집)는 0건 사용, ADR offering은 Decision Placement Matrix 경로와 중복 → 죽은 중복. grill-with-docs의 **순수 인터뷰 품질**(인프라 비의존)만 grill-me에 흡수하고, 미사용 용어집·중복 ADR offering은 DROP. 스킬 수 **20 → 19**.

## 결정 (AskUserQuestion)
| 항목 | 결정 | 근거 |
|------|------|------|
| 흡수 범위 | **Lean (A·B·C·D)** — 순수 인터뷰 품질만 흡수, 용어집(E)·ADR offering(F) DROP | E는 0건 사용(죽음), F는 Decision Placement Matrix 중복. grill-me 미니멀 철학 유지하며 grilling 깊이만 강화 |

흡수 내용(A·B·C·D):
- **A Sharpen fuzzy language** — 모호/중의 용어를 정확한 canonical 용어로 좁힌다.
- **B Discuss concrete scenarios** — 도메인 관계·경계를 구체 시나리오·엣지케이스로 stress-test.
- **C Cross-reference with code** — 진술과 코드가 어긋나면 즉시 모순 표면화.
- **D Domain awareness** — 탐색 시 기존 문서(specs/PRD/decisions)도 확인.

DROP(E·F):
- **E CONTEXT.md 용어집** — challenge against glossary + inline 갱신. 도입 후 0건 생성(죽은 인프라).
- **F ADR offering** — 3조건 게이트. `.claude/HYBRID.md` Decision Placement Matrix가 이미 ADR 라우팅 커버 → 중복.

## 변경 표면
- **live 스킬**: `.claude/skills/grill-me/SKILL.md` 보강(description 강화 + A·B·C·D 본문) / `.claude/skills/grill-with-docs/` dir 제거
- **.agents 미러**: `.agents/skills/grill-me/SKILL.md` 재생성(setup 미러 로직: frontmatter+DO NOT EDIT 헤더+body, EOF 0a0a) / `.agents/skills/grill-with-docs/` dir 제거
- **config/manifest**: `.codex/config.json` skills 배열 `"grill-with-docs"` 제거(20→19, no-BOM) / `SKILLS_MANIFEST.md` (20개)→(19개) + grill-with-docs 행 제거 + grill-me 설명 보강 + 호출패턴
- **CLAUDE.md / AGENTS.md**: Idea→PRD Routing 자동제안 목록·선택지=체크박스 목록에서 grill-with-docs 제거(live + setup `$tmplClaudeMd`·`$tmplAgentsMd`)
- **README/GUIDE/USAGE**: grill-with-docs 행/언급 제거 + grill-me 설명 보강 + 스킬 카운트 20→19 전수 + 버전 v2.36→v2.37 + changelog 링크 범프
- **setup.ps1**: 헤더 STATUS/`$ver` 2.36→2.37, 헤더 skill 목록 주석, grill-me embed 블록(`@"..."@`) 보강 + grill-with-docs embed 블록(`@'...'@`) 제거, 임베드 manifest/config/완료요약 카운트, **-Upgrade 마이그레이션 block 신규**(구 grill-with-docs dir 제거 + config 정리)
- **PAWPAD_VERSIONS.md**: v2.37 행 + 제목 범위 v2.18→v2.37 + 누적 스킬 19개
- **codemap**: setupScript v2.37 노트

## -Upgrade 마이그레이션 (기존 설치)
1. `.claude\skills\grill-with-docs` / `.agents\skills\grill-with-docs` 존재 시 Remove (grill-me는 toolkit 재생성·보강)
2. `.codex\config.json` skills 배열에서 `"grill-with-docs"` 줄 제거 (no-BOM 유지, 병합 union 시 구 항목 잔존 방지)
- 모두 백업 전 수행 → 백업은 마이그레이션 후 상태 기준 (ADR-002/v2.34 선례 패턴)

## 비변경 (audit 보존)
backup/ · wip/done/ · sessions/ · reviews/ · handoffs/ · specs/ · 과거 changelog(v2.28·v2.36 등) — 과거 문서 속 `grill-with-docs` 표기는 의도적 stale (ADR-002 선례).

## 검증
- PSParser 0 (setup.ps1 파싱)
- live `.claude/skills/grill-me/` == `.agents/skills/grill-me/` 미러 (DO NOT EDIT 헤더 제외)
- 스킬 수 19 일관 (.claude == .agents == config == manifest == setup 임베드)
- 임베드 == live (grill-me skill 블록·$tmpl 목록·manifest·config)
- `.codex/config.json` no-BOM + JSON valid
- grill-with-docs 잔재 0 (라이브 dir·config·manifest·자동제안 목록; audit 제외)
- security-check 🔴 0

## 리뷰
- Claude 서브에이전트(Read/Grep/Glob 전용, EDR-safe) 문서형 /review 라운드트립 **PASS 96% findings 0** (7불변식 검증). reviews/grill-merge-v237-review-01.md.
- codex exec 크로스모델 리뷰는 이 머신 EDR 차단(os error 10013)으로 불가 → WSL/EDR-free 머신.

## 후속 보정 — 스킬 리스트 완성 (2026-06-23)
v2.37 직후 사용자 지적("스킬 리스트에 스킬 누락, 설명/예시 미흡")으로 문서 스킬 카탈로그 정합 보정. 근본 원인: `viewer-apply`(v2.36 신규)가 README에만 반영되고 GUIDE/USAGE에 누락 — GUIDE 카탈로그가 "(19개)"라면서 18개만 나열. 문서전용(GUIDE.md·USAGE.md, setup 비임베드 독립 repo 문서 → 미러/임베드 동기 불요).
- **GUIDE**: 카탈로그 Workflow에 `/viewer-apply` 행 추가(→19개 일치) + §2d "통합 4탭 검토 — /mockup viewer + /viewer-apply" worked example 신설 + 체이닝 치트시트 기획→구현 흐름에 viewer 단계 추가.
- **USAGE**: §1 "이럴 땐" 표에 `/mockup viewer`·`/viewer-apply`·`/code-delegate` 행 추가 + §6 전체목록에 `viewer-apply` 행 추가(→19개).
- 검증: viewer-apply가 README·GUIDE 카탈로그·USAGE §6·SKILLS_MANIFEST 4표면 모두 존재, GUIDE 카탈로그 19행 일치. 문서전용 → security-check 면제.
