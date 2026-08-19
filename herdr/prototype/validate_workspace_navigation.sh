#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/server_lifecycle.sh"
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/w"
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
session=wn
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/workspace-navigation-validation.jsonl"
evidence_tmp="$runtime/workspace-navigation-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "workspace-navigation validation requires the prototype Herdr binary" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_PROTOTYPE_DIR="$prototype"

cli() { "$herdr" --session "$session" "$@"; }
record() {
  jq -cn --arg name "$1" --argjson value "$2" \
    '{check:$name,evidence:$value}' >>"$evidence_tmp"
}
wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 100 ]; then
      echo "workspace-navigation validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}
send_action() {
  action=$1
  before=$(wc -l <"$driver_log" | tr -d ' ')
  printf '%s\n' "$action" >&3
  wait_for "client action $action" sh -c \
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "$3" ]' \
    sh "$driver_log" "$before" "SENT $action"
}
focused_workspace() {
  cli workspace list | jq -er '.result.workspaces[] | select(.focused).workspace_id'
}
workspace_is() { [ "$(focused_workspace)" = "$1" ]; }
focused_pane() { cli pane list | jq -er '.result.panes[] | select(.focused).pane_id'; }
pane_is() { [ "$(focused_pane)" = "$1" ]; }
sentinel_ready() {
  cli pane process-info --pane "$1" 2>/dev/null |
    jq -e 'any(.result.process_info.foreground_processes[]?; .name == "sleep")' >/dev/null
}
production_hashes() {
  jq -cn \
    --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
    --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
    --arg fe "$(shasum -a 256 "$root/fish/functions/fe.fish" | awk '{print $1}')" \
    --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
    --arg neovim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
    '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"fish/functions/fe.fish":$fe,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$neovim}'
}
cleanup() {
  status=$?
  trap - EXIT INT TERM
  exec 3>&- 2>/dev/null || true
  if [ -n "${driver_pid:-}" ]; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  cli session stop "$session" --json >/dev/null 2>&1 || true
  if [ -n "${server_pid:-}" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  cli session delete "$session" --json >/dev/null 2>&1 || true
  rm -f "$driver_fifo" "$evidence_tmp"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

herdr_sweep_stale_server "$socket"
herdr_guard_server "$socket"
rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir" "$runtime/one" "$runtime/two" "$runtime/three"
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' "$prototype/config.toml" >"$config"
: >"$evidence_tmp"
production_before=$(production_hashes)
config_result=$(cli config check 2>&1)
record config "$(jq -cn --arg result "$config_result" '{result:$result,previous_workspace:"prefix+(",next_workspace:"prefix+)",last_pane:["prefix+Tab","Ctrl-^/Ctrl-6"]}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "workspace-navigation socket" test -S "$socket"
rm -f "$driver_fifo"
mkfifo "$driver_fifo"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "workspace-navigation client" grep -q '^READY$' "$driver_log"

w1=$(focused_workspace)
cli workspace rename "$w1" One >/dev/null
w2=$(cli workspace create --cwd "$runtime/two" --label Two --no-focus | jq -er '.result.workspace.workspace_id // .result.workspace_id')
w3=$(cli workspace create --cwd "$runtime/three" --label Three --no-focus | jq -er '.result.workspace.workspace_id // .result.workspace_id')
p1=$(cli pane list | jq -er --arg workspace "$w1" '.result.panes[] | select(.workspace_id == $workspace).pane_id')
p2=$(cli pane list | jq -er --arg workspace "$w2" '.result.panes[] | select(.workspace_id == $workspace).pane_id')
p3=$(cli pane list | jq -er --arg workspace "$w3" '.result.panes[] | select(.workspace_id == $workspace).pane_id')
pids='[]'
for pane in "$p1" "$p2" "$p3"; do
  cli pane run "$pane" "exec sleep 300" >/dev/null
  wait_for "sentinel in $pane" sentinel_ready "$pane"
  pid=$(cli pane process-info --pane "$pane" | jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
  pids=$(printf '%s\n' "$pids" | jq -c --arg pane "$pane" --argjson pid "$pid" '. + [{pane_id:$pane,pid:$pid}]')
done

test "$(focused_workspace)" = "$w1"
send_action next-workspace
wait_for "next workspace two" workspace_is "$w2"
send_action next-workspace
wait_for "next workspace three" workspace_is "$w3"
send_action next-workspace
wait_for "next workspace wrap" workspace_is "$w1"
send_action previous-workspace
wait_for "previous workspace wrap" workspace_is "$w3"
record cycle "$(jq -cn --arg w1 "$w1" --arg w2 "$w2" --arg w3 "$w3" '{start:$w1,next_sequence:[$w2,$w3,$w1],previous_from_first:$w3,wrapped:true}')"

cli workspace focus "$w1" >/dev/null
wait_for "last-pane setup one" pane_is "$p1"
cli workspace focus "$w2" >/dev/null
wait_for "last-pane setup two" pane_is "$p2"
send_action last-pane-direct
wait_for "direct last pane to one" pane_is "$p1"
send_action last-pane-direct
wait_for "direct last pane toggles two" pane_is "$p2"
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
record last_pane "$(jq -cn --arg first "$p1" --arg second "$p2" --argjson pids "$pids" '{binding:"Ctrl-^/Ctrl-6",setup:[$first,$second],toggle:[$first,$second],cross_workspace:true,processes_survived:true,sentinels:$pids}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn \
  --arg config_hash "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg client_hash "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg validator_hash "$(shasum -a 256 "$prototype/validate_workspace_navigation.sh" | awk '{print $1}')" \
  --argjson production "$production_after" \
  '{config_sha256:$config_hash,client_sha256:$client_hash,validator_sha256:$validator_hash,production_sha256:$production}')"
record result "$(jq -cn --arg version "$("$herdr" --version)" '{status:"PASS",version:$version,session:"wn",model:"workspaces-within-session",production_configuration_modified:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr workspace-navigation validation: PASS (%s)\n' "$evidence"
