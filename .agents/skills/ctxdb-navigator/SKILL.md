---
name: ctxdb-navigator
description: Keyword depth context loader. Use at session start (or "컨텍스트 로드"/"INDEX 읽어줘") to traverse .ctxdb/ INDEX->L1->L2 and load only the minimum keyword-matched files, saving tokens. Also the hook-free fallback when a new topic appears mid-session.
---
# DO NOT EDIT: generated from .claude/skills/ctxdb-navigator/SKILL.md by pawpad-setup.ps1.
# ctxdb-navigator - 키워드 depth 컨텍스트 로더

## 목적
.ctxdb/ 계층 인덱스를 탐색해 작업에 필요한 최소 L1/L2(+L3/L4 블록)만 로드. 전체 로드 금지로 토큰 절약.

## 회수 경로 2가지
| 경로 | 수행 주체 | 매칭 | 발동 |
|---|---|---|---|
| 자동 | UserPromptSubmit hook | INDEX 키워드 **정확매칭** | 매 프롬프트 (hook 가용 시) |
| 폴백 | agent (이 스킬) | keywords.md **의미매칭** | 세션 시작 / hook 무주입 / 표현이 흔들리는 요청 |

hook은 결정적 문자열 매칭이라 동의어·어순 변형을 놓친다. 조직 정책·비Windows 환경에서는 발화조차 안 한다.
**둘 중 하나가 반드시 돈다**는 전제로 설계됐다 — hook이 조용하면 agent가 대신 한다.

## 트리거
- 세션 시작 시 (SessionStart hook이 INDEX 미리 주입 -> 키워드 매칭만 수행)
- "INDEX.md 읽어줘", "컨텍스트 로드" 입력 시
- **세션 중 신규 주제 등장 시 1회** (hook-free 폴백): 아래 조건 전부 충족하면 폴백 수행
  1. 직전까지 다루지 않은 주제/도메인이 프롬프트에 등장
  2. 컨텍스트에 `=== PawPad ... Auto Context ===` 주입 블록이 **없다** (= hook 무주입)
  3. 그 주제로 이미 폴백을 돌린 적 없다 (같은 주제 반복 금지)
  -> 조건 미충족이면 침묵. 매 프롬프트 판단 금지(과발화 = 토큰 낭비).

## Lookup 알고리즘 (최대 3 read)
1. `.ctxdb/keywords.md` 통째 read -> **의미·맥락 매칭**으로 도메인 1개 선택
   (grep 아님. 정확 단어/띄어쓰기/조사 흔들림 무관 — agent가 의도로 해석한다. keywords.md 없으면 INDEX 키워드 표로 대체)
2. `.ctxdb/INDEX.md`의 해당 행 -> `L1/{domain}.md` + `L2/L3 경로` 컬럼
3. L1 read -> 포인터 따라 L2 tail 150줄 (최대 2개). L3/L4는 **통째 금지**, `## ` 블록 중 키워드 맞는 것만
- 금지: .ctxdb 전체 read / L3·L4 파일 통째 read / keywords.md를 grep 정확매칭

## 절차
STEP 1: INDEX.md 읽기
  .ctxdb/INDEX.md 읽기. 없으면 즉시 보고.
STEP 2: AGENT SYNC 확인
  이전 에이전트의 마지막 작업 L2 파일 / 상태 확인.
STEP 3: 키워드 매핑
  위 Lookup 알고리즘 수행.
  키워드 충돌: 히트 수 많은 도메인 우선, 동수면 매핑 테이블 우선순위 컬럼.
  키워드 불명확: L2/progress-current.md만 로드 후 사용자 명확화 요청.
STEP 4: 최소 로드
  L1 <= 1개, L2 <= 2개 (예외규칙 해당 시 L2 3개). L3/L4는 블록 단위.
STEP 5: 크기 점검
  L2 150줄 초과 또는 2,000토큰(문자수/3.5) 초과 -> context-saver STEP 5(계층 승격) 안내.
STEP 6: 요약
  "로드 완료: {파일목록} / 핵심: {2~3줄}"

## 첫 응답 검증 출력 (의무)
첫 응답 최상단에 1줄: 📂 .ctxdb: {project} | {last-date} | {loaded L2} | {status}
누락 시 사용자는 INDEX 미로드로 간주 -> 재확인 요청.

## 무주입 진단
hook이 `{}`를 반환한 사유는 `.ctxdb/.state/{claude|codex}-last-decision`에 기록된다
(`no-match | tokens=N` / `already-loaded | ...` / `no-refs | ...` / `loaded | ...`).
"회수가 안 된다"는 의심이 들면 이 파일부터 본다 — 무주입 3경로가 화면상 구분되지 않기 때문에 둔 계측점이다.

