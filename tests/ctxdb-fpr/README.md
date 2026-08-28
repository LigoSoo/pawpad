# tests/ctxdb-fpr — ctxdb 회수 오탐률(FPR) 리플레이

`tests/ctxdb-recall`(회귀셋)과 목적이 다르다.

| | ctxdb-recall | ctxdb-fpr |
|---|---|---|
| 질문 | 불러와야 할 때 불러오는가 (**재현율**) | 불러오지 말아야 할 때 안 불러오는가 (**정밀도**) |
| 입력 | 합성 픽스처 INDEX + 설계된 프롬프트 | **실 `.ctxdb/INDEX.md`** + **실제 과거 프롬프트** |
| 판정 | 자동(어서션) | 반자동 — 매칭 여부는 자동, 관련성은 사람/에이전트 라벨링 |
| 실패 시 | exit 1 (회귀) | exit 0 (관측 도구, 게이트 아님) |

## 왜 훅 로그가 아니라 리플레이인가

`.ctxdb/.state/{runtime}-last-decision`을 며칠 모아 세는 방법은 성립하지 않는다:

- `Save-Decision`이 `Set-Content` — 매 프롬프트 **덮어쓰기**. 파일은 항상 2줄(세션 id + 최신 1건).
- 기록 포맷에 **프롬프트도 매칭 키워드도 score도 없다** → 사후에 "관련 없는데 loaded"를 가릴 수 없다.
- 세션 dedupe(`{runtime}-loaded`)가 같은 ref 재매칭을 `already-loaded`로 삼켜 세션당 표본이 사실상 1건.

transcript(`~/.claude/projects/*/*.jsonl`)에는 실제 프롬프트가 그대로 남아 있다. 이걸 실 훅에 다시 먹이면
제품 코드를 건드리지 않고 오늘 숫자가 나온다.

## 사용

```powershell
# 1) 코퍼스 추출 (transcript -> JSON 배열). extract-corpus.py 참조
python tests\ctxdb-fpr\extract-corpus.py <transcript-dir> <out.json>

# 2) 리플레이 (현행 v2.48 = CJK 하한 2)
powershell -NoProfile -ExecutionPolicy Bypass -File tests\ctxdb-fpr\run-fpr-replay.ps1 `
    -CorpusJson out.json -CtxdbSource D:\path\to\repo -Out r-f2.tsv -Tag mycorpus

