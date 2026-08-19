#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/server_lifecycle.sh"
runtime="$prototype/.runtime/ct"
config_home="$runtime/config"
config="$config_home/herdr/config.toml"
session=gate-tabs
herdr="$prototype/.runtime/bin/herdr"
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/tab-lifecycle-validation.jsonl"
evidence_tmp="$runtime/tab-lifecycle-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client-driver.log"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "tab validation requires the prototype Herdr binary; run ./herdr/prototype/run.sh cli config check first" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_TAB_CLOSE_STATE_DIR="$runtime/close-confirm"
export HERDR_TAB_MOVE_LOG="$runtime/tab-move.log"

cli() {
  "$herdr" --session "$session" "$@"
}

record() {
  name=$1
  value=$2
  jq -cn --arg name "$name" --argjson value "$value" \
    '{check:$name,evidence:$value}' >>"$evidence_tmp"
}

focused_tab() {
  cli tab list | jq -er '.result.tabs[] | select(.focused).tab_id'
}

tab_ids() {
  cli tab list | jq -c '[.result.tabs[].tab_id]'
}

pane_for_tab() {
  tab=$1
  cli pane list | jq -er --arg tab "$tab" \
    '.result.panes[] | select(.tab_id == $tab) | .pane_id' | sed -n '1p'
}

wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 80 ]; then
      echo "tab validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}

tab_count_is() {
  expected=$1
  [ "$(cli tab list | jq '.result.tabs | length')" -eq "$expected" ]
}

focused_is() {
  [ "$(focused_tab)" = "$1" ]
}

tab_absent() {
  tab=$1
  [ "$(cli tab list | jq --arg tab "$tab" '[.result.tabs[] | select(.tab_id == $tab)] | length')" -eq 0 ]
}

tab_pane_count_is() {
  tab=$1
  expected=$2
  [ "$(cli pane list | jq --arg tab "$tab" '[.result.panes[] | select(.tab_id == $tab)] | length')" -eq "$expected" ]
}

tab_order_is() {
  [ "$(tab_ids)" = "$1" ]
}

pid_dead() {
  ! kill -0 "$1" 2>/dev/null
}

confirmation_state() {
  state_session=$1
  state_socket=$2
  state_session_key=$(printf '%s' "$state_session" | tr -c '[:alnum:]_.-' '_')
  state_socket_key=$(printf '%s' "$state_socket" | shasum -a 256 |
    awk '{print substr($1, 1, 16)}')
  printf '%s/%s-%s.pending\n' "$HERDR_TAB_CLOSE_STATE_DIR" \
    "$state_session_key" "$state_socket_key"
}

start_sentinel() {
  tab=$1
  pane=$(pane_for_tab "$tab")
  cli pane send-text "$pane" "exec sleep 300" >/dev/null
  cli pane send-keys "$pane" return >/dev/null
  wait_for "sentinel process in $tab" sentinel_ready "$pane"
  cli pane process-info --pane "$pane" |
    jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid'
}

sentinel_ready() {
  pane=$1
  cli pane process-info --pane "$pane" 2>/dev/null |
    jq -e 'any(.result.process_info.foreground_processes[]?; .name == "sleep")' >/dev/null
}

send_action() {
  action=$1
  before=$(wc -l <"$driver_log" | tr -d ' ')
  printf '%s\n' "$action" >&3
  attempts=0
  while :; do
    lines=$(wc -l <"$driver_log" | tr -d ' ')
    if [ "$lines" -gt "$before" ] && [ "$(tail -n 1 "$driver_log")" = "SENT $action" ]; then
      return 0
    fi
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 80 ]; then
      echo "tab validation timed out sending $action" >&2
      return 1
    fi
    sleep 0.05
  done
}

