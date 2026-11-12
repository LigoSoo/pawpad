---
name: codemap
description: Code map - a guide to source when search stalls, plus pitfalls that are not written in the code. Search the source first; consult the map when the request has nothing searchable, the first search is empty or scattered, or right before editing an area. Owner-separated edit permissions for multi-agent work.
---
# CodeMap Skill - 길잡이 + 주의사항 기록

## 목적
검색이 막힐 때 소스 위치로 데려다 주는 길잡이, 그리고 소스에 적혀 있지 않은 주의사항·실측의 기록.

토큰 절감 장치가 아니다. 실측(v2.56, 요청 3건 x 모델 2종 x 2회)에서 사용량은 codemap 없이 검색하는 것과 사실상 같았다(-2.4% ~ -0.1%, 같은 조건 안의 편차보다 작다). 값은 두 곳에 있다:
1. 검색어가 헛짚는 요청에서 한두 번 만에 도착한다.
2. 고치기 전에 주의사항을 안다 (재작업 한 번이 위치 찾기 열 번보다 비싸다).

## 언제 보는가 (검색 먼저)
요청에 화면 문구·식별자가 있으면 소스를 바로 검색한다. codemap은 아래일 때만 본다.
1. 요청에 검색할 말이 없다 (순수 증상 서술).
2. 첫 검색이 0건이거나 여러 영역에 흩어진다 (파일 8개 초과가 기준).
3. 어떤 영역의 파일을 처음 고치기 직전 — 그 파일명으로 leaf를 Grep해 주의사항만 확인한다 (1회).
검색 직행은 정상 경로다. Retrieval 표시 라인의 codemap 칸에는 "불요"라고 적는다.

## leaf 규격 (머리 3줄 + 주의사항)
<!-- codemap leaf: {id} -->
src: {파일 경로} [{기준 심볼}], {파일 경로} [{기준 심볼}]
증상: {사용자가 실제로 쓰는 말 5~8개, 쉼표 구분}
주의사항:
- {이렇게 고치면 안 된다 + 이유 한 구절}

- src: 그 영역을 고칠 때 여는 파일 전부와 기준 심볼. 줄 번호는 쓰지 않는다 (금방 낡는다).
- 증상: Lookup의 검색 대상이다. 정제된 용어만 적으면 걸리지 않는다 — 화면 문구와 사용자 말투를 둘 다 넣는다 (예: 실행 기록 표, 표가 화면 밖으로 넘친다).
- 주의사항: 5줄 이내. 소스 주석에 이미 있는 내용은 옮기지 않는다. 판단에 쓰이는 수치 1개는 허용 (예: 기동 대기의 대부분은 저장소 준비 한 곳, 약 2.7초).
- 이전 버전 leaf의 "함정:" 줄은 "주의사항:"과 같은 뜻이다. 그 leaf를 고칠 때 이름만 바꾼다.
- 경위·실측 서술은 leaf에 쓰지 않는다. .ctxdb/L2 또는 decisions/arch.md에 둔다. leaf에 포인터도 두지 않는다 (그쪽은 키워드로 회수된다).
- 크기: 신규·수정 leaf 권장 1.5KB. hard cap은 4096 byte.

## 심볼 표 (선택 — 파일이 여러 개인 영역만)
[domain]:[symbol]    [file_path]    [핵심 시그니처/타입]: [역할 1줄]
파일을 열지 않고 위치+시그니처+역할을 파악하는 용도. 핵심 심볼만, 각 1줄. 로직 복붙 금지.

예시:
auth:login         src/features/auth/login.<ext>         Login: 로그인 화면(이메일+소셜)
db:user            src/models/user.<ext>                 User{id,name,role}: 사용자 모델
api:fetchUser      src/api/user_api.<ext>                fetchUser(id)->User: 유저 조회

