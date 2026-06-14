---
name: feature-architecture
description: Feature-first structure reference. Enforcement lives in CLAUDE.md/AGENTS.md Architecture Principles; this file is the detailed decision tree, anti-patterns, and stack examples. Use when starting a new feature, placing new code, or restructuring modules.
---
# Feature Architecture - Structure Discipline (참조 문서)

> **강등 안내**: 구조 원칙은 **CLAUDE.md/AGENTS.md `Architecture Principles (Feature-First)`가 강제**한다(신규/변경 코드만, 레거시 비강제).
> 이 파일은 별도 호출 대상이 아닌 **상세 참조** — 경계 판단 결정트리 / 스택별 예시 / anti-pattern.
> **lean-code와 소유권 분리**: lean-code="할지 말지·범위"(restraint), feature-architecture="하기로 한 코드를 어디 둘지"(structure). 접점은 Rule of Three뿐, 모순 없음.

## 코어 규칙 (CLAUDE.md/AGENTS.md가 강제, 여기선 참조)
1. **모듈 경계**: colocation + 단일 public boundary
2. **횡단 import 금지** (단 public boundary 의존은 허용)
3. **Rule of Three**
4. **신규 = 가산적 + 최소 integration edit 허용**

## 상세 규칙
### 5. 파일 1책임 + 비대화 시 분할
한 파일 = 한 책임. 커지면 분할. codemap 심볼과 1:1 유지 → 색인 정확도.

### 6. codemap 도메인 명명 정렬
파일/심볼명이 `domain:symbol`로 깔끔히 매핑되게 명명. 예: `src/menu-c/c-export/export.logic` → `menu-c:exportLogic`. DoD#5(codemap 갱신)와 짝 → "codemap 이용 개발"의 명명 브릿지.

### 7. anti-pattern 체크리스트
- **god-module**: 한 파일/폴더가 여러 도메인 책임 → 분할
- **순환참조**: A→B→A → public boundary 또는 hoist로 단방향화
- **premature 추상화**: 2곳 중복에 성급한 공통화 (Rule of Three 위반)
- **layer-first 회귀**: controllers/·services/ 식 레이어 우선 분할로 복귀
- **shared-dump 회귀**: cross-menu 2회 사용을 즉시 global shared로 올림

### 8. public boundary 스택별 예시 (코어는 관계형, 구체는 여기)
| 스택 | public boundary |
|------|------------------|
| TS/JS | `index.ts` / package exports |
| Python | `__init__.py` / 명시적 module API |
| Rust | `mod.rs` / `lib.rs` |
| Go | package-level exported identifiers |
| Rails/Next | 프레임워크 route/module 관례 **우선** |

## 신규 기능 위치 결정트리
```
새 기능이...
├─ 기존 메뉴(도메인) 소속 → 그 메뉴 폴더 아래 하위 폴더 추가 (형제 로직 불변)
├─ 새 메뉴(도메인)        → 새 도메인 폴더 + 첫 기능 하위 폴더
└─ 메뉴 횡단(공통)        → core/ 또는 shared/ (특정 메뉴 소속 아님)

어느 경우든: route/menu registry, module manifest, DI registration,
            public export 같은 최소 integration edit은 허용 (규칙4).
            단 integration 파일에 feature "로직"이 늘면 경계 재검토 신호.
```
- **허용**(registration-only): router 테이블에 1줄 추가, nav menu 배열에 항목 추가, DI 컨테이너 등록, package export 추가.
- **금지**(logic-bearing parent edit): 기존 형제 기능 파일에 새 기능의 비즈니스 로직을 끼워넣기.

## 공통 코드 승격 = 사용 범위 따라 (Rule of Three와 모순 없이)
```
기능 내부에서만   → 기능 폴더 안
같은 메뉴 2곳     → 기본 duplicate 유지
                   (단 auth/권한/HTTP client/formatting 등 안정된 cross-cutting infra는 즉시 shared 허용)
같은 메뉴 3곳째   → 소속 범위 재판단 → 메뉴 내 shared
다른 메뉴도 사용  → "도메인 소유권 없는 stable utility/infra"일 때만 global shared 승격.
                   특정 feature concept이면 public boundary 의존 또는 duplicate 유지 (shared-dump 회귀 방지)
```
**cross-menu 2회 사용을 즉시 global로 올리지 말 것** (Rule of Three 게이트).

## 프레임워크 관례 우선 (배포 안전)
Next.js(app/ 라우팅), Rails(MVC 규칙) 등 **프레임워크가 구조를 강제하면 그것을 우선** 따르고, 그 관례 **안에서** feature-first 원칙(colocation/단일 경계/횡단 격리)을 적용한다. 프레임워크 관례를 거슬러 강제하지 않는다.
