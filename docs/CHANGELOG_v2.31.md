# CHANGELOG v2.31 — 문서/lane 토큰 sharding (PRD Area-Sharding + Completed Task Log)

> 두 변경은 동일 의도(문서/lane 토큰 sharding)이며 작업 단위가 커서 2 lane으로 분리 진행했으나 **단일 버전 v2.31**로 묶는다. 둘 다 v2.30(Verification Evidence)의 "완료/audit 분리·활성만 hot" 자매.

## 변경: 프로젝트 PRD를 도메인 영역 단위로 shard + feature-id 라우팅

### 배경
기획 PRD가 단일 거대 파일로 누적(데모 `src/_PRD.md` 42KB). 기능 기획·구현, 체크포인트/handoff 재개 시 무관한 영역까지 전체 PRD read → 토큰 과소비. `.ctxdb`는 INDEX→L1→L2 키워드 depth 로딩으로 이 문제를 컨텍스트 DB엔 이미 해결했으나 프로젝트 PRD는 라우팅 밖. (메모: pawpad ON START는 PRD를 자동 로드하지 않음 — 이득 지점은 기획·구현·재개 시 PRD 참조.)

### 구조
```
src/PRD-tree.md      # 인덱스(SoT): 도메인 트리 + Feature ID + 영역 상태 마커 + 전역 개요(상단)
src/prd/{area}.md    # 영역별 상세 PRD (예: prd/TQ-AUTH.md) — 해당 영역 작업 시에만 read
```
기존 monolithic `src/PRD.md`/`src/_PRD.md`는 영역별로 흡수·분해(중복 제거). **자동 마이그레이션 없음, 이후 작업부터 적용**(v2.30 철학).

### 규칙
- **라우팅(D2)**: lane feature-id 접두 → 영역(TQ-FRIEND-03 → TQ-FRIEND) → `prd/TQ-FRIEND.md`만 read. 결정적·무추측(오라우팅 0). 부족 시 on-demand 추가(lazy, hard-skip 아님 → 무손실).
- **인덱스(D3)**: PRD-tree.md 단일 SoT. 신규 index 파일 금지(.ctxdb/INDEX 이중화 방지). 영역 행에 `✓완료/🔨진행/⬜예정` 마커.
- **완료 skip(D4)**: ✓완료 영역 shard 기본 read 안 함(on-demand). 물리 이동 없음(PRD 참조 가치 유지).
- **메커니즘(D5)**: instruction 기반(hook 아님). PRD read는 prompt 트리거 아닌 기획 행위 → hook 부적합 + 차단 머신 동작.

### Doc Update Rules 개정
- `New feature → src/PRD-tree.md(인덱스 행) + src/prd/{area}.md(상세)`
- `Feature/UX → src/prd/{area}.md`
- `New screen/route → Feature ID in PRD-tree.md(인덱스)` (유지)
- 신규 읽기 규율 1줄: "PRD 상세 read: PRD-tree(인덱스) → feature-id 영역 해석 → 해당 src/prd/{area}.md만(✓완료 skip, on-demand)".

### 영향받는 스킬
- to-prd: 무관·불변(기능별 specs/{id}.md는 별개 레이어).
- mockup: PRD-tree(인덱스) read 유지 → 동작 무관. "(+PRD)" → "(+ 해당 src/prd/{area}.md)" 정정(PRD.md deprecate). live+임베드+.agents 미러 동기.
- memory: PRD-tree 존속, 무관.

### 범위 외(의도)
- task-list = lane이 추적 주체 → 아래 ② Completed Task Log로 **동일 버전 내** 처리(별도 백로그 아티팩트 신설 X).
- 기존 monolithic PRD 자동 마이그레이션, 데모 예제 파일 실제 분할, 신규 index/스킬/hook, 완료 영역 물리 이동.

### 검증
PSParser parse-ok / embed==live(Doc Update Rules·읽기규율 CLAUDE·AGENTS×2) / mockup live==embed==.agents 미러 / stale 버전 grep 0 / 규약 경로 `src/prd/{area}.md` 일관 / security 🔴0. 신규 스킬 0(count 18 유지).

### 프로세스
brainstorming(superpowers; 축=도메인영역 / 라우팅=feature-id / 레이아웃=PRD-tree인덱스+prd/{area} / 스코프=PRD전용 / 완료=마커+skip) → spec(.claude/pawpad/specs/prd-area-sharding.md) → 구현 → /review(배포본 codex exec) → 동결.

---

## ② 추가 변경: Completed Task Log (lane 완료 작업항목 분리)

### 배경
lane 파일의 ✅완료 작업항목이 상세 구현노트째 여러 섹션에 무제한 누적 → 체크포인트/handoff 재개 시 매번 전체 재read. v2.30은 Verification Evidence만 분리, 완료 **작업항목**은 방치(실증: 실 lane `todayquest-mvp.md` ~100줄 대부분이 ✅완료 + 구현 로그).

### 구조·규칙
- `.claude/pawpad/verifications/{feature-id}-tasklog.md`(newest-first, add-only audit). lane은 archive 2종: `-archive.md`(검증) + `-tasklog.md`(완료작업), verifications/ 디렉터리 재사용(신규 dir 0).
- 보존: 미완/진행(⏳/⚠/🆕/무마커) 전수, 완료(✅)는 최근 세션분만 lane, 이전은 tasklog 이월 + 포인터 `> 완료 작업 M건 -> .claude/pawpad/verifications/{feature-id}-tasklog.md`.
- 트리거: ON checkpoint(/checkpoint·60% rollover) + ON TASK DONE. 완료판정 = ✅ 마커. instruction 기반.
- 규칙 위치: HYBRID "Completed Task Log" 섹션(Verification Evidence 옆) + checkpoint 스킬 step1 + Session Protocol ON TASK DONE.

### 검증
PSParser OK / embed==live(HYBRID 섹션·ON TASK DONE·checkpoint) / checkpoint live==embed==.agents 미러(byte-equal) / stale 0 / security 🔴0. 신규 스킬 0.

### 리뷰 (양 변경 각각 codex exec 자율 리뷰)
- PRD Area-Sharding: review-01 PASS_WITH_FIXES 92%(M 경로표기 → `src/prd/{area}.md` 정규화 반영).
- Completed Task Log: review-01 PASS_WITH_FIXES 96%(L checkpoint `.agents` 미러 EOF 1byte → setup -NoBom `content+CRLF` 로직 재생성, hash 정확 일치).