## _index.md 구조 (Phase A flat)
# MAP (data flow / 한눈 조망)   <- 모듈 흐름 다이어그램 (구조·영향범위 파악, 선택)
[레이어/화살표. 예: ui --입력--> core --결과--> render]
# INDEX
[영역별 leaf 블록 또는 심볼 표]

## ON START 읽기
- Phase B(_root.md 존재): _root.md만 read (MAP + ROUTE). _index.md는 라우팅 스텁이라 읽지 않는다.
- Phase A: MAP만 부분읽기(상단). INDEX는 context에 올리지 않는다.
- HOT 절은 두지 않는다 (v2.56 폐지). 최근 작업은 _meta.md RECENT와 ctxdb L2에 있다.
  기존 HOT 절은 다음 codemap 갱신 때 비운다 — 각 항목의 심볼이 leaf에 있는지 Grep으로 확인하고, 없으면 leaf에 1줄 추가한 뒤 지운다.
  hot-archive 계열 보관 파일도 같은 절차로 leaf와 대조한 뒤 라우팅 스텁(3줄 이내)으로 줄인다. 새로 만들지 않는다.

## 다른 문서의 _index.md 지칭 읽는 법 (Phase B)
CLAUDE.md/AGENTS.md와 다른 스킬·훅 안내문의 "codemap/_index.md 갱신·확인"은 Phase A 표기다. Phase B에서는 이렇게 읽는다:
- 추가·수정 = 해당 features/{feature-id}.md leaf
- 위치 확인 = 아래 Lookup 알고리즘
- _index.md 스텁에는 아무것도 쓰지 않는다 (스텁이 다시 자라면 분할이 무효가 된다).

## 권한 (Owner 분리)
| 작업 | 허용 |
|------|------|
| leaf 추가, 주의사항 줄 추가 | 누구나 (어느 lane이든) |
| leaf의 src: 를 실제와 맞춤 (틀린 경로 고침, 자기가 옮기거나 지운 파일 반영) | 누구나 |
| 주의사항 줄 수정·삭제, leaf 삭제·분할 | lane owner만 |

owner 확인: _wip.md Locks 섹션에서 해당 파일 매핑 확인.
Lock 없는 파일은 추가만 허용, 수정/삭제 시 _wip.md Locks에 임시 lock 등록 권장.

## 업데이트 규칙 (드물게)
| 시점 | 액션 | 누가 |
|------|------|------|
| 새 영역(폴더·화면·서비스) 생성 | leaf 추가 (src, 증상 2줄부터) | 생성한 lane |
| 파일 이동·이름 변경 | 해당 leaf의 src: 수정 | 옮긴 lane (자기가 옮긴 파일) |
| 파일 삭제 | src: 에서 제거 | 지운 lane (자기가 지운 파일) |
| 주의사항 발견 | 주의사항 줄 추가 (5줄 이내) | 누구나 |
| leaf를 읽었는데 src: 가 틀렸다 | 그 자리에서 고침 | 누구나 |

위 다섯 경우가 아니면 "codemap skip"을 선언한다. 작업마다 갱신하지 않는다. (다른 문서의 짧은 표기 "새 영역·파일 이동/개명/삭제·새 주의사항"은 이 다섯 경우를 가리킨다 — 틀린 src: 를 발견해 고치는 것은 언제든 한다.)
task-done 6번 · checkpoint 2번 · handoff 6번에서 건드린 leaf의 src: 경로가 실제로 있는지 확인한다.

기존 leaf의 이행은 점진적이다: 위 경우로 leaf를 건드릴 때 그 leaf만 머리 3줄을 붙이고 서술을 걷어낸다. 걷어낸 서술이 ctxdb L2/L3에 없으면 L2에 1줄 digest로 옮긴 뒤 지운다. 안 건드리는 leaf는 옛 규격으로 둔다 — Lookup의 Grep은 옛 본문에도 걸린다.

## 동시 수정 충돌 방지 (하이브리드)
- 두 에이전트가 동시에 같은 codemap 파일 수정 시:
  - append 충돌 -> 양쪽 라인 모두 보존
  - 명백한 중복 -> 다음 세션에서 owner가 정리
