---
name: context-saver
description: Save the current session work into .ctxdb/L2/, update INDEX.md AGENT SYNC, and refresh INDEX/L1 keyword mapping for any new domain/symbol. Use when the Stop hook emits a checkpoint block, on "세션저장"/"save context", or before /compact.
---
# context-saver - 세션 컨텍스트 저장

## 목적
현재 세션 작업을 .ctxdb/L2/ 에 기록하고 INDEX.md AGENT SYNC를 갱신. 다음 세션이 키워드로 재로드.

## 트리거
- Stop hook decision:block (checkpoint) 수신 시
- "저장해줘", "세션저장", "컨텍스트저장", "save context" 입력 시
- /compact 실행 전 반드시 먼저 실행 (순서 역전 금지)

## 절차
STEP 1: 저장 대상 L2 결정
  작업 내용 분석 -> 해당 도메인 L2 파일 선택 (없으면 progress-current.md).
STEP 2: L2 기록 (append)
  형식: ## [{에이전트명}] YYYY-MM-DD HH:MM — {작업 요약}
  내용: 완료 작업, 결정사항, 변경 파일, 미완료, 다음 작업.
  크기(세션 블록): **1회 append ≤ 40줄**. digest 전용 — 항목당 1줄 위주, 코드/로그/diff 원문 금지.
    (L2 tail 150줄이 hook으로 매 세션 화면·컨텍스트에 주입됨. 긴 블록 = 토큰 낭비 + Codex CLI 화면 노이즈.)
    40줄 초과가 필요하면 본문은 canonical 위치(spec/ADR/verifications/lane)에 쓰고 L2에는 포인터 1줄.
  크기(파일 전체): 150줄 또는 2,000토큰 초과 시 분할 경고.
STEP 3: INDEX.md AGENT SYNC 갱신
  자기 행만 수정 (타 에이전트 행 금지). 컬럼: 마지막 작업일, 기록 L2, 상태.
  상태 셀 = 헤드라인 1줄(150자 이내): {버전/기능} + {결과 1구} + {잔여 유무} + "상세 -> L2 {블록명}" 포인터.
  L2 세션 블록 전문 복제 금지 — INDEX는 매 세션 무조건 주입되므로 상세는 on-demand 자리(L2)에 1벌만 둔다(SoT 1곳, drift 방지, 주입 토큰 절감).
  L2 3개+ -> L1 포인터로 대체 (-> L1/{파일}.md).
STEP 4: 키워드 인덱스 갱신 (신규 도메인/심볼 등장 시만)
  이번 작업에서 기존 INDEX/L1에 없는 도메인·핵심 용어가 생겼으면 반영:
  - 신규 도메인: L1/domain-{new}.md 생성(키워드 + 파일/심볼 포인터) + INDEX 키워드->L1 매핑 1행 추가
  - 기존 도메인 새 용어: 해당 L1 키워드 열에 누락된 핵심어만 추가 (중복/유사어 금지)
  - codemap 연계: 이번에 _index.md에 추가한 신규 심볼의 도메인이 INDEX 키워드로 잡히는지 확인, 누락 시 추가
  - 폭주 방지: INDEX는 도메인당 1행. L1 키워드는 검색용 핵심어만 (심볼 전수나열 금지 = codemap 역할). 변화 없으면 이 STEP 건너뜀.
  - 2음절 등록은 **도메인 고유어만**: 한글 2음절부터 매칭되므로 일반어(문서·작업·확인·내용·정리 등)를 넣으면 무관한 프롬프트가 그 도메인을 끌어온다.
    일반어를 꼭 쓰려면 도메인이 그 말로만 불리는지 확인하고, 아니면 3음절 이상 고유어(예: 배포본·적재큐)로 등록한다.
  - keywords 층 동반: 신규 도메인을 만들었으면 .ctxdb/keywords.md에도 "의도·증상 -> 도메인" 1~2줄 추가.
    INDEX 키워드는 hook의 정확매칭용, keywords.md는 agent의 의미매칭용 — 표현이 흔들리는 요청은 후자만 잡는다.
  - 권한(하이브리드): 키워드 추가는 누구나 / 기존 매핑 행 수정·삭제는 신중 (codemap 권한 준용, 충돌 시 양쪽 보존 후 정리)
STEP 5: 성장 판정 (계층 승격)
  저장량이 늘면 계층을 넓힌다. 경고만 남기고 넘기면 파일이 계속 커져 키워드 로드의 토큰 절감이 무효가 된다.
  아래 중 하나라도 걸리면 **이번 세션 안에** 처리:

  | 대상 | 임계 | 조치 |
  |---|---|---|
  | L2 파일 | 150줄 또는 2,000토큰 초과 | 오래된 블록을 L3/{name}-{YYYY-MM}.md 상단으로 이월 |
  | L3 파일 | 400줄 초과 | 연 단위로 L4/{name}-{YYYY}.md 이월 |
  | L1 파일 | 60줄 초과 또는 키워드 30개 초과 | 주제별 도메인 분할 **제안**(사용자 확인) + INDEX 행도 분리 |
  | INDEX 행 | 한 도메인이 전체 키워드의 절반 이상 | 위와 동일. 프로젝트 전체가 1개 도메인이면 어떤 키워드가 맞든 같은 내용이 온다 |

  **이월 시 포인터 갱신 필수 (생략 금지)**: 이월한 파일 경로를 ① 해당 L1 본문 ② INDEX 행의 `L2/L3 경로` 컬럼 양쪽에 남긴다.
  회수는 INDEX/L1의 포인터만 따라간다 — 포인터 없이 내리면 그 기억은 키워드로 **영구 회수 불가**가 된다.
  이월은 append-only(무손실). 블록 삭제 금지, 위치만 이동. 블록 경계는 `## ` 헤더 — 헤더 없는 덩어리는 L3/L4에서 블록 단위 회수가 안 된다.
STEP 6: 보고
  "저장 완료: {L2 파일 목록}" 출력. 키워드 갱신 시 "INDEX/L1 키워드 갱신: {요약}", 승격 시 "계층 승격: {이동 경로}" 추가.

## 주의
- 이월(L2->L3->L4)은 확인 없이 진행 가능(무손실·append-only). 도메인 분할만 사용자 확인.
- codemap(_index.md)과 역할 분리: codemap=심볼 위치(전수, 정밀), ctxdb 키워드=도메인 라우팅(핵심어 소수). 키워드에 심볼 전부 넣지 말 것.
- Decision Placement(.claude/HYBRID.md Decision Placement Matrix): L2는 세션 재개 digest 전용. 지속 결정(arch ADR / spec scope / 거절기록)은 L2에만 묻지 말고 canonical 위치(decisions/arch.md, specs/, decisions/rejected.md)에도 기록.
