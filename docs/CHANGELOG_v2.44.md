# CHANGELOG v2.44 — 외부 문서 구현 진입 게이트 + 선택지 체크박스 전면화 + 데스크탑 스택 4종

날짜: 2026-07-14
기반: v2.43 (task-done 종결 게이트 3종)
스킬 수: 20 (불변)

## Summary

사용자 실관측 사고 2건 + 설치 프리셋 요구 1건 대응.

1. **외부 문서 구현 진입 게이트** — md/spec 개발 문서를 첨부하고 "이 문서를 참조해서 구현해줘"라고 하면, agent가 phase 분해·task 저장까지는 수행하면서 clarity(모호도 체크)/design/code-delegate 게이트는 발화하지 않고 곧장 코딩으로 진행하던 사고. 원인은 지침 사각지대 3곳: ① `Idea → PRD Routing` 트리거가 "아이디어→PRD 구체화"로 한정되어 이미 문서가 있는 요청은 라우팅 스코프 밖 ② code-delegate 자동제안 조건 "written 설계"가 pawpad specs 파일을 암시해 외부 첨부 문서는 판정 회색지대 ③ "매 응답 판단 X(과추천 방지)" 억제 편향이 회색지대에서 침묵으로 작동. → 외부 문서 진입 경로를 명시 정의.
2. **선택지 체크박스 전면화** — 선택지 질문 규칙이 기획/설계 스킬 6종 "진행 중"으로 한정되어, 스킬이 발화하지 않으면(1번 사고) 체크박스 규칙도 같이 죽던 문제. → 스킬 무관 전면 확장 + 추천 표시 + 자유 입력 보장 명시.
3. **데스크탑 스택 프리셋 4종** — PC 데스크탑 애플리케이션 프로젝트용 `-Stack` 프리셋 부재. → wpf/tauri/electron/avalonia 추가.

## Added

- **CLAUDE.md / AGENTS.md `### 외부 문서 구현 진입 게이트`** (Idea → PRD Routing 하위, live + `$tmplClaudeMd`/`$tmplAgentsMd` 임베드):
  - 외부 문서(첨부 md/spec/기획서 경로) 참조 구현 요청 시 — 문서 존재 ≠ 게이트 통과.
  - ① clarity 채점 **의무**: 코딩 시작 전 문서 기준 모호도 블록 1회 출력. PASS(≤임계값)면 질문 없이 바로 진행(마찰 최소), BLOCK이면 재질문 라운드.
  - ② UI/화면 포함 시 design 1회 추천. ③ 코딩 진입 시 code-delegate 1회 권장.
  - phase 분해·task 저장만으로 게이트 건너뛰기 금지.
- **clarity SKILL `## 외부 문서 모드`** (live + 임베드 + `.agents` 미러): 자동 발동 트리거, 채점 대상 = 문서 + 대화 보충(문서 명시 정보는 명확 인정), 블록 출력 의무·재질문 조건부, phase 분해 후에도 채점 유지.
- **setup `-Stack` 데스크탑 프리셋 4종** (`$profiles` + `$validStacks` + TR ko/en `stackOpts` + 대화형 switch 1~8):
  - `wpf` — WPF (.NET 8) + MVVM. dotnet Commands, code-behind 로직 금지·CommunityToolkit.Mvvm·ResourceDictionary 컨벤션, ADR(MVVM/DI).
  - `tauri` — Tauri 2 (Rust + Web Frontend). tauri dev/build Commands, IPC 커맨드 집중·capabilities 최소 권한 컨벤션, ADR(셸 선택/IPC 경계).
  - `electron` — Electron + TypeScript. main/preload/renderer 3분할, contextIsolation true·nodeIntegration false·contextBridge 화이트리스트 보안 컨벤션, ADR(프로세스 경계/electron-builder).
  - `avalonia` — Avalonia UI (.NET 8) + MVVM. 크로스플랫폼 XAML, MVVM 라이브러리 단일화 컨벤션, ADR(크로스플랫폼/MVVM 단일화).

## Changed

- **CLAUDE.md / AGENTS.md `### 선택지 질문 = 체크박스`** (live + 임베드): 스코프 "기획/설계 스킬 진행 중" → **스킬 진행 여부 무관 전면**. 추천 1개 첫 옵션 + 라벨 끝 "(추천)" + description 근거. 선택지 밖 답은 도구 기본 제공 "Other" 자유 입력 — 선택지 생략·산문 질문 대체 금지.
- **CLAUDE.md / AGENTS.md 코딩 위임 제안**: "written 설계" → "written 설계(외부 첨부/참조 문서 포함)".
- **code-delegate SKILL 위임 적합성 게이트 1** (live + 임베드 + 미러): 외부 참조 문서를 written 설계로 인정, 문서 경로 포인터 전달.
- setup usage 주석·헤더 Stack 프리셋 목록·완료 요약(ko/en)·`unknownStack` 대상 목록 8종 반영.
- README stale 보정: `.codex/config.json` skills 배열 카운트 19 → 20 (v2.43 릴리스 잔재 2곳, task-done 추가분 미반영이던 표기).

