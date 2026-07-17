#!/usr/bin/env bash

set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SOCKET="dotfiles-application-label-$$"

cleanup() {
    tmux -L "$SOCKET" kill-server 2>/dev/null || true
}
trap cleanup EXIT

tmux -L "$SOCKET" -f "$ROOT/tmux/tmux.conf" new-session -d -s label-test /bin/sleep 30
pane=$(tmux -L "$SOCKET" list-panes -t label-test -F '#{pane_id}' | head -n1)

tmux -L "$SOCKET" set-option -p -t "$pane" @agent_status_agent claude
agent_label=$(tmux -L "$SOCKET" display-message -p -t "$pane" \
    '#{E:@catppuccin_application_text}')
if [[ $agent_label != ' claude' ]]; then
    printf 'FAIL: expected Claude application label, got <%s>\n' "$agent_label" >&2
    exit 1
fi

tmux -L "$SOCKET" set-option -pu -t "$pane" @agent_status_agent
pane_command=$(tmux -L "$SOCKET" display-message -p -t "$pane" \
    '#{pane_current_command}')
command_label=$(tmux -L "$SOCKET" display-message -p -t "$pane" \
    '#{E:@catppuccin_application_text}')
if [[ $command_label != " $pane_command" ]]; then
    printf 'FAIL: expected ordinary command fallback, got <%s>\n' "$command_label" >&2
    exit 1
fi

printf 'application label tests: PASS\n'
