# CHANGELOG v2.38 — codemap ON START 부분읽기

> PawPad — Agentic Engineering Toolkit. v2.37 기반. ON START codemap read 토큰 절감(부분읽기 + INDEX grep on-demand). 동작·스킬 수(19) 불변.

## 요약
코드 작업 세션 ON START(step7)에서 `.claude/codemap/_index.md`를 통째로 읽던 것을 **MAP+HOT(조망)만 부분읽기**로 전환. 전체 심볼표(INDEX)는 context에 올리지 않고, 특정 심볼 위치가 필요할 때만 **Grep**으로 그 줄만 가져온다(전체 로드보다 쌈). 더불어 HOT 섹션이 spec("최근 3~5개·1줄")을 크게 위반(28개·장문, 12.4k)하던 것을 spec대로 정리. 결과로 코드세션 ON START codemap read가 **~7k → ~0.5k tok** 절감 — ON START 절감 3종(_meta 상단만·HYBRID 조건부·codemap 부분읽기) 완성.

## 배경 (분석 세션 2026-06-24~25)
- `/context` 실측 33.6k baseline 분해 → 절감 여력은 ON START 프로토콜 read에 국한(harness 27.6k·Memory 6k 불변) 확인.
- _meta(상단만, v2.35)·HYBRID(조건부, v2.35)는 부분읽기 적용됨. codemap만 미적용 = 코드세션 전체 read의 절반(~7k)을 codemap이 차지.
- 발견: HOT가 spec(3~5개·1줄)을 위반(28개·장문) → "MAP+HOT만 읽기"의 read 자체가 12.4k로 비대. HOT 트림이 절감의 핵심.

## 결정 (AskUserQuestion)
| 항목 | 결정 | 근거 |
|------|------|------|
| lane scope | **B: 메커니즘 + HOT 정리** | 메커니즘만(A)은 MAP+HOT 비대로 절감 ~3k에 그침. HOT 정리 병행 시 ~6.5k(약 2배). HOT 장문은 _meta RECENT·review 파일과 중복이라 손실 적음 |

## 메커니즘
- **ON START**: codemap은 MAP+HOT(조망)만 부분읽기(상단). INDEX는 안 읽음.
- **심볼 조회**: 특정 심볼 위치 필요 시 INDEX를 Grep(`domain:symbol` 또는 파일명) — 매칭 줄만 반환.
- **HOT 규율**: 최근 3~5개·각 1줄. 비대 시 부분읽기 효과 반감 → 초과·노후 항목은 INDEX로 강등.

## 변경 표면
- **Session Protocol step7**: CLAUDE.md / AGENTS.md (live) + setup.ps1 `$tmplClaudeMd`·`$tmplAgentsMd` 임베드(2곳) — "MAP+HOT만 부분읽기, INDEX는 심볼 필요 시 Grep on-demand" 추가
- **codemap SKILL**: `.claude/skills/codemap/SKILL.md` (live) + `.agents/skills/codemap/SKILL.md` (미러) + setup.ps1 embed(`@"..."@`) — `## ON START 읽기 (토큰 절감)` 섹션 신설
- **codemap _index.md**: HOT 섹션 28개·장문 → 5개·1줄 정리. HOT-only 심볼 18개(실심볼 7 + 리뷰포인터 11)는 **삭제 아닌 INDEX 강등**(INDEX는 grep-on-demand라 ON START 비용 0, 무손실). MAP+HOT 부분읽기분 **1811 bytes**(ON START read 대상). 총 파일 25818 → 18829 bytes(INDEX 65→84). BOM·LF·EOF 보존
- **README/GUIDE/USAGE**: 버전 v2.37→v2.38 + 변경 이력 항목 추가 + changelog 링크 범프 (스킬 카운트 19 불변)
- **PAWPAD_VERSIONS.md**: v2.38 행 + 제목 범위 v2.18→v2.38 + 누적 현황
- **setup.ps1**: 헤더/STATUS/`$ver` 2.37→2.38

## 절감 효과
| | 전 | 후 |
|---|---|---|
| `_index.md` 총 크기 | 25,818 bytes | 18,829 bytes (INDEX 강등 보존) |
| **ON START codemap read** | ~7k tok (전체) | **~0.5k tok (MAP+HOT 1,811 bytes)** ← 실 절감 |
| INDEX (grep-on-demand) | ON START 로드됨 | ON START 미로드 (비용 0) |
| 코드세션 ON START 절감 | — | ~6.5k tok (~11%+) |

분석/질문 전용 세션은 codemap 자체를 skip하므로 절감 0(변동 없음). 효과는 코드수정 세션에 한정.

## 검증
- PSParser 0 (setup.ps1 구문)
- 스킬 19 불변 (.claude / .agents / config 일관)
- step7 embed==live (4표면 동일 문구)
- codemap SKILL embed==live·live==mirror (EOF 관례)
- `_index.md` HOT 5엔트리·BOM·LF·CR 0
- stale v2.37 헤더/링크 잔재 0
- security 🔴0 (프로토콜·문서 변경, 자격증명 무)

## 미실행
- -Upgrade behavioral smoke(EDR-free 머신). 이 변경은 마이그레이션 코드 없음(섹션 추가/문구 변경뿐) → 기존 -Upgrade Merge-MdToolkitSections 경로로 자동 반영.
