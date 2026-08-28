# CHANGELOG v2.49 — codemap size cap 자동 감시

| 항목 | 값 |
|------|-----|
| 날짜 | 2026-08-28 |
| 기반 | v2.48 |
| 스킬 수 | 21 (불변) |
| 성격 | 훅 기능 추가 + 스킬 문서 1절 교체 |

## 1. 문제

`codemap` size cap(`_root.md` 2KB / leaf 4KB)은 **v2.40(2026-06-30, trim-router)부터 규칙으로 존재**했다.
그런데 **집행하는 장치가 하나도 없었다.**

| 집행 표면 | 상태 |
|---|---|
| 훅 10개 | 크기 검사 **0건** (`2048`/`4096` 문자열 0) |
| `task-done` SKILL 체크리스트 | 항목 없음 |
| `CLAUDE.md` DoD #5 | cap 미언급 |
| `codemap/SKILL.md` size cap 절 | 검사 절차를 `spec(codemap-8kb-router.md Acceptance)`로 위임 — **그 파일은 설치처에 없다**(빈 포인터) |

결과: 설치처 `dblogscope_claude`에서 **2개월 만에 41개 중 14개가 상한 초과**(초과 합 46,168 B).
최악은 `features/ingestion.md` 18,021 B = cap의 **4.4배**.

### 왜 단조 증가하나 — 비대칭
```
커지는 쪽 ── 매 작업마다 agent가 leaf에 append
             + Stop hook이 8턴마다 "codemap 갱신하라"고 재촉          ← 가속됨
줄이는 쪽 ── 아무도 재지 않음. 규칙은 SKILL.md 문서에만 존재         ← 부재
```

### 결정적 대조
**같은 `stop-check` 훅이 `.ctxdb/L2`는 크기를 실측한다** — 150줄/2000토큰 초과 시
`[L2 split needed]` 차단 블록을 내고 세션 시그니처로 dedupe까지 한다
(`.claude/hooks/stop-check.ps1:211-222` / `.sh:172-201` / `.codex/hooks/stop-check.ps1:75-110`).

동일 훅 · 동일 문제("조회 때 통째로 읽히므로 크면 절감이 무력화") · 동일 해법(분할).
**codemap만 대상에서 빠져 있었다.**

## 2. 수정

### 2.1 훅 3표면에 codemap size cap 점검 추가
| 표면 | 파일 |
|---|---|
| Claude PowerShell | `.claude/hooks/stop-check.ps1` |
| Claude bash 포트 | `.claude/hooks/stop-check.sh` |
| Codex | `.codex/hooks/stop-check.ps1` |

(`.codex/hooks/stop-check.sh`는 `.ps1`을 exec 하는 shim — 수정 대상 아님)

**cap 3단**
| 대상 | cap | 근거 |
|---|---|---|
| `_root.md` | 2,048 | route 전용, 모든 조회의 길목 |
| **`_index.md`** | **30,720** | **Phase A flat 상한.** 4,096을 걸면 Phase A(미전환) 저장소가 **전량 오탐**한다. 30KB는 SKILL의 Phase A→B 전환 임계값이라 그 자리에서 "Phase B로 가라"가 맞는 신호다 |
| 그 외 | 4,096 | Phase B leaf·keywords·hot-archive |

**동작**
- 초과 파일을 `상대경로(bytes/cap)` 형태로 수집 (하위 디렉터리 동명 파일 구분)
- 세션별 시그니처 dedupe — state 파일은 **L2와 분리**(`claude-codemap-warned` / `codex-codemap-warned`).
  섞으면 한쪽 해소가 다른 쪽 경고를 지운다
- 초과 시 `[codemap split needed]` `decision:block` 1회

**안내 문구**
> 하위 leaf(`features/{id}/{subtopic}.md`)로 쪼개고 **원본은 라우팅 스텁으로 남긴다**(기존 포인터 보존).
> `_index.md`가 초과면 Phase B(trim-router)로 전환.

### 2.2 `codemap/SKILL.md` size cap 절 교체 (live + `.agents` 미러 + setup 임베드)
빈 포인터(`spec codemap-8kb-router.md`)를 제거하고 cap 3단 + 자동 집행 + 스텁 규약으로 교체.

## 3. 근거 — 설치처 실측

`dblogscope_claude`(248 `.cs` / 1.82 MB / Phase B codemap)에서 14파일을 하위 leaf로 분할한 결과:

