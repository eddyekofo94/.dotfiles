#!/bin/sh
# Weekly wrapper: run the disk-bloat cleanup and log it.
set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
log_dir="$config_dir/evidence/weekly_cleanup"
mkdir -p "$log_dir"
log_file="$log_dir/$(date +%Y-%m-%d).txt"

/usr/bin/python3 "$config_dir/weekly_cleanup.py" --apply >"$log_file" 2>&1
