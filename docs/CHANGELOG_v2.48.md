# CHANGELOG v2.48 — ctxdb 키워드 회수 복구 + 계층 성장 규약

> 날짜: 2026-08-27 | 기반: v2.47 | 스킬 수: **21 불변**
> 한 줄: "프롬프트 키워드로 과거를 부른다"가 설치처에서 6주간 한 번도 동작하지 않았다. 원인 6종을 toolkit 원본에서 재확인해 훅을 고치고, 저장량에 따라 L2→L3→L4로 넓어지는 성장 규약과 회귀셋을 붙였다.

---

## 1. 문제 (실측)

관측 레포 `dblogscope_claude`(v2.46 설치, Windows 11). 진단 보고서는 이 레포에 커밋하지 않았다 — 아래가 요지다.

- `.ctxdb/.state/claude-loaded`가 **설치일(2026-07-14) 이후 한 번도 생성된 적 없음** = 자동 주입 0회.
- 서로 다른 두 주제("배치 삽입 성능", "아이콘 캐시 배포")가 **동일 페이로드**(같은 SHA-256)를 받음.
- L3에 807줄이 쌓여 있는데 훅 전체에 `L3` 문자열 0건.

toolkit 원본에서 6종 전부 재확인(`.claude/hooks/ctxdb-inject.ps1`, `.codex/hooks/ctxdb-inject.ps1` 동형):

| ID | 결함 | 원본 위치 |
|---|---|---|
| D-1 | 길이 하한 3이 영어 기준 → **한글 2음절 키워드 전량 탈락** | `Get-PromptTokens` + `Find-L1Match` 양쪽 |
| D-2 | `Find-L1Match` 첫 히트 즉시 반환 → 짧은 일반어가 엉뚱한 도메인 선점 | `Find-L1Match` |
| D-3 | `Get-L2Refs` 정규식이 `L2/`만 매칭 → **이월한 L3는 회수 경로 없음** | `Get-L2Refs` |
| D-4 | L1 포인터 탐색을 주입 범위(앞 120줄)와 묶음 → L1이 자라면 조용히 무주입 | 메인 흐름 |
| D-5 | `elseif ($explicit)` → **매칭 성공이 폴백을 끈다** | 메인 흐름 |
| D-6 | 무주입 3경로가 전부 `{}` → 6주간 정상으로 보임 | 메인 흐름 |

**실측 사멸률**: 관측 레포 INDEX 키워드 98개 중 37개(38%) 탈락. toolkit 자체도 64조각 중 6개(9%) —
한글 키워드 비율에 정비례한다(`스킬`·`시각`·`품질`·`배포`·`문서`·`이름`).

**D-1 대조 실험** (toolkit, 동일 INDEX 행 · 변수는 키워드 길이 하나):

```
"프로젝트 이름 어떻게 정했지"  -> {}                             (이름 = 2자, 등록돼 있는데 탈락)
"브랜드 네이밍 다시 보자"      -> loaded L2/branding-session.md   (브랜드 = 3자)
```

### 1-1. 보고서에 없던 추가 발견

- **N-1 (최중요)** `stop-check.ps1`은 L2 150줄 초과 시 "L3로 분할하라"고 block 한다. 그런데 D-3으로 L3는 회수되지 않는다.
  → **규정을 성실히 지킬수록 장기기억이 사라지는 구조**. D-3은 단독 버그가 아니라 성장 규칙과 결합된 데이터 손실 경로였다.
- **N-2** hook-free 대체 경로 부재. `ON START`(CLAUDE.md 0단계)만 agent 수동이고 **세션 중 회수는 훅 전용** —
  조직 정책으로 훅이 막히거나 비Windows면 기능이 0이 된다.
- **N-3** codemap Phase B는 `keywords.md`를 **agent가 읽어 의미매칭**한다(SKILL 명시: "grep 아님"). ctxdb는 PowerShell 정확매칭이라
  조사·동의어·어순은 원리적으로 놓친다. 길이 하한만 고쳐서는 부족.
- **N-4** `Get-L2Refs`가 고르는 L2 2개는 관련도 상위가 아니라 **L1 앞 120줄 등장순**.
- **D-6 부분 정정** — 주입 **성공** 시에는 status 1줄이 이미 있었다. 정확히는 "무주입 시 진단 없음".