cleanup() {
  status=$?
  trap - EXIT INT TERM
  if [ "$status" -ne 0 ] && [ -S "$socket" ]; then
    cli plugin log list --plugin prototype.tab-history --limit 100 \
      >"$runtime/tab-history-plugin-log.json" 2>&1 || true
  fi
  exec 3>&- || true
  if [ -n "${driver_pid:-}" ]; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  cli session stop "$session" --json >/dev/null 2>&1 || true
  if [ -n "${server_pid:-}" ]; then
    wait "$server_pid" 2>/dev/null || true
  fi
  cli session delete "$session" --json >/dev/null 2>&1 || true
  rm -f "$driver_fifo" "$evidence_tmp"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Build a gate-only configuration from the checked-in prototype. Nothing is
# installed into normal Herdr, tmux, Fish, Ghostty, or Neovim configuration.
herdr_sweep_stale_server "$socket"
herdr_guard_server "$socket"
rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir"
sed -e 's/^last_pane = \["prefix+tab", "ctrl+\^"\]$/last_pane = ""/' \
  -e 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  "$prototype/config.toml" >"$config"
printf '\n[[keys.command]]\nkey = "prefix+tab"\ntype = "plugin_action"\ncommand = "prototype.tab-history.last"\ndescription = "focus previous tab"\n\n[[keys.command]]\nkey = "prefix+{"\ntype = "shell"\ncommand = "exec \\"$HERDR_PROTOTYPE_DIR/tab_move.sh\\" left"\ndescription = "move tab left"\n\n[[keys.command]]\nkey = "prefix+}"\ntype = "shell"\ncommand = "exec \\"$HERDR_PROTOTYPE_DIR/tab_move.sh\\" right"\ndescription = "move tab right"\n\n[[keys.command]]\nkey = "prefix+ctrl+x"\ntype = "shell"\ncommand = "exec \\"$HERDR_PROTOTYPE_DIR/close_other_tabs.sh\\""\ndescription = "confirm close other tabs"\n' >>"$config"
: >"$evidence_tmp"

config_result=$(cli config check 2>&1)
record config "$(jq -cn --arg result "$config_result" '{result:$result}')"

schema=$($herdr api schema --json)
printf '%s\n' "$schema" | jq -e '
  any(.schemas.request.oneOf[];
    .properties.method.const? == "tab.move" and
    .properties.params["$ref"] == "#/schemas/request/$defs/TabMoveParams")
' >/dev/null
move_params=$(printf '%s\n' "$schema" | jq -c \
  '.schemas.request["$defs"].TabMoveParams')
record reorder_api "$(jq -cn --arg version "$($herdr --version)" --argjson params "$move_params" '{version:$version,method:"tab.move",params:$params}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "gate-tabs socket" test -S "$socket"
cli plugin link "$prototype/tab-history" >/dev/null

rm -f "$driver_fifo"
mkfifo "$driver_fifo"
"$prototype/tab_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "Herdr tab client" grep -q '^READY$' "$driver_log"
wait_for "initial tab" tab_count_is 1

sentinels='[]'
initial=$(focused_tab)
pid=$(start_sentinel "$initial")
sentinels=$(printf '%s\n' "$sentinels" | jq -c --arg tab "$initial" --argjson pid "$pid" '. + [{tab_id:$tab,pid:$pid}]')

expected=2
while [ "$expected" -le 4 ]; do
  send_action create
  wait_for "tab count $expected" tab_count_is "$expected"
  tab=$(focused_tab)
  pid=$(start_sentinel "$tab")
  sentinels=$(printf '%s\n' "$sentinels" | jq -c --arg tab "$tab" --argjson pid "$pid" '. + [{tab_id:$tab,pid:$pid}]')
  expected=$((expected + 1))
done
created=$(cli tab list | jq -c '.result.tabs')
printf '%s\n' "$created" | jq -e 'length == 4 and all(.[]; .pane_count == 1)' >/dev/null
record create "$(jq -cn --argjson tabs "$created" --argjson sentinels "$sentinels" \
  '{prefix_binding:"prefix+c",tabs:$tabs,sentinels:$sentinels}')"

t1=$(printf '%s\n' "$created" | jq -er '.[0].tab_id')
t2=$(printf '%s\n' "$created" | jq -er '.[1].tab_id')
t3=$(printf '%s\n' "$created" | jq -er '.[2].tab_id')
t4=$(printf '%s\n' "$created" | jq -er '.[3].tab_id')

test "$(focused_tab)" = "$t4"
send_action next
wait_for "next tab wrap" focused_is "$t1"
send_action previous
wait_for "previous tab wrap" focused_is "$t4"
record cycle "$(jq -cn --arg start "$t4" --arg next "$t1" --arg previous "$t4" '{start:$start,next:$next,previous:$previous}')"

send_action index2
wait_for "indexed tab selection" focused_is "$t2"
record indexed "$(jq -cn --arg binding "prefix+2" --arg tab "$t2" '{binding:$binding,focused_tab:$tab}')"

# numbered_tab.sh is purely positional. A digit past the current tab count is a
# silent no-op: no tab is created, the tab list is untouched, focus stays put.
numbered_before=$(tab_ids)
send_action index7
sleep 0.2
test "$(cli tab list | jq '.result.tabs | length')" -eq 4
test "$(tab_ids)" = "$numbered_before"
test "$(focused_tab)" = "$t2"

# Digits within range address left-to-right position, not creation order.
send_action index4
wait_for "position 4 selection" focused_is "$t4"
send_action index1
wait_for "position 1 selection" focused_is "$t1"
send_action index2
wait_for "return to position 2" focused_is "$t2"
record numbered_noop "$(jq -cn --arg binding "prefix+7" \
  --argjson tabs "$numbered_before" --arg focused "$t2" \
  --arg t4 "$t4" --arg t1 "$t1" \
  '{binding:$binding,tab_count:4,tab_created:false,
    tabs_unchanged:$tabs,focus_unchanged:$focused,
    positional:[{binding:"prefix+4",position:4,focused_tab:$t4},
      {binding:"prefix+1",position:1,focused_tab:$t1}]}')"

