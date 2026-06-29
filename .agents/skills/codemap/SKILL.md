---
name: codemap
description: Symbol location registry. Use to record or look up where feature components live without searching files; enforces owner-separated edit permissions for multi-agent work.
---
# DO NOT EDIT: generated from .claude/skills/codemap/SKILL.md by pawpad-setup.ps1.
# CodeMap Skill - Symbol Location Registry

## 목적
구현된 기능 컴포넌트 위치를 심볼 테이블로 관리.
수정/참조 시 파일 탐색 없이 즉시 위치 파악.

## 심볼 포맷
[domain]:[symbol]    [file_path]    [핵심 시그니처/타입]: [역할 1줄]
목적: 에이전트가 파일을 열지 않고 위치+시그니처+역할 파악 -> 토큰 절약. 실제 수정 시에만 해당 파일 read.
핵심/자주 만지는 심볼만 시그니처+역할 상세. 주변부는 위치만. (codemap=요약, 코드=전체. 로직 복붙 금지)

예시:
auth:login         src/features/auth/login.<ext>         Login: 로그인 화면(이메일+소셜)
db:user            src/models/user.<ext>                 User{id,name,role}: 사용자 모델
api:fetchUser      src/api/user_api.<ext>                fetchUser(id)->User: 유저 조회

## 도메인 분류
| 도메인 | 대상 |
|--------|------|
| auth   | 인증 화면, services |
| club   | (예시 도메인) |
| member | (예시 도메인) |
| db     | 데이터 모델, repository |
| api    | 외부 API 연동 |
| ui     | 공통 UI 컴포넌트 |
| core   | 공통 서비스, 유틸 |

## _index.md 구조
# MAP (data flow / 한눈 조망)   <- 모듈 흐름 다이어그램 (구조·영향범위 파악, 선택)
[레이어/화살표. 예: ui --입력--> core --결과--> render]
# HOT (최근 접근 3~5개)
[최근 심볼]
# INDEX
[전체: domain:symbol  file_path  시그니처: 역할]

## ON START 읽기 (토큰 절감)
- ON START/재개 시 MAP+HOT(조망)만 부분읽기(상단). INDEX는 context에 올리지 않음.
- 특정 심볼 위치 필요 시 INDEX를 Grep(domain:symbol 또는 파일명) — 매칭 줄만 반환 = 전체 로드보다 쌈.
- HOT 규율 필수: 최근 3~5개·각 1줄. 비대하면 부분읽기 효과 반감 -> 초과·노후 항목은 INDEX로 강등.

## 권한 (Owner 분리)
| 작업 | 허용 |
|------|------|
| 신규 항목 추가 (append) | 누구나 (어느 lane이든) |
| 기존 항목 수정 (경로/이름 변경) | lane owner만 |
| 기존 항목 삭제 | lane owner만 |
| HOT 섹션 갱신 | 누구나 |

owner 확인: _wip.md Locks 섹션에서 해당 파일 매핑 확인.
Lock 없는 파일은 추가만 허용, 수정/삭제 시 _wip.md Locks에 임시 lock 등록 권장.

## 업데이트 규칙
| 시점 | 액션 | 누가 |
|------|------|------|
| 새 화면/컴포넌트/서비스 생성 | INDEX에 추가 | 생성한 lane |
| 파일 경로/클래스명 변경        | 해당 행 수정 | **owner만** |
| 파일 삭제                     | 해당 행 제거 | **owner만** |
| 작업 후                       | HOT 섹션 상단 | 누구나 |

## 동시 수정 충돌 방지 (하이브리드)
- 두 에이전트가 동시에 _index.md 수정 시:
  - append 충돌 -> 양쪽 라인 모두 보존
  - 명백한 중복 -> 다음 세션에서 owner가 정리
- 같은 행을 양쪽이 수정 시 -> owner가 우선, 비owner는 _wip.md에 충돌 보고

## 성장 전략 (size-aware, trim-router)
파일 작으면 flat, 커지면 trim-router로 split. page-type별 cap 초과 = task 완료 전 split 필수.
1차 비대 제어는 entry 1줄 규율(긴 문단 entry가 진짜 bloat 원인 — 상세는 spec/lane, codemap엔 포인터만).

### Phase A — flat (~30KB / ~80 entries 이하)
단일 _index.md. MAP + HOT + feature 섹션(# features/...)으로 그룹. 1줄 규율 엄수.

### Phase B — trim-router (~30KB 초과 또는 통째읽기 사고 빈발)
작은 페이지로 분할. domain 중간층 없음(feature leaf와 내용 중복·3중쓰기 drift 유발 → 제외).
구조:
  .claude/codemap/_root.md      -> route + MAP + HOT. source pointer 금지. hard-cap 2KB
  .claude/codemap/keywords.md   -> 한국어/동의어를 feature로 라우팅. source pointer 금지. hard-cap 4KB
  .claude/codemap/features/{feature-id}.md -> source pointer + 최소 판단근거. hard-cap 4KB
- root: route만, 심볼표 금지.
- keywords: 사용자 표현/의도/증상 -> feature 경로만 (동의어 나열보다 "의도·증상→feature" 서술 지향; agent가 의미로 매칭하므로 정확 단어 불요. 파일/심볼 금지 → stale에도 source 무영향). 4KB 초과 시에만 도메인별 분할.
- feature leaf: 실제 수정후보 파일+심볼. leaf 4KB 근접 시 features/{id}/ 하위 ui,data,domain,test로 split.

### Lookup 알고리즘 (최대 3 read)
1. 한국어/자연어/증상 → keywords.md **통째 read 후 의미·맥락 매칭**(grep 아님 — agent가 프롬프트 의도로 해석) → feature leaf 1개 → source. 정확 단어/공백/표현 흔들림 무관(예: "최근완료"="최근 완료", "축하 효과 잘림"→부화 연출 character). (root는 첫 진입만)
2. 영문 심볼 알면 → rg로 .claude/codemap/features 직접 grep (정확매칭·페이지 통째읽기 불필요).
3. 금지: codemap 전체 read / keywords.md를 grep으로 정확매칭(의미매칭이 기본) / 심볼 줄범위 아는데 source 파일 통째 read.
- 핵심: 자연어=의미매칭(표현 강건), 영문심볼=rg 정확매칭. 분할은 lookup 성능 불변 + 실수로 통째읽기만 차단. 다운사이드 없음.

### generated 제외
*.g.dart, *.freezed.dart, lib/generated/** 는 source pointer 대상 아님. 필요시 model leaf에 generated companion exists만 기록.
fallback rg: rg -n "kw|Symbol" lib -g "!*.g.dart" -g "!*.freezed.dart" -g "!lib/generated/**"

### size cap (완료 게이트)
root 2KB / keywords·feature 4KB hard cap. 초과 시 split 후 완료.
검사: .claude/codemap 하위 *.md 각 파일 UTF-8 byte 수가 cap(_root.md=2048, 그외=4096)을 넘으면 FAIL. PowerShell 스크립트는 spec(codemap-8kb-router.md Acceptance) / lane 참조.