## Verification

- `PSParser::Tokenize` parse-ok (0 errors).
- `-Stack` smoke: `$validStacks` 8종, 대화형 switch `^(4|wpf)$`~`^(7|avalonia)$` 매핑, default=generic 유지.
- `.agents/skills/{clarity,code-delegate}/SKILL.md` 미러: setup writer 로직(frontmatter + `# DO NOT EDIT` 헤더 + body + CRLF) 그대로 재생성, EOF `0d0a 0d0a` 확인.
- 임베드 델리미터 사전 grep 확인: `$tmplClaudeMd`/`$tmplAgentsMd`/clarity = expandable `@"..."@`(신규 텍스트 backtick·`$` 무포함으로 무이스케이프), code-delegate = literal `@'...'@`.
- stale grep: README/GUIDE/USAGE의 `v2.43` 표기 전수 → v2.44 (이력 항목 제외), USAGE 상세 보고서 링크 v2.41 stale → v2.44 보정.
- **Codex 행동 smoke (E2E)**: full 설치 샌드박스에서 `codex exec`로 "docs/login-feature-spec.md 참조해서 구현해줘" 실행 → AGENTS.md 신규 게이트 발화 확인: `🐾 Active Skills: clarity r1/5 | design`, 모호도 블록 68/100 **BLOCK**(기준 30) 출력 + 재질문 3건 — 코딩 직행 없이 게이트 정지. 재질문은 번호 목록(Codex엔 AskUserQuestion 도구 없음 → 텍스트 선택지 폴백, 기존 동작과 동일).
- **Claude Code 행동 smoke (E2E)**: 동일 샌드박스에서 `claude -p` headless 실행 → "외부 문서 구현 진입 게이트 발동" 명시 선언 + clarity 외부 문서 모드 채점 **67/100 BLOCK** + 5차원 표·재질문 3건(차원 태깅) + PASS 이후 예정 절차로 design 추천·lane 생성·code-delegate 권장을 정확히 예고 — 게이트 3항 전부 인지. 양 런타임 채점 유사(67 vs 68) = 채점 기준 일관.

## Review (codex exec, review-01)