send_action next
wait_for "last-tab setup" focused_is "$t3"
t3_pane=$(pane_for_tab "$t3")
extra_pane=$(cli pane split "$t3_pane" --direction down --ratio 0.5 --focus | jq -er '.result.pane.pane_id')
wait_for "second pane in current tab" tab_pane_count_is "$t3" 2
send_action last
wait_for "exact last-tab action" focused_is "$t2"
record last_tab "$(jq -cn --arg previous "$t2" --arg from "$t3" --arg extra_pane "$extra_pane" --arg result "$(focused_tab)" '{previous_tab:$previous,from_tab:$from,second_pane_in_from_tab:$extra_pane,result:$result}')"

send_action index3
wait_for "reorder setup" focused_is "$t3"
order_before=$(tab_ids)
send_action move-right
expected_right=$(printf '%s\n' "$order_before" | jq -c '.[0:2] + [.[3], .[2]]')
wait_for "move tab right" tab_order_is "$expected_right"
order_right=$(tab_ids)
test "$(focused_tab)" = "$t3"
send_action move-left
wait_for "move tab left" tab_order_is "$order_before"
order_restored=$(tab_ids)
t3_pid=$(printf '%s\n' "$sentinels" | jq -er --arg tab "$t3" '.[] | select(.tab_id == $tab).pid')
kill -0 "$t3_pid"
record reorder "$(jq -cn --argjson before "$order_before" --argjson right "$order_right" --argjson restored "$order_restored" --arg tab "$t3" --argjson pid "$t3_pid" '{moved_tab:$tab,sentinel_pid:$pid,before:$before,after_right:$right,restored:$restored}')"

send_action create
wait_for "disposable close tab creation" tab_count_is 5
closed_tab=$(focused_tab)
closed_pid=$(start_sentinel "$closed_tab")
send_action close
wait_for "close active tab" tab_absent "$closed_tab"
wait_for "closed tab sentinel exit" pid_dead "$closed_pid"
record close "$(jq -cn --arg tab "$closed_tab" --argjson pid "$closed_pid" '{closed_tab:$tab,sentinel_pid:$pid,tab_absent:true,sentinel_dead:true}')"

