# CHANGELOG v2.42 — analyze hook stderr 피드백 fix

## Summary
v2.41을 적용(`-Upgrade`)한 프로젝트에서도 PostToolUse:Edit hook이 다음 에러로 계속 실패한다는 리포트를 받았다:
```
Failed with non-blocking status code: No stderr output
PostToolUse:Edit hook returned blocking error [powershell ... run-hook.ps1 analyze.ps1]: No stderr output
```
v2.41은 "bash가 hook command를 실행 자체를 못 찾던" 문제(디스패치 실패)만 고쳤을 뿐이었고, 이번은 **디스패치는 성공하지만 진단 결과가 agent에게 전달되지 않는** 별개의 설계 결함이다.

## Root Cause
claude-code-guide 서브에이전트로 Claude Code 공식 문서를 조사해 확인:
- `PostToolUse` hook은 Tool이 이미 실행된 뒤 호출되므로 **항상 non-blocking**이며, exit 2일 때만 **stderr**를 agent에게 전달한다(공식 문서: "exit 2: Shows stderr to Claude (tool already ran)"). stdout은 `updatedToolOutput` JSON 파싱 용도로만 쓰이고 일반 텍스트로는 무시된다.
- 기존 analyze 커맨드(`dart analyze | Select-Object -Last 5` / `npx tsc --noEmit | Select-Object -Last 5` / `mypy . | Select-Object -Last 5`, Unix는 `| tail -5`)는 진단 결과를 **stdout에만** 출력했다. 이 자체는 v2.41 이전부터, 즉 analyze 훅이 처음 설계될 때부터 있던 결함이다.
- 결과: 타입 에러 등으로 analyze 커맨드가 nonzero exit 하면, hook 프로세스도 nonzero(때때로 2)로 종료되어 Claude Code가 "blocking error" 알림을 띄우지만, stderr가 비어 있어 agent는 실제 진단 내용을 전혀 받지 못하고 "No stderr output"만 본다 — 애초 의도(Edit 직후 lint/typecheck 피드백)가 동작하지 않고 있었다.

## Changed
- `pawpad-setup.ps1`
  - `.claude/hooks/analyze.ps1`(Windows) 생성 내용 변경: 진단 결과를 변수로 캡처(`( <원래 파이프라인> ) | Out-String`) → `$LASTEXITCODE`가 nonzero면 `[Console]::Error.Write(...)`로 stderr에 재전송 + `exit 2`, 클린이면 `exit 0`.
  - `.claude/hooks/analyze.sh`(Unix, **신규**) 생성 — 기존엔 wrapper 파일 없이 raw bash 커맨드를 settings.json에 그대로 넣었음(`$p.AnalyzeBash` 직접 삽입). 동일한 캡처→stderr 재전송→exit 2/0 패턴을 bash로 구현(`out=$(... 2>&1); code=$?; if [ $code -ne 0 ]; then echo "$out" >&2; exit 2; fi; exit 0`).
  - `$analyzeCmd`(Unix)가 이제 `bash $claudeHookRoot/analyze.sh`를 가리키도록 변경(과거엔 raw pipeline 직삽입).

## Verification
- PSParser 전체 스크립트 parse-ok(구문 에러 0). 생성된 `analyze.ps1`/`analyze.sh` 문자열을 별도로 PowerShell 파서·수동 검토로 이스케이프 정확성 확인.
- 샌드박스 설치(`-Stack node -Force`) 후 두 시나리오를 bash 디스패치로 직접 재현:
  - **에러 시나리오**(가짜 진단 + nonzero exit) → `bash -c "<생성된 command>"` 실행 결과 `exit=2`, stderr에 진단 텍스트 정확히 캡처됨.
  - **클린 시나리오**(exit 0) → `exit=0`, stderr 비어있음(불필요한 알림 없음) 확인.
- 타 훅(session/prompt/compact/stop/status) 영향 없음(analyze 전용 변경).

## Notes
- 이미 설치된 다운스트림 프로젝트가 이 fix를 받으려면 `-Upgrade` 재실행 필요(v2.41만 적용하고 v2.42 안 받으면 여전히 "No stderr output" 재현됨 — 별개 버그이므로 v2.41 단독 반영으로는 해결 안 됨).
- 급하면 수동 반영 가능: `.claude/hooks/analyze.ps1`(Windows) 또는 `.claude/hooks/analyze.sh`(Unix) 내용을 이 버전의 패턴대로 교체 + Unix는 settings.json PostToolUse command를 `bash .claude/hooks/analyze.sh`로 변경.
- 스킬 수 19 불변, 다른 훅·기능 로직 변경 없음.