---

## 2. 변경

### 2-1. 훅 (Claude · Codex 동형)

| 항목 | 내용 |
|---|---|
| `Test-TokenLength` 신설 | CJK(한글·한자·가나) 2자 / 라틴 3자로 하한 분리 |
| `Get-TokenVariants` 신설 | 한국어 조사 스트립. 원형 + 어간 **양쪽**을 후보로(긴 조사 우선, 1회만, 어간 2자 이상 유지) |
| `Find-L1Match` 점수화 | 첫 히트 즉시 반환 폐기 → 전 행 스캔 후 히트 수 최대 선택, 동점은 우선순위 컬럼 |
| `Get-CtxRefs`(구 `Get-L2Refs`) | 정규식 `L[234]/` — L3/L4 포인터도 회수 대상 |
| `Get-BlockMatches` 신설 | L3/L4는 `## ` 헤더로 블록 분할 → 키워드 히트 블록만 주입(최대 60줄). 파일 통째 금지 |
| 탐색/주입 분리 | 포인터는 L1 **본문 전체**에서 찾고, 주입만 앞 120줄 |
| 폴백 상시 | `elseif` 제거. 후보가 비면 항상 `L2/progress-current.md` |
| `Save-Decision` 신설 | 무주입 사유를 `.ctxdb/.state/{claude|codex}-last-decision`에 기록. **`{}` 출력 계약은 유지** |