| 항목 | 전 | 후 |
|---|---|---|
| codemap `.md` | 41 | 79 |
| size cap FAIL | **14** | **0** |
| 초과 합 | 46,168 B | 0 |
| 대표 조회 경로 | 41,912 B (~12.3k tok) | **7,167 B (~2.1k tok)** |
| 절감 | — | **-83%** |
| dangling 링크 | — | **0** (내부 213건 + pawpad 참조 전수) |

대표 경로 = 실제 lane `ingest-log-delete` 재현
(`_root` + `keywords` + `keywords/ingest` + `wpf/ingestion-manage`(스텁) + `.../traps`).

## 4. 검증

### 4.1 기능 12/12 (3런타임 × 4케이스)
| 케이스 | Claude ps1 | Claude sh | Codex ps1 |
|---|---|---|---|
| Phase B 초과 leaf 5,000 B → 경고 | PASS | PASS | PASS |
| 같은 세션 재실행 → dedupe(무경고) | PASS | PASS | PASS |
| **Phase A `_index.md` 20 KB → 무경고**(오탐 시험) | PASS | PASS | PASS |
| `_index.md` 35 KB → 경고 | PASS | PASS | PASS |

### 4.2 정적
- `PSParser` 오류 **0** (`.claude`·`.codex` 훅)
- `bash -n` OK
- **live == setup 임베드** byte 대조 3/3 IDENTICAL
- `.agents` 미러 = live + 생성 헤더 1줄(writer 규약) — 본문 동일

## 5. 범위 밖 (Won't)
- `task-done` 체크리스트 / `CLAUDE.md` DoD #5 항목 추가 — **훅이 자동 집행**하므로 중복.
  항목 인플레를 만들지 않는다.
- 자동 분할 실행 — 어디서 자를지는 의미 판단이라 사람/agent 몫. 훅은 **지적만** 한다.

## 6. 업그레이드
기존 설치는 `pawpad-setup.ps1 -Upgrade` 재실행.
설치 직후 codemap이 이미 상한 안이면 아무 변화도 보이지 않는 것이 정상이다.

⚠ **훅은 세션 중 교체돼도 반영되지 않는다** — `-Upgrade` 후 Claude Code 재시작이 필요하다(v2.48 관측).
---

## 사후수정#1 (2026-08-28, 버전 불변)

### 문제 — Phase B에서 SessionStart codemap 주입이 조용히 꺼진다
toolkit 자체 codemap을 Phase B로 전환하다 발견했다.

`session-start` 훅의 auto 판정은 `.claude/codemap/_index.md`의 `# INDEX` 심볼 줄을 세어
임계값(기본 60) 이상이면 주입한다. 그런데 **Phase B에서 `_index.md`는 라우팅 스텁**이라
심볼이 0줄이다 → 항상 미달 → 주입이 꺼진다. `inject=on`으로 강제해도 주입되는 것은
스텁 5줄뿐이라 조망 가치가 없다.

v2.47이 Session Protocol step7을 "`_root.md` 우선, 없으면 `_index.md`"로 고쳤는데
**훅은 같이 고치지 않았다.** 결과적으로 **저장소가 클수록(=Phase B로 갈수록) 주입이 사라지는**
역전이 남아 있었다. 이번에 codemap cap 감시를 넣으면서 Phase B 전환이 실제로 일어나
드러났다.

### 수정 (4표면)
| 표면 | 내용 |
|---|---|
| `.claude/hooks/session-start.ps1` | auto 판정에 `_root.md` 존재 시 즉시 true(이미 30KB 넘겨 전환한 대형) + 주입 대상 `_root.md` 우선 |
| `.claude/hooks/session-start.sh` | 동일 포팅(`cmr` 변수, `elif [ -f "$cmr" ]; then inject=1`) |
| `pawpad-setup.ps1` 임베드 ×2 | 위 둘의 배포 사본 |

`.codex/hooks/session-start.*`는 codemap을 읽지 않아 대상이 아니다(실측 0건).

### 검증
- 양 런타임에서 Phase B 저장소(toolkit 자신) 주입 결과에 `# ROUTE`(=`_root.md` 본문) 포함,
  `inject skipped` 미발생
- PSParser 0 · `bash -n` OK · **live == setup 임베드 5/5 byte 대조**
- toolkit codemap Phase B 전환 실측: flat 30,127 B(심볼 117) → `_root` 1,729 + `keywords` 2,102
  + `features/` 13 leaf, **cap 전수 PASS 16파일 / FAIL 0**, 심볼 117 전건 보존
