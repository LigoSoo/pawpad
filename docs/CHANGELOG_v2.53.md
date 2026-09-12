# CHANGELOG v2.53 — Codex 표면 기본 미설치 (opt-in `-WithCodex`)

- 날짜: 2026-09-12
- 기준: v2.52
- 스킬 수: **22 불변**
- Claude 산출물: **바이트 불변** (CLAUDE.md / .claude/skills / .claude/hooks)

---

## 1. 왜

사용자 요구: **"Codex에서 현재 스킬을 사용하는 건 불안하다."**

PawPad는 v2.18부터 단일 배포본이 Claude Code와 Codex 양쪽 표면을 **항상 함께** 깔았다. Codex 런타임에서
스킬이 의도대로 동작한다는 확신이 없는 상태에서는, 설치가 자동으로 만들어 놓은 `AGENTS.md` + 스킬 미러가
"쓰라고 놓인 것"처럼 보인다. 기본값을 뒤집는다 — **기본 설치는 Claude 전용**, Codex는 명시적 선택.

## 2. 무엇이 바뀌나

`-WithCodex` 스위치 신설. 지정하지 않으면 아래 4종을 **생성하지 않는다**.

| 층 | 산출물 | 비고 |
|----|--------|------|
| A | `.agents/skills/*` (22개 미러) | `code-delegate`만 Codex 전용본, 나머지는 Claude 본문 복사 |
| B | `AGENTS.md` | CLAUDE.md의 Codex 미러 |
| C | `.codex/config.json` | 보조 설정(`skills` 배열 포함) |
| D | `.codex/config.toml` · `hooks.json` · `hooks/*` | Codex native lifecycle hook |

부수 효과 3건:

- 진행 바 단계 **29 → 25** (Codex 4단계 제외). 완료 체크리스트에서도 해당 행이 사라진다.
- `.ctxdb/.state/codex-turn-count` · `codex-loaded` 미생성 (Codex hook이 없으면 읽는 주체도 없다).
- `~/.codex/skills/` 전역 섀도잉 경고는 **Codex 표면을 설치할 때만** 발화한다.

## 3. 기존 설치는 바뀌지 않는다 (자동 감지)

`AGENTS.md` / `.agents/skills` / `.codex/config.json` / `.codex/hooks.json` 중 **하나라도 있으면**
`-WithCodex` 없이도 Codex 표면을 계속 설치·갱신한다.

근거: `-Upgrade`가 사용자 자산을 말없이 지우지 않는다는 기존 규율과 같은 방향이다. 이 감지 덕분에
기본값 변경이 **이미 배포된 설치처의 동작을 전혀 바꾸지 않는다** — 새 프로젝트에만 적용된다.

제거를 원하면 수동 삭제다. 설치 스크립트가 Codex 표면을 지우는 경로는 만들지 않았다(백업 없는 파괴 금지).

## 4. 기각한 대안

**부분 제외(A만, 또는 A+B)**: `AGENTS.md` 본문이 `.agents/skills/*` 경로를 다수 참조하고
`.codex/config.json`의 `skills` 배열도 같은 스킬 목록을 가리킨다. A만 빼면 **죽은 경로를 가리키는 문서**가
남는다. 사용자 결정으로 A+B+C+D 전체 제외.

**`-Upgrade` 시 기존 Codex 산출물 제거**: 의도는 명확하지만 백업 없는 삭제는 파괴적이고,
`-Upgrade`의 계약("툴킷 파일만 갱신, 사용자 데이터 보존")과 충돌한다.

## 5. 왜 Claude 측 텍스트는 건드리지 않았나

스킬 본문에는 `CLAUDE.md/AGENTS.md Response Style이 강제한다` 같은 산문이 여러 곳에 있다.
이것을 설치 모드에 따라 갈라 쓰면 **두 모드의 스킬 바이트가 달라져** `live==embed` 대조와
바이트 보존 회귀 테스트가 둘 다 무의미해진다. 존재하지 않는 파일명이 설명문에 남는 비용보다
"Claude 산출물은 모드와 무관하게 동일"이라는 불변식이 크다. `.claude/HYBRID.md`도 같은 이유로 유지한다
(협업 프로토콜 문서이자 `ON START` step 2의 읽기 대상).

## 6. 표면

- `pawpad-setup.ps1`: param `-WithCodex` / `$script:installCodex`·`$script:codexDetected` 판정 /
  `$stepTotal` 분기 / 게이트 5곳(AGENTS.md · Codex native adapter · Codex skill mirror · Codex config.json ·
  codex state 파일) / 섀도잉 경고 / i18n 3키(ko·en) + 완료 요약 상태줄 / 헤더 usage
- `tests/codex-delegation/run-generation-tests.ps1`: `Invoke-Setup`이 신버전에만 `-WithCodex` 전달
  (구 baseline은 파라미터가 없다) + `-NoCodex` 경로 신설, 신규 검증 6건
- 문서: `README.md` · `GUIDE.md` · `USAGE.md` · `PAWPAD_VERSIONS.md`

## 7. 검증

| 항목 | 결과 |
|------|------|
| PSParser (설치 스크립트 / 테스트 러너) | 0 / 0 |
| 기본 설치 (`-Preset full`) | exit 0 · 0 failed · 스킬 22 · `AGENTS.md`/`.agents`/`.codex` **전부 미생성** · 진행 바 25/25 |
| `-WithCodex` 설치 | exit 0 · 0 failed · `AGENTS.md` 생성 · 미러 22/22 · `.codex/hooks.json`·`config.json` 생성 · 29/29 |
| 두 모드 Claude 측 바이트 대조 | 43/43 동일 (`.claude/settings.json`만 픽스처 절대경로 차이 — 경로 정규화 후 동일 확인) |
| 기존 Codex 설치에 `-Upgrade` (스위치 없이) | 미러 강제 오염 후 재갱신 확인 · `MERGED .codex/config.json` · 0 failed |
| Claude 전용 설치에 `-Upgrade` | `AGENTS.md`/`.agents`/`.codex` 여전히 미생성 · 0 failed |
| `tests/codex-delegation` 회귀 | **24/24 PASS** (기존 18 + 신규 6) |

미검증: 설치처 실전개(다운스트림 4곳은 전부 Codex 표면 보유 → 자동 감지 경로로만 영향).
