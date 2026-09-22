# CHANGELOG v2.54 — Codex 전용 번들 축 (`-CodexPreset` / `-CodexBundles`)

- 날짜: 2026-09-22
- 기준: v2.53
- 스킬 수: **22 불변**
- 진행 바 단계: **25 / 29 불변**
- 기본 산출물(축 미지정): **불변** — 두 표면에 같은 세트를 깐다

---

## 1. 왜

사용자 질문: **"Claude Code는 전체 설치, Codex는 핵심 스킬만 — 이런 식으로 따로 설치할 수 있나?"**

답은 "아니오"였다. 실측하면 제어 축이 두 개뿐이다.

| 축 | 스위치 | 입도 |
|----|--------|------|
| Codex 표면 on/off | `-WithCodex` (v2.53) | 전부 아니면 전무 |
| 번들 선택 | `-Preset` / `-Bundles` (v2.39) | **두 표면에 동시 적용** |

Codex 미러는 `.claude/skills` 전 디렉터리를 1:1 복사하고(`pawpad-setup.ps1` Codex skill mirror 단계),
prune은 `foreach ($base in @('.claude\skills', '.agents\skills'))`로 **같은 집합을 양쪽에서** 지웠다.
수동으로 `.agents/skills/{일부}`를 지워도 다음 `-Upgrade`의 미러 루프가 전량 재생성한다.

## 2. v2.53이 기각한 "부분 제외"와의 관계

v2.53은 Codex 표면의 부분 제외를 기각했다. 사유는 정확했다 — `AGENTS.md` 본문과 `.codex/config.json`의
`skills[]`가 `.agents/skills` 경로를 다수 참조하므로, 일부만 빼면 **죽은 경로를 가리키는 문서가 남는다**.

이번에 그 정합 작업을 실제로 수행해 기각 사유를 해소했다. 핵심 관찰:

> 이미 존재하는 bundle prune 5단계가 그 정합 로직(디렉터리 제거 / `config.json` 동기 / 매니페스트 동기 /
> docs 트림 / 가드)을 **전부 갖고 있었다**. 문제는 로직이 없는 게 아니라, **양 표면에 같은 집합을
> 먹이고 있었다**는 것뿐이다.

따라서 변경의 본질은 새 로직이 아니라 **집합 분기 + 트림 함수 추출**이다.
정규식 트림 로직 자체는 한 글자도 바뀌지 않았고, `Remove-SkillRefs` / `Sync-SkillsManifest`로 뽑아내
호출을 파일별로 다른 집합에 태웠을 뿐이다. 회귀 위험을 그 경계 안에 가뒀다.

## 3. 무엇이 바뀌나

```powershell
# Claude 전체 + Codex 핵심만
.\pawpad-setup.ps1 -Stack generic -WithCodex -Preset full -CodexPreset lean
#   -> .claude/skills 22개 / .agents/skills 12개(Core)

# 번들 단위 지정도 가능
.\pawpad-setup.ps1 -Preset full -CodexBundles prd,review
```

- Codex 축 **미지정 시 Claude 축을 그대로 상속** → v2.53 이하와 동일 산출물.
- `-CodexPreset` / `-CodexBundles`를 주면 `-WithCodex`를 암묵 적용한다(의도가 명백하므로).
- Core 12는 양쪽 고정. 즉 **Codex 최소 = Core 12**이고, 이것이 "핵심 스킬만"의 실체다.
- 프리셋 값은 Claude 축과 동일: `lean`=12 / `standard`=18 / `full`=22.

### 표면별 정합 매트릭스

| 산출물 | 기준 집합 |
|---|---|
| `.claude/skills/*` · `CLAUDE.md` · `.claude/HYBRID.md` · `.claude/SKILLS_MANIFEST.md` | keepC (Claude 축) |
| `.agents/skills/*` · `AGENTS.md` · `.codex/config.json` `skills[]` · `.agents/SKILLS_MANIFEST.md` | keepX (Codex 축) |

