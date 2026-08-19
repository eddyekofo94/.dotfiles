#!/bin/sh
set -eu

# Optional live gate: prints a canonical handoff before launching real Claude
# in a disposable Herdr session, then proves clear-and-replay leaves that
# handoff in Claude's composer without making a model request.

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/server_lifecycle.sh"
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime=$(mktemp -d /tmp/hcl.XXXXXX)
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
session=rpclaude
herdr="$prototype/.runtime/bin/herdr"
socket="$config_home/herdr/sessions/$session/herdr.sock"
driver_fifo="$runtime/fifo"
driver_log="$runtime/client.log"
server_log="$runtime/server.log"
marker=HERDR_LIVE_CLAUDE_REPLAY_SENTINEL
stage=setup

cleanup() {
  status=$?
  trap - EXIT INT TERM
  exec 3>&- 2>/dev/null || true
  if [ -n "${driver_pid:-}" ]; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  "$herdr" --session "$session" session stop "$session" --json >/dev/null 2>&1 || true
  if [ -n "${server_pid:-}" ]; then
    wait "$server_pid" 2>/dev/null || true
  fi
  "$herdr" --session "$session" session delete "$session" --json >/dev/null 2>&1 || true
  if [ "$status" -ne 0 ]; then
    printf 'Herdr live Claude gate failed at %s (runtime: %s)\n' "$stage" "$runtime" >&2
  else
    rm -rf -- "$runtime"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

read_text() {
  source=$1
  shift
  response=$("$herdr" --session "$session" pane read "$pane" \
    --source "$source" "$@" --format text)
  case "$response" in
    \{*) printf '%s\n' "$response" | jq -r '.result.text // .result.content // empty' ;;
    *) printf '%s\n' "$response" ;;
  esac
}

wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 900 ]; then
      printf 'Timed out waiting for %s\n' "$description" >&2
      return 1
    fi
    sleep 0.1
  done
}

claude_process_visible() {
  "$herdr" --session "$session" pane process-info --pane "$pane" | jq -e '
    any(.result.process_info.foreground_processes[]?;
      .argv0 == "claude" or .argv[0] == "claude" or .name == "claude")
  ' >/dev/null
}

claude_composer_ready() {
  visible=$(read_text visible)
  latest=$(printf '%s\n' "$visible" | awk '/^[[:space:]]*❯/{line=$0} END{print line}')
  remainder=$(printf '%s' "$latest" | sed -E 's/^[[:space:]]*❯[[:space:]]*//')
  [ -n "$latest" ] && [ -z "$remainder" ]
}

handoff_ready() {
  recent=$(read_text recent-unwrapped --lines 500)
  printf '%s\n' "$recent" >"$runtime/recent.txt"
  count=$(printf '%s\n' "$recent" | grep -Fc "$marker" || true)
  visible=$(read_text visible)
  printf '%s\n' "$visible" >"$runtime/visible.txt"
  latest=$(printf '%s\n' "$visible" | awk '/^[[:space:]]*❯/{line=$0} END{print line}')
  remainder=$(printf '%s' "$latest" | sed -E 's/^[[:space:]]*❯[[:space:]]*//')
  extract_status=0
  printf '%s\n' "$recent" | READY_PROMPT_CAPTURE_LINES=500 \
    "$root/herdr/prototype/ready_prompt_parser.sh" --extract /dev/stdin >/dev/null || extract_status=$?
  [ "$count" -ge 1 ] && [ -n "$latest" ] && [ -z "$remainder" ] && \
    [ "$extract_status" -eq 0 ]
}

[ -x "$herdr" ] || {
  echo "live Claude gate requires the prototype Herdr binary" >&2
  exit 2
}
mkdir -p "$config_home/herdr"
cp "$prototype/config.toml" "$config"

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_PROTOTYPE_USER_CONFIG_HOME="$HOME/.config"

stage=server
herdr_sweep_stale_server "$socket"
herdr_guard_server "$socket"
"$herdr" --session "$session" server >"$server_log" 2>&1 &
server_pid=$!
wait_for "Herdr socket" test -S "$socket"

stage=client
mkfifo "$driver_fifo"
"$prototype/tab_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "Herdr client" grep -q '^READY$' "$driver_log"

stage=pane
pane=''
wait_for "initial pane" sh -c '
  pane=$($1 --session "$2" pane list 2>/dev/null | jq -r ".result.panes[0].pane_id // empty")
  [ -n "$pane" ]
' _ "$herdr" "$session"
pane=$("$herdr" --session "$session" pane list | jq -er '.result.panes[0].pane_id')

stage=handoff-fixture
"$herdr" --session "$session" pane send-text "$pane" \
  "printf '\\nReady-to-paste prompt: \`$marker\`\\n'" >/dev/null
"$herdr" --session "$session" pane send-keys "$pane" return >/dev/null

stage=claude-start
"$herdr" --session "$session" pane send-text "$pane" \
  'exec env -u CLAUDECODE claude --permission-mode plan' >/dev/null
"$herdr" --session "$session" pane send-keys "$pane" return >/dev/null
wait_for "Claude process" claude_process_visible
wait_for "Claude composer" claude_composer_ready
wait_for "canonical Claude handoff" handoff_ready

stage=clear-replay
HERDR_PANE_ID="$pane" HERDR_READY_PROMPT_READY_INTERVAL=0.1 \
  "$prototype/ready_prompt.sh" --clear
sleep 1

stage=assertion
recent_after=$(read_text recent-unwrapped --lines 500)
marker_count=$(printf '%s\n' "$recent_after" | grep -Fc "$marker" || true)
composer_after=$(printf '%s\n' "$recent_after" | awk '
  /^[[:space:]]*❯/ { block = $0; next }
  block != "" { block = block "\n" $0 }
  END { print block }
')
composer_marker_count=$(printf '%s\n' "$composer_after" | grep -Fc "$marker" || true)
pane_snapshot=$("$herdr" --session "$session" pane get "$pane")
agent_status=$(printf '%s\n' "$pane_snapshot" | jq -r '.result.pane.agent_status // "unknown"')
sleep 1
pane_snapshot_later=$("$herdr" --session "$session" pane get "$pane")
agent_status_later=$(printf '%s\n' "$pane_snapshot_later" | jq -r '.result.pane.agent_status // "unknown"')
printf 'Herdr live Claude state: marker=%s composer-marker=%s status=%s later=%s\n' \
  "$marker_count" "$composer_marker_count" "$agent_status" "$agent_status_later"
[ "$marker_count" -ge 1 ]
[ "$composer_marker_count" -eq 1 ]
[ "$agent_status" != working ]
[ "$agent_status_later" != working ]
claude_process_visible

printf 'Herdr live Claude clear-replay: PASS (submitted=false)\n'
