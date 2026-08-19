#!/bin/sh
# Weekly wrapper: run the token budget check, log it, and notify only when
# something is over budget (a clean week stays silent).
set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
log_dir="$config_dir/evidence/context_budget"
mkdir -p "$log_dir"
log_file="$log_dir/$(date +%Y-%m-%d).txt"

if python3 "$config_dir/context_budget_check.py" >"$log_file" 2>&1; then
  exit 0
fi

osascript -e 'display notification "Launch-context token budget exceeded. See ~/.dotfiles/agent-config/evidence/context_budget/" with title "Claude context budget"' >/dev/null 2>&1 || true
cat "$log_file"
exit 1