> `{}` 계약을 유지한 이유: 보고서는 무주입 시에도 한 줄 주입을 제안했으나, Codex는 additionalContext를 TUI에 렌더링하므로
> 매 프롬프트 노이즈가 된다(`HOOK_TESTING.md` #5 계약과도 충돌). 진단은 state 파일로 뺐다.

### 2-2. 규약

| 항목 | 내용 |
|---|---|
| INDEX `L2/L3 경로` 컬럼 | 포인터를 L1 본문 길이와 **분리**(D-4 근본). 비우면 기존대로 L1 본문에서 탐색 — 구 형식 호환 |
| `.ctxdb/keywords.md` 신설 | 의도·증상 → 도메인 의미매칭 층. **agent 전용**(훅은 안 읽음). codemap `keywords.md` 패턴 이식. 상한 4KB |
| context-saver STEP 5 | 계층 승격: L2 150줄/2000토큰 → L3, L3 400줄 → L4, L1 60줄·키워드 30개 초과 → 도메인 분할 제안. **이월 시 INDEX·L1 포인터 갱신 의무**(N-1 차단), append-only |
| context-saver STEP 4 | 신규 도메인 생성 시 `keywords.md` 1~2줄 동반 갱신 |
| checkpoint 실행 절차 | `context-saver` 호출 단계 추가(D-8) — 빠지면 다음 세션이 그 작업을 키워드로 못 찾는다 |
| Session Protocol `ON NEW TOPIC` | 새 주제 + 훅 주입 블록 부재면 `keywords.md` 의미매칭 1회(N-2 폴백). 같은 주제 재발동 금지 |

### 2-3. 회귀셋 `tests/ctxdb-recall` (신규, **배포본 미포함**)

toolkit 개발 자산. 픽스처(가짜 설치처) + 21케이스 러너. 설치처에는 넣지 않는다(설치본이 훅을 테스트할 이유가 없다).

> **이력 정정(2026-08-27)**: 최초 구현·통과는 다른 머신에서 이뤄졌고 산출물이 이 레포에 없었다.
> 같은 사양(C1~C18)으로 이 머신에서 재구현해 커밋했다. 설계 메모와 검출력 근거는 `tests/ctxdb-recall/README.md`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\ctxdb-recall\run-recall-tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\ctxdb-recall\run-recall-tests.ps1 -Hook ".codex/hooks/ctxdb-inject.ps1"
```

C1 한글 2음절 / C2 조사 / C3 라틴 회귀 보존 / C4 무관 주제 무주입+사유 / C5 L1 150행 아래 포인터 /
C6 매칭 성공 + 포인터 0 → 폴백 / C7 L3 블록 선별(무관 블록 미포함 검증) / C8 다중 히트 우선 / C9·C10 세션 dedupe /
C11·C12 구 3컬럼 INDEX 호환 / C13 mixed L2/L3에서 아카이브 미절단 / C14 조사 오분해 금지(음성) /
C15 INDEX 부재 진단 / C16 L4 회수 / C17 60줄 컷 / C18 Codex pointer 모드 /
C19·C20·C21 영문 어간 + 한글 조사(`React를`·`Docker에서`·`Flutter로`, 사후수정#1).

**비교 기준**: 임베드 대조는 워크트리 EOL이 아니라 **개행 정규화 후 내용 동일성**(또는 Git blob) 기준이다 —
`core.autocrlf` 때문에 워크트리 표현이 파일마다 다르고, 그것은 배포 산출물의 차이가 아니다.

---

## 3. 표면 (동기 대상)

| 표면 | 파일 |
|---|---|
| 훅 live | `.claude/hooks/ctxdb-inject.ps1`, `.codex/hooks/ctxdb-inject.ps1` |
| 훅 임베드 | `pawpad-setup.ps1` 2곳 |
| 스킬 | `checkpoint` · `context-saver` · `ctxdb-navigator` × (live + `.agents` 미러 + setup 임베드) |
| 프로토콜 | `CLAUDE.md` · `AGENTS.md` + setup 내 두 템플릿 (`ON NEW TOPIC`) |
| ctxdb 템플릿 | setup `.ctxdb\INDEX.md`(컬럼 추가) + `.ctxdb\keywords.md`(신규) |
| toolkit 자체 데이터 | `.ctxdb/INDEX.md`(컬럼 + 2음절 키워드 복원) · `.ctxdb/keywords.md` |
| 문서 | `README` · `GUIDE` · `USAGE` · `PAWPAD_VERSIONS` · `docs/HOOK_TESTING.md`(#17·#18) |

---

## 4. 검증

| 항목 | 결과 |
|---|---|
| PSParser | `pawpad-setup.ps1` / 훅 2종 parse errors 0 |
| 회귀셋 (Claude 훅) | **20/20 PASS** (+Codex 전용 C18 SKIP) — 사후수정#1로 18→21케이스 |
| 회귀셋 (Codex 훅) | **21/21 PASS** |
| 회귀 검출력 (mutation) | 수정본에 D-1·D-2·D-3·D-4·D-5·60줄컷을 하나씩 되심어 **6/6 검출**. D-1·D-3은 파급이 넓어 여러 케이스가 동시에 죽으므로, 개별 검출력은 나머지 4종의 targeted mutation(단일 케이스만 실패)이 증명 |
| 스킬 미러 정합 | self `-Upgrade` 후 emitted==live — 21개 중 변경분 3개(`checkpoint`·`context-saver`·`ctxdb-navigator`) 외 불일치 0 |
| 자체 배포 | toolkit self `-Upgrade`: 1 created / 77 updated / 4 merged / 17 skipped / **0 failed** |
| 다운스트림 배포 | TeamPitch_2.0 · TodayQuest · LottoNumberPicks 각 78 updated, kingdom_test_cluade 77 updated — **각 0 failed**, 4곳 전부 훅 2종 + `keywords.md` + `ON NEW TOPIC` 적중 |
| 픽스처 스모크 | 4컬럼 INDEX 픽스처: "로고"(CJK 2자) → `L2/brand.md` · "로고를"(조사) → 동일 · "배포" → `L3/deploy-2026-07.md` 블록 회수 · 미등록어 → `{}` |
| toolkit 실환경 스모크 | "로고 어떻게 만들었지"(2자) → `L1/domain-brand-docs.md` + `L2/progress-current.md`, "로고를 다시 보자"(조사) → 동일, "스킬 점검 언제 했지" → `L1/domain-skill-audit.md`, "conventions"(라틴 회귀) → `L2/codebase-map-current.md`, 무관 주제 → `{}` + `no-match \| tokens=4` 기록 |

---

## 5. 비고 / 미결

- **설치처 데이터 마이그레이션 제외**(사용자 결정). `dblogscope_claude`의 L3 807줄 재회수·도메인 분할은 별건.
  설치처의 임시 수정(L1 축소, `Get-TextLines $l1Path` 120→60)은 `-Upgrade` 재설치 시 되돌아간다 — 원본이 근본 수정을 담았으므로 무해.
- **toolkit 자체 INDEX 재구성 완료**(2026-08-27). 구 3~5행은 L1 컬럼에 `L2/`·`docs/`·`codemap` 경로를 넣고 있어
  `Find-L1Match`의 `L1/` 요구를 못 맞췄다 — 신·구 훅 모두에서 영구 무매칭이었다(`로고` 등록돼 있는데 `{}`).
  4컬럼으로 전환하고 `L1/domain-brand-docs.md` · `L1/domain-skill-audit.md`를 신설해 포인터를 4번째 컬럼으로 옮겼다.
  `.ctxdb/`는 gitignore이므로 이 재구성은 배포물이 아니라 toolkit 자체 데이터에만 적용된다.
- **`.sh` 스텁 현행 유지**(D-7). `pwsh` 부재 시 `hook-skip`. 단일 배포본 철학 + Mac 지원 보류 결정(`_meta` NEXT)에 따른다.
  비Windows에서는 `ON NEW TOPIC` agent 폴백이 회수를 대신한다.
- **오탐률 미측정**. 하한을 2자로 낮추면 짧은 일반어 오탐이 늘 수 있다. 점수화 매칭이 완충이지만 실사용 관측이 필요하다.
- **Codex pointer 모드는 C18 1건만 커버**. 나머지 픽스처는 `injectMode: full` 고정 — 렌더링을 벗겨야 회수 로직 자체가 보인다. pointer 렌더링의 세부 변형은 미커버.

---

## 6. 사후수정 #1 (2026-08-27, **버전 불변**)

`/code-review ultra` 교차 리뷰(main → a0bc912, 19파일 +1721/−253) 지적 2건. 둘 다 nit이나 실버그라 반영.

### 6-1. `Get-TokenVariants` — 영문 어간 + 한글 조사에서 스트립 실패

`React를`, `Flutter로`, `Docker에서` 같은 **라틴 어간 + 한글 조사** 조합에서 어간이 후보에 오르지 않았다.
`Get-Jongseong`이 라틴 문자에 `-1`을 반환하는데 `if ($jong -lt 0) { break }`가 어간 추가 **전에**
루프를 끊었기 때문이다. 결과적으로 라틴 INDEX 키워드(`react`·`flutter`·`firebase`·`riverpod`)가
한국어 프롬프트에서 조용히 무매칭 — v2.48이 고치려던 실패 모드와 같은 성격의 사각지대다.

수정: 어간이 한글로 끝나지 않으면 형태(C/V) 검사를 건너뛴다. 받침이 없어 형태를 계산할 수 없고,
실제 조사 선택은 한국어 발음을 따르므로 코드로 정할 수 없다. 이 조합에서 뒤에 붙은 한글은
사실상 조사뿐이다. 오분해 위험(`전문가`→`전문`)은 한글 어간 고유의 문제라 영향 없다(C14 PASS 유지).

표면 4곳: 훅 live 2 + `pawpad-setup.ps1` 임베드 2. 회귀 C19·C20·C21 추가 —
**수정 전 3건 전부 FAIL, 수정 후 PASS**로 검출력 확인.

> 이 결함이 v2.48 회귀셋 18케이스를 통과한 이유: C1·C2는 순수 한글 어간+조사, C14는 한글 어간의
> 오분해 방지 음성 케이스뿐이었다. **라틴 어간 + 한글 조사 조합이 커버 공백이었다.**

### 6-2. `.gitignore` — `.ctxdb/L4/` 누락

v2.48이 L4를 실저장 계층으로 승격(`context-saver` STEP 5: L3 400줄 초과 → L4 이월)했는데
ignore 목록은 `L1/L2/L3`까지였다. 이 블록의 목적이 "개인 dogfood 서사를 배포하지 않는다"인데,
L4가 같은 성격의 데이터를 받는 새 목적지가 되면서 유일한 방어가 비어 있었다.
`.ctxdb/L4/` 추가 + 주석 문구 동기. (설치처에는 setup이 ctxdb ignore 블록을 쓰지 않으므로 toolkit 자체 1표면.)

