# CHANGELOG v2.41 — analyze hook bash 디스패치 호환 fix

## Summary
Windows 설치에서 PostToolUse(analyze, `Write|Edit|MultiEdit` 후 정적분석) 훅이 Claude Code 업데이트 이후 다음 에러로 실패하는 문제 수정:
```
PostToolUse:Edit hook error: /usr/bin/bash: line 1: Select-Object: command not found
```
settings.json `"command"`에 raw PowerShell 파이프라인(`npx tsc --noEmit | Select-Object -Last 5` 등)을 직접 넣던 방식을, 다른 모든 훅(session-start/ctxdb-inject/pre-compact/stop-check/statusline)과 동일하게 `-File`로 `.ps1` 스크립트를 실행하는 방식으로 통일했다.

배경: Claude Code가 hook `"command"`을 Git Bash(`/usr/bin/bash`)로 디스패치하도록 바뀌면서, bash가 모르는 PowerShell cmdlet(`Select-Object`)이 그대로 노출된 raw 파이프라인 문자열이 깨졌다. 다른 훅들은 원래부터 `powershell -File ...` 형태로 powershell.exe를 명시 호출했기 때문에 영향이 없었고, analyze만 예외였다.

## Changed
- `pawpad-setup.ps1`
  - `$analyzeCmd`(Windows) 생성 방식 변경: raw pipeline(`$p.AnalyzePS`) 직접 삽입 → `powershell -NoProfile -ExecutionPolicy Bypass -File $claudeRunHook analyze.ps1`.
  - 신규 훅 파일 `.claude/hooks/analyze.ps1` 생성 — 스택별 `$p.AnalyzePS` 값(`dart analyze | Select-Object -Last 5` / `npx tsc --noEmit | Select-Object -Last 5` / `mypy . | Select-Object -Last 5`)을 그대로 파일 내용으로 기록. `run-hook.ps1`(root-aware wrapper)이 그대로 재사용되어 다른 훅과 동일하게 프로젝트 루트에서 실행된다.
  - Unix(AnalyzeBash, `... | tail -5`)는 변경 없음 — bash가 직접 실행하므로 원래부터 문제 없었음.

## Verification
- PSParser 전체 스크립트 parse-ok(구문 에러 0).
- 샌드박스 설치(`-Stack node -Force`, 임시 git repo)에서 생성된 `.claude/settings.json`의 PostToolUse `"command"` JSON 유효성 확인(`ConvertFrom-Json` 통과), `.claude/hooks/analyze.ps1` 내용이 `npx tsc --noEmit | Select-Object -Last 5`로 정확히 기록됨 확인.
- bash 디스패치 재현: 생성된 command 문자열을 `bash -c "..."`로 직접 실행 → 기존 `Select-Object: command not found` 에러 재현 안 됨(실행이 `run-hook.ps1` → `analyze.ps1` → 실제 `npx`/`tsc`까지 도달; 남은 실패는 샌드박스에 실제 TypeScript 프로젝트가 없어서 발생하는 무관한 환경 에러).
- 서브에이전트(Opus) 교차 리뷰 수행: 최초 수정안(`-Command '...'` 인라인 래핑)은 bash 디스패치에는 안전하나 **cmd.exe 경유 디스패치 시 작은따옴표가 파이프를 보호하지 못해 재파손 가능**하다는 지적 → 다른 훅과 동일한 `-File` 스크립트화로 대체해 bash/cmd 어느 경로든 안전하도록 재설계. 타 훅(session/prompt/compact/stop/status)은 원래부터 `-File` 방식이라 동일 클래스 문제 없음도 교차 확인. `Merge-JsonToolkitKeys`(-Upgrade 경로) 영향 없음 확인.

## Notes
- 이미 설치된 다운스트림 프로젝트가 이 fix를 받으려면 `-Upgrade` 재실행 필요. 급하면 해당 프로젝트 `.claude/settings.json`의 PostToolUse `"command"`를 `powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/run-hook.ps1 analyze.ps1` 형태로 바꾸고 `.claude/hooks/analyze.ps1`(스택별 원래 analyze 커맨드 그대로)을 추가하면 즉시 수동 반영 가능.
- 스킬 수 19 불변, 다른 훅·기능 로직 변경 없음(디스패치 견고성 fix에 한정).
