# PawPad 버전별 업데이트 (v2.18 → v2.41)

| 버전 | 날짜 | 핵심 변경 | 주요 영향 요소 |
|------|------|----------|--------------|
| v2.18 | 2026-06-04 | Codex native adapter | `.agents/skills` 미러, `.codex/config.toml`·`hooks.json`, repo skill mirror |
| v2.19 | 2026-06-04 | Claude hook 확장 + 토글 | UserPromptSubmit/PreCompact hook, pawpad-config 토글, caveman/lean-code 참조 강등, statusline UTF-8 stdin fix |
| v2.20 | 2026-06-09~10 | 통합 단일 배포본 | 양 런타임 hook(SessionStart/UserPromptSubmit/PreCompact/Stop+statusLine), `.ctxdb` 키워드 DB, codebase-map 7축, 단일 `pawpad-setup.ps1` |
| v2.21 | 2026-06-11 | security-check 게이트 | security-check 스킬(DoD#8, 🔴=완료 BLOCK), -Upgrade 설치 모드(데이터 보존), 전역 Codex 섀도잉 경고 |
| v2.22 | 2026-06-11 | KMS 코드명 제거 | `.claude/pawpad/`, `pawpad-config.json`, codemap `pawpad:` 접두 (ADR-002, -Upgrade 자동 마이그레이션) |
| v2.23 | 2026-06-11 | 설치 UI | paw 배너 + 28단계 실시간 진행 바 + 실측 체크리스트 |
| v2.24 | 2026-06-12 | 설치 UI live 모드 | 진행 바 1줄 제자리 갱신, 파일 로그 숨김(`-ShowLog` 복원), 배너 보정 |
| v2.25 | 2026-06-12 | lean-code rename | 스킬 karpathy→lean-code(인물명 제거), -Upgrade 구 섹션명 자동 마이그레이션 |
| v2.26 | 2026-06-13 | feature-architecture | feature-architecture 스킬, CLAUDE/AGENTS Architecture Principles(코어4+DoD#9), lean-code와 소유권 분리 |
| v2.27 | 2026-06-14 | Idea→PRD Routing + Active Skills | 아이디어→PRD 스킬 추천 라우팅, 매 응답 Active Skills 라인, doc/스킬 군살 제거 |
| v2.28 | 2026-06-16 | mockup 스킬 + 자동제안 | mockup 스킬(PRD-tree→단일 HTML lo/hi-fi, Feature ID drift), 단계경계 자동제안, 선택지=체크박스 |
| v2.29 | 2026-06-16 | review 스킬 | review 스킬(문서형 크로스에이전트 리뷰 라운드트립), state 2종(REVIEW_REQUESTED/DONE) |
| v2.30 | 2026-06-17 | Verification Evidence 분리 | lane 검증근거 최근 2건 cap, 초과분 `verifications/{id}-archive.md`, HYBRID 섹션 신설 |
| v2.31 | 2026-06-17 | 문서/lane 토큰 sharding | ① PRD Area-Sharding(`src/prd/{area}.md`+PRD-tree 인덱스+feature-id 라우팅) ② Completed Task Log(완료항목 tasklog 이월) |
| v2.32 | 2026-06-18 | clarity 접근법 게이트 | clarity PASS 후 2-3 접근법(트레이드오프+추천 1개 필수)→선택→구현계획, 자명 단일 생략 (brainstorming 메커니즘 이식) |
| v2.33 | 2026-06-18 | code-delegate 스킬 | code-delegate 스킬(18→19): 코딩 단계 사용자 선택 모델 서브에이전트 위임(설계=Opus/코딩=하위 모델), 부모 컨텍스트·토큰 절감, 자동제안 구현 진입 경계 |
| v2.34 | 2026-06-19 | skill rename memory→resume | `memory`→`resume`("기억저장" 오해→세션재개 ON START 동작 직결), `/memory` 하드제거, -Upgrade 구 dir 자동 마이그레이션(ADR-002), 스킬 19 불변 |
| v2.35 | 2026-06-19 | resume 최소로드 | ON START 토큰 절감: ① HYBRID 조건부화(resume↔CLAUDE/AGENTS 정합, 솔로 ~5.8k) ② _meta RECENT skip(_meta 재정렬 헤더→BLOCKED→NEXT→RECENT 하단+상단만 부분읽기, ~5.5k). 기능·스킬 19 불변 |
| v2.36 | 2026-06-23 | 통합 기획 뷰어 (데이터-구동, 4탭) | 4탭(PRD/기능명세서/메뉴구성도/와이어프레임) 통합 뷰어. 범용 `spec-viewer.html`(데이터 비종속, File System Access API)가 고정명 외부 JSON(`src/viewer/{prd,fts,userflow,wire}.json`)을 폴더 1회 선택 후 자동 로드·편집·제자리 저장(다운로드·백엔드 X)·재로드. 폴더 핸들 IndexedDB 기억→`↻ 다시 열기` 1클릭(임의경로 자동열기 보안상 불가). PRD/명세 변경=agent가 JSON만 수정(HTML 불변→토큰↓). 항목 존재=설계/개발 대상(승인 단계 없음), status 예정/진행중/완료(agent 갱신·읽기전용). src/viewer/*.json ON START/resume 자동로드 금지. 신규 스킬 viewer-apply(19→20, JSON→스팩 동기)+mockup viewer 모드. 렌더: 기능명세서=CSS 트리, 메뉴구성도=계층 트리+드래그앤드랍(순서·뎁스 재배치+뎁스색), 와이어프레임=디바이스 프레임(mobile/web)+컴포넌트 lo-fi |
| v2.37 | 2026-06-23 | grill-with-docs → grill-me 흡수 (스킬 20→19) | 죽은 중복 스킬 제거. grill-with-docs 고유가치 중 순수 인터뷰 품질만 grill-me에 흡수: 모호 용어→canonical 좁힘, 엣지케이스 시나리오 stress-test, 진술 vs 코드 모순 표면화, 탐색 시 기존 문서 확인. 미사용 `CONTEXT.md` 용어집·Decision Placement Matrix와 중복인 ADR offering은 DROP. 표면: grill-me live+embed+.agents 미러 보강 / grill-with-docs live+미러 dir 제거 / SKILLS_MANIFEST·config.json·CLAUDE/AGENTS 자동제안목록 정리 / README·GUIDE·USAGE 스킬 카운트 20→19 / -Upgrade 구 dir+config 자동 정리(ADR-002 선례) |
| v2.38 | 2026-06-25 | codemap ON START 부분읽기 | 코드세션 ON START codemap read 토큰 절감(~7k→~0.5k). MAP+HOT(조망)만 read, INDEX(전체 심볼표)는 심볼 필요 시 Grep on-demand. HOT를 spec(최근 3~5개·1줄)대로 정리(28→5, HOT-only 심볼 INDEX 강등·무손실; `_index.md` 25.8k→18.8k 총파일, INDEX는 grep-on-demand 미로드). ON START 절감 3종(_meta·HYBRID·codemap) 완성. 표면: Session Protocol step7(CLAUDE/AGENTS live+setup $tmpl 2) / codemap SKILL ON START 규칙(live+.agents 미러+setup embed) / _index.md HOT 트림 / README·GUIDE·USAGE·PAWPAD_VERSIONS·CHANGELOG. 동작·스킬 19 불변 |

| v2.39 | 2026-06-26 | 번들 선택 설치 + 안내 언어 i18n | 설치 시 스킬 번들 선택(`-Preset lean\|standard\|full` / `-Bundles prd,ui,delegate,review`, prune-at-end). Core 11 고정 + Optional 4 번들(prd/ui/delegate/review, ui·delegate→prd 하드의존 자동포함). 미선택 시 스킬 dir + `config.json`/`SKILLS_MANIFEST` + CLAUDE/AGENTS/HYBRID 본문 참조까지 dangling 0 정리. 안내 메시지 언어 `-Lang en\|ko`($TR 테이블, 사람 안내만 — 스킬/에이전트 문서는 단일 소스 무변경). 스킬 내용·19 불변(가드는 install-time 1줄) |
| v2.40 | 2026-06-30 | codemap trim-router (small-page) | codemap 성장전략 flat→trim-router: 대규모(50KB+) `_index.md`를 `_root.md`(route)+`keywords.md`(한국어→feature)+`features/{id}.md`(source pointer)로 분할, cap root 2KB·그외 4KB. generated(`*.g.dart`/`*.freezed.dart`/`lib/generated`) source pointer 제외, lookup 알고리즘(최대 3 read)+1줄규율. **domain 중간층 제외**(leaf 중복·3중쓰기 drift 회피 = trim). 통째읽기 사고 ~14k→~1k 봉쇄·grep 성능 불변(다운사이드 0). account-link pilot 검증(size PASS·lookup 2/2·non-circular). codemap SKILL(live+`.agents` 미러+setup embed) 동기, 스킬 19 불변. **v2.40 내 보강(2026-07-01~02, 버전 불변·v2.25 BOM-fix 선례)**: ① analyze hook 2단계 fix — settings.json raw PowerShell 파이프라인이 Git Bash 디스패치와 충돌 → 다른 훅과 동일 `-File` 스크립트(`analyze.ps1`/`analyze.sh` 신규)로 통일 + PostToolUse는 exit 2의 stderr만 agent에 전달하므로 진단 결과 stderr 재전송·exit 2/0 정규화(설계 이래 미동작이던 Edit 직후 진단 피드백 최초 활성화, 기존 설치는 `-Upgrade` 필요). Unix `analyze.sh`는 파이프 exit 소실 버그(`$?`=tail exit) 발견 → `set -o pipefail`+그룹 리다이렉트로 보정. ② codemap lookup 의미매칭 명시 — 자연어 키워드는 keywords.md를 grep 정확매칭이 아닌 **통째 read 후 의미·맥락 매칭**(표현/공백 흔들림 강건, lookup miss→전체 소스 스캔 토큰 폭증 방지). 상세: docs/CHANGELOG_v2.40.md Addendum |
| v2.41 | 2026-07-02 | retrieval-source 표시 (A 선언식 + B 계측식) | agent가 코드를 codemap/ctxdb로 찾았는지 소스 전체를 뒤졌는지 가시화(Sonnet 5 "codemap 미경유 전체 스캔→토큰 2~3배" 관측 대응). **A 선언식**: CLAUDE/AGENTS Response Style `### Retrieval 표시` — 탐색 수행 응답 상단 `📡 Retrieval: codemap {hit\|miss\|미사용} \| ctxdb {…} \| src {read N\|full-scan N (사유)}` 1줄, 소스 탐색 전 codemap lookup 의무+full-scan 사유 선언(codemap-first 행동 유도). **B 계측식**(Claude 전용): 신규 `read-track` 훅(`PostToolUse: Read\|Grep\|Glob`)이 read 경로를 cmap/ctx/src 분류→`.ctxdb/.state/claude-read-stats` 누적(toolkit 내부 미집계, SessionStart reset)→statusline `📡 cmap N ctx N src N` 실측(자기보고와 달리 위조 불가). settings.json PostToolUse=read-track(항상)+analyze(스택 조건부). 기존 설치 `-Upgrade`, 스킬 19 불변 |

# 누적 현황 (현재 v2.41)

| 항목 | 수치 |
|------|------|
| 스킬 | 19개 |
| 런타임 | Claude Code + Codex (단일 배포본) |
| hook | 양 런타임 5종 (SessionStart/UserPromptSubmit/PreCompact/Stop/statusLine) + Claude PostToolUse(read-track 항상·analyze 스택 조건부) |
| DoD 게이트 | 9개 (security-check #8, feature-architecture #9 포함) |
| 컨텍스트 DB | `.ctxdb` 키워드 depth 로딩 (INDEX→L1→L2) |
| 코드 맵 | codemap(심볼 레지스트리, size-aware: flat→trim-router) + codebase-map(7축 고수준) |
