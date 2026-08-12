# 스킬셋 점검 프롬프트 (수동 실행)

> 용도: 아래 `## 프롬프트` 블록을 통째로 복사해 Claude Code 새 세션에 붙여 넣는다.
> 주기는 사용자가 정한다(예약·루프 없음). 실행 위치는 **`D:\Antigravity_Project\pawpad-toolkit`**.
> 이 문서의 `## 환경 사실`은 2026-08-11에 실측한 값이다. 프로젝트가 늘거나 경로가 바뀌면 여기부터 고친다.

---

## 프롬프트

```
PawPad 스킬셋 점검을 실행한다. 지금은 스킬 파일을 고치는 작업이 아니라, 점검하고 변경안을 보고서로 남기는 작업이다.

## 목표
최근 1~2주 세션 기록을 근거로, 21개 PawPad 스킬 문서가 실제 사용 패턴과 어긋난 지점을 찾아 변경안을 만든다.
판단 기준은 "현재 Claude Code 엔진에서, 이 4개 프로젝트를 실제로 굴릴 때 이 문서가 맞는가"이다.

## 대상 프로젝트
| 프로젝트 | repo | 세션 기록(jsonl) |
|---|---|---|
| PawPad | D:\Antigravity_Project\pawpad-toolkit | C:\Users\craki\.claude\projects\D--Antigravity-Project-pawpad-toolkit\ |
| TodayQuest | D:\Antigravity_Project\TodayQuest | C:\Users\craki\.claude\projects\D--Antigravity-Project-TodayQuest\ |
| TeamPitch_2.0 | D:\Antigravity_Project\TeamPitch_2.0 | C:\Users\craki\.claude\projects\d--Antigravity-Project-TeamPitch-2-0\ (선두 d 소문자) |
| LottoNumberPicks | D:\Antigravity_Project\LottoNumberPicks | **없음** — 아래 대체 근거 사용 |

LottoNumberPicks는 `~/.claude/projects` 아래에 transcript 디렉터리가 없다. 이 프로젝트는
`.ctxdb/L2`·`L3`, `.claude/pawpad/wip/done/`, `.claude/pawpad/_meta.md` RECENT만 근거로 쓰고,
"세션 기록 없음"을 보고서에 명시한다. 없는 근거를 추정으로 메우지 않는다.

## 스킬 SoT (중요)
스킬 문서의 단일 원본은 **`pawpad-setup.ps1`** 이다. 설치 스크립트가 here-string으로 찍어낸다:
    Write-FileContent ".claude\skills\{name}\SKILL.md" -NoBom @"..."@
따라서 각 프로젝트의 `.claude/skills/*/SKILL.md` 와 `.agents/skills/*/SKILL.md`(Codex 미러)는 **생성물**이다.
거기를 고치면 다음 `-Upgrade`에 덮여 사라진다. 변경안은 항상 `pawpad-setup.ps1`의 해당 here-string을 가리킬 것.
반영 시에는 live 표면(CLAUDE.md / AGENTS.md / setup 내 두 템플릿)까지 같이 봐야 하는 항목인지 표시한다.

대상 스킬 21종:
brainstorming caveman checkpoint clarity code-delegate codebase-map codemap context-saver
ctxdb-navigator design feature-architecture grill-me handoff lean-code mockup resume review
security-check task-done to-prd viewer-apply

TeamPitch_2.0의 `.claude/skills/`에는 `teampitch-architecture.md` `teampitch-data-models.md`
`teampitch-testing.md` 3개가 더 있다. 이건 PawPad 스킬이 아니라 그 프로젝트 로컬 문서다 — 점검 대상 아님,
drift로 오판하지 말 것.

## 근거 수집 (토큰 주의)
최근 21일 transcript 합계가 20MB를 넘는다. **jsonl을 통째로 읽지 마라.** grep/추출로만 접근한다.

실행 빈도 집계:
    grep -oh '"name":"Skill","input":{"skill":"[^"]*"' <jsonl들> | sort | uniq -c | sort -rn
슬래시 호출:
    grep -oh '<command-name>[^<]*</command-name>' <jsonl들> | sort | uniq -c | sort -rn

이 두 집계로 "실제 실행된 스킬"과 빈도를 먼저 뽑는다.

## 이번 회차 대상 선정 — 근거 있는 것만, 최대 3개
- 위 집계에서 **최근 1~2주 실행 기록이 있는 스킬만** 후보다. 기록 없는 스킬은 이번 회차 대상이 아니다
  (근거가 없으면 "반복 패턴"을 판정할 수 없다. 그런 스킬은 아래 `## 제거 후보`에서 따로 다룬다).
- 후보를 **빈도 높은 순**으로 정렬하고, 직전 보고서에서 이미 다룬 스킬은 뒤로 미룬다(로테이션).
- 위에서부터 **최대 3개**를 고른다. 후보가 3개 미만이면 **그만큼만** 본다 — 숫자를 채우려고 근거 없는 스킬을 끌어오지 않는다.
- 후보가 0개면 근거 수집 결과만 적고 "변경 없음"으로 끝낸다.
- 보고서 첫머리에 `이번 회차 대상: N개 / 후보 M개 / 제외 사유(로테이션·근거부족)`를 밝힌다.

> caveman처럼 매 응답 상시 활성인 스킬은 호출 집계에 안 잡힐 수 있다. 이런 상시 스킬은
> "빈도 최상위"로 간주하되, 로테이션 규칙을 그대로 적용해 매회 반복 점검하지 않는다.

