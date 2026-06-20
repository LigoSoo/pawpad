---
name: review
description: 문서형 크로스에이전트/세션 리뷰 라운드트립 게이트. 변경 내용을 review-request 문서로 정리해 다른 세션·에이전트(Codex↔Claude)가 직접 검증하며 리뷰하고, review-result 문서로 반환받아 수정한다. codex exec 자율 리뷰보다 저토큰(보완 관계). 커밋/완료 전 또는 사용자가 "리뷰"/"review"/"교차검증"을 언급할 때 사용.
---

# Review Skill - 문서형 리뷰 라운드트립 게이트

## 목적
교차 검증(리뷰)을 **문서 기반 라운드트립**으로 수행한다. 요청측이 review-request 문서를 쓰고 lane state로 핸드오프 → 다른 세션/에이전트가 읽고 **직접 검증**하며 리뷰 → review-result로 반환 → 요청측이 수정.

왜: `codex exec` 자율 리뷰는 repo 전체 재탐색으로 토큰 대량 소모(실측 1회 247k). review 스킬은 **큐레이트 scope + 직접 검증 체크리스트**로 저토큰이면서 독립성 유지.

## codex exec와의 관계 (보완, 대체 X)
- **기본 = review 스킬** (저비용 문서형, 크로스세션/에이전트).
- **에스컬레이션 = `codex exec` 자율 리뷰**: 다음 시 권장 — 배포본/설치 스크립트 변경, 저자 맹점 우려 큼, 영향 범위 광범위·불확실, request로 scope를 좁히기 어려움.

## 성격
Instruction skill. PowerShell command 아님. agent가 절차를 따라 문서를 읽고 쓴다.

## 트리거
/review [request|do] [feature-id]
- 인자 생략 시 **lane state 자동 분기**:
  - 대상 lane에 REVIEW_REQUESTED **없음** → **요청 작성 모드**(request).
  - REVIEW_REQUESTED **있음** → **리뷰 수행 모드**(do).
- `/review request` | `/review do` 로 명시도 가능.
- 리뷰측은 보통 별도 호출 없이 resume ON START가 REVIEW_REQUESTED를 발견해 진입.

## 산출물 위치 (기존 reviews/ 관례)
- request: `.claude/pawpad/reviews/{feature-id}-review-prompt-NN.md`
- result : `.claude/pawpad/reviews/{feature-id}-review-NN.md`
- NN = 라운드 번호(01, 02…). 재리뷰 시 증가.

## state / 소유권 (work owner 불변)
lane 필드: `reviewer`(리뷰 대상 에이전트), `review`(현재 review 문서 경로).
- 요청 모드: request 작성 → lane state=**REVIEW_REQUESTED** + reviewer 지정 + request 경로 기록. **work owner는 그대로 둔다.**
- 리뷰 모드: result 작성 → lane state=**REVIEW_DONE** + result 경로 기록.
- 리뷰어는 work lane을 점유하지 않는다(검토자일 뿐). work 내용 수정 금지, review state·경로만 갱신(HYBRID Lane Rule 예외).

## 요청 모드 절차 (요청측)
1. 리뷰 대상 결정(보통 현재 작업 lane의 feature-id) + reviewer 결정(Codex / Claude / 다음 세션).
2. review-request 문서 작성(아래 템플릿). **요약만 쓰지 말고 직접 검증 체크리스트 필수**.
3. lane: state=REVIEW_REQUESTED, reviewer=대상, review=request 경로 기록. _wip.md updated 갱신.
4. 사용자에게 "리뷰 대기" 안내(리뷰는 다른 세션/에이전트가 수행).

## 리뷰 모드 절차 (리뷰측)
1. lane state=REVIEW_REQUESTED 발견(ON START 또는 /review) → review-request 문서 read.
2. **요약을 맹신하지 말고** request의 체크리스트대로 **지정 파일을 직접 열고 명령을 직접 실행**해 검증.
3. review-result 문서 작성(아래 템플릿): verdict + 충족도 + findings.
4. lane: state=REVIEW_DONE, review=result 경로 기록. work owner·내용 미수정.

## 수정/라운드 (요청측)
1. REVIEW_DONE 발견 → result read.
2. findings 반영 수정.
3. 재리뷰 필요 시 다시 `/review`(request NN+1) → REVIEW_REQUESTED 토글.
4. **종결은 요청측 재량**: findings 0 또는 수용 가능 판단 시 리뷰 종료(work 계속/완료). 합의 무한 반복 강제 X.

## review-request 템플릿
```
# Review Request — {feature} (round NN)
- 요청자 / reviewer 대상 / 일자
## 범위·배경
## 변경 파일 (경로 목록)
## diff / 변경 요약
## 이미 한 검증 (결과)
## [필수] 직접 검증 — 요약 신뢰 말고 아래를 직접 확인
- [ ] 파일: {경로} — {무엇을 확인}
- [ ] 명령: {명령} — {기대 결과}
## 질문 / 우려 지점
## result 작성 위치: reviews/{feature}-review-NN.md
```

## review-result 템플릿
```
# Review — {feature} (review-NN)
- 리뷰어 / 일자
## 판정: PASS | PASS_WITH_FIXES | FAIL   |   충족도: NN%
## findings
| # | 심각도 H/M/L | 파일:라인 | 문제 | 수정 지시 |
|---|---|---|---|---|
## 검증 통과 (직접 확인한 항목)
```

## 원칙
- **직접 검증 강제**: request 체크리스트 없이 요약만 리뷰 금지(저자 맹점 상속 → 결함 누락).
- 리뷰어는 work lane 미점유(소유권 불변). review state·경로만 전이.
- 종결은 요청측 재량(수용 가능 finding 무한 반복 금지).
- 고위험은 codex exec로 에스컬레이션(위 기준).
- 선택지 질문은 AskUserQuestion(체크박스), 자유서술은 텍스트.

## handoff / security-check 와의 관계
- handoff = 작업 인계(owner 이전, snapshot). review = 검토만(owner 불변). 별개.
- security-check = 자동 스캔 게이트(DoD#8 필수). review = 사람/에이전트 판단(자동제안, 강제 X).
