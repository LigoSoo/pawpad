# CHANGELOG v2.39 — 번들 선택 설치 + 안내 언어 i18n

> PawPad — Agentic Engineering Toolkit. v2.38 기반. 설치 시 스킬 번들 선택(`-Preset`/`-Bundles`) + 안내 메시지 언어 선택(`-Lang en|ko`). 스킬 내용·스킬 수(19) 불변.

## 요약
설치기에 두 가지 선택 기능 추가.
1. **번들 선택 설치**: Core 11(인프라, 고정) 외 Optional 스킬을 기능 번들 단위로 선택. `-Preset lean|standard|full` 또는 `-Bundles prd,ui,delegate,review`. 미지정 시 대화형 프롬프트(Enter=full, 하위호환).
2. **안내 언어 i18n**: 사람 대상 설치 안내 메시지를 영어/한글 선택. `-Lang en|ko`(Enter=ko). **스킬 내용·CLAUDE.md 등 에이전트 문서는 단일 소스 무변경**(독자가 이중언어 LLM이라 동작 무관 + 영문화 토큰이점 미미: 문서 이미 ~88% 비한글).

방식은 **prune-at-end** — 전체 19 설치 후 미선택 번들 정리. 기존 19개 스킬 write 블록 무수정(가산적).

## 번들 정의
| 번들 | 스킬 | 의존 |
|------|------|------|
| (Core, 고정) | resume, ctxdb-navigator, checkpoint, context-saver, handoff, codemap, codebase-map, caveman, lean-code, feature-architecture, security-check (11) | — |
| prd | clarity, grill-me, to-prd (3) | 자기완결 (to-prd가 기획 허브) |
| ui | design, mockup, viewer-apply (3) | ⇒ prd (design이 to-prd 등록절차 의존) |
| delegate | code-delegate (1) | ⇒ prd (위임할 written spec 전제) |
| review | review (1) | 자기완결 |

프리셋: `lean`=Core 11 / `standard`=Core+prd+delegate+review (16) / `full`=19. ui·delegate 선택 시 prd 자동 포함.

## 메커니즘 (prune)
미선택 번들에 대해 4개 정합 지점 동기 → dangling 0:
1. 스킬 디렉토리 제거 (`.claude/skills/{s}` + `.agents/skills/{s}`)
2. `.codex/config.json` `skills` 배열을 설치분만으로 재생성
3. `.claude/SKILLS_MANIFEST.md` 카운트 + 테이블 행 + 호출/체이닝 줄 정리
4. **docs 본문**(CLAUDE.md/AGENTS.md/HYBRID.md): prd 없으면 `## Idea → PRD Routing` 섹션 통째 제거 / 부분 케이스는 enumeration 토큰(`·`·`{,}`) + `design(...)` 줄 + review·mockup 줄 + Active Skills 첨자 토큰 제거. 안전망으로 "설치 스킬만 추천" 가드 1줄 추가.

dangling은 docs 본문이 ~90%(스킬 파일·config·manifest는 소수). 스킬 파일만 빼면 생성 문서가 미설치 스킬을 가리켜 "죽은 추천" 발생 → 위 트림으로 해소.

## 안내 언어 i18n
- `$TR` 메시지 테이블(ko/en) + `$L = $TR[$Lang]`. 지역화: 배너 후 언어 프롬프트, 스택/번들 프롬프트, 번들 설치 줄, 완료 메시지, changelog(ko=상세/en=압축), generic 노트, 다음 단계, force/업그레이드 힌트, 섀도잉 경고, 체크리스트 헤더, 백업없음.
- 스킬 본문·CLAUDE/AGENTS/HYBRID 등 **에이전트 문서는 미지역화**(단일 소스).

## 변경 표면
- **setup.ps1**: param `-Preset`/`-Bundles`/`-Lang` 추가, 번들 해석 블록(스택 선택 뒤), prune 블록(완료 요약 직전), `$TR` 테이블 + 언어 해석, 인스톨 안내 메시지 `$L` 치환, 헤더/STATUS/`$ver` 2.38→2.39, Usage 줄, 완료 요약 CHANGELOG 참조/번들 bullet
- **README/GUIDE/USAGE**: 버전 v2.38→v2.39 + 변경 이력 항목 + changelog 링크 범프 (스킬 카운트 19 불변)
- **PAWPAD_VERSIONS.md**: v2.39 행 + 제목 범위 v2.18→v2.39 + 누적 현황 헤더
- **스킬 내용·19개 불변** (가드는 install-time 1줄, 템플릿 섹션/스킬 추가 없음)

## 검증 (샌드박스 C:\Antigravity\pawpad-Toolkit-test)
| 프리셋 | 디스크 스킬 | config | manifest | docs dangling |
|--------|------------|--------|----------|---------------|
| lean | 11 | 11 | 11 | **0** |
| standard | 16 | 16 | 16 | **0** |
| full / default(무인자) | 19 | 19 | 19 | 0 (하위호환, prune 생략) |

- `-Lang en` / `-Lang ko` 양쪽 안내 출력 정상, 스킬 내용 동일(무변경).
- BOM(UTF8) 보존, PSParser 0.
- 인코딩 교훈: 무-BOM .ps1엔 유니코드 리터럴 금지 → `[char]0xB7`(·)·`[char]0xAC1C`(개) 런타임 생성, 파일 IO `[System.IO.File]` + UTF8. `"v$ver:"` → `"v${ver}:"` (drive-scope 오해석 회피).

## 미실행
- Codex 크로스모델 리뷰(이 머신 EDR이 codex exec 차단). Claude 네이티브 검증으로 대체.
- -Upgrade + 번들 조합 behavioral smoke(EDR-free 머신). prune은 설치 후처리라 -Upgrade 경로와 독립.
