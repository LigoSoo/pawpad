# 스킬셋 점검 프롬프트 (수동 실행)

> 용도: 아래 `## 프롬프트` 블록을 통째로 복사해 Claude Code 새 세션에 붙여 넣는다.
> 주기는 사용자가 정한다(예약·루프 없음). 실행 위치는 **`D:\Antigravity_Project\pawpad-toolkit`**.
> 흐름: **점검 → 변경안을 체크박스로 제시 → 사용자가 고른 것만 그 자리에서 반영 → 기록**.
> 이 문서의 `## 환경 사실`은 2026-08-11 실측값이다. 프로젝트가 늘거나 경로가 바뀌면 여기부터 고친다.

---

## 프롬프트

```
PawPad 스킬셋 점검을 실행한다.

## 목표
최근 1~2주 세션 기록을 근거로, 21개 PawPad 스킬 문서가 실제 사용 패턴과 어긋난 지점을 찾는다.
찾은 변경안을 **체크박스로 제시해 내 선택을 받고, 내가 고른 것만 이 실행 안에서 반영한다.**
판단 기준은 "현재 Claude Code 엔진에서, 이 4개 프로젝트를 실제로 굴릴 때 이 문서가 맞는가"이다.

전체 흐름: 1)근거 수집 → 2)대상 선정 → 3)대조·변경안 도출 → 4)체크박스 선택 → 5)선택분 반영·검증·커밋 → 6)기록

## 대상 프로젝트
| 프로젝트 | repo | 세션 기록(jsonl) |
|---|---|---|
| PawPad | D:\Antigravity_Project\pawpad-toolkit | C:\Users\craki\.claude\projects\D--Antigravity-Project-pawpad-toolkit\ |
| TodayQuest | D:\Antigravity_Project\TodayQuest | C:\Users\craki\.claude\projects\D--Antigravity-Project-TodayQuest\ |
| TeamPitch_2.0 | D:\Antigravity_Project\TeamPitch_2.0 | C:\Users\craki\.claude\projects\d--Antigravity-Project-TeamPitch-2-0\ (선두 d 소문자) |
| LottoNumberPicks | D:\Antigravity_Project\LottoNumberPicks | **없음** — 아래 대체 근거 사용 |

LottoNumberPicks는 `~/.claude/projects` 아래에 transcript 디렉터리가 없다. 이 프로젝트는
`.ctxdb/L2`·`L3`, `.claude/pawpad/wip/done/`, `.claude/pawpad/_meta.md` RECENT만 근거로 쓰고,
"세션 기록 없음"을 명시한다. 없는 근거를 추정으로 메우지 않는다.

## 스킬 SoT (중요)
스킬 문서의 단일 원본은 **`pawpad-setup.ps1`** 이다. 설치 스크립트가 here-string으로 찍어낸다:
    Write-FileContent ".claude\skills\{name}\SKILL.md" -NoBom @"..."@
각 프로젝트의 `.claude/skills/*/SKILL.md`, `.agents/skills/*/SKILL.md`(Codex 미러)는 **생성물**이다.
거기를 고치면 다음 `-Upgrade`에 덮여 사라진다. **반영은 반드시 `pawpad-setup.ps1`에 한다.**
스킬 규칙이 CLAUDE.md/AGENTS.md에도 걸쳐 있으면 live 2표면 + setup 내 템플릿 2표면 = 4표면을 같이 본다.

대상 스킬 21종:
brainstorming caveman checkpoint clarity code-delegate codebase-map codemap context-saver
ctxdb-navigator design feature-architecture grill-me handoff lean-code mockup resume review
security-check task-done to-prd viewer-apply

TeamPitch_2.0의 `.claude/skills/`에 있는 `teampitch-architecture.md` `teampitch-data-models.md`
`teampitch-testing.md` 3개는 PawPad 스킬이 아니라 그 프로젝트 로컬 문서다 — 점검 대상 아님, drift로 오판 금지.

## 1) 근거 수집 (토큰 주의)
최근 21일 transcript 합계가 20MB를 넘는다. **jsonl을 통째로 읽지 마라.** grep/추출로만 접근한다.

실행 빈도 집계:
    grep -oh '"name":"Skill","input":{"skill":"[^"]*"' <jsonl들> | sort | uniq -c | sort -rn
슬래시 호출:
    grep -oh '<command-name>[^<]*</command-name>' <jsonl들> | sort | uniq -c | sort -rn

보조 근거(문맥 해석용): 각 repo의 `.ctxdb/L2/progress-current.md`, `.ctxdb/L3/progress-*.md`,
`.claude/pawpad/wip/done/*.md`(lane 종결 + Verification Evidence), `.claude/pawpad/_meta.md` RECENT.

## 2) 대상 선정 — 근거 있는 것만, 최대 3개
- 최근 1~2주 **실행 기록이 있는 스킬만** 후보다. 기록 없는 스킬은 점검 대상이 아니라 `제거 후보`로 다룬다.
- 빈도 높은 순 정렬 + 직전 보고서에서 이미 다룬 스킬은 뒤로 미룬다(로테이션).
- 위에서부터 **최대 3개**. 후보가 3개 미만이면 그만큼만 — 숫자 채우려고 근거 없는 스킬을 끌어오지 않는다.
- 후보가 0개면 근거 수집 결과만 보고하고 "변경 없음"으로 끝낸다.

> caveman처럼 매 응답 상시 활성인 스킬은 `Skill` 호출 집계에 안 잡힌다. 이런 상시 스킬은
> 빈도 최상위로 간주하되, 로테이션은 똑같이 적용해 매회 반복 점검하지 않는다.

## 3) 대조 — 무엇을 찾나
선정한 스킬의 SKILL.md와 세션 기록을 대조해 아래 4종만 찾는다:
1. 사용자의 교정 지시 — 스킬대로 했는데 사용자가 "그거 아니라"고 돌린 것
2. 스킬을 벗어난 즉흥 처리 — 문서에 없는 방식으로 했는데 통했고 반복된 것
3. 반복된 에러 — 같은 실패를 여러 세션에서 되풀이한 것
4. 문서에 없는데 매번 반복된 수동 단계 — 사실상 절차인데 문서화가 안 된 것

규율:
- **반복 또는 명시적 교정만.** 우연한 1회는 올리지 않는다. 근거는 세션·날짜·인용으로 댄다.
- **잘 작동하는 기존 지시는 건드리지 않는다. 전면 재작성 금지.** 문장 추가/수정/삭제 단위의 최소 편집으로 제안한다.
- 직전 보고서에서 이미 반영됐거나 기각된 항목은 다시 올리지 않는다.

## 4) 선택 받기 — AskUserQuestion 체크박스 (핵심)
변경안을 **산문 목록으로 늘어놓지 말고 AskUserQuestion으로 받는다**(CLAUDE.md "선택지 질문 = 체크박스").

- **스킬 1개당 질문 1개**, `multiSelect: true`. 대상이 3개면 질문 3개.
- 각 질문의 옵션 = 그 스킬의 변경안(도구 상한상 **최대 4개**). 4개를 넘으면 근거가 강한 순으로 4개만 올리고
  나머지는 보고서에 "이월"로 남긴다.
- 옵션 `label`은 무엇을 바꾸는지 한 줄로. `description`에 **근거(언제·무슨 일)와 실제 편집 내용**을 넣는다.
  근거가 가장 강한 항목을 첫 옵션에 두고 label 끝에 "(추천)".
- 각 질문의 마지막 옵션은 항상 **"이 스킬은 이번엔 반영 안 함"** — 사용자가 통째로 넘길 수 있어야 한다.
- 제거 후보가 있으면 **별도 질문 1개**로 묶는다(`multiSelect: true`, 옵션=스킬명, 마지막에 "전부 유지").
- 질문은 최대 4개까지만 만든다(도구 상한). 스킬 3 + 제거후보 1 = 4가 상한선이다.

질문을 던지기 전에, 응답 본문에 각 변경안의 **before/after 발췌**를 짧게 보여준다. 체크박스만으로는
무엇이 바뀌는지 판단할 수 없다.

## 5) 반영 — 선택된 것만
사용자가 고른 항목만 실행한다. 고르지 않은 것은 손대지 않는다.

- 편집 대상은 `pawpad-setup.ps1`의 해당 here-string. **live `.claude/skills/**` 를 직접 고치지 않는다.**
- 4표면 항목(CLAUDE/AGENTS live 2 + setup 템플릿 2)은 전부 같이 고친다. 하나만 고치면 다음 설치에 되돌아간다.
- 반영 후 검증(PawPad DoD):
  1. `[System.Management.Automation.PSParser]::Tokenize()` errors 0
  2. 자체 `.\pawpad-setup.ps1 -Upgrade -Stack generic` → **0 failed**
  3. `-Upgrade` 후 `git status`에 `.claude/**` diff 0 (emitted==live 확인)
  4. `-Upgrade` 후 live SKILL.md에 편집 내용이 실제로 반영됐는지 grep 1건 이상 확인
- 버전: **기본은 올리지 않는다.** 문구 교정·절차 명료화는 `docs/CHANGELOG_v{현재}.md`의 `## Addendum`으로 흡수한다.
  스킬 수(21) 변동이나 절차 신설급이면 **먼저 물어본다** — 임의로 올리지 않는다.
- lane: `.claude/pawpad/wip/skill-audit-{YYYY-MM-DD}.md` 생성 후 종료 시 `wip/done/`으로 이관 + `_meta.md` RECENT 1줄.
- codemap: 변경한 스킬 심볼이 `.claude/codemap/_index.md`에 있으면 갱신.
- 커밋: 반영분만. 커밋 메시지에 "어떤 근거로 무엇을 바꿨는지" 적는다. **push는 하지 않는다.**

## 6) 기록
`D:\Antigravity_Project\pawpad-toolkit\.claude\pawpad\reviews\skill-audit_{YYYY-MM-DD}.md`
(폴더 없으면 생성. gitignore 대상이라 커밋되지 않는다.)

같은 폴더의 **직전 보고서를 먼저 읽고 이어받는다** — 반영·기각 이력이 다음 회차의 중복 제안을 막는다.

    # 스킬셋 점검 {YYYY-MM-DD}
    - 근거 기간 / 프로젝트별 세션 수 / 이번 회차 대상 N개 (후보 M개, 제외 사유: 로테이션·근거부족)
    - 직전 보고서: {경로}

    ## 결과
    | # | 스킬 | 유형 | 근거(세션·날짜·인용) | 편집 내용 | 표면 | 결과 |
    |---|------|------|--------------------|---------|------|------|
    | 1 | ... | 교정지시 | ... | ... | setup only / 4표면 | ✅반영 / ❌기각 / ⬜이월 |

    ## 제거 후보
    | 스킬 | 마지막 실행 | 판단 근거 | 결과 |

    ## 기각 누적 (다시 제안하지 말 것)
    ## 다음 회차 로테이션 (이번에 다룬 스킬은 뒤로)

## 하지 말 것
- 선택을 받기 전에 스킬 파일을 고치지 않는다.
- 고르지 않은 항목을 "겸사겸사" 같이 고치지 않는다.
- 전면 재작성, 임의 버전 올림, push — 전부 금지.

## 마무리
- 의미 있는 변경이 없으면 보고서에 **"변경 없음"** 한 줄만 쓰고, 응답도 그 사실만 보고한다.
- 반영했으면 무엇을 왜 바꿨는지 + 검증 결과 + 커밋 해시를 보고한다.
- 사용자가 전부 기각했으면 기각 사실만 기록하고 파일은 건드리지 않는다.
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
| AskUserQuestion 상한 | 질문 4개 / 질문당 옵션 4개 — 스킬 3 + 제거후보 1 이 상한선 |

### 갱신이 필요해지는 조건
- 프로젝트 추가/이름 변경 → 대상 프로젝트 표 + transcript 인코딩 디렉터리명
- LottoNumberPicks에서 Claude Code 세션을 다시 쓰기 시작 → "없음" 항목 해제
- 스킬 수 21 변동 → 스킬 목록
- Claude Code가 transcript 스키마를 바꿈 → 추출 패턴 2종
- AskUserQuestion 상한 변경 → 4)의 질문/옵션 개수 규칙
