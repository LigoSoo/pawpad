```text
  ═════════════════════════════

          ▄██▄    ▄██▄
          ████    ████
          ▀██▀    ▀██▀
     ▄██▄     ▄▄▄▄     ▄██▄
     ████   ▄██████▄   ████
     ▀██▀ ▄██████████▄ ▀██▀
         ██████████████
        ████████████████
        ████████████████
         ▀████▀  ▀████▀

         P A W   P A D
   Agentic Engineering Toolkit

  ═════════════════════════════
```

# PawPad — Agentic Engineering Toolkit (v2.37 FROZEN)

Claude Code ⇄ Codex 하이브리드 협업을 위한 **멀티에이전트 상태관리 + 토큰절약 하니스**.
하나의 PowerShell 스크립트로 어떤 프로젝트에든 19개 스킬 · PawPad 상태머신 · 양 런타임 자동화 hook · 키워드 컨텍스트 DB · 7축 코드베이스 맵 · 보안 검증 게이트를 설치한다.

> **단일 통합 배포본**: `pawpad-setup.ps1` 하나가 Claude Code + Codex 양쪽 hook을 설치한다 (per-agent 변형 없음).
> 대상 스택은 프리셋(flutter/node/python/generic) 선택 — `CLAUDE.md`/`AGENTS.md`의 `<YOUR_*>`만 채우면 어떤 스택에든 적용.

---

## 무엇을 해결하나

| 문제 | 해결 |
|------|------|
| 세션이 끊기면 맥락 유실 | **모든 상태를 파일에 저장** (`.claude/pawpad/`) → 새 세션이 읽고 이어감 |
| 에이전트 전환(Claude↔Codex) 시 인수 누락 | lane owner/state 머신 + handoff snapshot |
| 심볼 위치를 매번 검색 | `codemap/_index.md` 레지스트리 + 세션시작/키워드 자동 주입 |
| 낯선 repo 구조 파악에 트리 전체를 읽음 | **codebase-map** 7축 고수준 맵(아키텍처/구조/관례/관심사) + digest-only 주입 |
| 누적 컨텍스트로 토큰 폭증 | `.ctxdb` **키워드 depth DB** — 매 프롬프트 키워드로 L1≤1/L2≤2만 lazy-load |
| codemap/저장을 깜빡함 | **Stop hook**이 8턴마다 강제 체크포인트 + **PreCompact hook**이 compaction 직전 저장 유도 |

---

## 요구사항

- **Windows PowerShell 5.1** (hook은 `.ps1`. Unix는 `.sh` wrapper + `pwsh`)
- 실행정책: `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`
- Claude Code (hook 자동) 또는 OpenAI Codex (네이티브 hook, `/hooks` trust 1회)

---

## 설치

> **받기**: 이 저장소의 `pawpad-setup.ps1` **한 파일**만 있으면 된다 (외부 의존성·패키지 설치 없음). raw 파일을 내려받거나 저장소를 클론한다.

### 빠른 시작 (3단계)

```powershell
# 1) pawpad-setup.ps1 을 설치할 프로젝트 루트에 복사 → 그 루트에서 실행
.\pawpad-setup.ps1 -Stack generic        # 프리셋: flutter | node | python | generic

# 2) CLAUDE.md / AGENTS.md 의 <YOUR_*> (Stack·Commands·Boundaries) 채우기

# 3) 에이전트(Claude Code/Codex)에서 첫 명령
#    /resume   → 기존 작업 재개      |   /clarity → 새 기능 기획 시작
```

