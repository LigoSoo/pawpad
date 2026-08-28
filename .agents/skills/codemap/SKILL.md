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
검사: .claude/codemap 하위 *.md 각 파일 byte 수 cap — _root.md=2048 / _index.md=30720(Phase A flat 상한, 초과 시 Phase B 전환) / 그외=4096. 초과 시 FAIL.
자동 집행(v2.49): stop-check 훅이 매 Stop마다 검사해 [codemap split needed] 차단 블록을 낸다(세션당 시그니처 1회 dedupe, Claude ps1/sh + Codex 3표면). 수동 스크립트 불요.
분할 시 상위 파일은 삭제하지 말고 라우팅 스텁으로 남긴다 — 다른 leaf·문서가 가리키던 포인터가 그대로 산다.

## 초기 부트스트랩 (기존 코드베이스에 처음 도입할 때)
설치는 codemap 템플릿만 만든다. 이미 코드가 쌓인 프로젝트는 **1회 백필**을 해야 lookup이 동작한다. 백필 없이 두면 miss -> 소스 full-scan 경로가 열린 채 운영된다(실관측: 설치 후 수 주간 1개 도메인만 등록된 상태로 방치).

### 발동 판정 (자동 1회 제안)
코드 수정 세션 ON START에 **등록 심볼 < 10 && 소스 파일 >= 30**이면 부트스트랩을 1회 제안한다. 거절 시 그 세션에서 재제안 금지. 신규(빈) 프로젝트는 대상 아님 — 증분 등록으로 충분.

### 절차
1. **스캔 범위** — 소스 루트만. generated 제외(위 generated 제외 절 패턴을 스택에 맞게 치환).
2. **등록 기준** — 포함: public 진입점(클래스/화면/route/서비스/repository/모델 진입점/상태 provider·store/주요 public 메서드). 제외: private 헬퍼, 1줄 getter, 뷰 내부 렌더 로직, 순수 표현용 서브컴포넌트.
3. **규모 분기** —
   - 소스 < 40 파일: 인라인 진행.
   - 소스 >= 40 파일: code-delegate로 배치 위임. 기능/폴더 기준 3~4배치(배치당 30~40파일). 각 서브는 .claude/codemap/_staging/{batch}.md에 **직접 Write**하고 **반환은 4줄 요약만**(staging 경로 / 심볼 수 / 파일 수 / 특이사항). 심볼 본문을 부모로 반환하면 위임 이득이 사라진다. 서브는 _index.md 직접 편집 금지(owner 권한).
4. **병합** — owner가 staging을 합친다. 기존 MAP·HOT·수기 등록 섹션은 **보존**(덮어쓰기 금지), 중복 심볼만 제거. 병합 후 _staging/ 제거.
5. **크기 판정** — 합계 30KB 초과면 flat 유지하지 말고 즉시 Phase B(trim-router) 전환. leaf가 4KB 근접하면 layer(data/state/ui)로 분할.
6. **검증 게이트(완료 조건)** — (a) size cap 전수 검사 PASS (b) 무작위 심볼 5~6개의 path:line을 실파일과 대조해 **전건 일치**. 불일치 시 해당 배치 재작업.

### Phase B 전환 시 _index.md 처리
_index.md는 삭제하지 않고 **라우팅 스텁**으로 남긴다(3~5줄: _root.md / keywords.md / features/ 포인터 + "심볼표 없음, 통째 read 금지" 명시). 기존 문서·설정이 _index.md 경로를 가리키는 경우가 있어 경로가 죽으면 ON START read가 실패한다.

