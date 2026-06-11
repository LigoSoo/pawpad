#!/usr/bin/env sh
set -eu

if command -v pwsh >/dev/null 2>&1; then
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  exec pwsh -NoProfile -File "$script_dir/stop-check.ps1"
fi

printf '%s\n' '{}'
