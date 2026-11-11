# CHANGELOG v2.55 — 세션 시작 비용 · 훅 없는 환경 안전망

- 날짜: 2026-11-11
- 기준: v2.54
- 스킬 수: **22 불변** (본문만 6개 수정)
- 진행 바 단계: **25 / 29 불변**
- 훅 · CLAUDE.md/AGENTS.md 템플릿 · 번들 구성: **불변**

---

## 1. 왜

스킬 22개를 전수 감사하면서 설치처 한 곳(.NET 데스크톱 앱, 소스 307파일, 4개월 사용)을 실측했다. 그 머신은 조직 정책으로 훅이 전부 차단돼 있다.

| 항목 | 실측 |
|---|---|
| 세션 시작 때 읽는 양 | `INDEX.md` 12.7KB + `_wip.md` 21.7KB(active lane 0) + `_meta.md` 8.5KB ≈ **43KB** |
| `INDEX.md` AGENT SYNC | 에이전트 2종인데 **행 21개**("그 앞" 이력 행 누적), 한 줄 최대 649자 |
| `_wip.md` | 종결 메모가 쌓여 182줄 |
| 툴킷 자체 `_meta.md` | 36줄에 24.4KB — 한 줄 최대 2,102자 |
| codemap 크기 상한 초과 | 93파일 중 **8개** (HOT 보관 파일 5.3KB 포함) |
| ctxdb 저장 누락 | 한 세션이 통째로 미기록 → 나중에 재구성 |

원인은 읽는 쪽이 아니라 **쓰는 쪽 규칙의 구멍** 네 가지다.

1. `context-saver`가 "자기 행만 수정"이라고만 했다. 행을 **추가**하는 것은 막지 않았고 INDEX에는 크기 상한이 없었다.
2. 상한이 전부 **줄 수**였다(RECENT 8줄, L2 150줄). 한 줄이 수백~수천 자가 되면 상한을 지키면서 양만 는다.
3. `task-done`에 **ctxdb 저장이 없었다.** checkpoint·handoff에는 있다. 8턴 자동 저장은 Stop 훅 전용이라, 훅이 없는 머신에서는 작업을 끝내도 장기기억에 남지 않는다.
4. codemap 크기 상한은 v2.49부터 **Stop 훅만** 집행한다. 훅이 없으면 집행자가 없다.

여기에 codemap 스킬이 분할 전(Phase A)·후(Phase B) 설명을 섞어 쓰고, 분할 후 HOT이 넘칠 때의 규칙이 없어 설치처가 보관 파일을 따로 만들어 낸 것이 겹쳤다.

---

## 2. 무엇이 바뀌나

### context-saver
- AGENT SYNC는 **에이전트당 1행**. 이전 상태는 덮어쓴다. 이력 행 추가 금지(이력은 L2/L3 블록 헤더에 이미 있다).
- 표 밖에 세션 요약 줄을 두지 않는다.
- **`INDEX.md` 전체 8KB 상한.** 저장 후 byte를 재고, 넘으면 그 저장 안에서 줄인다(이력 행 삭제 → 긴 상태 셀 축약 → 키워드 행 분할 판정).
- 트리거에 호출 지점(task-done 7 / checkpoint 3 / handoff 7)과 훅 없는 환경 안내를 추가.

### task-done (7 → 8단계)
- 3번: `_wip.md`에 **종결 메모 줄을 남기지 않는다.** 쌓여 있던 메모는 done 파일 존재를 확인하고 함께 지운다.
- 4번: RECENT 1줄 **300자 이내**. `_meta.md` **8KB 상한** — 줄 수와 byte를 함께 잰다. 끝난 NEXT 항목은 `sessions/`로 옮긴다.
- 6번: 건드린 codemap 파일의 **byte 수 점검**(2048 / 30720 / 4096).
- **7번 신설: context-saver 실행.** 같은 세션에서 이미 checkpoint로 저장했으면 skip 선언.
- lane 없이 진행한 작업을 종결할 때도 4·6·7·8번은 실행한다.

