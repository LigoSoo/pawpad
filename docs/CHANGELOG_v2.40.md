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
  - Lookup 알고리즘 (최대 3 read): 한국어/증상→keywords **통째 read 후 의미·맥락 매칭**(grep 아님, agent가 의도로 해석 → 표현/공백 흔들림 강건)→leaf→source / 영문 심볼→features rg 정확매칭 / codemap전체·keywords grep정확매칭·통째읽기 금지.
  - keywords.md 작성 지향: 동의어 나열보다 "의도·증상→feature" 서술(정확 단어 불요, agent가 의미 매칭).
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
- lookup 의미매칭 명시(v2.40 내 보강): 자연어 키워드는 grep 정확매칭이 아니라 agent가 keywords.md를 의미로 해석 → "최근완료"="최근 완료" 등 표현/공백 흔들림 무영향(취약점은 source 직접 grep 쪽). downstream(TodayQuest) 52KB→trim-router 실마이그레이션 + 3-케이스 토큰실험에서 도출: ①라벨 greppable=평탄 grep 우위 ②대형파일 통째읽기 사고=codemap ~85% 상한 ③증상형(grep 불가)=토큰 무승부+decoy 회피/정타율이 codemap 가치.

## Addendum (v2.40 내 보강, 2026-07-01) — analyze hook 2단계 fix
다운스트림(TodayQuest, Windows) `PostToolUse:Edit` 훅이 Claude Code 업데이트 이후 두 단계에 걸쳐 실패한다는 리포트를 받아 같은 세션에서 연속 수정. 신규 버전 번호 없이 v2.40에 보강(사소 패치, BOM-fix(v2.25) 선례와 동일 정책).

**원인1 — bash 디스패치 미스매치**: Windows analyze 커맨드(`$p.AnalyzePS`, 예 `npx tsc --noEmit | Select-Object -Last 5`)를 settings.json `"command"`에 raw PowerShell 파이프라인으로 직접 삽입해왔다. 다른 훅(session/prompt/compact/stop/status)은 전부 `-File`로 powershell.exe를 명시 호출하는데 analyze만 예외였다. Claude Code가 hook command를 Git Bash로 디스패치하면서 bash가 모르는 `Select-Object`에서 `Select-Object: command not found`로 실패. 최초 수정안(`-Command '...'` 인라인 래핑)을 서브에이전트로 교차 리뷰한 결과 cmd.exe 경유 디스패치 시 재파손 가능하다는 지적을 받아, 다른 훅과 동일한 `-File` 스크립트 실행(`.claude/hooks/analyze.ps1` 신규)으로 재설계.

**원인2 — stderr 미전달**: 위 수정 반영 후에도 `blocking error ... No stderr output`이 재현됨. claude-code-guide 서브에이전트로 Claude Code 공식 문서를 조사해 `PostToolUse` hook은 **exit 2일 때만 stderr**를 agent에게 전달(stdout은 무시)함을 확인. analyze 커맨드는 애초부터 진단 결과를 stdout(`Select-Object`/`tail`)으로만 출력해왔으므로, 에러가 있어도 agent는 내용을 전혀 받지 못했다(analyze 훅이 처음 설계된 이래 있던 결함으로, "Edit 직후 lint/typecheck 피드백"이라는 원래 의도가 한 번도 동작한 적이 없었음).

**수정**: 진단 결과를 캡처해 stderr로 재전송 + exit 2(에러 있음)/0(클린) 정규화. Windows(`analyze.ps1`) + 신규 Unix(`analyze.sh`, 기존엔 wrapper 파일도 없이 raw bash 커맨드였음) 동일 패턴.

**검증**: PSParser parse-ok. 샌드박스 설치(`-Stack node -Force`) 후 실패/클린 양쪽 시나리오를 `bash -c "<생성된 command>"`로 직접 재현 — 에러 시나리오: exit=2 + stderr에 진단 텍스트 정확히 캡처, 클린 시나리오: exit=0 + stderr 비어있음. 다운스트림 반영은 `-Upgrade` 재실행 필요. 스킬 19·다른 훅 로직 불변.
