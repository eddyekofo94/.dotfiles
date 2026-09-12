#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
. "$prototype/server_lifecycle.sh"
# Keep the Unix socket below macOS's sun_path limit even from a long named
# worktree path.
runtime="/tmp/herdr-agent-cycle-${UID:-$(id -u)}"
config_home="$runtime/config"
config="$config_home/herdr/config.toml"
session=gate-agent-cycle
herdr="$prototype/.runtime/bin/herdr"
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence="$prototype/evidence/agent-cycle-validation.jsonl"
evidence_tmp="$runtime/evidence.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "agent cycle validation requires the prototype Herdr binary" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_PROTOTYPE_DIR="$prototype"

cli() { "$herdr" --session "$session" "$@"; }
focused_tab() { cli tab list | jq -er '.result.tabs[] | select(.focused).tab_id'; }
focused_is() { [ "$(focused_tab)" = "$1" ]; }
agent_count_is() { [ "$(cli agent list | jq '.result.agents | length')" -eq "$1" ]; }
pane_for_tab() {
  cli pane list | jq -er --arg tab "$1" '.result.panes[] | select(.tab_id == $tab) | .pane_id' | sed -n '1p'
}
wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    [ "$attempts" -lt 80 ] || { echo "agent cycle validation timed out: $description" >&2; return 1; }
    sleep 0.05
  done
}
send_action() {
  action=$1
  before=$(wc -l <"$driver_log" | tr -d ' ')
  printf '%s\n' "$action" >&3
  wait_for "send $action" sh -c "test \$(wc -l <'$driver_log' | tr -d ' ') -gt $before && test \"\$(tail -n 1 '$driver_log')\" = 'SENT $action'"
}
cleanup() {
  status=$?
  trap - EXIT INT TERM
  exec 3>&- || true
  [ -z "${driver_pid:-}" ] || { kill "$driver_pid" 2>/dev/null || true; wait "$driver_pid" 2>/dev/null || true; }
  cli session stop "$session" --json >/dev/null 2>&1 || true
  [ -z "${server_pid:-}" ] || wait "$server_pid" 2>/dev/null || true
  if [ "$status" -ne 0 ]; then
    mkdir -p "$prototype/.runtime/agent-cycle-failure"
    cp "$driver_log" "$server_log" "$prototype/.runtime/agent-cycle-failure/" 2>/dev/null || true
    cp -R "$config_home/herdr/sessions/$session" \
      "$prototype/.runtime/agent-cycle-failure/session" 2>/dev/null || true
  fi
  cli session delete "$session" --json >/dev/null 2>&1 || true
  rm -rf "$runtime"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

herdr_sweep_stale_server "$socket"
herdr_guard_server "$socket"
rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$prototype/evidence"
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' "$prototype/config.toml" >"$config"
: >"$evidence_tmp"
cli config check >/dev/null
cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "server socket" test -S "$socket"

mkfifo "$driver_fifo"
"$prototype/tab_client.py" "$herdr" "$config_home" "$config" "$session" "$prototype" \
  <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "client" grep -q '^READY$' "$driver_log"
wait_for "initial tab" sh -c "test \$(\"$herdr\" --session '$session' tab list | jq '.result.tabs | length') -eq 1"

t1=$(focused_tab)
t2=$(cli tab create --focus | jq -er '.result.tab.tab_id')
t3=$(cli tab create --focus | jq -er '.result.tab.tab_id')
t4=$(cli tab create --focus | jq -er '.result.tab.tab_id')
p1=$(pane_for_tab "$t1")
p3=$(pane_for_tab "$t3")
p4=$(pane_for_tab "$t4")
cli pane report-agent "$p1" --source gate:agent-cycle --agent AgentOne --state idle \
  --agent-session-id agent-one >/dev/null
cli pane report-agent "$p3" --source gate:agent-cycle --agent AgentThree --state working \
  --agent-session-id agent-three >/dev/null
cli pane report-agent "$p4" --source gate:agent-cycle --agent AgentFour --state blocked \
  --agent-session-id agent-four >/dev/null
wait_for "three agents" agent_count_is 3

cli agent focus "$p1" >/dev/null
wait_for "agent one" focused_is "$t1"
"$prototype/agent_cycle.py" next
wait_for "direct helper next" focused_is "$t3"
cli agent focus "$p1" >/dev/null
wait_for "agent one reset" focused_is "$t1"
send_action alt-ctrl-agent-next
wait_for "next skips non-agent tab" focused_is "$t3"
send_action alt-ctrl-agent-next
wait_for "next follows agent order" focused_is "$t4"
send_action alt-ctrl-agent-next
wait_for "next wraps" focused_is "$t1"
send_action alt-ctrl-agent-previous
wait_for "previous wraps" focused_is "$t4"

cli tab focus "$t2" >/dev/null
send_action alt-ctrl-agent-next
wait_for "non-agent next" focused_is "$t3"
cli tab focus "$t2" >/dev/null
send_action alt-ctrl-agent-previous
wait_for "non-agent previous" focused_is "$t1"

cli tab focus "$t1" >/dev/null
send_action alt-ctrl-home-next
wait_for "tab next preserved" focused_is "$t2"
send_action alt-ctrl-home-previous
wait_for "tab previous preserved" focused_is "$t1"

jq -cn \
  --arg t1 "$t1" --arg t2 "$t2" --arg t3 "$t3" --arg t4 "$t4" \
  --arg helper "$(shasum -a 256 "$prototype/agent_cycle.py" | awk '{print $1}')" \
  --arg client "$(shasum -a 256 "$prototype/tab_client.py" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  --arg production "$(shasum -a 256 "$root/herdr/config.toml" | awk '{print $1}')" \
  --arg prototype_config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  '{check:"agent_cycle",evidence:{transport:{next:"kitty-csi-u-106;7u",previous:"kitty-csi-u-107;7u"},tabs:{agents:[$t1,$t3,$t4],non_agent:$t2},next_order:[$t1,$t3,$t4,$t1],previous_wrap:[$t1,$t4],non_agent:{next:$t3,previous:$t1},tab_chords_preserved:true,wrap:true,sort_performed:false,hashes:{helper:$helper,client:$client,validator:$validator,production_config:$production,prototype_config:$prototype_config}}}' \
  >"$evidence_tmp"
cp "$evidence_tmp" "$evidence"
echo "Herdr direct agent cycle validation: PASS"
