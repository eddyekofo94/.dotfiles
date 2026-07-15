#!/usr/bin/env bash

# THROWAWAY PROTOTYPE: render one tmux window's simulated agent summary.

set -u

ROOT=$(cd "$(dirname "$0")" && pwd)
. "$ROOT/model.sh"

window=$1
frame=$(date +%s)
rendered=

while IFS='|' read -r visible agent project state; do
    [ "$visible" = 1 ] || continue

    project=$(agent_status_project "$project")
    icon=$(agent_status_icon "$state" "$frame") || continue
    color=$(agent_status_color "$state") || continue

    if [ -n "$rendered" ]; then
        rendered="$rendered#[fg=#6c7086] · "
    fi
    rendered="$rendered#[fg=#cdd6f4]$agent:$project #[fg=$color]$icon"
done < <(tmux list-panes -t "$window" -F '#{@prototype_visible}|#{@prototype_agent}|#{@prototype_project}|#{@prototype_state}')

if [ -n "$rendered" ]; then
    printf '%s' "$rendered"
else
    tmux display-message -p -t "$window" '#W'
fi
