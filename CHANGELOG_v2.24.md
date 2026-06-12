# CHANGELOG v2.24 - Install UI live 모드: 진행 바 1줄 제자리 갱신

Date: 2026-06-12
Status: FROZEN
Base: v2.23 (`docs/CHANGELOG_v2.23.md`, Codex 리뷰 PASS)
Lane: `setup-live-bar-v2.24`

## Summary
v2.23 설치 UI의 진행 바가 단계마다 새 줄로 찍혀 스크롤되던 것을, 지원 환경에서 **한 줄 제자리 갱신(live 모드)**으로 변경. 파일 단위 로그는 live 모드에서 숨김(실패/경고는 항상 표시), `-ShowLog`로 기존 상세 출력 복원. 배너 발바닥 아트 1줄 보정. **설치 내용물(생성 파일/스킬/훅) 무변경.**

## Added
- **live 모드** (`$script:uiLive = useAnsi && -not $ShowLog`):
  - `Step-Begin`: 진행 바를 `` `r ``(캐리지 리턴)로 같은 줄에 재출력. 이전 라벨이 더 길면 공백 패딩으로 잔상 제거 (`$script:lastBarLen` 추적).
  - `Write-InstallLog` 게이트: 파일 단위 로그(CREATED/UPDATED/SKIP/MERGE-Q/MERGED/mirror count)를 live 모드에서 숨김. `-Always` 플래그(FAILED/MERGE-FAIL/mirror WARNING)는 항상 출력 — 이때 바가 떠 있으면 줄 내림(`$script:barOnLine` 가드) 후 출력해 바를 침범하지 않음.
  - `Show-InstallChecklist`: live 바를 100%로 마지막 제자리 갱신 후 줄 확정 → 체크리스트 출력.
- **`-ShowLog` 스위치**: live 모드 끄고 v2.23 순차 출력(바 줄 + 파일 로그 전체) 복원.
- 폴백 자동: 비ANSI/legacy 콘솔/출력 리다이렉트(CI) 환경은 live 비활성 → 기존 순차 출력 그대로 (로그 보존).

## Changed
- 배너 발바닥 아트 보정: 4행 `▄██▄              ▄██▄` → `▄██▄     ▄▄▄▄     ▄██▄` (메인 패드 상단 곡선 — pawpad-mark.png 근사 향상). setup `Show-PawBanner` + README.md 코드블록 동기.
- `$ver` 2.23 → 2.24, 헤더 STATUS, Usage `[-ShowLog]`, 완료 요약 설치 UI 항목/CHANGELOG 참조.

## 비변경 (보증)
- 생성 파일 목록·내용 무변경 (버전 표기 제외). `Write-FileContent` 쓰기 정책/병합/백업/마이그레이션 로직 무변경 — 출력 함수만 `Write-Host` → `Write-InstallLog` 치환.
- 카운터($created/$updated/$merged/$skipped/$failed) 및 체크리스트 판정 로직(v2.23 merge-q 포함) 무변경.
- 폴백(비ANSI/리다이렉트) 출력은 v2.23과 동일 — smoke 로그 패턴(CREATED/SKIP/MERGED grep) 호환 유지.

## Verification
- parse 0 errors / Step-Begin 28 = $stepTotal 28 (불변)
- fresh smoke(리다이렉트=폴백 경로): 82 created | 0 failed, 새 배너 아트 출력, 체크리스트 전부 ✓
- upgrade smoke: 62 updated | 4 merged | 0 failed, MERGE 4단계 ✓ (v2.23 merge-q 회귀 없음)
- live 모드: 리다이렉트 캡처로는 검증 불가 — 실제 터미널(Windows Terminal)에서 육안 확인 필요 항목으로 명시
- security-check: 변경분 출력 코드 + 문서만 — 🔴 0

## Codex 교차 리뷰 (review-01 → fix 반영)
- 리뷰: `.claude/pawpad/reviews/setup-live-bar-v2.24-review-01.md` — `PASS_WITH_FIXES` 92%. stdout 라우팅 완전성(설치 구간 직접 Write-Host 0건)/live 정적 검증/폴백 보존/PS5.1/배너 동기 전부 PASS.
- **F1 🟡 반영**: `Merge-MdToolkitSections`/`Merge-JsonToolkitKeys`/`Update-Gitignore`의 write cmdlet에 `-ErrorAction Stop` + try/catch — 실패 시 `MERGE-FAIL`/`FAILED` `-Always` 출력 + `$failed++`, 성공 로그·카운터는 쓰기 성공 후에만 (기존 잠재 거짓 성공 경로 차단).
- **F2 🔵 반영**: codemap `pawpad:setupScript` v2.24 현행화 (~3990줄, live bar 이력 추가).
- fix 검증: 실패 주입 smoke(읽기전용 CLAUDE.md+.gitignore → -Upgrade): `MERGE-FAIL`/`FAILED` 표시 + `3 merged | 2 failed` + exit 1 + 체크리스트 ✗ / 정상 upgrade smoke: `4 merged | 0 failed` 회귀 없음 / parse 0.
- live 모드 육안 검증: 사용자 실제 터미널 실행으로 정상 동작 확인 (2026-06-12).

## Notes
- live 모드 전제: 바 갱신 사이 다른 stdout 출력 금지 — 설치 구간의 모든 직접 Write-Host를 Write-InstallLog로 라우팅했고, 사전 작업(백업/마이그레이션) 출력은 바 표시 전이라 영향 없음.
- 향후 설치 구간에 새 Write-Host 추가 시 반드시 Write-InstallLog 사용 (live 바 깨짐 방지).
