#!/usr/bin/env bash

set -u

ROOT=$(cd "$(dirname "$0")/../.." && pwd)

printf 'Tmux worktree state:\n'
git -C "$ROOT" status --short -- tmux CONTEXT.md docs/agent-status-design.md docs/adr/0001-native-agent-events-for-tmux-status.md
printf '\nVerification: %s\n' "$ROOT/tmux/scripts/verify.sh"
printf 'Manual QA:   %s\n' "$ROOT/tmux/MANUAL_QA.md"
