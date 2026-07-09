# CHANGELOG v2.42 — retrieval 계측 시각화 (색상 + route% + hit%)

날짜: 2026-07-08 | 기반: v2.41 (retrieval-source 표시 A 선언식 + B 계측식) | 스킬 19 불변

## 배경
v2.41이 statusline에 `📡 cmap N ctx N src N` **원시 카운터**를 노출했으나, 사용자가 "PawPad 코어(codemap/ctxdb 라우팅)가 실제로 동작하는지 한눈에 보고 싶다"고 요청. 원시 숫자만으론 라우팅 활성/이탈·히트율이 즉시 안 읽힘. v2.42는 동일 계측 위에 **시각 신호(색상) + 파생 지표(route%, hit%)** 를 얹어 코어 동작을 대시보드화한다. **statusline은 UI 렌더라 모델 컨텍스트에 안 들어감 → 전부 모델 토큰 0.**

## 추가 지표
1. **색상** — 라우팅 활성(`cmap|ctx > 0`)=초록 / 소스직행(`src`만, `cmap==ctx==0`)=노랑 경고. 코드맵 미경유 full-scan을 색으로 즉시 포착.
2. **route%** = `(cmap+ctx)/(cmap+ctx+src)` — 탐색이 라우팅 계층을 얼마나 경유했는지. 초록≥50 / 노랑≥25 / 빨강<25. (프록시 지표: src-heavy가 항상 나쁜 건 아님 — 코드맵 hit 후 타깃 다독은 정상. 색은 참고용.)
3. **hit%** — codemap·ctxdb **선언 hit/miss율**. 원시 read 카운터로는 hit/miss(코드맵에 심볼이 있었나)를 알 수 없으므로, agent가 이미 매 응답 출력하는 `📡 Retrieval:` 선언을 **stop-check 훅이 파싱**해 누적. 초록≥70 / 노랑≥40 / 빨강<40. `미사용` 턴은 분모 제외.

**표시 형식(사용자 선택: 라우팅율 헤드라인)**: `ctx 25% (248k/1M) | Opus 4.8 | 📡 codemap 80% · routed 4 / full-scan 1 · src 14`
- `codemap N%` = **codemap 경유율** = routed/(routed+full-scan). routed=`codemap hit` 선언, full-scan=`codemap miss` 선언. 초록≥70/노랑≥40/빨강<40. → "잘 작동하는가" 주지표.
- `src N` = 색인 미경유 **직접 read 볼륨**(백스톱). **선언 0 + src>0 = 미선언 직접읽기(풀스캔 의심) → src 노랑 경고.**
- `· ctx N%` = ctxdb 매칭율(프롬프트↔context), ctxdb 샘플 있을 때만 뒤에 붙음.
- 선언 0건이면 `codemap –`. 활동 전무면 📡 통째 생략.
- **폐기(혼란 방지)**: 원시 `cmap N ctx N` 카운트 + `route%`(=(cmap+ctx)/total 프록시) 제거. 기계 카운터로는 "소스를 codemap 경유로 찾았나"를 구분 못 함(파일 경로만 봐선 알 수 없음) → 그 판정은 선언 기반 `codemap%`가 담당, `src`는 위조불가 백스톱.

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

## 리뷰 (2단계 크로스리뷰, 2026-07-08)

### 1차 — 독립 fresh-eyes 서브에이전트 (Opus)
**PASS_WITH_FIXES 88% → 반영 후 PASS.** (당시 codex exec를 다른 머신 EDR 차단 노트를 근거로 미시도 — 후속 확인 결과 현 머신은 차단 아님, 노트는 머신 한정.)
- **🔴(반영)**: `stop-check.sh`의 greedy sed `s/.*codemap\([^|]*\).*/\1/`가 라인의 **마지막** "codemap"(=src 세그먼트의 `(codemap 경유)` 토큰)을 매칭 → cseg=`경유)`로 cmap 레코드 누락. "codemap 경유"는 라우팅(hit) 턴에만 나오므로 bash에서 cmap hit이 체계적으로 누락돼 PS≠bash. 최초 검증이 이 머신 jq 부재로 PS만 실행돼 누출. **수정: `|` 고정 순서 위치 분해(awk `$1`/`$2`, PS `$segs[0]`/`$segs[1]`)** — 표준 라인·오염 케이스 재검증 통과.
- **🟡(반영)**: PS `xseg` 키워드 매칭이 codemap hit 경로 내 'ctxdb' 부분문자열에 오선택. 동일 위치 분해로 해소.
- **🟡(반영)**: route%/hit% PS `[math]::Round` vs bash 정수 절삭 divergence → 우선 bash를 round-half-up으로 맞춤(2차에서 더 정밀 지적).

