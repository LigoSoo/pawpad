#!/usr/bin/env sh
set -eu

if command -v pwsh >/dev/null 2>&1; then
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  exec pwsh -NoProfile -File "$script_dir/ctxdb-inject.ps1"
fi

printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"ctxdb: hook-skip | - | L2 0 files | pwsh not found for .codex/hooks/ctxdb-inject.sh"}}'