send_action index2
wait_for "close-others survivor focus" focused_is "$t2"

# A destructive action without a session identity must fail before it can
# create shared confirmation state or close any tab.
survivor_pane=$(pane_for_tab "$t2")
primary_state=$(confirmation_state "$session" "$socket")
missing_session_status=0
env -u HERDR_SESSION HERDR_SOCKET_PATH="$socket" \
  HERDR_PANE_ID="$survivor_pane" HERDR_BIN_PATH="$herdr" \
  HERDR_TAB_CLOSE_STATE_DIR="$HERDR_TAB_CLOSE_STATE_DIR" \
  "$prototype/close_other_tabs.sh" 2>"$runtime/missing-session.err" ||
  missing_session_status=$?
test "$missing_session_status" -ne 0
test -z "$(find "$runtime/close-confirm" -type f -name '*.pending' -print 2>/dev/null)"
test "$(cli tab list | jq '.result.tabs | length')" -eq 4

send_action close-others
test "$(cli tab list | jq '.result.tabs | length')" -eq 4
test -f "$primary_state"
printf '%s\n' "$sentinels" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
first_press_tabs=$(tab_ids)

# A first press from another session namespace must not consume this session's
# pending confirmation, even when both probes target the same disposable server.
foreign_session=gate-tabs-foreign
foreign_state=$(confirmation_state "$foreign_session" "$socket")
foreign_status=0
HERDR_SESSION="$foreign_session" HERDR_SOCKET_PATH="$socket" \
  HERDR_PANE_ID="$survivor_pane" \
  "$prototype/close_other_tabs.sh" 2>"$runtime/foreign-close-others.err" ||
  foreign_status=$?
test "$foreign_status" -eq 75
test -f "$foreign_state"
test -f "$primary_state"
test "$(cli tab list | jq '.result.tabs | length')" -eq 4
printf '%s\n' "$sentinels" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
foreign_press_tabs=$(tab_ids)

# A second server can use the same conventional session name and repeat tab
# IDs. A distinct socket identity must still get an independent confirmation.
socket_alias="$runtime/gate-tabs-alias.sock"
ln -s "$socket" "$socket_alias"
alias_state=$(confirmation_state "$session" "$socket_alias")
alias_status=0
HERDR_SOCKET_PATH="$socket_alias" HERDR_PANE_ID="$survivor_pane" \
  "$prototype/close_other_tabs.sh" 2>"$runtime/alias-close-others.err" ||
  alias_status=$?
test "$alias_status" -eq 75
test -f "$alias_state"
test -f "$primary_state"
test "$(cli tab list | jq '.result.tabs | length')" -eq 4
alias_press_tabs=$(tab_ids)

send_action close-others
wait_for "confirmed close other tabs" tab_count_is 1
test "$(focused_tab)" = "$t2"
survivor_pid=$(printf '%s\n' "$sentinels" | jq -er --arg tab "$t2" '.[] | select(.tab_id == $tab).pid')
kill -0 "$survivor_pid"
target_pids=$(printf '%s\n' "$sentinels" | jq -c --arg tab "$t2" '[.[] | select(.tab_id != $tab).pid]')
printf '%s\n' "$target_pids" | jq -r '.[]' | while IFS= read -r pid; do
  wait_for "closed other-tab sentinel $pid" pid_dead "$pid"
done
record close_others "$(jq -cn --arg survivor "$t2" --argjson survivor_pid "$survivor_pid" --argjson first_tabs "$first_press_tabs" --argjson foreign_tabs "$foreign_press_tabs" --argjson alias_tabs "$alias_press_tabs" --arg foreign_session "$foreign_session" --argjson target_pids "$target_pids" '{first_press_preserved_tabs:$first_tabs,missing_session_failed_closed:true,foreign_first_press_preserved_tabs:$foreign_tabs,foreign_session_namespace:$foreign_session,same_session_distinct_socket_preserved_tabs:$alias_tabs,survivor_tab:$survivor,survivor_pid:$survivor_pid,closed_target_pids:$target_pids,confirmation_required:true,session_and_socket_scoped_confirmation:true}')"