`HYBRID.md`를 keepX로 깎지 않는 이유: **양 에이전트 공유 SoT**라서 Codex 기준으로 깎으면 Claude가 자기
스킬 설명을 잃는다. 대신 비대칭 설치에서는 `AGENTS.md`에 범위 가드 1줄(`pawpad-codex-scope`)을 붙인다 —
"HYBRID가 언급하는 스킬 중 `.agents/skills`에 없는 것은 Codex에서 호출 불가".

## 4. 결정 4건

| # | 결정 | 채택 | 기각 |
|---|------|------|------|
| D1 | CLI 표면 | `-CodexPreset` + `-CodexBundles` (Claude 축과 대칭, 프리셋 재사용) | 단일 스위치 / `-CodexSkills` 명시목록(Core·의존 규칙 우회) |
| D2 | SKILLS_MANIFEST | `.agents/SKILLS_MANIFEST.md` 분리 + `contextFiles.skillsManifest` 포인터 전환 | 단일 파일 + "Codex 가용" 열(× 행을 Codex가 읽는 건 v2.53 기각 사유와 동계열) |
| D3 | 선택 영속화 | `pawpad-config.json` `bundles`에 기록 → `-Upgrade`에서 재사용(인자 우선) | 기록 안 함 / 기록만 하고 경고 |
| D4 | codexSel 초과 | 자동 교집합 + 경고 1줄 | 에러 중단(배치 설치에서 깨짐) / Claude 쪽 자동 승격(사용자 지정 무시) |

D3은 **v2.39부터 잠복해 있던 기보유 결함**도 같이 해소한다. 번들 선택이 어디에도 기록되지 않아
`-Upgrade`에서 인자를 생략하면 말없이 full로 복원됐다. `pawpad-config.json`은 `-Upgrade`에서 SKIP
(사용자 영역)이므로 기록이 보존된다.

D4의 근거: 미러 소스가 `.claude/skills`이므로 Codex는 Claude 설치 범위를 **물리적으로 초과할 수 없다**.
번들별 스킬 집합이 서로 겹치지 않으므로(`prd`/`ui`/`delegate`/`review`/`qa`) 번들 교집합 == 스킬 교집합이고,
번들 단계에서 깔끔히 처리된다.

## 5. 부수 결함 수정 3건

### 5-1. 제거할 게 없는 표면은 문서를 열지 않는다

제거할 스킬이 없는 표면은 **문서를 열지도 않게** 했다(`Remove-SkillRefs` / `Sync-SkillsManifest` 선두 반환,
가드 1줄도 실제로 줄어든 표면에만 부착).

발견 경위: Codex 축만 줄인 설치에서 prune이 발동하면서 `CLAUDE.md`도 재기록됐고, 그 결과

1. UTF-8 **BOM이 떨어졌다**(`ReadAllText`가 BOM을 벗기고 `WriteAllText`가 BOM 없이 다시 쓴다), 그리고
2. Claude 쪽은 아무것도 줄지 않았는데 `pawpad-bundles guard` 줄이 붙었다.

둘 다 "Claude 축을 건드리지 않았으면 Claude 산출물은 바이트 불변"이라는 v2.53 규율 위반이다.

> 남은 기존 동작: Claude 축을 **실제로** 줄이면(`-Preset lean` 등) `CLAUDE.md`의 BOM은 여전히 떨어진다.
> v2.39부터의 동작이며 이번 범위 밖으로 뒀다.

### 5-2. 쉼표 형식 번들 인자가 무시되던 결함 (v2.39부터 잠복)

`-Bundles prd,review`는 문서에 적힌 대로 써도 **Core 12만** 깔렸다.
PowerShell이 `prd,review`를 **배열**로 파싱해 `[string]` 파라미터에 공백 join된 `"prd review"`를 넘기는데,
파싱 코드가 `,`만 잘라 토큰이 깨졌기 때문이다(회피책은 `-Bundles "prd,review"` 인용). 구분자에 공백·세미콜론을 추가해
두 축(`-Bundles` / `-CodexBundles`) 모두 문서표기 그대로 동작한다. `-CodexBundles`를 같은 형식으로 내는 이상 같이 고쳐야 했다.

