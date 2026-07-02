# CHANGELOG v2.41 — retrieval-source 표시 (A 선언식 + B 계측식)

날짜: 2026-07-02 | 기반: v2.40 (+ v2.40 내 보강: analyze hook fix·codemap 의미매칭) | 스킬 19 불변

## 배경
다운스트림(TodayQuest, Claude Code v2.1.198 + Sonnet 5)에서 "작은 기능 수정인데 context 급증 + 토큰 소모 평소(Opus) 대비 2~3배" 리포트. 사후 질문 결과 agent가 **codemap을 경유하지 않고 소스 전체를 뒤져서** 대상을 찾았다고 답변. v2.40 보강(codemap 의미매칭 명시)이 원인 측 대응이라면, v2.41은 **관측 측 대응** — "어떻게 찾았는지"를 응답과 statusline에 상시 가시화해 이탈을 즉시 발견한다.

## A. 선언식 — 응답 내 Retrieval 라인 (Claude + Codex 공용)
CLAUDE.md/AGENTS.md `## Response Style`에 `### Retrieval 표시` 하위섹션 추가 (Merge-MdToolkitSections 앵커인 `##` 섹션 제목은 불변 — 섹션 내부 추가라 `-Upgrade` 병합 안전):
- 형식: `📡 Retrieval: codemap {hit(경로)|miss|미사용} | ctxdb {hit(파일)|miss|미사용} | src {read N (codemap 경유)|full-scan N (사유)}` — 탐색 수행 응답만, Active Skills 라인 아래.
- 규율: 소스 탐색 전 codemap lookup 의무. miss여도 곧장 full-scan 금지(keywords/INDEX 의미매칭 재시도), 그래도 miss면 **사유와 함께 full-scan 선언**.
- 효과: Active Skills 라인과 동일 메커니즘 — 매 탐색마다 선언 의무 자체가 codemap-first 행동을 유도. 자기보고 한계는 B가 보완.
- CLAUDE.md 버전에만 "허위 선언 금지: statusline 실측 카운터와 대조" 문구 포함(Codex는 statusline 없음).

## B. 계측식 — read-track 훅 + statusline 카운터 (Claude Code 전용)
- 신규 훅 `.claude/hooks/read-track.ps1`/`.sh` — settings.json `PostToolUse` matcher `Read|Grep|Glob`(항상 설치, 스택 무관). stdin JSON의 `tool_input.file_path`(Read)/`tool_input.path`(Grep/Glob)를 분류:
  - `.claude/codemap/` → `cmap` / `.ctxdb/` → `ctx` / 그 외 `.claude`·`.agents`·`.codex` → **미집계**(toolkit 내부 read는 잡음) / 나머지 → `src`
  - `.ctxdb/.state/claude-read-stats`에 1줄 append (ascii). **관측 전용: 항상 exit 0** (exit 2 금지 — agent 피드백 없음).
- `session-start.ps1`/`.sh`: 세션 시작 시 카운터 파일 reset.
- `statusline.ps1`/`.sh`: 집계해 `ctx N% (Nk/1M) | Model | 📡 cmap N ctx N src N` append (0건이면 생략, `.sh`는 기존 jq-gate 하위). **src 폭증 = 전체 스캔 신호**를 실시간 관측 — 자기보고와 달리 위조 불가.
- settings.json 템플릿: `PostToolUse` 상시화 — read-track entry(항상) + analyze entry(스택 조건부, v2.40 보강분).
- 한계(명시): `ctx` 카운트는 agent가 **직접 read**한 것 기준 — UserPromptSubmit 훅이 자동 주입하는 L1/L2 로드는 미포함(주입은 이미 📂 라인으로 가시화됨). Codex는 PostToolUse 훅이 없어 계측 미지원(A 선언만).

## 표면
- `pawpad-setup.ps1`: $ver 2.41 / line1·STATUS / $tmplClaudeMd·$tmplAgentsMd(Retrieval 하위섹션, 이중 backtick 임베드) / settings.json 하드빌드(PostToolUse 재구성) / read-track.ps1·.sh 임베드 신규 / session-start·statusline ps1·sh 임베드 수정 / 완료요약 ko·en
- live: CLAUDE.md·AGENTS.md·.claude/settings.json·hooks 4파일 수정 + read-track 2파일 신규
- docs: README·GUIDE(이력 entry)·USAGE(bullet)·PAWPAD_VERSIONS(행+누적) / 본 보고서

## 검증 (2026-07-02, PowerShell+Bash — EDR-safe)
- setup PSParser 0 errors.
- read-track.ps1 실호출(5 시나리오 stdin JSON): src/cmap/ctx 분류 + toolkit 내부 미집계 + Glob pattern-only→src — 카운터 파일 4줄 정확.
- read-track.sh 동일 4 시나리오 bash 실호출: 분류 일치.
- statusline.ps1 실호출: `ctx 12% (120k/1M) | Fable 5 | 📡 cmap 1 ctx 1 src 2` 정확. statusline.sh 집계 블록 단독 검증(이 머신 jq 부재로 전체 스크립트는 기존 폴백 경로) — 동일 출력 + 빈 파일 시 📡 생략 확인.
- session-start.ps1/.sh 실호출: claude-read-stats 0 byte reset 확인.
- settings.json 하드빌드 시뮬레이션: analyze 有(node)=PostToolUse 2 entry / 無(generic)=1 entry, 양쪽 ConvertFrom-Json 파싱 OK.
- 미실행: 다운스트림 실세션 E2E(이 머신 org 정책 hooks 차단 — 배포 대상 머신에서 확인 필요), codex exec 크로스 리뷰(EDR 차단 → Claude 서브에이전트 리뷰로 대체).

## 리뷰 (Claude 서브에이전트 fresh-eyes, 2026-07-02)
**PASS_WITH_FIXES 90%** — 체크리스트 17항목 전부 ✅ (요약: .claude/pawpad/reviews/v241-retrieval-indicator-review-01.md). 반영:
- **Med-1(반영)**: 분류 패턴이 트레일링 `/` 요구 → 디렉토리 자체 경로(`path=.claude/codemap` 등 Grep on-demand의 전형) 오분류(cmap 언더카운트·ctx→src 오탐). 수정: PS `(/|$)` 경계, bash `target="/$target/"` 정규화. 실호출 재검증 — dir 경로 cmap/ctx 정타, `myproject.claude`·`src/.claudetest` 오탐 없음(ps1+sh 동일).
- **Low-1(반영)**: bash substring 매칭이 PS와 divergence(`myproject.claude/codemap/` 오탐) — 위 정규화로 함께 해소.
- **Low-2(기록만)**: Add-Content 병렬 충돌 시 무음 소실 가능 — 관측 전용·근사치 목적이라 수용(bash `>>`는 O_APPEND).
