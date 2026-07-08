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
- `stop-check.ps1`/`.sh`: Stop 훅이 `transcript_path`에서 **방금 완료된 assistant 메시지**를 읽어 `📡 Retrieval:` 라인 추출 → codemap/ctxdb 세그먼트의 `hit`/`miss` 판정 → `.ctxdb/.state/claude-retrieval-stats`에 `cmap:hit|cmap:miss|ctx:hit|ctx:miss` append.
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
- stop-check.ps1 실호출(mock transcript: codemap hit + ctxdb miss): `cmap:hit`/`ctx:miss` 기록 정확. **재실행 시 dedupe로 무중복 확인**.
- bash -n: statusline·stop-check·session-start·read-track .sh 4파일 전부 OK.
- 미실행: 다운스트림 실세션 E2E(배포 대상 머신 확인 필요), codex exec 크로스 리뷰(권장 — 동결 절차).

## 한계 (명시)
- hit%는 **agent 자기선언 기반** — 허위선언은 v2.41의 `cmap` 실측 카운터와 대조돼 억제되나, 선언 누락 턴은 미집계.
- route%는 프록시(코드맵 hit 후 타깃 다독을 라우팅 실패로 오독하지 않도록 색은 참고 신호).
- ANSI 색상은 Claude Code statusLine이 렌더(터미널 지원 전제). 미지원 환경은 이론상 이스케이프 노출 가능(현행 Claude Code는 지원).