### resume
- ON START 절차에 0번(ctxdb INDEX)을 넣고 7번을 `_root.md` 우선으로 고쳐 CLAUDE.md Session Protocol과 맞췄다.
- 상태표에 `REVIEW_REQUESTED` · `REVIEW_DONE` 추가(v2.29부터 누락).
- `_meta.md` 업데이트 규칙에 300자 · 8KB · NEXT 정리를 반영.

### codemap
- `_index.md 구조`를 Phase A로 명시. ON START 읽기에 Phase B 줄 추가.
- **"다른 문서의 `_index.md` 지칭 읽는 법" 절 신설** — DoD와 다른 스킬의 "`_index.md` 갱신"은 Phase B에서 leaf + `_root.md` HOT을 뜻한다. 스텁에는 심볼을 쓰지 않는다.
- **HOT 넘침 규칙**: 각 1줄 200자 이내. 밀려난 항목은 Phase A면 INDEX로, **Phase B면 버린다.** 보관 파일을 만들지 않는다.
- 훅이 돌지 않는 환경에서는 task-done 6번 · checkpoint 2번이 크기 상한을 집행한다고 명시.

### checkpoint
- 2번을 Phase A/B 공통 문구로 바꾸고 codemap byte 점검을 추가.
- 4번에 `_meta.md` 300자 · 8KB 포인터.

### handoff
- 6번을 checkpoint 2번과 같은 문구로(Phase A/B 분기 + codemap 스킬 포인터 + byte 점검). 리뷰 지적 반영.

### 리뷰 반영 (같은 버전 안)
독립 리뷰(Claude 서브에이전트, 변경분만 제공) 판정 **PASS_WITH_FIXES** — 중간 5 · 경미 8, 유실 경로 없음. 반영한 것:
- task-done: "이미 이관됨"과 "lane 없음"을 분리하고 lane 없는 종결의 보고 형식을 명시. ctxdb skip은 L2 블록만 생략, AGENT SYNC는 항상 종결 상태로 덮어쓴다. `_meta` 초과 원인이 상단이면 NEXT를 줄인다.
- context-saver: 이력 행은 누가 썼든 삭제 가능(각 에이전트의 최신 1행만 불가침). INDEX 초과 원인이 키워드 표면 셀을 줄이고, 안 되면 보고하고 진행(분할은 사용자 확인 사항이라 저장 안에서 못 끝낸다).
- codemap: HOT에서 버리기 전 leaf 등록 확인. 이미 만든 보관 파일은 leaf 대조 후 스텁으로. 미설치 스킬 이름(clarity) 제거.
- resume: lane 포맷 State 줄과 Session Rollover 줄을 본문과 일치. "review 스킬 설치 시"로 표기.
- README · GUIDE · SKILLS_MANIFEST의 task-done 설명에 ctxdb 저장 추가. PAWPAD_VERSIONS 행 순서 정렬.

---

## 3. 결정

| 결정 | 근거 |
|---|---|
| 읽는 쪽(CLAUDE.md Session Protocol)은 안 건드린다 | 섹션 제목이 `-Upgrade` 병합 앵커다. 비대의 원인은 쓰는 쪽이라 거기만 고쳐도 읽는 양이 준다 |
| 상한은 byte로 | 줄 수 상한이 긴 줄로 무력화된 것이 실측 원인 |
| INDEX 8KB · `_meta` 8KB | 설치처 INDEX의 정당한 내용(키워드 표 + 머리말)이 약 5KB. `_meta`는 300자 × 8줄 + 상단 |
| 다른 스킬의 `_index.md` 문구는 일괄 수정하지 않고 codemap에 해석 규칙 1절 | 스킬 6개 + DoD를 고치면 임베드 · 미러 · 병합 앵커까지 번진다. 해석 규칙은 한 곳이면 된다 |
| HOT 보관 파일 금지 | lookup에 쓰이지 않고, 같은 내용이 ctxdb L2에 있으며, 크기 상한만 넘긴다 |
| 훅은 손대지 않는다 | 이번 대상은 훅이 **없는** 환경. 훅이 있는 머신의 동작은 그대로 |

