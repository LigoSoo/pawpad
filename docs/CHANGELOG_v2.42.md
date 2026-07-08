# CHANGELOG v2.42 — retrieval 계측 시각화 (색상 + route% + hit%)

날짜: 2026-07-08 | 기반: v2.41 (retrieval-source 표시 A 선언식 + B 계측식) | 스킬 19 불변

## 배경
v2.41이 statusline에 `📡 cmap N ctx N src N` **원시 카운터**를 노출했으나, 사용자가 "PawPad 코어(codemap/ctxdb 라우팅)가 실제로 동작하는지 한눈에 보고 싶다"고 요청. 원시 숫자만으론 라우팅 활성/이탈·히트율이 즉시 안 읽힘. v2.42는 동일 계측 위에 **시각 신호(색상) + 파생 지표(route%, hit%)** 를 얹어 코어 동작을 대시보드화한다. **statusline은 UI 렌더라 모델 컨텍스트에 안 들어감 → 전부 모델 토큰 0.**

## 추가 지표
1. **색상** — 라우팅 활성(`cmap|ctx > 0`)=초록 / 소스직행(`src`만, `cmap==ctx==0`)=노랑 경고. 코드맵 미경유 full-scan을 색으로 즉시 포착.
2. **route%** = `(cmap+ctx)/(cmap+ctx+src)` — 탐색이 라우팅 계층을 얼마나 경유했는지. 초록≥50 / 노랑≥25 / 빨강<25. (프록시 지표: src-heavy가 항상 나쁜 건 아님 — 코드맵 hit 후 타깃 다독은 정상. 색은 참고용.)
3. **hit%** — codemap·ctxdb **선언 hit/miss율**. 원시 read 카운터로는 hit/miss(코드맵에 심볼이 있었나)를 알 수 없으므로, agent가 이미 매 응답 출력하는 `📡 Retrieval:` 선언을 **stop-check 훅이 파싱**해 누적. 초록≥70 / 노랑≥40 / 빨강<40. `미사용` 턴은 분모 제외.

표시 예: `ctx 12% (24k/200k) | Opus 4.8 | 📡 cmap 2 ctx 1 src 4 route 43% hit c 67%(2/3) x 100%(1/1)`

## 계측 방식 — stop-check가 응답 Retrieval 라인 파싱 (SoT, 모델 토큰 0)
- `stop-check.ps1`/`.sh`: Stop 훅이 `transcript_path`에서 **방금 완료된 assistant 메시지**를 읽어 `📡 Retrieval:` 라인 추출 → `|` 기준 **고정 순서 위치 분해**(seg0=codemap / seg1=ctxdb / seg2=src)로 codemap·ctxdb 세그먼트의 `hit`/`miss` 판정 → `.ctxdb/.state/claude-retrieval-stats`에 `cmap:hit|cmap:miss|ctx:hit|ctx:miss` append. (위치 분해 이유는 리뷰 섹션 참조.)
- **uuid dedupe**: `claude-retrieval-seen`에 마지막 처리 assistant uuid 저장 → 여러 Stop 재진입(decision:block 등)에도 동일 응답 재계수 방지.
- **미사용 미기록**: `미사용`/선언 없음은 hit율 분모에서 제외(탐색 없는 순수 문답이 hit율을 왜곡하지 않음).
- bash 포트는 `jq` 필요 — 없으면 graceful skip(계측만 누락, 훅 본 기능 정상).
- `statusline.ps1`/`.sh`: 위 파일 집계 + `claude-read-stats` 집계를 색상 ANSI로 렌더.
- `session-start.ps1`/`.sh`: 세션 시작 시 `claude-retrieval-stats`·`claude-retrieval-seen` reset(기존 `claude-read-stats` reset과 동렬).

## 표면
- `pawpad-setup.ps1`: $ver 2.42 / line1·STATUS(+이전 v2.41 강등) / 임베디드 템플릿 6개 수정(statusline·stop-check·session-start × ps1·sh) / 완료요약 ko·en
- live: `.claude/hooks/` statusline·stop-check·session-start ps1·sh 6파일 수정
- docs: README(4행) / 본 보고서
- 신규 state 파일: `.ctxdb/.state/claude-retrieval-stats`·`claude-retrieval-seen`(런타임, .gitignore 대상)