`0 failed` 면 성공. 이후 아래 모드별 실행과 [설치 후 필수 설정](#설치-후-필수-설정)을 참고.

설치할 프로젝트 **루트**에 `pawpad-setup.ps1`를 복사한 뒤:

```powershell
# 신규 설치 (기존 파일은 건너뜀). -Stack 생략 시 대화형 선택
.\pawpad-setup.ps1 -Stack generic

# 재설치 / 덮어쓰기 (사용자 데이터 자동 백업 → .claude/pawpad/backup/{timestamp}/)
.\pawpad-setup.ps1 -Stack generic -Force

# 기존 설치 업그레이드 (툴킷 파일만 갱신, PawPad/커스텀 보존, 혼합 파일은 툴킷 섹션·키만 자동 병합)
.\pawpad-setup.ps1 -Upgrade

# 설치 중 파일 단위 상세 로그 보기 (기본: live 진행 바 1줄 갱신, 파일 로그 숨김)
.\pawpad-setup.ps1 -ShowLog
```

출력에 `Created / Updated / Merged / Skipped / Failed` 요약이 뜬다. `0 failed`면 성공.
`~/.codex/skills/`에 동일 이름 스킬(전역 섀도잉)이 있으면 경고가 출력된다 (삭제는 안 함, 정리 권장 안내만).

### 설치 후 필수 설정
1. `CLAUDE.md` / `AGENTS.md` 의 **Stack · Commands · Boundaries** 를 실제 프로젝트에 맞게 수정
2. `.claude/pawpad/_meta.md` 의 `STACK` 줄 수정
3. `.ctxdb/INDEX.md` 의 **키워드→L1 매핑 테이블**을 프로젝트 도메인에 맞게 작성
4. 기존 코드가 있으면 에이전트에게 "`.claude/codemap/_index.md` 초기값 만들어줘" / "codebase-map 7축 작성해줘" 요청
5. `.claude/HYBRID.md` 읽고 협업 프로토콜 숙지
6. **Codex 사용 시**: Codex에서 `/hooks` 실행 → project-local hooks review/trust (1회)

> Claude hook은 **다음 세션부터** 동작한다 (SessionStart/Stop은 세션 로드 시 등록).

---

## 무엇이 설치되나

```
CLAUDE.md / AGENTS.md            # 에이전트 컨텍스트 (Claude / Codex). 완료 기준(DoD) 8번 = security-check 보안 게이트 포함
pawpad-setup.ps1     # 통합 단일 설치 스크립트 (FROZEN v2.37, 설치 UI: paw 배너+live 진행 바+체크리스트, -ShowLog로 상세 로그)
.codex/
├── config.json                  # Codex 보조 설정 (skills 19 + context/backup keys)
├── config.toml                  # project config layer note
├── hooks.json                   # Codex lifecycle hook router (SessionStart/UserPromptSubmit/PreCompact/Stop)
└── hooks/{*.ps1,*.sh}           # Codex native hooks (cwd 상위탐색 self-location)
.agents/skills/{19}/SKILL.md     # Codex repo skill mirror (.claude/skills 단일소스, DO NOT EDIT 헤더)
.gitignore                       # backup / .ctxdb/.state 등 자동 등록
docs/HOOK_TESTING.md             # hook 회귀 방지 체크리스트 (event/runtime별 출력 계약)
.claude/
├── settings.json                # Claude hooks 5종 (절대+forward-slash, run-hook.ps1 경유)
├── pawpad-config.json              # 런타임 토글 (codemap.inject auto/on/off)
├── hooks/
│   ├── run-hook.ps1             # root-aware wrapper (하위 cwd에서도 repo root로 실행)
│   ├── session-start.ps1        # state reset + codemap/INDEX 주입
│   ├── ctxdb-inject.ps1         # UserPromptSubmit: 키워드 L1/L2 최소주입 (session dedupe)
│   ├── pre-compact.ps1          # PreCompact: compaction 직전 context-saver 유도
│   ├── stop-check.ps1           # Stop: 8턴 체크포인트 + L2 분할 품질강제
│   └── statusline.ps1           # ctx 사용%(예: ctx 31% (62k/200k)) + .sh wrapper들
├── HYBRID.md                    # 협업 프로토콜 (Decision Placement Matrix · Verification Evidence)
├── SKILLS_MANIFEST.md           # 스킬 카탈로그 (19)
├── skills/{19}/SKILL.md         # 스킬 정의 (no-BOM, --- frontmatter)
├── codemap/_index.md            # 심볼 위치 레지스트리
└── pawpad/
    ├── _wip.md                  # active lane router
    ├── _meta.md                 # 이력 + STACK/SPRINT
    ├── specs/                   # PRD 산출물
    ├── codebase/                # codebase-map 7축 (ARCH/STRUCT/CONV/TEST/CONCERNS + opt STACK/INTEG)
    ├── wip/{feature}.md         # 진행 중 lane
    ├── wip/done/                # 완료 lane (timestamp 보존, 삭제 금지)
    ├── handoffs/                # 인수인계 snapshot
    ├── reviews/                 # 교차 에이전트 리뷰 보고서
    ├── verifications/           # 긴 검증 근거
    ├── decisions/arch.md        # ADR (장기 결정)
    └── backup/                  # -Force/-Upgrade 시 자동 백업 (gitignore)
.ctxdb/                          # 키워드 depth 컨텍스트 DB
├── INDEX.md                     # 키워드 → L1 매핑 + AGENT SYNC
├── L1/domain-*.md               # 도메인별 L2 포인터
├── L2/*.md                      # 상세 (작업 내러티브/결정/codebase-map digest)
└── .state/                      # turn-count / codex-turn-count / loaded / last-compact (gitignore)
```

---

## 스킬 19개

### Core — 상태/코드
| 스킬 | 용도 |
|------|------|
| `/resume` | 세션 시작 재개 프로토콜 (HYBRID/_wip/lane/meta/codemap 읽기) |
| `/codemap` | 심볼(클래스/함수/위젯) **위치** 레지스트리, owner 분리 권한 |
| `/codebase-map` | **7축 고수준 맵** (아키텍처/구조/관례/테스트/관심사). codemap=위치, codebase-map=구조·관례. digest-only 주입 |
| `/ctxdb-navigator` | **키워드 depth 컨텍스트 최소 로드** (토큰 절약) |
| `/context-saver` | 세션 작업을 `.ctxdb/L2`에 저장 + AGENT SYNC 갱신 |
| `/clarity` | 구현 전 요청 모호도 5차원 스코어링, 재질문 → PASS 후 접근법 게이트(실질 대안 ≥2면 2-3 대안 + 추천 1개) |
| `/design` | 화면/컴포넌트 UI/UX 설계 게이트 (토큰→레이아웃→원칙) |
| `/mockup` | PRD-tree→단일 HTML 목업 시각화 (lo/hi-fi, Feature ID 태깅 + drift 경고) |
| `/lean-code` | 코드 작성 시 과설계/범위이탈 방지 가드레일 (구 karpathy) |
| `/feature-architecture` | feature-first 구조 규율 (참조). 강제는 CLAUDE/AGENTS `Architecture Principles` |
| `/caveman` | 응답 압축 모드 (기본 ON, `normal mode`로 해제) |
| `/security-check` | **보안 검증 게이트** — secrets/취약점/위험 설정/PawPad 산출물 스캔. 🔴(critical) 검출 시 작업 완료 차단 — CLAUDE.md 완료 기준(Definition of Done) 8번: 코드 변경 작업은 이 스캔 🔴 0건이어야 완료 인정 |

### Workflow — 협업/기획
| 스킬 | 용도 |
|------|------|
| `/grill-me` | 계획/설계를 재귀 심문으로 스트레스 테스트 (모호 용어 canonical 좁힘·엣지케이스 시나리오·진술 vs 코드 모순 표면화 포함) |
| `/to-prd` | 대화 → PRD 변환 → `specs/` 저장 + lane `SPEC_READY` |
| `/viewer-apply` | 통합 뷰어(spec-viewer)가 저장한 `src/viewer/*.json`을 읽어 스팩 동기 — 남은 항목→spec 생성/갱신, 삭제→제거/아카이브 |
| `/review` | 문서형 크로스에이전트/세션 리뷰 라운드트립 (codex exec 보완·저토큰). 변경을 request 문서로 → 다른 세션/에이전트가 직접 검증 리뷰 → result 반환 |
| `/code-delegate` | 코딩 단계 서브에이전트 위임. 모델 선택 → spec/lane 포인터 전달 → 서브에이전트 코딩 → 요약 반환. 부모(Opus) 컨텍스트·토큰 절감 (Claude Code 주력) |
| `/checkpoint` | 컨텍스트 50~60% 롤오버 게이트 (lane/codemap/meta 저장) |
| `/handoff` | 다른 에이전트/세션 인수인계 (snapshot + owner 이전) |

> 스킬은 PowerShell 명령이 아니라 **instruction**. 에이전트가 SKILL.md 절차를 따라 파일을 읽고 쓴다.

---

## 핵심 워크플로 (사용법 요약)

**아이디어 → 기획 → 구현** 파이프라인. 각 단계가 스킬 1개로 게이트된다:

```
아이디어
  └ /clarity        모호도 5차원 스코어 → 임계값까지 재질문 → (접근법 2-3 대안+추천 선택) → 구현계획
  └ /grill-me       설계 결정 재귀 심문 (상호의존·트레이드오프·비가역 결정 정리)
  └ /to-prd         대화 → PRD(specs/) 저장 + lane SPEC_READY 등록
  └ /mockup         PRD-tree → 단일 HTML 목업 (lo-fi 와이어프레임 → hi-fi 디자인)
                    화면별 Feature ID 태깅 + 트리↔목업 drift 검사 → 코딩 전 구조 확정
  └ /mockup viewer  PRD-tree/spec → src/viewer/*.json → spec-viewer 4탭(PRD/기능명세서/메뉴구성도/와이어) 브라우저 시각 확정(드래그 재배치·UI 검토) → /viewer-apply 로 스팩 동기
        ↓ (구현 세션이 lane 인수)
구현
  └ /resume         SPEC_READY lane 인수 (state=WIP)
  └ /code-delegate  (선택) 코딩 단계 위임 — 모델 선택 → 서브에이전트 코딩 → 요약 반환 (부모 컨텍스트·토큰 절감)
  └ 코딩            /codemap(심볼 위치) · /lean-code(과설계 방지) · /design(화면)
  └ /security-check 🔴 0건 (DoD 게이트, 코드 변경 시 필수)
  └ /review        (선택) 고위험·배포본 변경이면 다른 세션/에이전트에 문서형 리뷰 요청 → 반영
  └ 완료            DoD 충족 → lane wip/done/ 이동 + _meta 기록
```

- **자연 흐름 자동제안**: PRD/PRD-tree 갱신·기획 스킬 종료 등 *단계 경계*에서 다음 스킬·목업을 **1회** 추천(강제 X, 거절 시 다음 경계까지 침묵). 선택지 질문은 체크박스로.
- **세션 유지**(긴 작업): hook이 매 프롬프트 키워드 컨텍스트 주입 + 8턴마다 체크포인트. 50~60%에서 `/checkpoint`, 에이전트 전환 시 `/handoff`.
- **교차 검증**: 중요한 변경은 `/review`로 문서형 라운드트립 — Codex(또는 Claude) **독립 리뷰** → `.claude/pawpad/reviews/`에 PASS/findings 기록 후 반영 (codex exec 자율 리뷰 대비 저토큰·보완).

> 상황별 "이럴 땐 이 스킬"은 [`USAGE.md`](USAGE.md), 기능 1개 단계별 워크스루는 [`GUIDE.md`](GUIDE.md).

---

## 자동화 (양 런타임 hook)

**Claude Code** (`.claude/settings.json`, `run-hook.ps1` wrapper 경유):
- **SessionStart**: `.ctxdb/INDEX.md` 라우터 + codemap(토글) 주입 + 세션 state reset
- **UserPromptSubmit** (`ctxdb-inject.ps1`): 프롬프트 키워드로 **L1≤1/L2≤2 최소 주입** (같은 세션 재주입 방지 dedupe)
- **PreCompact** (`pre-compact.ps1`): native compaction 직전 `context-saver` 유도 (Stop 8턴과 중복 가드)
- **Stop** (`stop-check.ps1`): 8턴마다 `decision:block` 체크포인트 + L2 분할 품질강제
- **statusLine** (`statusline.ps1`): 매 턴 컨텍스트 사용%(예: `ctx 31% (62k/200k)`)

**Codex** (`.codex/hooks.json`, `/hooks` trust 후): SessionStart/UserPromptSubmit/PreCompact/Stop 동일 구조를 cwd 상위탐색 self-locating launcher로 실행. 미신뢰/비활성 시 SKILL.md 수동 절차로 graceful degrade.

> 양 런타임 hook은 **임의 cwd(root + 하위)**에서 동작 검증됨. 절대경로는 forward-slash + 동적 타겟루트, **setup이 생성하는** hook `.ps1`은 BOM UTF-8(CP949 한글 안전).

## .ctxdb 토큰 절약 (키워드 depth DB) + 3계층 컨텍스트

- `INDEX.md`(키워드→L1) → `L1/domain-*.md`(L2 포인터) → `L2/*.md`(상세)의 3계층. 키워드 매칭으로 **L1≤1/L2≤2만** 로드.
- **3자 분리**: `codemap`=심볼 위치(저고도) · `codebase-map`=구조/관례(고고도) · `.ctxdb L2`=작업 내러티브/결정
- 효과는 조건부: 누적 큰 프로젝트 + 다세션일 때 유효. 작은/단일세션은 오버헤드 — 무지성 적용 금지.

---

## 설치 검증

```powershell
# 스킬 19개 frontmatter (no-BOM, --- 로 시작)
(Get-ChildItem .claude\skills -Directory).Count   # 19

# hook 등록 확인 (5종 = hooks 4 + statusLine, forward-slash)
$j=(Get-Content .claude\settings.json -Raw | ConvertFrom-Json); $j.hooks.PSObject.Properties.Name; if($j.statusLine){'statusLine'}

# Codex skills 배열 19
(Get-Content .codex\config.json -Raw | ConvertFrom-Json).skills.Count   # 19

# 스크립트 STATUS
Get-Content .\pawpad-setup.ps1 -TotalCount 2   # v2.37 Unified ... FROZEN
```

설치 후 첫 작업은 보통 `/clarity` 또는 `/resume`로 시작한다.

---

## 사용 가이드

- **처음이면 / 바이브 코딩** → **[`USAGE.md`](USAGE.md)** : 상황별 "이럴 땐 이 스킬" 표 + 흐름 예시 + FAQ
- **기능 1개 기획→완성→배포** 단계별 워크스루 → **[`GUIDE.md`](GUIDE.md)**
- 변경 이력: `docs/CHANGELOG_v2.37.md` (이전: v2.18~v2.36)
- hook 회귀 체크리스트: `docs/HOOK_TESTING.md`
- 협업 프로토콜 상세: `.claude/HYBRID.md`

## 버전 / 변경 정책

`v2.37 FROZEN` (Unified Claude + Codex Distribution). 변경 시 **새 버전 번호 + 변경 보고서 + Codex 리뷰** 절차를 따른다. 동결본을 직접 고치지 않는다.
기존 설치 환경의 버전 업그레이드는 `-Upgrade` 모드 사용 (툴킷 파일만 갱신, 사용자 데이터 보존).