- 같은 행을 양쪽이 수정 시 -> owner가 우선, 비owner는 _wip.md에 충돌 보고

## 성장 전략 (size-aware, trim-router)
파일 작으면 flat, 커지면 trim-router로 split. page-type별 cap 초과 = task 완료 전 split 필수.
길어짐을 막는 1차 장치는 leaf 규격이다 (긴 문단이 진짜 bloat 원인 — 서술은 ctxdb, codemap엔 주소와 주의사항만).

### Phase A — flat (~30KB 이하)
단일 _index.md. MAP + 영역별 블록(# features/...)으로 그룹.

### Phase B — trim-router (~30KB 초과 또는 통째읽기 사고 빈발)
작은 페이지로 분할. domain 중간층 없음(feature leaf와 내용 중복·3중쓰기 drift 유발 → 제외).
구조:
  .claude/codemap/_root.md      -> MAP + ROUTE. source pointer 금지. hard-cap 2KB
  .claude/codemap/keywords.md   -> 의미 매칭 폴백. 의도·증상 → leaf 경로만. hard-cap 4KB
  .claude/codemap/features/{feature-id}.md -> leaf (머리 3줄 + 선택 심볼 표). 권장 1.5KB, hard-cap 4KB
- root: route만, 심볼표 금지.
- keywords: Lookup 1번이 0건일 때만 읽는 폴백이다. 새 leaf의 증상은 leaf의 증상: 줄에 적고, keywords에는 영역 단위 한 줄만 둔다. keywords/{영역}.md 분할과 스텁 leaf는 새로 만들지 않는다 (기존 것은 그대로 동작한다).
- feature leaf: leaf 4KB 근접 시 features/{id}/ 하위 ui,data,domain,test로 split.

### Lookup 알고리즘 (leaf 직접 검색, 최대 2 read)
Phase A(flat)에는 features/ 와 keywords.md 가 없다 — 아래의 "features/ 를 Grep"은 _index.md 를 Grep하는 것으로 읽고, 걸린 영역 블록만 그 줄 범위로 read한다. 2번(keywords 폴백)은 건너뛴다.
1. 요청의 낱말 2~3개로 .claude/codemap/features/ 를 Grep한다. 증상: 줄과 src: 줄이 걸린다. 가장 잘 맞는 leaf 1개만 read.
   사용자 표현 그대로 0건이면 뜻이 같은 다른 낱말로 한 번 더 (예: 관리용 -> 시스템, 안 보이게 -> 숨김).
2. 그래도 0건이면 keywords.md를 통째 read 후 의미로 골라 leaf 1개 (폴백).
3. 영문 심볼·파일명을 알면 그것으로 features/ 를 Grep한다 ("언제 보는가" 3번의 주의사항 확인이 이 경로다).
4. leaf의 src: 줄에 적힌 파일·기준 심볼로 바로 소스를 연다. leaf를 읽고도 소스를 다시 검색해야 했다면 그 leaf는 규격 미달이다 — 그 자리에서 src: 를 채운다.
- 금지: codemap 전체 read / _root.md·keywords.md를 조회 때마다 read / leaf 여러 개 read / 넓은 패턴으로 Grep해 수십 줄을 받는 것.
- 목표: 소스 전까지 읽는 양 3KB 이하.

### generated 제외
*.g.dart, *.freezed.dart, lib/generated/** 는 source pointer 대상 아님. 필요시 model leaf에 generated companion exists만 기록.
fallback rg: rg -n "kw|Symbol" lib -g "!*.g.dart" -g "!*.freezed.dart" -g "!lib/generated/**"

### size cap (완료 게이트)
root 2KB / keywords·feature 4KB hard cap. 초과 시 split 후 완료.
검사: .claude/codemap 하위 *.md 각 파일 byte 수 cap — _root.md=2048 / _index.md=30720(Phase A flat 상한, 초과 시 Phase B 전환) / 그외=4096. 초과 시 FAIL.
자동 집행(v2.49): stop-check 훅이 매 Stop마다 검사해 [codemap split needed] 차단 블록을 낸다(세션당 시그니처 1회 dedupe, Claude ps1/sh + Codex, 훅 3곳). 수동 스크립트 불요.
훅이 돌지 않는 환경(조직 정책 차단·hook 미신뢰)에는 자동 집행이 없다 — task-done 6번·checkpoint 2번·handoff 6번에서 이번에 건드린 codemap 파일의 byte 수를 직접 재고, 초과면 그 자리에서 분할한다.
분할 시 상위 파일은 삭제하지 말고 라우팅 스텁으로 남긴다 — 다른 leaf·문서가 가리키던 포인터가 그대로 산다.

## 초기 부트스트랩 (기존 코드베이스에 처음 도입할 때)
설치는 codemap 템플릿만 만든다. 이미 코드가 쌓인 프로젝트는 **1회 백필**을 하면 검색이 헤매는 요청에서 길잡이가 생긴다. 심볼을 전수 등록하지 않는다 — 영역마다 leaf 1개, 머리 2줄(src, 증상)이면 된다. 주의사항은 비워 두고 겪으면서 채운다.

### 발동 판정 (자동 1회 제안)
코드 수정 세션 ON START에 **등록 항목(leaf · 영역 블록 · 심볼 행의 합) < 3 && 소스 파일 >= 30**이면 부트스트랩을 1회 제안한다. 옛 심볼 표만 있는 설치처는 등록 항목이 있으므로 대상이 아니다. 거절 시 그 세션에서 재제안 금지. 신규(빈) 프로젝트는 대상 아님 — 영역이 생길 때 leaf를 추가하면 충분.

### 절차
1. **스캔 범위** — 소스 루트만. generated 제외(위 generated 제외 절 패턴을 스택에 맞게 치환).
2. **등록 단위** — 영역(폴더·화면·서비스) 하나에 leaf 하나. src: 에는 그 영역을 고칠 때 여는 진입 파일과 기준 심볼(클래스/화면/route/서비스/repository/상태 store). 증상: 에는 그 화면의 문구와 그 영역에 대해 사용자가 할 법한 말. private 헬퍼·뷰 내부 로직은 적지 않는다.
3. **규모 분기** —
   - 소스 < 40 파일: 인라인 진행.
   - 소스 >= 40 파일: code-delegate로 배치 위임. 기능/폴더 기준 3~4배치(배치당 30~40파일). 각 서브는 .claude/codemap/_staging/{batch}.md에 **직접 Write**하고 **반환은 4줄 요약만**(staging 경로 / leaf 수 / 파일 수 / 특이사항). 본문을 부모로 반환하면 위임 이득이 사라진다. 서브는 _index.md 직접 편집 금지(owner 권한).
4. **병합** — owner가 staging을 합친다. 기존 MAP·수기 등록 섹션은 **보존**(덮어쓰기 금지), 중복만 제거. 병합 후 _staging/ 제거.
5. **크기 판정** — 합계 30KB 초과면 flat 유지하지 말고 즉시 Phase B(trim-router) 전환.
6. **검증 게이트(완료 조건)** — (a) size cap 전수 검사 PASS (b) 무작위 leaf 5~6개의 src: 경로와 기준 심볼을 실파일과 대조해 **전건 일치**. 불일치 시 해당 배치 재작업.

### Phase B 전환 시 _index.md 처리
_index.md는 삭제하지 않고 **라우팅 스텁**으로 남긴다(3~5줄: _root.md / keywords.md / features/ 포인터 + "심볼표 없음, 통째 read 금지" 명시). 기존 문서·설정이 _index.md 경로를 가리키는 경우가 있어 경로가 죽으면 ON START read가 실패한다.
