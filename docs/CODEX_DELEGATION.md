# Codex 위임 실행 보완

## 범위
v2.52 기반 Codex 전용 보완. `code-delegate`는 사용자 model/effort 명시, 독립 컨텍스트, 짧은 결과 회수, 런타임 제약 내 대기를 사용한다. AGENTS의 Codex 섹션은 UTF-8 읽기와 이미 읽은 범위 재사용을 안내한다. 모델 기본값·지원 목록·대기 시간을 하드코딩하지 않는다.

`pawpad-setup.ps1`의 `$codexCodeDelegateSkill`이 Codex 전용 스킬의 원본이다. 다른 스킬은 기존 `.claude/skills` 미러를 유지한다. `.agents`만 수정하면 재생성 때 사라지므로 생성기와 산출물을 함께 갱신한다. 기존 설치에는 `-Upgrade`를 사용한다(기본 실행은 기존 파일을 건너뜀).

Claude용 CLAUDE.md, 스킬, hook 동작은 유지한다. checkpoint/dedupe/pointer 알고리즘, 기획·디자인·품질 기준과 앱 코드는 변경하지 않는다. 이 변경은 LLM이 읽는 실행 지침이며 서버에서 모델 설정이나 호출 횟수를 강제하는 기능이 아니다.

## 검증
- `powershell -NoProfile -ExecutionPolicy Bypass -File tests/codex-delegation/run-generation-tests.ps1`
- baseline은 수정 전 v2.52 commit `3081267deaaab562783440ec8cd343f4a03511ca`. 다른 기준이면 `-BaselineRef`로 명시한다. 해당 git object가 필요하다.
- 임시 설치처에서 신규/업그레이드/반복 업그레이드/lean 제외, 사용자 데이터 보존, Claude 파일 동일성을 검사한다. fixture/log는 TEMP에 남기며 실제 설치처는 변경하지 않는다.
- 기존 `tests/ctxdb-recall/run-recall-tests.ps1`을 Claude/Codex hook 각각에 실행한다.
- 생성 검증은 설치 결과를 확인한다. 실제 LLM이 설정·대기·판정을 올바르게 수행하는지는 별도 행동 검증 대상이다.
- 2026-09-11: 생성 회귀 18/18, ctxdb Claude 20/20(+Codex 전용 1 skip), Codex 21/21 통과. 신규 설치 Claude 파일 40개·다른 Codex 스킬 21개 바이트 동일, 업그레이드 Claude 스킬/hook 39개 바이트 동일 및 CLAUDE.md 본문 보존 확인.
- PowerShell 구문·frontmatter(이름/설명/길이/placeholder/BOM) 직접 검사 통과. skill-creator의 Python quick_validate.py는 이 실행 환경에 Python이 없어 실행하지 않았다. 변경 5파일 보안 패턴·수동 검토에서 critical 0.

## 효과의 한계
실측에서 독립 컨텍스트 격리는 작동했으나 부모 대기 후 모델 호출과 하위 구현 보완 비용이 있었다. 큰 캐시 미스도 확인됐다. 모델/effort 지정 누락과 읽기 방식은 이번 범위에 포함하되, 절감률과 품질 개선은 아직 측정하지 않았다. 부모·하위 합산 input/cached input/output과 같은 완료 기준으로 비교해야 한다.

모델을 호출하는 A/B 실험, 자동 세션 분리, 기존 앱 업그레이드·배포는 이 변경에 포함하지 않는다.

## 롤백
변경 전 브랜치 `backup/pre-codex-token-fix-20260911`, 작업 브랜치 `fix/codex-delegation-cost`. 미커밋 사용자 변경을 확인한 뒤 이전 브랜치로 전환한다. 이미 설치한 프로젝트의 복원은 설치 전 자동 백업과 해당 프로젝트 git 상태를 기준으로 별도 수행한다.
