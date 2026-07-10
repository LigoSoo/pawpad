# CHANGELOG v2.43 — task-done 종결 게이트 3종 (A+B+C)

날짜: 2026-07-09 | 기반: v2.42 (retrieval 계측 시각화) | 스킬 19→20 (task-done 신규, Core)

## 배경
사용자 실관측 사고: 다른 프로젝트에서 "이번 이슈 종료 작업 해줘"로 작업을 마감해 왔으나, 이후 `/resume`가 **이미 종료한 작업을 다음 작업으로 재제안** — 확인 결과 lane→done 이관 안 된 항목 다수. 근본 원인: ON TASK DONE은 CLAUDE/AGENTS의 **선언적 지시**(훅·검증 없음)라 자연어 종료 요청에서 모델이 부분 실행(state만 갱신, 이동 생략 등)하거나 통째 누락. 남은 stale lane은 세션마다 재작업을 유도. v2.43은 완료 시점(A·B)과 다음 세션(C)에 계층 방어를 깐다.

## A — 신규 `task-done` 스킬 (19→20, Core 번들)
- ON TASK DONE 6단계를 **순서 고정 체크리스트로 강제**: ① Verification Evidence 최근 2건 cap(초과분 archive 이월) ② lane→wip/done/{id}_{ts}.md 이동(삭제 금지) ③ _wip Active Lanes 제거 ④ _meta RECENT 1줄 append+8줄 cap 이월 ⑤ tasklog 이월(HYBRID Completed Task Log) ⑥ codemap 갱신(없으면 skip 선언) ⑦ git commit(비-git이면 "git unavailable" 기록, 완료 차단 안 함).
- 발동: "작업 종료"/"이슈 종료"/"마무리"/"task done" 자연어 + agent 자체 ON TASK DONE + Stop hook `[lane-close]` 리마인더.
- 전제 게이트: DoD 미충족 시 종결 중단·사유 보고. 중간 실패 시 수행/미수행 항목 명시(재실행 이어가기). 이미 done이면 중복 이관 금지(잔존 _wip 항목만 정합 회복).
- 자동제안 제외 목록(task-done 추가) — Session Protocol/hook 트리거라 이중 추천 방지.