# 3) 대조군 (v2.47 동작 = CJK 하한 3)
powershell ... -Out r-f3.tsv -CjkFloor 3
```

`-CjkFloor 3`은 훅 **사본**의 `Test-TokenLength` CJK 분기만 2→3으로 치환한다
(`Get-TokenVariants`의 "어간 2자 이상 유지" 조건은 건드리지 않는다 — 그건 조사 스트립 규칙이지 하한이 아니다).
앵커가 안 맞으면 exit 2로 멈춘다. 훅 구조를 바꾸면 여기 정규식도 같이 본다.

## 설계 메모 (함정)

1. **프롬프트마다 새 session_id** — 안 그러면 2번째부터 전부 `already-loaded`가 되어 오탐률이 0%로 위장된다.
2. **ASCII 이스케이프 JSON** — `ConvertTo-AsciiJson`. 회귀셋 README 함정 ②와 동일 이유.
   파이프 바이트가 `[Console]::OutputEncoding`에 좌우돼 한글이 깨지면 tokens=0 → 역시 오탐률 0% 위장.
3. **PS 5.1 `ConvertFrom-Json`은 JSON 배열을 파이프라인에서 풀지 않는다** — `@()`로 감싸면
   "배열 하나를 담은 1원소 배열"이 되어 코퍼스 전체가 1건으로 접힌다(실측). `foreach` + `[Array]` 언롤로 회피.
4. **codemap 주입 off** — 픽스처 config에서 끈다. 이 측정 대상은 ctxdb 회수뿐이다.
5. **`.state` 미복제** — 실 repo의 dedupe 상태가 새면 결과가 오염된다.

## 코퍼스 종류

- **자기 코퍼스**: 해당 repo의 프롬프트 → 그 repo의 INDEX. loaded 중 무관한 것이 오탐.
- **음성 대조군(off-domain)**: 다른 프로젝트의 프롬프트 → 이 repo의 INDEX.
  구성상 대부분 무관해야 정상 — 여기서 loaded가 나오면 거의 오탐이다.
  (단, PawPad 자체 이야기는 어느 프로젝트에서도 나오므로 전건 오탐은 아니다. 라벨링 필요.)

## 1회차 실측 (2026-08-28, v2.48 훅 · 커밋 d37d511)

코퍼스는 `~/.claude/projects/*` transcript에서 추출한 **실제 프롬프트 122건**.
원문은 사용자 발화라 `.gitignore` 처리 — 커밋하지 않는다. 아래는 집계만 남긴다.

| 코퍼스 | INDEX | n | loaded@CJK2 | loaded@CJK3 |
|---|---|---|---|---|
| toolkit 자기 코퍼스 | pawpad-toolkit | 54 | 20 | 12 |
| off-domain 음성대조 (TodayQuest/A1Mini/3DPrinter/kingdom) | pawpad-toolkit | 61 | 3 | 3 |
| TeamPitch 자기 코퍼스 | TeamPitch_2.0 | 7 | 2 | 2 |

**오탐률**: 전체 122건 중 loaded 25건(20.5%). 라벨링 결과 오탐 9건(보수적 판정, 애매 3건 포함)
= **전체 대비 7.4% / loaded 대비 36%**. 명확한 오탐만 세면 6건(4.9% / 24%). 정밀도 64~76%.
오탐 1건당 평균 66줄 주입 — 9건 합계 591줄(≈10.6k 토큰) 낭비.

### 결론: **CJK 2자 하한은 오탐 원인이 아니다**

v2.48이 남긴 미결("2자로 낮춘 부작용 미측정")에 대한 답:

- 하한 3(=v2.47 동작)으로 되돌리면 toolkit 코퍼스에서 **8건이 사라지는데 그 중 6건이 정탐**
  (`로고`·`랜딩`·`회전` → brand-docs, `스킬` → skill-audit). 애매 2건만 줄어든다.
- off-domain 61건에서는 **하한 2와 3의 결과가 완전히 동일**(loaded 3건, 차이 0). 즉 2자 하한이
  무관한 프롬프트를 새로 끌어온 사례가 **0건**이다.
- 실제 오탐 9건의 원인 키워드는 전부 **3자 이상**: `프롬프트`(4자, 5건) · `테스트`(3자, 1건) · `skill`(1건) · `home`(4자, 1건).

### 진짜 오탐 원인 3종 (하한과 무관)

| # | 원인 | 실례 |
|---|---|---|
| F-1 | **키워드 셀의 구(句)가 단어로 쪼개진다.** `Find-L1Match`가 셀을 `[,\s/|]+`로 split → INDEX에 `점검 프롬프트`로 등록해도 `점검`·`프롬프트`가 **각각 독립 키워드**가 된다 | "…뭐라고 **프롬프트**를 쓸까?"(주제=codemap 백필) → `domain-skill-audit` 적재 |
| F-2 | **일반어가 키워드로 등록돼 있다.** `테스트`·`프롬프트`·`조사`·`제거`·`후보`·`점검` 등 도메인 식별력이 없는 낱말 | "직접 에뮬레이터로 **테스트** 진행해"(타 프로젝트) → `domain-ctxdb-recall` 적재 |
| F-3 | **score=1을 그대로 채택한다.** 히트 1개, 그것도 일반어 1개면 근거가 약한데 임계값이 없다 | 오탐 9건 전부 score 낮음 |

toolkit INDEX가 유독 취약한 이유: 도메인이 "이 툴킷 자체를 만드는 일"이라 키워드가
`프롬프트`·`점검`·`조사`·`제거`처럼 **작업 동사/메타 용어**다. TeamPitch INDEX(`클럽`·`회비`·`출석`)처럼
사물명사 위주면 같은 하한에서도 오탐이 훨씬 적다.