### 5-3. 번들 기록을 문자열이 아니라 JSON 구조로 갱신 (Codex 적대적 리뷰 지적)

초기 `Update-BundleRecord`는 `pawpad-config.json`을 **문자열로** 다뤄 마지막 `}` 앞에 블록을 끼운다. 툴킷이 만든 파일 형태에서는 동작하지만 사용자가 파일을 손대면 깨졌다:

- 빈 객체 `{}` → 쉼표를 무조건 붙여 `{,"bundles":...}` (파싱 불가)
- 한 줄로 압축된 JSON → 기존 `bundles`를 못 찾아 중복 키 추가
- 중첩 객체가 들어있는 `bundles` → 첫 닫는 중괄호까지만 치환해 문서 파손

저장 전 검증이 없어 설치는 그대로 성공 처리되고, 이후 번들 복원과 hook 설정 읽기가 같이 죽는다.

→ `ConvertFrom-Json`으로 파싱해 **최상위 `bundles` 속성만** 갱신하고(다른 속성 보존), `ConvertTo-Json -Depth 100` 직렬화 + 재파싱에 성공한 **뒤에만** 임시파일로 교체한다(BOM 없음). 실패는 조용히 넘어가지 않고 설치 실패로 집계한다.

> 부수 효과: PS 5.1 `ConvertTo-Json`은 사다리꼴 들여쓰기와 `>` 이스케이프를 낸다. JSON으로는 유효하며, bash hook의 `sed` 추출(`inject` / `largeRepoSymbolThreshold` / `injectMode`)도 실측 정상 동작한다.

## 6. 검증

| 항목 | 결과 |
|------|------|
| PSParser | 0 에러 |
| 설치 매트릭스 8조합 | 각 **0 failed** (full/full · full(Claude전용) · full/lean · standard/lean · lean/full · upgrade-recall · 쉼표형 `-CodexBundles` · 쉼표형 `-Bundles`) |
| v2.53 대비 동일 인자 산출물 diff | `_meta`(버전 문자열) · `pawpad-config`(bundles) · `config.json`(포인터) · 신규 매니페스트 **4건뿐** |
| `full/lean` Claude 산출물 | `full/full`과 **42파일 바이트 동일** |
| `.agents/skills` 개수 == `config.json` `skills[]` | 12 == 12 |
| dangling | `AGENTS.md`·`config.json`에서 Codex 제외 스킬명 **0** / `CLAUDE.md`에서 Claude 제외 스킬명 **0** |
| `-Upgrade` 인자 없음 + 기록 `codex:lean` | Codex 12 유지 (full 복원 안 됨) |
| 자체 `-Upgrade` | 83항목 **0 failed**, 미러 22/22, `.claude/skills` 내용 변화 0 |
| `tests/codex-delegation` | **46/46** (신규 22) |
| 기존 config 형태별 방어 | `{}` · 한 줄 압축 · 중첩 객체 → 전부 유효 JSON 유지 + 사용자 속성 보존, 0 failed / 비-JSON → **1 failed로 집계**(성공 위장 없음) |
| lean 라운드트립 | 빈 배열 기록 → 인자 없는 `-Upgrade`에서 12/12 유지 |

### 관측 (수정 안 함)

`-Preset lean` 계열에서 `AGENTS.md`의 한 줄이 문법적으로 깨진다 —
"기본은 Claude 미러, ~~`code-delegate`는~~ 는 Codex 전용 실행 절차를 사용한다."
backtick 스트립 정규식이 이름만 지우고 조사를 남긴 것으로, **v2.39부터의 기존 동작**이다.
이번 변경으로 새로 생긴 것이 아니며, 트림 정규식을 건드리면 기존 lean 설치의 출력이 같이 바뀌므로
별건으로 분리했다.