### 2차 — codex exec review (실제 codex CLI, gpt-5.4-mini, `--base aa6fde9~1`)
**2건 지적 → 반영 후 clean.** codex 미차단 확인 후 정통 크로스엔진 리뷰 실행.
- **[P2](반영)**: 1차의 round-half-up 수정이 불완전 — PS `[math]::Round`는 **banker's rounding**(round-half-to-even, `Round(12.5)=12`)이라 bash half-up과 **정확히 .5 케이스에서 여전히 divergence**(예 1/8=12.5% → PS 12 / bash 13), 색 버킷 경계까지 갈릴 수 있음. **수정: PS도 half-up으로 통일** — `[int][math]::Floor(x + 0.5)`. 재검증 12.5/42.5/62.5 → PS·bash 공히 13/43/63.
- **[P3](반영)**: Retrieval 파싱이 assistant 텍스트 내 `Retrieval:`+`codemap` 포함 **첫 줄**을 잡아, 응답이 **형식 예시를 인용**(리뷰/문서 응답)하면 예시 라인을 실제 선언으로 오계수. 실제 선언엔 중괄호 `{}`가 없고 형식 예시엔 `{hit|miss}`가 있음. **수정: `{` 포함 라인 제외**(PS `-notmatch '\{'`, bash `grep -v '{'`). 재검증: 예시+실선언 혼재 → 실선언 선택, 예시 단독 → 미기록.
- **통과 확인**: dedupe, ANSI reset, div-by-zero 가드, 기존 컨텍스트%·checkpoint/L2-split 무회귀.

## 사후 수정 (실사용 발견, 2026-07-09) — 🔴 파서가 transcript 다중 엔트리를 못 읽어 기능 무동작
사용자가 "statusline routing 가시화가 동작 안 하는 것 같다" 보고 → 실제 transcript 스키마 점검으로 근본 원인 확정.
- **증상**: `claude-retrieval-stats` 계속 0건 → statusline이 항상 `codemap –`(데이터 없음). hit/routing 지표가 전혀 안 뜸.
- **근본 원인**: Claude Code transcript는 **한 응답을 `text`/`thinking`/`tool_use` 각각 별개 JSONL 엔트리**로 기록한다. stop-check 파서가 뒤에서 **첫 assistant 엔트리에서 `break`** 했는데, 그게 보통 `thinking`이나 `tool_use`(text 없음)라 `$lastText`가 비어 `📡 Retrieval:` 선언을 놓침. 초기 검증이 단일-엔트리 mock transcript(text만)라 실제 다중-엔트리 스키마를 못 잡음(uuid는 뽑혀 `seen`은 갱신되나 stat 0건).
- **수정**: 첫 엔트리 break 폐기 → 최근 60줄 window에서 **유효 Retrieval 선언(중괄호 예시 제외)을 담은 가장 최근 assistant text 엔트리**를 스캔해 사용(thinking/tool_use 엔트리 skip), dedup은 그 엔트리 uuid. PS(`stop-check.ps1`) + bash(`stop-check.sh` jq 재작성) 동일.
- **검증**: 실제 스키마 재현 mock(text 선언 엔트리 + 후행 thinking/tool_use 엔트리)에서 `cmap:hit ctx:miss` 정확 기록(이전 파서는 tool_use tail에서 빈값), dedup 무중복, 예시 단독 미기록. PSParser 0·emitted==live 6/6·설치 exit0·bash -n. (bash/jq E2E는 이 머신 jq 부재로 로직+syntax 검증 — 다운스트림 Mac/Linux 확인 권장.)
- **교훈**: 훅이 실런타임 산출물(transcript)을 파싱할 땐 mock이 아니라 **실제 스키마**로 검증할 것. 단일 응답=단일 엔트리 가정이 오류.

## 사후 수정 #2 (실사용 발견, 2026-07-09) — 🔴 0-byte seen 파일 NPE로 stats 여전히 0
파서 fix(#1) 후 NEXT 검증 절차 수행 중 stats가 여전히 0건 → outer `try/catch {}`가 삼키던 두 번째 결함 확정.
- **증상**: #1 반영 후에도 `claude-retrieval-stats` 0건. 파싱 로직 replay는 선언을 정확히 찾는데 실제 hook 실행만 미기록.
- **근본 원인**: `session-start.ps1`이 매 세션 `claude-retrieval-seen`을 `Set-Content -Value @()`로 **0-byte reset** → stop-check.ps1의 `(Get-Content -Raw).Trim()`에서 PS 5.1은 0-byte 파일의 `-Raw`가 **`$null`** → `.Trim()` NPE → retrieval 블록 전체가 outer catch에 삼켜져 stats·seen 둘 다 미기록. seen이 영원히 0-byte로 남아 **매 세션 매 Stop 100% 재현**. #1 검증 mock은 seen 파일이 없는 상태(Test-Path false 분기)라 이 경로를 못 밟음.
- **수정**: `"$(Get-Content ... -Raw)".Trim()` — 서브식스트링 보간으로 null→"" 정규화(1줄). live `stop-check.ps1` + `pawpad-setup.ps1` 임베디드 템플릿 동기. bash(`stop-check.sh`)는 `cat` 빈 파일=`""`라 무관. 같은 패턴인 `oversize-warned` read(:89)는 항상 비어있지 않은 sig로만 쓰여 미트리거 — 미수정.
- **검증**: 0-byte seen 재현 fixture(실스키마 다중 엔트리 transcript, 별도 프로세스 stdin 파이프)에서 `cmap:hit` 기록 + seen=uuid 갱신 + 재실행 dedupe 무중복. PSParser 0(양 파일). 라이브 세션 실선언 E2E 확인.
- **교훈**: 예외를 삼키는 광역 try/catch 아래 로직은 "찾는 단계" replay만으론 부족 — **쓰기 단계까지 실상태 파일(0-byte reset 포함)로 관통 검증**할 것. PS 5.1 `Get-Content -Raw`는 빈 파일에서 `""`가 아니라 `$null`.
