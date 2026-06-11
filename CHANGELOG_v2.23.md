# CHANGELOG v2.23 - Install UI: paw 배너 + 실시간 진행 바 + 설치 체크리스트

Date: 2026-06-11
Status: FROZEN
Base: v2.22 (`docs/CHANGELOG_v2.22.md`)
Lane: `setup-install-ui-v2.23`

## Summary
`pawpad-setup.ps1` 설치 경험 개선. pawpad-mark.png 발바닥 마크를 반블록 문자(▄▀█) 아트로 재현한 배너, 28단계 실시간 진행 바, 설치 종료 시 실측 결과 기반 2열 체크리스트 추가. **설치 내용물(생성 파일/스킬/훅) 변경 없음** — 출력 UI만 추가.

## Added
- `Show-PawBanner`: paw 아트 배너. pawpad-mark.png 형태 재현(위 toe bean 2 세로타원 + 옆 bean 2 + 메인 패드, 하단 중앙 패임 lobe). 색: 발바닥 코랄(38;2;240;130;130) / 라인·서브타이틀 민트(38;2;126;200;177). 스택 선택 프롬프트 전에 출력.
- `Write-UiLine`: ANSI truecolor 감지 시 escape 코드, 아니면 `-ForegroundColor` 폴백. 감지: WT_SESSION / ConEmuANSI / TERM_PROGRAM / pwsh 7+, 출력 리다이렉트 시 비활성.
- `Step-Begin` × 28: 설치 섹션마다 진행 바 1줄(`[██░░] 32% (10/28) skill: codemap`). 스킬 15종 전부 개별 단계로 표시.
- `Complete-CurrentStep`: 단계별 실측 판정 — 단계 중 `failed` 증가=`fail`, 쓰기 카운터(created/updated/merged) 증가=`ok`, 변화 없음=`skip`.
- `Show-InstallChecklist`: 완료 요약 직전 100% 바 + 28단계 2열 체크리스트(✓ 설치/갱신 · `-` 기존 유지 · ✗ 실패).
- 콘솔 UTF-8 보장: legacy cp949 콘솔에서 블록 문자 깨짐 방지(`[Console]::OutputEncoding` 65001 강제, try/catch).

## Changed
- 기존 텍스트 헤더(`PawPad ... | Setup v$ver` + `===` 줄) 제거 — 배너가 대체. Hybrid Harness/Project/Stack/Hooks 정보 줄은 유지.
- `.gitignore` 단계의 "Updating .gitignore..." 안내 줄 제거 — Step-Begin 진행 줄이 대체.
- `$ver` 2.22 → 2.23, 헤더 STATUS 갱신, 완료 요약에 설치 UI 항목 + CHANGELOG 참조 v2.23.

## 비변경 (보증)
- `Write-FileContent` / `Get-UpgradeAction` / 병합·백업·마이그레이션 로직 무변경.
- 생성되는 파일 목록·내용 무변경 (v2.23 버전 표기 제외).
- CREATED/SKIP/UPDATED/MERGED/FAILED per-file 로그 그대로 유지 (진행 바 아래 출력).
- `$stepTotal=28`은 Step-Begin 호출 수와 일치 유지 필요 — 불일치 시 % 표시만 어긋나고 설치 동작 무관 (주석 명시).

## Verification
- parse 0 errors (`Parser::ParseFile`), `Step-Begin` 호출 28 = `$stepTotal` 28
- fresh smoke (임시 디렉토리): 82 created | 0 failed, 배너/진행 바 0→100%/체크리스트 전 항목 ✓, EXIT 정상
- re-run smoke (동일 디렉토리 재실행): 82 skipped, 체크리스트 전 항목 `-` (기존 유지 실측 판정 확인)
- 리다이렉트 출력 환경: useAnsi 자동 비활성 → ConsoleColor 폴백 렌더 정상
- security-check: 변경분 Write-Host UI 코드만 — secrets/네트워크/외부실행 없음, 🔴 0

## Codex 교차 리뷰 (review-01 → fix 반영)
- 리뷰: `.claude/pawpad/reviews/setup-install-ui-v2.23-review-01.md` — `PASS_WITH_FIXES`, 충족도 92%. 무변경 보증/PS5.1/ANSI 폴백/BOM·cp949 전 항목 확인.
- **F1 🟡 반영**: `-Upgrade` 혼합 파일 단계가 MERGE-PENDING queue 시 `skip`으로 오표시되던 버그 수정 — `merge-q` 상태 추가(Step-Begin이 mergePending 수 스냅샷), 후단 병합 pass가 `mergePassHadFailure` 기록, 체크리스트 출력 시 `merge-q` → 병합 성공 `✓`/실패 `✗` 확정. 범례 "✓ 설치/갱신/병합".
- **F2 🟢 반영**: codemap `pawpad:setupScript` 중복 정리 — HOT 항목 v2.23 현행화, INDEX 구항목 `pawpad:setupScriptV221Historical`로 versioned 격리.
- fix 검증: parse 0 / fresh(82 created) → `-Upgrade`(62 updated | 4 merged | 0 failed) 시나리오에서 MERGE 4단계 전부 `✓` 표시 확인.

## Notes
- 배너/바 블록 문자는 한글 폰트에서 ambiguous-width 렌더 가능 — 닫힌 우측 테두리를 쓰지 않는 열린 레이아웃이라 정렬 깨짐 없음 (설계 의도).