- 판정: PASS_WITH_FIXES 92% (High 0 / Med 1 / Low 1) — `.claude/pawpad/reviews/v244-review-result-01.md`
- Med-1 반영: bundle prune이 신규 게이트의 optional 스킬 참조를 정리하지 않던 결함 — step 4에 게이트 clause 제거 규칙 추가(design→clause 2/②, code-delegate→clause 3/③) + clarity SKILL 후속 추천 문구를 스킬 이름 비종속으로 재작성("설치된 스킬만 추천"). **선재 잠복 결함 동시 봉합**: `` `/review` ``·`` `/code-delegate` `` 코드스팬이 backtick-strip 패턴(`` `skill`` 접두)과 불일치해 prd-only 조합서 리뷰 제안/코딩 위임 bullet이 dangling — 해당 bullet 라인·압축 clause 제거 규칙 추가(v2.39는 lean/standard만 smoke해 미노출).
- Low-2 반영: bundle 주석 `Core 11` → `Core 12` (v2.43 task-done 추가분).
- 반영 후 회귀: lean/prd-only/standard/full 4조합 fresh install — FAILED 0, 스킬 수 12/15/17/20 정합, 미설치 스킬 이름 dangling 0 (동사 "review/trust" 제외), PSParser 0.

## 사후수정 #1 (2026-07-14, 버전 불변) — 종결 기록 4벌 → 2벌 + 표시 계층 점검

배경: 세션 종결 시 같은 사실이 4곳(L2 세션 블록 / INDEX AGENT SYNC 상태 셀 / _meta RECENT / sessions 이월)에 기록되고, 그중 가장 뚱뚱한 사본(INDEX 상태 셀 = L2 거의 전문 복제)이 가장 비싼 자리(매 세션 무조건 hook 주입)에 있던 구조 개선.

- **context-saver SKILL STEP 3** (live + 임베드 + 미러): INDEX 상태 셀 = 헤드라인 1줄(150자 이내: 버전/기능 + 결과 1구 + 잔여 유무 + "상세 -> L2 {블록명}" 포인터). L2 세션 블록 전문 복제 금지 — 상세는 on-demand 자리(L2)에 1벌만(SoT 1곳, drift 방지, 주입 토큰 절감).
- **task-done SKILL 체크리스트 4항** (live + 임베드 + 미러): _meta RECENT 1줄 = 2문장 이내 + 커밋 해시(타임라인 전용, 상세는 L2/lane).
- 재개 정보 손실 없음 근거: BLOCKED/NEXT는 _meta 상단(ON START 상시 read), 헤드라인은 INDEX(상시 주입), 상세는 L2 1홉 read. hook/계측 코드 무변경 — 오탐/차단 회귀 가능성 0.
- **statusline 점검 (수정 없음, 정상 판정)**: ①`codemap 100% · routed 1 / full-scan 0` = hit 선언 1건/전체 선언 1건 → 100%. 산식 routed/(routed+full-scan)이라 100% 초과 불가, 표본 크기는 routed/full-scan 카운트로 병기 노출. `미사용` 선언은 분모 제외(v2.42 설계). 상태 파일 실측으로 화면 값 재현 확인. ②📡 세그먼트 간헐 표시 = session-start가 매 세션 stats 0-byte 리셋 + (선언 분모+src)=0이면 세그먼트 숨김 → 세션 초반·순수 문답 세션엔 안 뜨는 게 설계 의도. run-hook.ps1 Push-Location으로 cwd 문제 없음. ③🐾 Active Skills 라인 간헐 = hook 아닌 모델 지침 준수 문제 — 표시용 라인에 Stop hook 강제를 얹는 것은 비채택(v2.43 교훈: block 비용 > 표시 이득, 오탐 시 강제력화).

## 사후수정 #2 (2026-07-15, 버전 불변) — codemap 활용률 응답 단위 통일

배경: `codemap 100% · routed 2 / full-scan 0 · src 9`가 제작자도 오독하는 표기 — ①선언(응답 단위)과 실측(read 단위)이 한 줄에 섞여 "src 중 몇이 경유?"로 읽힘 ②분모가 선언뿐이라 미선언 풀스캔 턴이 빠져 100%가 과대 신호 ③분모 1~2에서 0/100% 스윙. 사용자 AskUserQuestion "응답 단위 통일안" 채택.

- **stop-check.ps1/.sh `cmap:direct` 계수**: 응답이 codemap hit/miss 선언 없이 src 2건 이상 읽음(read-track 실측) = '직행'으로 `claude-retrieval-stats`에 계수. src 1건 면제(백스톱 동일 — 이미 아는 파일 재편집). `미사용` 선언도 hit/miss 아님 → 직행(B3 일관). **순수 계측 — block/캡 로직 무변경**, dedupe 별도 파일(`claude-direct-seen`, uuid 고유라 세션 reset 불요).
- **statusline.ps1/.sh 렌더**: `📡 codemap 활용 N% (경유 X · 직행 Y) · 소스 읽기 N` — 활용률 = hit ÷ (hit+miss+direct), 미선언 사각으로 인한 100% 뻥튀기 제거. **분모 3 미만은 % 숨기고 건수만**(소표본 스윙 방지). 분모 0 시 `codemap 미선언`(노랑) 라벨 폐기 → dim `codemap –` (미선언 풀스캔은 이제 direct로 분모에 들어가므로 라벨 불요, 턴 중간 과도상태에 노랑 경고가 뜨던 노이즈 제거).
- CLAUDE.md/AGENTS.md Retrieval 표시 절 statusline 설명 문구 갱신 (live + 임베드 2곳).
- 검증: PSParser 0 · bash -n OK · secret-scan clean. **ps1 E2E 4/4**(미선언+src3→direct / 재실행 dedupe / hit 선언→hit만 / `미사용`+src3→direct) · **sh E2E 4/4 동일**(jq 1.7.1 scratchpad 확보) · statusline 렌더 ps1 4/4·sh 3/3(활용 67%/소표본 건수만/`codemap –`/저활용 25% 빨강 경로). **부수 해소: v2.43 잔여 NEXT "stop-check.sh jq 앵커 E2E" — 실 jq로 hit 정파싱·미사용 비계수 확인 완료.**
- 알려진 한계(문서화): retrieval 백스톱 block 후 교정 응답이 선언하면 원 응답(direct)+교정 응답(hit)이 각 1건씩 집계 — 논리적 한 턴이 분모 2가 될 수 있음. 원 응답의 미선언 행동 자체는 사실이므로 수용.

## Notes

- 표면(수정 파일): CLAUDE.md·AGENTS.md(live), `.claude/skills/{clarity,code-delegate}/SKILL.md`, `.agents/skills/{clarity,code-delegate}/SKILL.md`(재생성), `pawpad-setup.ps1`(임베드 4곳 + Stack 5면 + 헤더/`$ver`/완료요약), README.md, GUIDE.md, USAGE.md, PAWPAD_VERSIONS.md, docs/CHANGELOG_v2.44.md.
- clarity 게이트 강도 "채점 의무(PASS=무질문 통과)"·데스크탑 4종 전체 추가·live+배포본 동시 적용은 사용자 AskUserQuestion 선택(2026-07-14).
- 기존 설치는 `-Upgrade` 재실행으로 반영.
