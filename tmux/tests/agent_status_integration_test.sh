#!/usr/bin/env bash

set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT=$ROOT/tmux/scripts/agent_status.py
SOCKET=dotfiles-agent-status-test-$$
TMP_ROOT=$(mktemp -d)

test_tmux() {
    env -u TMUX tmux -L "$SOCKET" "$@"
}

cleanup() {
    test_tmux kill-server 2>/dev/null || true
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

ln -s /bin/sleep "$TMP_ROOT/codex"
test_tmux -f /dev/null new-session -d -s agent-status-test "$TMP_ROOT/codex 30"
pane=$(test_tmux display-message -p '#{pane_id}')
socket_path=$(test_tmux display-message -p '#{socket_path}')
server_pid=$(test_tmux display-message -p '#{pid}')
tmux_environment="$socket_path,$server_pid,0"

run_hook() {
    event=$1
    payload=$2
    printf '%s' "$payload" | TMUX="$tmux_environment" TMUX_PANE="$pane" \
        python3 "$SCRIPT" hook --agent codex --event "$event" >/dev/null
}

run_hook session-start '{"cwd":"/tmp/ExampleProject"}'
[ "$(test_tmux show-options -p -v -t "$pane" @agent_status_agent)" = codex ]
[ "$(test_tmux show-options -p -v -t "$pane" @agent_status_project)" = ExampleProject ]
[ "$(test_tmux show-options -p -v -t "$pane" @agent_status_state)" = ready ]

run_hook prompt '{"cwd":"/tmp/ExampleProject"}'
[ "$(test_tmux show-options -p -v -t "$pane" @agent_status_state)" = running ]

wait_for_option() {
    option=$1
    attempts=40
    while [ "$attempts" -gt 0 ]; do
        value=$(test_tmux show-options -gqv "$option" 2>/dev/null || true)
        [ -n "$value" ] && return 0
        attempts=$((attempts - 1))
        sleep 0.05
    done
    return 1
}

wait_for_option @agent_status_animator_pid
animator_pid=$(test_tmux show-options -gqv @agent_status_animator_pid)
window=$(test_tmux display-message -p '#{window_id}')
first_frame=$(test_tmux show-options -wqv -t "$window" @agent_status_rendered)
sleep 0.2
second_frame=$(test_tmux show-options -wqv -t "$window" @agent_status_rendered)
[ "$first_frame" != "$second_frame" ]

# Repeated running events and a config reload must not replace the lock owner.
run_hook prompt '{"cwd":"/tmp/ExampleProject"}'
test_tmux source-file "$ROOT/tmux/tmux.conf"
sleep 0.2
[ "$(test_tmux show-options -gqv @agent_status_animator_pid)" = "$animator_pid" ]
kill -0 "$animator_pid"
case "$(test_tmux show-options -gv @catppuccin_window_current_text)" in
    *'@agent_status_rendered'*) ;;
    *) printf 'window status does not use the cached renderer\n' >&2; exit 1 ;;
esac
case "$(test_tmux show-options -gv @catppuccin_window_current_text)" in
    *'@agent_status_rendered} ,'*) ;;
    *) printf 'window status does not protect wide agent icons from clipping\n' >&2; exit 1 ;;
esac
chooser_alias=$(test_tmux show-options -sv 'command-alias[108]')
case "$chooser_alias" in
    *'window_format'*'@agent_status_rendered'*) ;;
    *) printf 'window chooser does not use the cached agent renderer\n' >&2; exit 1 ;;
esac
case "$(test_tmux show-options -gv @catppuccin_window_current_text)" in
    *'#{b:pane_current_path}'*) ;;
    *) printf 'window status does not fall back to the project directory\n' >&2; exit 1 ;;
esac

# Windows without agents must leave the cached label empty so tmux can resolve
# the active pane's project directory dynamically, including after `cd`.
plain_window=$(test_tmux new-window -d -P -F '#{window_id}' -c "$ROOT" 'sleep 30')
TMUX="$tmux_environment" python3 "$SCRIPT" sync
[ -z "$(test_tmux show-options -wqv -t "$plain_window" @agent_status_rendered)" ]
plain_status=$(test_tmux display-message -p -t "$plain_window" '#{E:@catppuccin_window_current_text}')
case "$plain_status" in
    *'.dotfiles'*) ;;
    *) printf 'plain window status does not show project directory: %s\n' "$plain_status" >&2; exit 1 ;;
esac

expanded_status=$(test_tmux display-message -p '#{E:@catppuccin_window_current_text}')
case "$expanded_status" in
    *'codex:ExampleProject'*) ;;
    *)
        printf 'cached window status does not expand to the agent label: %s\n' \
            "$expanded_status" >&2
        exit 1
        ;;
esac
case "$(test_tmux show-options -gv @catppuccin_window_current_text)" in
    *'#('*agent_status.py*)
        printf 'window status still uses the one-second embedded renderer\n' >&2
        exit 1
        ;;
esac

run_hook stop '{"cwd":"/tmp/ExampleProject","last_assistant_message":"Which option do you prefer?"}'
[ "$(test_tmux show-options -p -v -t "$pane" @agent_status_state)" = question ]

attempts=40
while [ "$attempts" -gt 0 ] && kill -0 "$animator_pid" 2>/dev/null; do
    attempts=$((attempts - 1))
    sleep 0.05
done
! kill -0 "$animator_pid" 2>/dev/null
[ -z "$(test_tmux show-options -gqv @agent_status_animator_pid 2>/dev/null || true)" ]

cached=$(test_tmux show-options -wqv -t "$window" @agent_status_rendered)
case "$cached" in
    *'codex:ExampleProject'*''*) ;;
    *) printf 'unexpected cached question render: %s\n' "$cached" >&2; exit 1 ;;
esac

run_hook failure '{"cwd":"/tmp/ExampleProject","error":"rate limit"}'
[ "$(test_tmux show-options -p -v -t "$pane" @agent_status_state)" = failed ]

rendered=$(TMUX="$tmux_environment" python3 "$SCRIPT" render-window "$window" fallback)
case "$rendered" in
    *'codex:ExampleProject'*''*) ;;
    *) printf 'unexpected failed render: %s\n' "$rendered" >&2; exit 1 ;;
esac

printf 'agent status tmux integration: PASS\n'