## 검증 (2026-07-08, PowerShell+Bash)
- setup PSParser 0 errors.
- **sandbox 설치 후 emitted==live 6/6 byte-match** (Compare-Object diff 0), 설치 exit 0.
- statusline.ps1 실호출(mock stdin+state): `📡 cmap 2 ctx 1 src 4 route 43% hit c 67%(2/3) x 100%(1/1)` — 색상 ANSI 정확(라우팅=초록, route 43%=노랑, hit c 67%=노랑, x 100%=초록).
- statusline.sh 색/route/hit 블록 단독 실호출: src-only→노랑 triplet, route 0%→빨강, hit 25%→빨강 정확(이 머신 jq 부재로 전체 스크립트는 기존 폴백).
- stop-check.ps1 실호출(mock transcript): 표준 라우팅 라인(codemap hit + src "(codemap 경유)")·xseg 오염 케이스(codemap 경로에 'ctxdb' 포함) 양쪽 `cmap:hit`/`ctx:miss` 정확. **재실행 시 dedupe로 무중복 확인**.
- bash 세그먼트 분해 로직 standalone 실호출: 위치 분해가 greedy-sed 버그(아래 리뷰 🔴) 해소 확인. bash -n: statusline·stop-check·session-start·read-track .sh 4파일 전부 OK.
- 미실행: 다운스트림 실세션 E2E(배포 대상 머신 확인 필요), 이 머신 jq 부재로 bash stop-check **전체 스크립트** E2E는 미실행(세그먼트 로직만 격리 검증).

## 한계 (명시)
- hit%는 **agent 자기선언 기반** — 허위선언은 v2.41의 `cmap` 실측 카운터와 대조돼 억제되나, 선언 누락 턴은 미집계.
- route%는 프록시(코드맵 hit 후 타깃 다독을 라우팅 실패로 오독하지 않도록 색은 참고 신호).
- ANSI 색상은 Claude Code statusLine이 렌더(터미널 지원 전제). 미지원 환경은 이론상 이스케이프 노출 가능(현행 Claude Code는 지원).
- **bash statusline은 jq 필요** — jq 없으면 컨텍스트% 자체가 `ctx n/a`라 retrieval 시각화 블록도 미도달(전체 statusline이 jq-required 도구라 의도된 동작). `.ps1`은 jq 불요.

## 리뷰 (독립 fresh-eyes 크로스리뷰, 2026-07-08 — codex exec 차단 → Opus 서브에이전트 대체)
**PASS_WITH_FIXES 88% → 반영 후 PASS.** codex exec가 이 환경에서 차단돼 v2.41 선례대로 독립 컨텍스트 서브에이전트 리뷰로 대체.
- **🔴(반영)**: `stop-check.sh`의 greedy sed `s/.*codemap\([^|]*\).*/\1/`가 라인의 **마지막** "codemap"(=src 세그먼트의 `(codemap 경유)` 토큰)을 매칭 → cseg=`경유)`로 cmap 레코드 누락. "codemap 경유"는 라우팅(hit) 턴에만 나오므로 bash에서 cmap hit이 체계적으로 누락돼 PS≠bash. 최초 검증이 이 머신 jq 부재로 PS만 실행돼 누출. **수정: `|` 고정 순서 위치 분해(awk `$1`/`$2`)** — 표준 라인·오염 케이스 재검증 통과.
- **🟡(반영)**: PS `xseg`가 키워드 매칭(`-match 'ctxdb'`)이라 codemap hit **경로에 'ctxdb' 부분문자열**이 있으면 seg0(codemap)을 ctxdb로 오선택 → ctx 오기록. 동일 위치 분해로 해소(PS도 `$segs[0]`/`$segs[1]`).
- **🟡(반영)**: route%/hit% PS는 `[math]::Round`, bash는 정수 절삭이라 예: route 300/7 → PS 43 vs bash 42, hit 2/3 → 67 vs 66. **bash도 round-half-up**(`(n*100 + d/2)/d`)으로 정합.
- **🟡(수용/문서화)**: 위 bash jq-gate 비대칭 — 한계 섹션 명시.
- **통과 확인**: hit-before-miss 순서(경로에 'miss' 포함해도 hit 우선), 미사용 제외(한글이라 ASCII 'hit'/'miss' 미포함), dedupe(tool_result 후행·복수 assistant·uuid 비교), ANSI reset 누수 없음, div-by-zero 가드, 기존 컨텍스트%·checkpoint/L2-split 무회귀.
