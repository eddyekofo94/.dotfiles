#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repo_dir=$(CDPATH= cd -- "$package_dir/.." && pwd)

echo 'Fish worktree:'
git -C "$repo_dir" status --short -- fish

echo 'Prompt cache entries:'
rg -c '__fish_(vcs|venv)_info_' "$package_dir/fish_variables" 2>/dev/null || echo 0

echo 'Resident Fish processes:'
ps -axo pid=,ppid=,rss=,etime=,comm= |
    awk '$5 == "fish" || $5 ~ /\/fish$/ { print }'
