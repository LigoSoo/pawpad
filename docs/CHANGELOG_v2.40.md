# CHANGELOG v2.40 — codemap trim-router (small-page)

## Summary
codemap 성장 전략을 flat single-index에서 **trim-router(small-page)**로 전환. 대규모(50KB+) codemap에서 "실수로 통째읽기" 토큰 사고를 구조적으로 봉쇄하고, 한국어/자연어 키워드 fanout을 해소한다. grep lookup 성능은 불변(다운사이드 0). 스킬 내용 갱신, 스킬 수 19 불변.

배경: 실측 다운스트림 앱(중소 규모 Flutter)의 `_index.md`가 50,975 bytes / 167 entries로 비대. 통째읽기 시 ~14K tokens. 기존 ON START 부분읽기(v2.38)로 평상시는 방어되나, 50KB flat 파일은 사고 유발 표면이 크고 한국어 키워드("발급")는 grep fanout이 컸다.

## Changed
- **codemap SKILL.md 성장 전략 재작성** (live `.claude/skills/codemap` + `.agents` 미러 + setup embed 3곳 동기):
  - Phase A — flat (~30KB/~80 entries 이하): 단일 `_index.md`, feature 섹션 그룹.
  - Phase B — trim-router (초과 또는 통째읽기 사고 빈발):
    - `_root.md` — route + MAP + HOT. source pointer 금지. hard-cap **2KB**.
    - `keywords.md` — 한국어/동의어를 feature로 라우팅. source pointer 금지. hard-cap **4KB**.
    - `features/{feature-id}.md` — source pointer + 최소 판단근거. hard-cap **4KB**.
  - **domain 중간층 없음** (feature leaf와 내용 중복·3중쓰기 drift 유발 → 스팩 원안에서 제외 = trim).
  - Lookup 알고리즘 (최대 3 read): 한국어→keywords→leaf→source / 영문 심볼→features grep 직행 / 통째읽기 금지.
  - **generated 제외**: `*.g.dart`, `*.freezed.dart`, `lib/generated/**` 는 source pointer 대상 아님. fallback rg에 exclude glob.
  - entry **1줄 규율** 강조(긴 문단 entry가 진짜 bloat 원인 — 상세는 spec/lane).
  - size cap 완료 게이트(root 2KB / 그외 4KB UTF-8 byte).
- `_index.md` 템플릿 헤더 주석 갱신(Phase A/B domain-routing → trim-router 안내).

## Verification
- account-link **pilot** (실측 50KB 데이터 기준, `.claude/pawpad/analysis/codemap-pilot/`):
  - size check: `_root.md` 1067/2048, `keywords.md` 1212/4096, `features/account-link.md` 1985/4096 → **ALL PASS**.
  - lookup "자녀코드 발급" → `_LinkCodeTile._issue` + `AccountLinkStore.issueCode` ✅
  - lookup "자녀 코드 입력" → `_ChildLinkSection._link` + `AccountLinkController.linkByCode` ✅
  - non-circular: 4개 심볼 실제 소스 실재 확인(settings_screen.dart:164, account_link_store.dart:27/48/120, parent_dashboard_screen.dart:268/339).
- 효과: 통째읽기 사고 최악값 ~14K tok → 페이지 max 4KB(~1.1K) 봉쇄. 한국어 lookup fanout ~1.5K → keywords+leaf ~0.9K + 모호 해소. 영문 grep 직행 ~0.5K 불변.
- live ↔ `.agents` 미러 ↔ setup embed 본문 byte 동기. setup PSParser parse-ok.

## Notes
- 동작 변경은 codemap lookup 방법론(에이전트 지침)만. 코드 로직·hook·스킬 수(19) 불변.
- 전체 167 entry 마이그레이션은 다운스트림 프로젝트 작업(pilot로 방법론 검증 완료). 본 릴리스는 방법론 배포.
- trim-router는 **size-aware**: 소규모 codemap(~30KB 이하)은 flat 유지 권장(분할 과설계 회피).
