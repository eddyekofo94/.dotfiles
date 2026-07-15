#!/usr/bin/env bash

# THROWAWAY PROTOTYPE: apply one event to one simulated agent pane.

set -eu

# Native agent adapters may fire when their CLI is not inside tmux. The shared
# boundary must be a harmless no-op in that case.
[ -n "${TMUX:-}" ] || exit 0

ROOT=$(cd "$(dirname "$0")" && pwd)
. "$ROOT/model.sh"

pane=$1
event=$2
current=$(tmux show-options -p -v -t "$pane" @prototype_state)
next=$(agent_status_next_state "$current" "$event") || exit 2

tmux set-option -p -t "$pane" @prototype_state "$next"
if [ "$next" = absent ]; then
    tmux set-option -p -t "$pane" @prototype_visible 0
else
    tmux set-option -p -t "$pane" @prototype_visible 1
fi

agent=$(tmux show-options -p -v -t "$pane" @prototype_agent)
project=$(tmux show-options -p -v -t "$pane" @prototype_project)
tmux display-message -t "$pane" "$agent:$project -> $next"
tmux refresh-client -S 2>/dev/null || true
