# Codex 위임 A/B 관측 — 2026-09-12

## 결론
두 결과물은 동일한 독립 계약 검사 17/17을 통과했다. B는 사용량 한도에 도달해 부모의 최종 정리/응답 전에 종료됐다. 따라서 아래 값은 A의 완료 사용량과 B의 중단 시점 사용량이며, 완료 비용 절감률로 비교할 수 없다. 추가 유료 재실험은 실행하지 않았다.

## 조건
- A: PawPad `3081267deaaab562783440ec8cd343f4a03511ca`; B: `7a62732b99fce9ade074df43dd2bde3c577a8300`.
- Codex CLI 0.154.0, 부모/하위 모두 사용자 지정 `gpt-5.6-sol / high`; 각 실행은 부모 1 + 구현 하위 1, A 후 B 순차 실행.
- 양쪽 같은 초기 stub, 명세, 프롬프트와 Node ESM POV column scheduler 과제. 외부 dependency, Flutter, 실제 센서, UI는 제외.
- 양쪽 사용자 config 미로드, model/effort와 하위 기본값 명시. 내장 `:workspace` 권한 + Windows elevated sandbox 사용. Hook trust 우회 없음; 로그에서 hook 주입 0건.
- 두 명세 SHA-256: `1ebc6ed57a4425dcbada2c69ee98b570ab12398bf88bf5a1757672e0e9a0da36`.
- 평가기는 미구현 stub의 17/17 실패를 확인한 후 실제 결과물을 평가했다. 에이전트의 자체 테스트와 별도 검사다.

## 관측 사용량
각 세션의 token_usage_record를 response_id별 중복 제거해 합산했다. cached input은 input의 부분집합, reasoning은 output에 포함되므로 추가 합산하지 않았다. 외부 평가자(이 비교를 준비·감독한 대화)의 사용량과 사전 실패 실행은 이 표에서 제외한다.

| 항목 | A 완료 | B 한도 중단 시점 |
|---|---:|---:|
| 부모 모델 요청 | 18 | 9 |
| 하위 모델 요청 | 7 | 10 |
| 전체 모델 요청 | 25 | 19 |
| 입력(캐시 포함) | 966,826 | 613,168 |
| 캐시 입력 | 879,488 | 553,088 |
| 캐시 제외 입력 | 87,338 | 60,080 |
| 출력 | 14,211 | 13,858 |
| 부모 wait_agent | 3 | 1 |
| 독립 계약 검사 | 17/17 | 17/17 |
| 프로세스 결과 | exit 0 | exit 1: usage limit |

A 실행: 08:26:33~08:32:37 KST. B 실행: 08:32:49~08:38:22 KST. B 시간은 완료 시간이 아니다.
B 하위는 완료했고 부모도 syntax/test 재검증 성공을 보고했지만, 최종 응답/종결 완료는 확인되지 않았다. 부모 호출 수가 적은 관측은 있으나 B 중단과 1회 표본 때문에 개선 효과를 확정하지 않는다. 하위 요청은 오히려 7→10회였다.

## 사전 실행 실패
2026-09-11 21:05~21:07 KST의 첫 A는 workspace-write 옵션을 전달했으나 실제 세션 권한이 read-only였다. 정책 차단으로 구현하지 못해 비교에서 제외했다. 로그는 보존했다. 부모/하위 합계 입력 394,095, 캐시 입력 337,408, 출력 4,239 토큰이 발생했다. 이후 모델 호출 없이 sandbox 파일 쓰기와 prompt-input의 workspace-write를 확인하고 새 작업공간에서 위 A/B를 시작했다.

## 한계
- 한 쌍, 고정 순서, 서버 캐시/응답 변동 통제 불가. 구독 한도는 평가자 대화나 다른 작업과 공유하므로 이 실험의 토큰만으로 차감률을 역산하지 않는다.
- 두 실행에 model/effort를 명시했으므로 기존 effort 생략 문제를 그대로 재현한 비교가 아니다.
- 짧은 순수 모듈 구현이다. 원래 Flutter 프로젝트의 실제 스윙 품질, 장시간 재개/캐시 미스, hook 조건별 비용이나 Claude 대비 효과는 검증하지 않았다.
- 이번 결과를 근거로 추가 스킬/품질 기준 변경을 하지 않는다. 완결된 절감 검증은 미완이며 재실험은 별도 사용자 결정 사항이다.

## 로컬 증거
- 실험 폴더: `C:/Users/craki/AppData/Local/Temp/pawpad-ab-4820de99-5492-42b4-9ee7-9da825129902` — manifest, prompt, A/B workspace, event JSONL, run 결과, summary.json.
- A 부모/하위: `01a092cb-51e6-7e23-a5fc-9b4e533ed67e` / `01a092cc-3af8-7421-8d85-d3fecc675e2a`.
- B 부모/하위: `01a092d1-0f07-7d43-8cf9-243692bebe22` / `01a092d2-3255-7370-985e-d2e0fdf05b84`.
- 사전 실패 폴더: `C:/Users/craki/AppData/Local/Temp/pawpad-ab-4d319a73-da3a-40e5-8e01-ebb47a3e0403`.
- 검증기/준비/실행/집계 스크립트: TEMP의 `pawpad-stage3-grade.mjs`, `pawpad-stage3-prepare.cjs`, `pawpad-stage3-run.cjs`, `pawpad-stage3-summarize.cjs`.
- 원 로그는 로컬에만 보존하며 credentials나 대화 원문을 이 문서에 복사하지 않는다. 보고서 작성 외 추가 제품 코드 변경 없음.
