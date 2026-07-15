#!/usr/bin/env bash

# THROWAWAY PROTOTYPE: launch an isolated agent-status tmux demo.

set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
SOCKET=dotfiles-agent-status-prototype
SESSION=agent-status-prototype
TMUX_BIN=${TMUX_BIN:-tmux}

prototype_tmux() {
    env -u TMUX "$TMUX_BIN" -L "$SOCKET" "$@"
}

cleanup() {
    prototype_tmux kill-server 2>/dev/null || true
}

cleanup
prototype_tmux -f "$ROOT/prototype.conf" new-session -d -s "$SESSION" -n agents \
    "$ROOT/pane.sh codex .dotfiles"

first_pane=$(prototype_tmux display-message -p -t "$SESSION:1.1" '#{pane_id}')
prototype_tmux split-window -h -t "$SESSION:1" \
    "$ROOT/pane.sh claude BibleStandard"
second_pane=$(prototype_tmux display-message -p -t "$SESSION:1.2" '#{pane_id}')

prototype_tmux set-option -p -t "$first_pane" @prototype_visible 1
prototype_tmux set-option -p -t "$first_pane" @prototype_agent codex
prototype_tmux set-option -p -t "$first_pane" @prototype_project .dotfiles
prototype_tmux set-option -p -t "$first_pane" @prototype_state running

prototype_tmux set-option -p -t "$second_pane" @prototype_visible 1
prototype_tmux set-option -p -t "$second_pane" @prototype_agent claude
prototype_tmux set-option -p -t "$second_pane" @prototype_project BibleStandard
prototype_tmux set-option -p -t "$second_pane" @prototype_state question

prototype_tmux new-window -d -t "$SESSION:2" -n nvim \
    "$ROOT/pane.sh non-agent normal-window-name"
prototype_tmux select-window -t "$SESSION:1"
prototype_tmux select-pane -t "$first_pane"

if [ "${1:-}" = --detached ]; then
    printf 'prototype socket: %s\n' "$SOCKET"
    printf 'attach: env -u TMUX tmux -L %s attach -t %s\n' "$SOCKET" "$SESSION"
    exit
fi

trap cleanup EXIT HUP INT TERM
prototype_tmux attach-session -t "$SESSION"
