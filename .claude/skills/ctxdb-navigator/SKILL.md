---
name: ctxdb-navigator
description: Keyword depth context loader. Use at session start (or "컨텍스트 로드"/"INDEX 읽어줘") to traverse .ctxdb/ INDEX->L1->L2 and load only the minimum keyword-matched files, saving tokens.
---
# ctxdb-navigator - 키워드 depth 컨텍스트 로더

## 목적
.ctxdb/ 계층 인덱스를 탐색해 작업에 필요한 최소 L1/L2 파일만 로드. 전체 로드 금지로 토큰 절약.

## 트리거
- 세션 시작 시 자동 (SessionStart hook이 INDEX 미리 주입 -> 키워드 매칭만 수행)
- "INDEX.md 읽어줘", "컨텍스트 로드" 입력 시

## 절차
STEP 1: INDEX.md 읽기
  .ctxdb/INDEX.md 읽기. 없으면 즉시 보고.
STEP 2: AGENT SYNC 확인
  이전 에이전트의 마지막 작업 L2 파일 / 상태 확인.
STEP 3: 키워드 매핑
  사용자 첫 메시지에서 키워드 추출 -> INDEX 매핑 테이블 -> L1/{파일}.md -> L2/{파일}.md
  키워드 충돌: 매핑 테이블 첫 행 우선.
  키워드 불명확: L2/progress-current.md만 로드 후 사용자 명확화 요청.
STEP 4: 최소 로드
  L1 <= 1개, L2 <= 2개 (예외규칙 해당 시 L2 3개).
STEP 5: 크기 점검
  L2 150줄 초과 또는 2,000토큰(문자수/3.5) 초과 -> "분할 필요" 경고.
STEP 6: 요약
  "로드 완료: {파일목록} / 핵심: {2~3줄}"

## 첫 응답 검증 출력 (의무)
첫 응답 최상단에 1줄: 📂 .ctxdb: {project} | {last-date} | {loaded L2} | {status}
누락 시 사용자는 INDEX 미로드로 간주 -> 재확인 요청.