기존 설치처의 이미 불어난 파일은 `-Upgrade`가 고치지 않는다(사용자 데이터라 SKIP). 다음 `task-done` 또는 `/checkpoint` 때 새 규칙이 적용되며 줄어든다.

---

## 4. 범위 밖 (감사에서 나왔으나 이번에 안 고친 것)

- `clarity`: 다섯 차원이 각 8점이면 40점 BLOCK인데 "13점 미만 질문 금지"라 물을 수 없다. 신규 프로젝트의 Where/Link 예외 없음.
- `to-prd`: "인터뷰 금지"와 "사용자 확인" 충돌, 장문 스토리 요구, 없는 `CONTEXT.md` 참조.
- `code-delegate`: 비용 절감 설명의 일반화, 백그라운드 서브에이전트 제약 미기재.
- `checkpoint`: 사용량 추정 기준(응답 50회 · 도구 100회)이 1M 컨텍스트에 안 맞는다.
- `ctxdb-navigator`: `keywords.md` 분할 관례 미기재.
- read-track 훅 대상이 `Read|Grep|Glob`이라 Bash로 읽는 에이전트의 codemap 활용률이 낮게 계측된다(설치처 실측: Bash 417 · Read 40).
- `_wip.md` 템플릿 하단의 사용법 · 상태표 약 30줄이 매 세션 함께 읽힌다.
- (리뷰 지적, 다음 버전) Stop 훅의 8턴 안내문과 CLAUDE.md/AGENTS.md 템플릿의 ON TASK DONE 줄이 옛 절차를 말한다 — `codemap/_index.md 갱신`, ctxdb 저장 없음. 스킬을 실행하면 스킬 본문이 이기지만, 훅 문구만 보고 수동 종결하면 빠질 수 있다. `codebase-map` 5번도 `_index.md`를 가리킨다(codemap 해석 절로 덮인다).

앞의 세 건은 Codex 사용량 분석 lane의 결론과 합쳐 처리한다.

---

## 5. 검증

| 항목 | 결과 |
|---|---|
| PSParser | 10,636 토큰 · **오류 0** |
| setup · 문서 4종 인코딩 | BOM 유지 · bare LF 0 |
| self `-Upgrade` | **0 created / 83 updated / 4 merged / 18 skipped / 0 failed** |
| fresh install (full) | 67 created · 0 failed · 스킬 22 |
| fresh install (lean) | 67 created · 0 failed · 스킬 12 |
| 수정 스킬 6종 fresh == live | full · lean 모두 **6/6 byte 일치** (리뷰 반영 후 재실행) |
| 미러 | source 22 / mirror 22. 본문은 live와 일치(미수정 스킬과 같은 EOF 차이 2자) |
| 정본 대조 | 작업 전 GitHub 정본 147파일과 **해시 전건 일치**(v2.54) |

미검증:
- 훅이 도는 머신에서의 실세션. 이번 변경은 스킬 문구뿐이고 훅 코드는 그대로다.
- 새 규칙이 실제로 파일을 줄이는지는 설치처에서 다음 종결 · 체크포인트를 거쳐야 확인된다.
- Codex 쪽 동작.
- 리뷰는 Claude 서브에이전트 1회. 다른 모델(Codex) 교차 리뷰는 하지 않았다.

---

## 6. 표면

`pawpad-setup.ps1`(스킬 임베드 6 · SKILLS_MANIFEST · 헤더 · `$ver` · 완료 요약) · `README.md` · `GUIDE.md` · `USAGE.md` · `PAWPAD_VERSIONS.md` · `docs/CHANGELOG_v2.55.md`

live 스킬 6종과 `.agents` 미러 6종은 setup이 재생성한다.