## B — stop-check lane-close 백스톱 (Claude 훅, ps1+sh)
- Stop 시: **마지막 assistant text 엔트리**(v2.42 다중 엔트리 스캔 방식 재사용)가 완료/종료 선언 매칭 `(작업|이슈|태스크|task|lane).{0,10}(완료|종료|마무리|done)` + `_wip.md` Active Lanes 잔존(`## Active Lanes` 섹션 위치 분해 후 `- ` 항목 검사) → `decision:block` 1회.
- 오탐 감쇄: ① 스킬명 `task-done` 문자열 제거 후 매칭(스킬 언급≠완료 선언) ② `claude-taskdone-warned` uuid dedupe(동일 응답 재경고 방지, `stop_hook_active` 루프가드는 기존) ③ 리마인더 문구에 "미완료면 무시" 명시.
- reason tail 분기: lane-close 포함 시 "If closing, execute task-done fully before stopping" (기존 "Report one line, then stop."이 종결 실행을 막지 않도록).
- bash 포트: awk 섹션 분해 + jq(라인 관용 slurp, v2.42 #3 방식) — jq 부재 시 graceful skip. 정규식 바이트 길이 보정 `{0,30}`(한글 3byte).
- Codex 훅 미적용(선례: v2.41/42 계측도 Claude 전용) — Codex는 A 스킬 미러+AGENTS 프로토콜로 커버.

## C — resume Lane 신뢰성 게이트 (스킬 + Session Protocol step 3)
- 원리: **lane은 계획의 SoT지만 무검증 신뢰 금지** — 다음 작업 제안 전 실상태 1회 대조.
- 3단 신호(신뢰도 순): ① _meta RECENT에 해당 feature-id DONE 기록 + lane 잔존 = **확정 누락** → 통지 후 task-done 즉시 종결 ② next steps 전항 체크/완료 선언 = 완료 의심 → 종결 제안(사용자 확인) ③ updated 오래됨 + next steps 첫 항목 실코드 spot-check 결과 이미 반영 = stale 의심 → 재개 전 사용자 확인.
- 확정 누락 외 자동 이관 금지(오판 시 파괴적). _meta 상단 부분읽기 호환: RECENT 대조는 feature-id Grep on-demand(통째 read 불요).
- CLAUDE/AGENTS Session Protocol step 3에 stale 게이트 1줄 + ON TASK DONE 줄에 task-done 실행 포인터.

## 표면
- 신규: `.claude/skills/task-done/SKILL.md` (+`.agents` 미러는 setup 재생성, resume 설치 단계 동거 — stepTotal 28 불변, v2.36 viewer-apply 선례)
- live: resume SKILL(게이트 섹션+타이밍 표), stop-check.ps1/.sh, CLAUDE.md(4)·AGENTS.md(2), SKILLS_MANIFEST(카운트+행+호출), .codex/config.json skills
- `pawpad-setup.ps1`: $ver 2.43 / line1·STATUS(+v2.42 강등) / task-done 임베드 신규(literal) / resume·stop-check×2·$tmplClaudeMd·$tmplAgentsMd 임베드 동기 / manifest·config 임베드 / $bpCore 11→12 / TR bundleOpts ko·en(12/17/20) / 완료요약 ko·en
- docs: README(8)·GUIDE(10, **v2.42 변경이력 bullet 누락 발견→v2.42+v2.43 동시 추가**)·USAGE(3)·PAWPAD_VERSIONS(제목+행+누적 20)·본 보고서 / codemap
- 신규 state 파일: `.ctxdb/.state/claude-taskdone-warned`(런타임). 추가 D에서 `claude-read-mark`·`claude-retrieval-warned` 추가.

## 검증 (2026-07-09)
- PSParser 0 errors (setup + live stop-check.ps1), bash -n OK (stop-check.sh)
- stop-check.ps1 실호출 fixture: 완료 선언+lane 잔존 → `[lane-close]` block / 재실행 dedupe 무발화 / lane 없음 → 무발화 / 'task-done' 언급만 → 무발화
- `-Upgrade` 실행: exit 0·0 failed, 미러 재생성 source=20 mirror=20, emitted==live(설치 후 live 불변 = embed==live)
- 카운트 grep: "19개/19 스킬/19 skills" 활성 잔재 0 (역사 기록 제외)

## 사후수정#1 — B 백스톱 lane 잔존 판정 오탐 (2026-07-09, v2.43 내 덮어쓰기)
실사용 첫 발화가 오탐이었다. lane 0건(_wip Active Lanes = "(없음)")인데 완료 선언 응답마다 `[lane-close]` block. 원인 2종:
1. **예시 블록 오독 (ps1+sh 공통)**: stock `_wip.md`는 `## Active Lanes` 섹션 **안에** 예시(`- feature-a:` 등 13줄)를 둔다 → `^\s*- ` 판정이 이를 실 lane으로 셈. 갓 설치한 모든 프로젝트에서 상시 발화.
2. **헤더 접두 매치 (sh 전용)**: awk `/^## Active Lanes/`가 하단 `## Active Lanes 필드 명세` 헤더까지 매치 → `f` 재점화, 명세 표의 `- owner:` 등 5줄 추가 오계수(18줄).
- fix: ps1 = Active Lanes 본문을 `(?m)^\s*(?:예시|[Ee]xample)`로 split 후 [0]만 판정. sh = awk 헤더 앵커 `/^## Active Lanes[[:space:]]*$/` + 예시 라인 `f=0` 절단.
- ps1 헤더 앵커는 **미적용**: `_wip.md`가 CRLF일 때 .NET `$`가 `\r` 앞에서 실패해 real lane을 놓친다(적용 시 real=0 회귀 확인). 기존 lazy 매치가 이미 첫 섹션에서 정지하므로 불요.
- 검증: ps1 실호출 E2E(stock 무발화 / real lane 발화 / uuid dedupe 무발화), awk 단독(stock 0 / real >0 / CRLF fixture 1), PSParser 0(setup+live), `bash -n` OK, `-Upgrade` 후 emitted live 재-E2E 통과. sh 전체 E2E는 jq 부재로 미실행(변경부는 awk, jq 경로 무변경).
- 감쇄 3종(선언측: 'task-done' 제거·uuid dedupe·"무시 가능" 문구)은 전부 **완료 선언** 판정만 다뤄 lane 잔존 판정 오탐을 못 막았다.

## 추가 D — retrieval 계측 결함 4종 (2026-07-09, v2.43 내 흡수, 버전 불변)
발단: 다운스트림 프로젝트에서 "최신 pawpad 적용 후에도 statusline에 codemap hit이 안 뜬다" 리포트. 1차 진단은 "훅 정상, agent 지침 미준수"였고 그 자체는 맞았다. 그러나 **그 세션이 별도 작성한 결함 리포트**(B1~B4)를 대조하니 훅에도 실결함이 있었다. 지표가 (a) 조용히 비거나 (b) 조용히 거짓이 되는 두 경로가 모두 열려 있었다.

**B1 — 선언 파서 앵커 부재 (지표 오염, 심각).** 매처가 `Retrieval:` + `codemap`을 **라인 어디서든** 찾았다. 따라서 훅 자신을 설명하는 산문("stop-check이 `📡 Retrieval:` 라인에서 codemap hit을 파싱한다")이 선언으로 오탐돼 `cmap:hit`이 기록되고, uuid dedupe로 굳는다. **훅을 디버깅·문서화하는 세션마다 자기 지표를 오염**시켰다(실제 발생: uuid `98c34512`, 그 턴 codemap lookup 0회인데 statusline `codemap 100%`).
- fix: 라인 선두 앵커 `^\s*(📡\s*)?Retrieval:\s*codemap\s` + **백틱/중괄호 라인 배제**(인용·형식 예시) + **3세그먼트 구조 검증**(`segs[1]`에 `ctxdb`, `segs[2]`에 `src`). 앵커만으론 부분 인용이 새므로 구조 검증을 함께 건다.

**B2 — 선언 누락 시 완전 무관측.** hit율은 100% 자기신고인데 `read-track`이 이미 기계적으로 수집하는 cmap/src 실측이 판정에 전혀 안 쓰였다(수집만 하고 사용처 없음). 선언을 빼먹으면 기록도 경고도 없고 statusline은 `codemap –` — 사용자는 "표시가 안 된다"만 본다.
- fix(훅): **read-track watermark 대조**. `claude-read-mark`(session 바인딩)로 직전 stop 이후 델타만 집계 → `cmap 0 + src ≥2 + 이번 턴 codemap hit/miss 선언 없음` = 미선언 full-scan으로 보고 `decision:block` 1회(`claude-retrieval-warned` uuid dedupe). src 1건은 면제(이미 아는 파일 재편집 = 라인 생략 허용 케이스), cmap lookup이 1건이라도 있으면 면제.
- fix(statusline ps1+sh): 분모 0인데 src>0이면 `codemap –` 대신 **`codemap 미선언`(노랑)** — 원인이 보이는 라벨.
- fix(구조): `stop_hook_active` 가드를 **최상단 즉시 exit → 판정만 생략**으로 변경. 기존 구조에선 block으로 선언을 요구해도 그 교정 응답의 Stop이 재진입 가드에 걸려 선언 파싱조차 안 됐다(백스톱이 무의미해지는 자기모순). 이제 계측/watermark는 항상 수행, block 재발행·turn 증가만 생략 → 루프가드 유지.

**B3 — `미사용` 허위 선언 무검출.** `미사용`은 분모에서 제외(설계상 의도)되므로 소스를 3개 읽고도 `codemap 미사용`이라 적으면 조용히 통과했다. CLAUDE.md:116이 약속한 "실측 카운터와 대조된다"는 **대조 로직이 코드에 없었고**, 근거로 든 statusline raw `cmap/ctx` 카운터는 v2.42가 이미 폐기(경유율 표시로 대체)했다 — 존재하지 않는 감시를 인용한 문구 = 억지력 0.
- fix: `codemap`을 **hit/miss로 선언한 경우에만** 백스톱 면제. `미사용` 선언은 선언 누락과 동일 취급 → B2 조건에 걸린다.
- fix(문서): CLAUDE.md·AGENTS.md(+setup 임베드 2종) 문구를 실제 강제 수단(앵커·구조·백스톱)으로 교체. AGENTS.md엔 해당 줄 자체가 없어 신규 추가.

**B4 — read-track 분류 정확도**(경미, → 사후수정#2에서 해소): `path` 없는 Grep/Glob은 전부 `src`로 계수. 전역 grep은 결과적으로 맞지만 `.claude/**` 겨냥 검색도 src로 오계수. 백스톱 임계가 `src ≥2`라 오탐 방향이나, 실측 병기(B2 watermark)를 도입한 뒤로는 분모를 직접 오염 → 해소.

- 리팩터: "가장 최근 assistant text 엔트리" 스캔을 lane-close 내부에서 **hoist** → lane-close/retrieval 백스톱 공용(중복 스캔 제거).
- 신규 state 파일: `.ctxdb/.state/claude-read-mark`, `claude-retrieval-warned`(런타임)
- 표면: `stop-check.{ps1,sh}`, `statusline.{ps1,sh}`, CLAUDE.md·AGENTS.md, `pawpad-setup.ps1`(훅 임베드 4종 + CLAUDE/AGENTS 템플릿 2종 + STATUS 줄)
- 검증: PSParser 0(setup + live stop-check/statusline), `bash -n` OK. 백스톱 매트릭스 **6/6 ps1·sh 동일**(①src2+cmap0+선언無→block ②선언有→무발화+`cmap:hit` ③src1→무발화 ④cmap1+src2→무발화 ⑤**재진입+선언有→무발화하되 stats 기록**(구조 fix 입증) ⑥재진입+선언無→무발화), dedupe 무발화·watermark 2→4 전진, block reason JSON 유효. 파서 매트릭스 **6/6 ps1**(리포트 재현 절차 그대로: 산문/백틱 없는 산문/인용된 형식/2세그먼트 → 전부 stats 빈 채 block, 정상 선언만 `cmap:hit`, `미사용`+src3 → block). sh는 jq 하류(구조 게이트·미사용 판정) 4/4 스텁 검증. 샌드박스 신규 설치(`0 failed`) 후 emitted==live 4/4 + emitted 훅으로 B1·B3 재-E2E 통과, statusline 렌더 `📡 codemap 미선언 · src 3`(노랑) 확인.

## 한계 (명시)
- D의 백스톱은 `src ≥2` 임계 — codemap 미경유 단일 파일 읽기는 통과(오탐 회피 대가). 선언의 hit/miss **내용 진위**는 여전히 검증 불가(경로 실재 여부 미대조). `hit` 선언 + 실측 `cmap 0` 대조는 codemap 주입(session-start inject) 시 정상 hit을 오탐하므로 미도입.
- D의 sh 앵커 정규식(jq `test()`)은 이 머신 jq 부재로 미실행 — ps1 동등 로직만 실측. jq 필터 자체는 리터럴 이식.
- B의 완료 선언 감지는 휴리스틱 — 선언 없는 완료(무언 종료)는 미포착(C가 다음 세션서 회수). 오탐은 1회 리마인더+무시 가능으로 수용.
- B는 이 머신처럼 org 정책이 hooks 차단이면 무효 — A(스킬)·C(resume 규율)는 훅 무관 동작.
- C의 ③단 신호는 모델 판단 의존(spot-check 규율) — 강제는 A·B가 담당, C는 회수망.

## 사후수정 #2 (버전 불변, 2026-07-09) — 다운스트림 리포트 2건

발단: 다운스트림 프로젝트(todayquest)에서 `pawpad-setup.ps1 -Upgrade` 후 git이 `.sh` 훅 + 스킬 문서 24개에 "LF → CRLF 변환" 경고를 냈다는 리포트. 함께 B4 미반영도 지적.

**E1 — `.gitattributes` 미배포** 🔴 (배포 경로 결함)
v2.43 본작업에서 toolkit **자기 레포에만** `.gitattributes`(`*.sh text eol=lf`)를 추가하고, **setup이 다운스트림에 생성하도록 만들지 않았다.** 즉 결함의 원인(autocrlf=true 클론이 bash 훅을 CRLF로 체크아웃 → `\r`이 jq 인자/heredoc 종료자/shebang에 섞여 조용히 깨짐)을 진단만 해두고 배포본에는 방어를 안 넣은 상태. Windows에선 증상이 없어 다운스트림이 Mac/Linux로 클론될 때 터진다.
- fix: `Update-Gitattributes` 신규(`pawpad-setup.ps1`, `Update-Gitignore` 옆). 비파괴 append — 파일 없으면 생성, 있으면 `*.sh … eol=lf` 또는 전역 `* text=auto … eol=lf`로 이미 강제된 경우 SKIP, 아니면 헤더 주석 1줄 + 규칙 1줄만 append(기존 항목 보존, trailing-newline 없어도 안전). git repo 아니면 SKIP.
- 설치 단계 `stepTotal` 28→29(`.gitattributes` 단계 추가).

**E2 — B4 해소**: `path` 없는 Grep/Glob의 경로형 필드 폴백.
`read-track.{ps1,sh}`가 `file_path` → `path`까지만 보고 없으면 무조건 `src`. 그래서 `Grep(glob=".claude/**")`, `Glob(".claude/hooks/*.sh")`, `Glob(".claude/codemap/**")`가 전부 src로 계수됐다 — B2 watermark 백스톱이 이 카운트를 분모로 쓰므로 오탐 유발 경로.
- fix: tool별 경로형 필드로 폴백 — **Glob은 `pattern`**(경로 glob), **Grep은 `glob`**(경로 필터). **Grep의 `pattern`은 내용 regex이지 경로가 아니므로 제외**(`.claude/codemap`을 검색어로 쓴 Grep이 cmap으로 오분류되는 역오탐 차단).
- 폴백조차 없는 무범위 Grep/Glob은 실제로 전역 탐색이므로 `src` 유지 — 백스톱 의도와 일치.

- 표면: `pawpad-setup.ps1`(`Update-Gitattributes` + 호출 + stepTotal + read-track 임베드 2종), `.claude/hooks/read-track.{ps1,sh}`
- 검증: PSParser 0(setup). **read-track 회귀 14/14 ps1·sh 동일**(Read cmap/src/ctx/.claude제외, Grep path=cmap/src, B4 4종: glob=`.claude/**`→미집계·Glob `.claude/hooks/*.sh`→미집계·Glob `.claude/codemap/**`→cmap·Glob `**/.claude/**`→미집계, 무범위 Grep→src, `Grep(pattern=".claude/codemap")`→src(역오탐 차단)). **pre-fix 베이스라인(HEAD)으로 동일 스위트 실행 → B4 4건 정확히 FAIL 재현**(10/14). emitted==live 2/2. **`Update-Gitattributes` AST 추출 실행 6/6**(생성·비파괴 append·중복 SKIP·전역 text=auto SKIP·non-git SKIP·2회 실행 멱등).

### 한계
- `Set-Content -Encoding UTF8`(PS 5.1)은 BOM을 붙인다. `.gitattributes` 첫 줄이 주석이라 git 파싱에 무해하나, 사용자가 첫 줄에 패턴을 추가하며 BOM 위치를 바꾸면 이론상 취약(`.gitignore` 경로와 동일 관행).
- 무범위 Grep(예: `Grep "sym"` repo-wide)은 여전히 src 1건 — 실제 탐색 규모와 무관하게 1로 계수.

## 사후수정 #3 (버전 불변, 2026-07-10) — `Get-Content -Tail` 최악값 경화 (**hang 원인 아님 — 오진 기록 포함**)

> ⚠️ 이 절은 처음에 "Stop 훅 hang의 원인"으로 기록했다가 **실측으로 반증되어 정정**했다. 진짜 원인은 사후수정 #4다. 오진 과정을 지운 뒤 결론만 남기면 같은 함정을 다시 밟으므로 그대로 둔다.

발단: 다운스트림 세션이 `running stop hooks… 1/2 · 15m 21s`로 정지. 합성 fixture(7MB, 120KB/줄)로 `stop-check.ps1`을 실호출하니 2분 타임아웃 초과 → "원인 발견"으로 결론지었다. **틀렸다.** 실제 그 세션의 transcript(21.7MB, 1011줄, 최대 786KB/줄)로 재측정하니 **구버전 훅도 1.35초**였다. `-Tail 60` 창(window) 안의 줄이 실전에선 작아 병리가 발현되지 않는다. 합성 fixture는 모든 줄을 크게 만들어 최악값을 인위적으로 만든 것이었다.

남는 사실(경화 가치는 있음): PS 5.1 `Get-Content -Tail`은 **`-Encoding`을 지정하면** 역방향 탐색이 초선형으로 붕괴한다. `stop-check.ps1:40`이 `-Tail 60 -Encoding UTF8`로 transcript를 읽었고, transcript 한 줄은 tool_result 때문에 수십~수백 KB다.

실측(16MB / 401줄 × 40KB):

| 방식 | 시간 |
|---|---|
| `Get-Content -Tail 80` (`-Encoding` 없음) | 0.19 s |
| `Get-Content -Tail 80 -Encoding UTF8` | **26.79 s** |
| `StreamReader`(UTF-8) 1패스 + 링버퍼 | 0.13 s |

7MB / 120KB per line fixture로 훅 전체를 실호출하면 **2분 타임아웃 초과**. 같은 fixture에서 수정 후 **1.25 s**.

함정은 `-Encoding UTF8`을 그냥 빼면 안 된다는 것: PS 5.1은 인코딩 미지정 시 ANSI(CP949 등)로 읽어 **Retrieval 선언의 이모지/한글이 깨지고 B1 앵커가 실패**한다. 속도와 정확성을 동시에 얻는 유일한 길이 StreamReader다.

- fix: `Get-TailLines`(FileStream `FileShare.ReadWrite` + StreamReader UTF-8 + 링버퍼) 신규, `stop-check.ps1`·`statusline.ps1` 양쪽 적용. `FileShare.ReadWrite`는 Claude Code가 append 중인 transcript를 잠금 충돌 없이 읽기 위함.
- 구현 함정: 링버퍼 반환을 `return ,$out`으로 쓰면 호출부 `@()`가 **"배열 1개를 담은 배열"** 로 재수집해 줄 단위 파싱이 통째로 죽는다(구현 중 실제 발생, 훅이 조용히 transcript를 못 읽음). 언롤 반환 + 호출부 `@()`가 정답.
- `statusline.ps1`은 `-Encoding`이 없어 **hang의 원인이 아니었다**(0.19s 경로). 다만 ANSI 읽기라 비-ASCII 줄에서 JSON 파싱이 깨질 수 있어 같은 헬퍼로 통일 — 정확성 개선이지 성능 수정이 아니다.
- `.sh` 포트는 `tail -n`이라 무관(무변경). v2.43 회귀 아님 — `-Tail`은 v2.41부터 존재. retrieval 백스톱(추가D)이 block→재생성을 유발해 이 비용을 한 턴에 여러 번 물리면서 증상이 드러났을 뿐이다.

- 표면: `.claude/hooks/stop-check.ps1`, `.claude/hooks/statusline.ps1`, `pawpad-setup.ps1`(임베드 2종)
- 검증: PSParser 0(setup + live 2종). **emitted==live 8/8**. **stop-check 백스톱/파서 매트릭스 7/7** — 수정본·pre-fix HEAD **양쪽 동일 7/7**로 기능 회귀 없음. 합성 최악 fixture `>120s → 1.25s`. **실제 transcript(21.7MB): before 1.35s / after 1.14s — 즉 실전 이득 없음, 최악값 보험일 뿐.** statusline 렌더 전후 동일(`ctx 8% (80k/1M) | Opus`).

### 조사 중 배운 것 (기록)
- **PS 5.1은 BOM 없는 .ps1을 CP949로 읽는다.** 스크래치 테스트 스크립트에 이모지/한글 **리터럴**을 넣으면 정규식이 조용히 깨져 "훅이 틀렸다"는 오진을 만든다(이번에 3회 반복). 테스트 하네스는 ASCII 전용으로 쓰고 비-ASCII는 `[char]0xD83D` 식으로 조립하거나, 패턴을 훅 파일에서 직접 추출할 것.
- **자식 프로세스 CWD는 `Set-Location`/`Push-Location`으로 신뢰할 수 없다.** 케이스 간 state가 새어 매트릭스가 거짓 FAIL(2건)을 냈다. `ProcessStartInfo.WorkingDirectory`로 명시할 것.
- **stdout/stderr 인터리브 순서는 신뢰 불가.** DBG(stderr)와 결과(stdout)를 grep으로 섞어 읽어 케이스를 오귀속했다. 단일 케이스 격리 실행이 결정적 측정이었다.

## 사후수정 #4 (버전 불변, 2026-07-11) — 🔴 retrieval 백스톱 block 교착 (추가D 자체 결함)

**증상**: 다운스트림 세션이 `running stop hooks… 1/2 · 22m 28s · ↓ 19.9k tokens`. 훅이 매달린 게 아니라 **block → 전체 응답 재생성**이 매 턴 반복된 것. 사용자에겐 수십 분 정지로 보인다.

**원인 2종이 곱해진다. 둘 다 v2.43 추가D가 넣은 것이다.**

1. **read-track이 `src`를 잘못 정의했다.** `.claude/.agents/.codex`가 아니면 전부 `src`. 그래서 **스크린샷 PNG, scratchpad 임시파일, 다른 repo의 파일**까지 "소스 읽기"로 계수했다. 실제 로그: `read-track measured 4 source reads` — 그 턴에 읽은 건 `scratchpad/qa/*.png` 4장뿐이었다.
2. **B3가 탈출구를 막았다.** 백스톱 면제는 `codemap hit|miss` 선언뿐이고 `미사용`은 면제가 아니다(허위 `미사용` 차단 목적). 그런데 위 오계수로 `srcDelta ≥ 2`가 서면, **소스를 하나도 안 읽은 에이전트가 낼 수 있는 정직한 선언은 `미사용`뿐인데 그게 곧 block 사유**가 된다. 정직할수록 못 빠져나온다.
3. uuid dedupe는 "같은 응답 재경고"만 막는다. 교정 응답은 **새 uuid**라 다음 Stop에서 다시 block → 무한.

**fix**

- `read-track.{ps1,sh}`: `src` = **이 repo(cwd) 하위 + 비-자산 파일**. 자산/바이너리 확장자(`png jpg jpeg gif webp bmp ico svg pdf zip gz mp4 mov mp3 wav ttf otf woff woff2 exe dll so dylib bin`) 미집계. 절대경로가 `cwd` 하위가 아니면 미집계(scratchpad·temp·타 repo). 상대경로는 repo 내부로 간주.
- `stop-check.{ps1,sh}`: retrieval block **세션당 하드캡 2회**(`claude-retrieval-warned` = `session / uuid / count` 3줄, legacy 1줄 포맷 하위호환). 원인이 무엇이든 무한 재생성 불가. B3의 억지력은 첫 2회로 유지된다.

**검증**
- read-track 재분류 매트릭스 **ps1·sh 각 10케이스 = 20/20**: 실사례(scratchpad PNG)·repo 자산 png·타 repo 절대경로 → 미집계 / repo 소스(절대·상대)·codemap·ctxdb·glob 분류는 기존대로.
- 기존 B4 회귀 스위트 **14/14 ps1·sh**(fixture의 비현실적 `cwd`를 실제 값으로 교정 후 — 첫 실행의 1건 FAIL은 새 "repo 밖" 규칙이 정확히 걸러낸 것이었다).
- 루프 하드가드 E2E: **정직한 `미사용` 선언 + src 2건**을 5턴 연속 재현(매 턴 새 uuid) → 발화 `BLOCK BLOCK - - -`. 세션당 2회에서 정지.
- stop-check 백스톱/파서 매트릭스 **7/7**, emitted==live **8/8**, PSParser 0, `bash -n` OK.
- 실제 transcript(21.7MB) 실호출 1.14s.

**교훈 (이번 건의 핵심)**
- **관측 도구가 관측 대상을 망가뜨렸다.** 계측(read-track)의 분류가 틀린 채로 그 위에 강제(block)를 얹으면, 오계수가 곧 강제력이 된다. 강제를 붙이기 전에 계측의 오탐률을 실사용 데이터로 먼저 재야 한다.
- **에이전트에게 정직한 탈출구가 항상 있어야 한다.** B3는 거짓 `미사용`을 막으려다 참인 `미사용`까지 막았다. 게이트를 설계할 때 "사실을 말하는 응답이 게이트를 통과하는가"를 반드시 확인할 것.
- **block은 공짜가 아니다.** 1회 = 전체 응답 재생성. 재발행 상한 없는 block 조건은 잠재적 무한 비용이다.
- 진단은 **실제 데이터로 재현**될 때까지 확정하지 말 것. 합성 fixture는 존재하지 않는 병목을 만들어냈다(#3 참조).