보조 근거(문맥 해석용):
- 각 repo `.ctxdb/L2/progress-current.md`, `.ctxdb/L3/progress-*.md`
- 각 repo `.claude/pawpad/wip/done/*.md` (lane 종결 기록 + Verification Evidence)
- 각 repo `.claude/pawpad/_meta.md` RECENT

## 무엇을 찾나
선정한 스킬의 SKILL.md와 실제 세션 기록을 대조해 아래 4종만 찾는다:
1. 사용자의 교정 지시 — 스킬대로 했는데 사용자가 "그거 아니라"고 돌린 것
2. 스킬을 벗어난 즉흥 처리 — 문서에 없는 방식으로 처리했는데 그게 통했고 반복된 것
3. 반복된 에러 — 같은 실패를 여러 세션에서 되풀이한 것
4. 문서에 없는데 매번 반복된 수동 단계 — 사실상 절차인데 문서화가 안 된 것

## 변경안 규율
- **반복 또는 명시적 교정만.** 우연한 1회는 변경안으로 올리지 않는다. 근거는 세션/날짜/인용으로 댄다.
- **잘 작동하는 기존 지시는 건드리지 않는다. 전면 재작성 금지.** 최소 편집(문장 추가/수정/삭제 단위)으로 제안한다.
- 오랫동안 실행 기록이 없는 스킬은 고치지 말고 **제거 후보**로 따로 보고한다(사용자가 필요 여부를 판단).
- 스킬 수(21)를 바꾸는 제안은 영향 범위가 크다 — 반드시 별도 항목으로 분리하고 파급(설치 체크리스트, 미러 수, 문서 앵커)을 적는다.

## 산출물
보고서를 `D:\Antigravity_Project\pawpad-toolkit\.claude\pawpad\reviews\skill-audit_{YYYY-MM-DD}.md`에 쓴다.
(폴더가 없으면 만든다. 이 경로는 gitignore 대상이라 커밋되지 않는다.)

같은 폴더의 **직전 보고서를 먼저 읽고 이어받는다**:
- 이미 제안했는데 승인되어 반영된 것 → 다시 올리지 않는다
- 이미 제안했는데 기각(❌)된 것 → 다시 올리지 않는다. 기각 목록을 보고서 말미에 누적 유지한다
- 아직 미결(⬜)인 것 → "이월" 표시로 유지
- 지난 회차에 다룬 스킬은 이번엔 뒤로 미뤄, 몇 주에 걸쳐 사용 중인 스킬 전체에 순서가 골고루 가게 한다

보고서 형식:

    # 스킬셋 점검 {YYYY-MM-DD}
    - 근거 기간 / 대상 프로젝트별 세션 수 / 이번 회차 대상 스킬 + 선정 근거
    - 직전 보고서: {경로} (이월 N건, 기각 누적 N건)

    ## 변경 제안
    | # | 스킬 | 유형 | 근거(세션·날짜·인용) | 제안 편집(pawpad-setup.ps1 기준) | 영향 표면 | 승인 |
    |---|------|------|--------------------|------------------------------|---------|------|
    | 1 | ... | 교정지시 | ... | ... | SKILL only / +CLAUDE·AGENTS | ⬜ |

    ## 제거 후보
    | 스킬 | 마지막 실행 | 판단 근거 | 승인 |

    ## 이월 / 기각 누적

## 절대 하지 말 것
- 스킬 파일(`pawpad-setup.ps1`의 here-string 포함)을 **이번 실행에서 수정하지 않는다.**
- 커밋하지 않는다. 버전 올리지 않는다.
- 반영은 사용자가 보고서 표의 `승인` 칸에 ✅를 찍은 뒤, 그 항목만 별도 실행에서 한다.

## 마무리
의미 있는 변경이 없으면 보고서에 **"변경 없음"** 한 줄만 쓰고, 응답도 그 사실만 보고한다.
있으면 변경 제안 표를 응답에 그대로 보여주고 승인을 요청한다.
```

---

## 환경 사실 (2026-08-11 실측)

| 항목 | 값 |
|---|---|
| transcript 루트 | `C:\Users\craki\.claude\projects\{경로인코딩}\*.jsonl` |
| 최근 21일 분량 | TodayQuest 4개 14MB · pawpad-toolkit 5개 6.1MB · TeamPitch_2.0 3개 1.4MB |
| 기록 날짜 | 2026-07-25, 07-26, 08-02, 08-10(6), 08-11(3) |
| LottoNumberPicks | transcript 디렉터리 **없음**. 마지막 커밋 2026-06-25 |
| 스킬 설치 상태 | TodayQuest 21 · TeamPitch_2.0 21(+로컬 3) · LottoNumberPicks 21 |
| 스킬 SoT | `pawpad-setup.ps1` (`Write-FileContent ".claude\skills\{name}\SKILL.md" -NoBom @"..."@`) |
| 스킬 실행 추출 | `"name":"Skill","input":{"skill":"<이름>"}` |
| 슬래시 추출 | `<command-name>/<이름></command-name>` |
| 보고서 폴더 | `.claude/pawpad/reviews/` — gitignore 대상(working memory), 최초 실행 시 생성 |

### 갱신이 필요해지는 조건
- 프로젝트 추가/이름 변경 → 대상 프로젝트 표 + transcript 인코딩 디렉터리명
- LottoNumberPicks에서 Claude Code 세션을 다시 쓰기 시작 → "없음" 항목 해제
- 스킬 수 21 변동 → 스킬 목록
- Claude Code가 transcript 스키마를 바꿈 → 추출 패턴 2종
