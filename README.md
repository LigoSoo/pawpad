# PawPad — Agentic Engineering Toolkit (v2.22 FROZEN)

Claude Code ⇄ Codex 하이브리드 협업을 위한 **멀티에이전트 상태관리 + 토큰절약 하니스**.
하나의 PowerShell 스크립트로 어떤 프로젝트에든 15개 스킬 · PawPad 상태머신 · 양 런타임 자동화 hook · 키워드 컨텍스트 DB · 7축 코드베이스 맵 · 보안 검증 게이트를 설치한다.

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

설치할 프로젝트 **루트**에 `pawpad-setup.ps1`를 복사한 뒤:

```powershell
# 신규 설치 (기존 파일은 건너뜀). -Stack 생략 시 대화형 선택
.\pawpad-setup.ps1 -Stack generic

# 재설치 / 덮어쓰기 (사용자 데이터 자동 백업 → .claude/pawpad/backup/{timestamp}/)
.\pawpad-setup.ps1 -Stack generic -Force

# 기존 설치 업그레이드 (툴킷 파일만 갱신, PawPad/커스텀 보존, 혼합 파일은 툴킷 섹션·키만 자동 병합)
.\pawpad-setup.ps1 -Upgrade
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
CLAUDE.md / AGENTS.md            # 에이전트 컨텍스트 (Claude / Codex), v2.22 하드닝 반영 (DoD#8 보안 게이트)
pawpad-setup.ps1     # 통합 단일 설치 스크립트 (FROZEN v2.22)
.codex/
├── config.json                  # Codex 보조 설정 (skills 15 + context/backup keys)
├── config.toml                  # project config layer note
├── hooks.json                   # Codex lifecycle hook router (SessionStart/UserPromptSubmit/PreCompact/Stop)
└── hooks/{*.ps1,*.sh}           # Codex native hooks (cwd 상위탐색 self-location)
.agents/skills/{15}/SKILL.md     # Codex repo skill mirror (.claude/skills 단일소스, DO NOT EDIT 헤더)
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
├── SKILLS_MANIFEST.md           # 스킬 카탈로그 (15)
├── skills/{15}/SKILL.md         # 스킬 정의 (no-BOM, --- frontmatter)
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

## 스킬 15개

### Core — 상태/코드
| 스킬 | 용도 |
|------|------|
| `/memory` | 세션 시작 재개 프로토콜 (HYBRID/_wip/lane/meta/codemap 읽기) |
| `/codemap` | 심볼(클래스/함수/위젯) **위치** 레지스트리, owner 분리 권한 |
| `/codebase-map` | **7축 고수준 맵** (아키텍처/구조/관례/테스트/관심사). codemap=위치, codebase-map=구조·관례. digest-only 주입 |
| `/ctxdb-navigator` | **키워드 depth 컨텍스트 최소 로드** (토큰 절약) |
| `/context-saver` | 세션 작업을 `.ctxdb/L2`에 저장 + AGENT SYNC 갱신 |
| `/clarity` | 구현 전 요청 모호도 5차원 스코어링, 재질문 |
| `/design` | 화면/컴포넌트 UI/UX 설계 게이트 (토큰→레이아웃→원칙) |
| `/karpathy` | 코드 작성 시 과설계/범위이탈 방지 가드레일 |
| `/caveman` | 응답 압축 모드 (기본 ON, `normal mode`로 해제) |
| `/security-check` | **보안 검증 게이트** — secrets/취약점/위험 설정/PawPad 산출물 스캔, 🔴 검출 시 완료 BLOCK (DoD#8) |

### Workflow — 협업/기획
| 스킬 | 용도 |
|------|------|
| `/grill-me` | 계획/설계를 재귀 심문으로 스트레스 테스트 |
| `/grill-with-docs` | 위 + 용어집/ADR(`decisions/arch.md`) 갱신 |
| `/to-prd` | 대화 → PRD 변환 → `specs/` 저장 + lane `SPEC_READY` |
| `/checkpoint` | 컨텍스트 50~60% 롤오버 게이트 (lane/codemap/meta 저장) |
| `/handoff` | 다른 에이전트/세션 인수인계 (snapshot + owner 이전) |

> 스킬은 PowerShell 명령이 아니라 **instruction**. 에이전트가 SKILL.md 절차를 따라 파일을 읽고 쓴다.

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
# 스킬 15개 frontmatter (no-BOM, --- 로 시작)
(Get-ChildItem .claude\skills -Directory).Count   # 15

# hook 등록 확인 (5종 = hooks 4 + statusLine, forward-slash)
$j=(Get-Content .claude\settings.json -Raw | ConvertFrom-Json); $j.hooks.PSObject.Properties.Name; if($j.statusLine){'statusLine'}

# Codex skills 배열 15
(Get-Content .codex\config.json -Raw | ConvertFrom-Json).skills.Count   # 15

# 스크립트 STATUS
Get-Content .\pawpad-setup.ps1 -TotalCount 2   # v2.22 Unified ... FROZEN
```

설치 후 첫 작업은 보통 `/clarity` 또는 `/memory`로 시작한다.

---

## 사용 가이드

- **처음이면 / 바이브 코딩** → **[`USAGE.md`](USAGE.md)** : 상황별 "이럴 땐 이 스킬" 표 + 흐름 예시 + FAQ
- **기능 1개 기획→완성→배포** 단계별 워크스루 → **[`GUIDE.md`](GUIDE.md)**
- 변경 이력: `docs/CHANGELOG_v2.22.md` (이전: v2.18~v2.21)
- hook 회귀 체크리스트: `docs/HOOK_TESTING.md`
- 협업 프로토콜 상세: `.claude/HYBRID.md`

## 버전 / 변경 정책

`v2.22 FROZEN` (Unified Claude + Codex Distribution). 변경 시 **새 버전 번호 + 변경 보고서 + Codex 리뷰** 절차를 따른다. 동결본을 직접 고치지 않는다.
기존 설치 환경의 버전 업그레이드는 `-Upgrade` 모드 사용 (툴킷 파일만 갱신, 사용자 데이터 보존).
