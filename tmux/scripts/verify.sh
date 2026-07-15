#!/usr/bin/env bash

set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

for script in tmux/scripts/*.sh tmux/tests/*.sh; do
    bash -n "$script"
done

python3 -c 'import ast, pathlib, sys; [ast.parse(pathlib.Path(path).read_text()) for path in sys.argv[1:]]' \
    tmux/scripts/agent_status.py tmux/tests/agent_status_test.py
PYTHONDONTWRITEBYTECODE=1 python3 tmux/tests/agent_status_test.py
node tmux/tests/opencode_agent_status_test.mjs

for config in tmux/hooks/*.json; do
    jq -e . "$config" >/dev/null
done

tmux/tests/agent_status_integration_test.sh
tmux/tests/ready_prompt_test.sh
tmux -f tmux/tmux.conf -L dotfiles-check start-server \; kill-server
git diff --check

printf 'tmux verification: PASS\n'