# Exercise Ghostty's Kitty CSI-u transport only after the original lifecycle
# sequence, so the disposable tab cannot perturb numbered-tab identities.
source_details=$(cli pane current --pane "$survivor_pane" | jq -c '.result.pane')
source_workspace=$(printf '%s\n' "$source_details" | jq -er '.workspace_id')
source_cwd=$(printf '%s\n' "$source_details" | jq -er \
  '.foreground_cwd // .cwd')
send_action alt-ctrl-new-tab
wait_for "Alt-Ctrl-t new tab" tab_count_is 2
alt_tab=$(focused_tab)
alt_details=$(cli tab get "$alt_tab" | jq -c '.result.tab')
alt_pane=$(pane_for_tab "$alt_tab")
alt_pane_details=$(cli pane current --pane "$alt_pane" | jq -c '.result.pane')
alt_cwd=$(printf '%s\n' "$alt_pane_details" | jq -er \
  '.foreground_cwd // .cwd')
printf '%s\n' "$alt_details" | jq -e \
  --arg workspace "$source_workspace" \
  '.workspace_id == $workspace and .focused == true and .pane_count == 1' >/dev/null
test "$alt_cwd" = "$source_cwd"

# Alt+Ctrl+n/p step tabs over the same transport, with two tabs open.
send_action alt-ctrl-next
wait_for "Alt-Ctrl-n next tab" focused_is "$t2"
send_action alt-ctrl-previous
wait_for "Alt-Ctrl-p previous tab" focused_is "$alt_tab"

# The arrow aliases arrive over a different transport and must resolve to the
# same native next_tab / previous_tab actions.
send_action alt-ctrl-right
wait_for "Alt-Ctrl-Right next tab" focused_is "$t2"
send_action alt-ctrl-left
wait_for "Alt-Ctrl-Left previous tab" focused_is "$alt_tab"

# Alt-t remains application-owned: the same transport must not create or focus
# a Herdr tab.
send_action alt-t
sleep 0.2
test "$(cli tab list | jq '.result.tabs | length')" -eq 2
test "$(focused_tab)" = "$alt_tab"
cli tab close "$alt_tab" >/dev/null
wait_for "Alt-Ctrl-t tab cleanup" tab_count_is 1
wait_for "return after Alt-Ctrl-t cleanup" focused_is "$t2"
record alt_new_tab "$(jq -cn \
  --arg tab "$alt_tab" --arg workspace "$source_workspace" \
  --arg source_cwd "$source_cwd" --arg created_cwd "$alt_cwd" \
  --arg next_tab "$t2" --arg previous_tab "$alt_tab" \
  '{binding:"alt+ctrl+t",transport:"kitty-csi-u-116;7u",
    created_tab:$tab,workspace:$workspace,source_cwd:$source_cwd,
    created_cwd:$created_cwd,focused:true,single_new_tab:true,
    alt_cycle:{next:{binding:"alt+ctrl+n",transport:"kitty-csi-u-110;7u",
        focused_tab:$next_tab},
      previous:{binding:"alt+ctrl+p",transport:"kitty-csi-u-112;7u",
        focused_tab:$previous_tab}},
    arrow_cycle:{next:{binding:"alt+ctrl+right",transport:"csi-1;7C",
        focused_tab:$next_tab},
      previous:{binding:"alt+ctrl+left",transport:"csi-1;7D",
        focused_tab:$previous_tab}},
    alt_t:{binding:"alt+t",transport:"kitty-csi-u-116;3u",
      tab_count_unchanged:true,focus_unchanged:true}}')"

record result "$(jq -cn --arg session "$session" '{status:"PASS",session:$session,production_configuration_modified:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr tab lifecycle validation: PASS (%s)\n' "$evidence"
