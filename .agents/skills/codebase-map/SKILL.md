---
name: codebase-map
description: High-level codebase map (7 axes). Use to record or recall architecture, structure, conventions, testing, and cross-cutting concerns without reading the whole tree. Complements codemap (symbol registry) at a higher altitude. Refresh on structural change.
---
# DO NOT EDIT: generated from .claude/skills/codebase-map/SKILL.md by pawpad-setup.ps1.
# CodeBase-Map Skill - High-Level Project Map

## 목적
코드베이스를 7축 고수준 문서로 관리. codemap이 "심볼 위치"(저고도)라면 codebase-map은 "아키텍처/구조/관례/관심사"(고고도).
신규 세션·신규 에이전트가 트리 전체를 읽지 않고 프로젝트 정신모델을 즉시 획득 -> 토큰 절약.

codemap과의 분리:
- codemap: domain:symbol -> file:role 1줄 레지스트리. "어디 있나".
- codebase-map: 축별 산문 문서. "어떻게 구성/동작/약속".

## 위치 (canonical)
.claude/pawpad/codebase/{axis}.md — 축당 1파일.
digest: .ctxdb/L2/codebase-map-current.md — 주입용 압축본.
codemap _index.md: pointer 1줄만 (pawpad:codebaseMap  .claude/pawpad/codebase/  7-axis high-level map).

## 7축 (required 5 + optional 2)
| 축 | 파일 | required | budget(줄) | 내용 |
|----|------|:--------:|:----------:|------|
| ARCH    | architecture.md | Y | 220 | 시스템 아키텍처, 레이어, 주요 데이터 흐름, 핵심 설계 결정(ADR 링크) |
| STRUCT  | structure.md    | Y | 150 | 디렉토리/모듈 레이아웃, 각 모듈 책임 1줄 |
| CONV    | conventions.md  | Y | 150 | 명명/타입/로깅/상수/에러 정책, 코드 스타일 |
| TEST    | testing.md      | Y | 150 | 테스트 전략, 명령, 커버리지 영역, fixture 위치 |
| CONCERNS| concerns.md     | Y | 150 | cross-cutting: 인증, 에러처리, 설정, 보안, 성능, 로깅 |
| STACK   | stack.md        | optional | 150 | 기술 스택, 핵심 의존성+버전, 빌드 도구 |
| INTEG   | integrations.md | optional | 150 | 외부 API/서비스 연동, 인증방식, 엔드포인트 |

required 5축은 항상 존재. optional 2축은 해당 시만 생성(없으면 미생성, digest에 "n/a" 표기 금지 — 행 자체 생략).

## 각 문서 헤더 (stale guard, 필수)
모든 axis 파일 최상단:
```
<!-- axis: ARCH -->
Last refreshed: YYYY-MM-DD
Stale when: 핵심 구조/데이터흐름 변경
Budget: 220 lines
```
- Last refreshed: 마지막 갱신 날짜(YYYY-MM-DD).
- Stale when: 이 문서를 다시 손봐야 하는 트리거 조건(축별 상이).
- Budget: 위 표의 줄 수. 초과 시 압축 또는 codemap/ADR로 분리. 산문 누적 금지.

## digest (.ctxdb/L2/codebase-map-current.md, budget 120줄)
주입 전용 압축본. 축당 3~6줄 요약 + canonical 파일 pointer.
원칙: digest는 "무엇이 있는지 + 어디 읽을지"만. 세부는 full 문서 on-demand read.

## digest-only 주입
ctxdb-inject hook이 codebase-map 키워드(architecture/structure/convention/codebase-map 등) 매치 시:
- digest(.ctxdb/L2/codebase-map-current.md)만 주입.
- full 7축 docs는 자동주입 금지 — 에이전트가 필요 시 on-demand read.
- 근거: full inject(7파일 ~1000줄)는 토큰절약 목적 파괴. digest 120줄로 정신모델 제공 후 deep-dive만 read.
- INDEX.md 키워드행 + L1 pointer가 digest를 가리킴.

## 생성 절차 (최초)
1. required 5축 파일 생성, 각 stale-guard 헤더 박기.
2. 코드베이스 스캔 -> 축별 내용 작성(budget 내).
3. optional 2축은 해당 시만.
4. digest 작성(축당 3~6줄).
5. codemap _index.md에 pointer 1줄 추가.
6. .ctxdb/INDEX.md 키워드행 + L1 pointer 등록.

## 갱신 절차 (refresh)
- 트리거: 해당 축 Stale when 조건 충족, 또는 구조 변경 PR.
- 변경 축 파일만 수정 -> Last refreshed 갱신 -> digest 해당 섹션 동기 -> budget 재확인.
- code+doc 한 단위(atomic). 구조 바꾸고 map 안 고치면 stale.

## 권한 (codemap과 동일 모델)
| 작업 | 허용 |
|------|------|
| 신규 축 파일 추가 | 누구나 (lane 무관) |
| 기존 축 내용 수정 | lane owner만 (_wip.md Locks 확인) |
| digest 갱신 | owner만 (내용 동기 책임) |
| codemap pointer 추가 | 누구나 |

## codemap vs codebase-map 선택
| 기록 대상 | 위치 |
|----------|------|
| 심볼 위치/시그니처 | codemap _index.md |
| 아키텍처/레이어/데이터흐름 | codebase-map ARCH |
| 디렉토리 책임 | codebase-map STRUCT |
| 명명/타입/로깅 정책 | codebase-map CONV |
| 되돌리기 어려운 결정 | decisions/arch.md ADR (codebase-map ARCH에서 링크) |

중복 금지: codebase-map은 codemap 심볼을 복붙하지 않음(pointer/요약만). ADR rationale도 복붙 금지(링크).

