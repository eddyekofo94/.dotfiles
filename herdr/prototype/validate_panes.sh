#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/server_lifecycle.sh"
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/cp"
config_home="$runtime/config"
config="$config_home/herdr/config.toml"
session=gp
herdr="$prototype/.runtime/bin/herdr"
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/pane-lifecycle-validation.jsonl"
evidence_tmp="$runtime/pane-lifecycle-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client-driver.log"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "pane validation requires the prototype Herdr binary" >&2
  exit 2
}

record() {
  name=$1
  value=$2
  jq -cn --arg name "$name" --argjson value "$value" \
    '{check:$name,evidence:$value}' >>"$evidence_tmp"
}

production_hashes() {
  jq -cn \
    --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
    --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
    --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
    --arg neovim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
    '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$neovim}'
}

wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 100 ]; then
      echo "pane validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}

cleanup() {
  status=$?
  trap - EXIT INT TERM
  if [ "$status" -ne 0 ]; then
    session_log="$config_home/herdr/sessions/$session/herdr-server.log"
    [ ! -f "$session_log" ] || cp "$session_log" "$runtime/failure-herdr-server.log"
    cli session list --json >"$runtime/failure-session-list.json" 2>&1 || true
  fi
  exec 3>&- 2>/dev/null || true
  if [ -n "${driver_pid:-}" ]; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  if [ -S "$socket" ]; then
    "$herdr" --session "$session" session stop "$session" --json >/dev/null 2>&1 || true
  fi
  if [ -n "${server_pid:-}" ]; then
    wait "$server_pid" 2>/dev/null || true
  fi
  "$herdr" --session "$session" session delete "$session" --json >/dev/null 2>&1 || true
  rm -f "$driver_fifo" "$evidence_tmp"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

herdr_sweep_stale_server "$socket"
herdr_guard_server "$socket"
rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir"
: >"$evidence_tmp"
production_before=$(production_hashes)
sed -e 's|^default_shell = .*$|default_shell = "'"$prototype"'/ready_prompt_agent_fixture.sh"|' \
  "$prototype/config.toml" >"$config"

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_PANE_CLOSE_OTHERS_STATE_DIR="$runtime/close-others-state"

cli() {
  "$herdr" --session "$session" "$@"
}

config_result=$(cli config check 2>&1)
record config "$(jq -cn --arg result "$config_result" \
  '{result:$result,close_others:{prefix:"prefix+o",shell:"Alt-o"},equalize:{prefix:"prefix+=",shell:"Alt-="}}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "pane gate socket" test -S "$socket"
mkfifo "$driver_fifo"
"$prototype/tab_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "pane gate client" grep -q '^READY$' "$driver_log"
wait_for "initial pane" sh -c \
  '"$1" --session "$2" pane list | jq -e ".result.panes | length == 1" >/dev/null' \
  _ "$herdr" "$session"
initial=$(cli pane current --current | jq -er '.result.pane.pane_id')
tab=$(cli pane current --pane "$initial" | jq -er '.result.pane.tab_id')

send_action() {
  action=$1
  before=$(wc -l <"$driver_log" | tr -d ' ')
  printf '%s\n' "$action" >&3
  wait_for "send $action" sh -c \
    '[ "$(wc -l <"$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "SENT $3" ]' \
    _ "$driver_log" "$before" "$action"
}

pane_count_is() {
  expected=$1
  [ "$(cli pane list | jq --arg tab "$tab" '[.result.panes[] | select(.tab_id == $tab)] | length')" -eq "$expected" ]
}

create_sleep_siblings() {
  first=$(cli pane split "$initial" --direction right --ratio 0.5 --no-focus | jq -er '.result.pane.pane_id')
  second=$(cli pane split "$first" --direction down --ratio 0.5 --no-focus | jq -er '.result.pane.pane_id')
  for target in "$first" "$second"; do
    cli pane send-text "$target" 'exec sleep 300' >/dev/null
    cli pane send-keys "$target" return >/dev/null
  done
  wait_for "sleep in first sibling" sh -c \
    '"$1" --session "$2" pane process-info --pane "$3" | jq -e '\''any(.result.process_info.foreground_processes[]?; .name == "sleep")'\'' >/dev/null' \
    _ "$herdr" "$session" "$first"
  wait_for "sleep in second sibling" sh -c \
    '"$1" --session "$2" pane process-info --pane "$3" | jq -e '\''any(.result.process_info.foreground_processes[]?; .name == "sleep")'\'' >/dev/null' \
    _ "$herdr" "$session" "$second"
  first_pid=$(cli pane process-info --pane "$first" | jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
  second_pid=$(cli pane process-info --pane "$second" | jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
}

export_root() {
  request_id="pane-gate-layout-$$-$(date +%s)"
  jq -cn --arg id "$request_id" --arg tab "$tab" \
    '{id:$id,method:"layout.export",params:{tab_id:$tab}}' |
    nc -U -w 2 "$socket" |
    jq -cer --arg id "$request_id" \
      'select(.id == $id and has("result")) | .result.layout.root'
}

layout_is_equalized() {
  export_root | jq -e '
    def leaves:
      if .type == "pane" then 1
      else ((.first | leaves) + (.second | leaves))
      end;
    def balanced:
      if .type == "pane" then true
      else
        (.first | leaves) as $first_leaves |
        (.second | leaves) as $second_leaves |
        ($first_leaves / ($first_leaves + $second_leaves)) as $expected |
        ((.ratio - $expected) < 0.000001 and (.ratio - $expected) > -0.000001) and
        (.first | balanced) and (.second | balanced)
      end;
    balanced
  ' >/dev/null
}

topology_signature() {
  jq -c '
    def signature:
      if .type == "pane" then {type,pane_id}
      else {type,direction,first:(.first|signature),second:(.second|signature)}
      end;
    signature
  '
}

create_sleep_siblings
cli pane resize --pane "$initial" --direction right --amount 0.2 >/dev/null
cli pane resize --pane "$second" --direction down --amount 0.15 >/dev/null
layout_before=$(export_root)
topology_before=$(printf '%s\n' "$layout_before" | topology_signature)
send_action equalize-panes
sleep 0.2
export_root >"$runtime/layout-after-prefix.json"
wait_for "prefix equalized layout" layout_is_equalized
layout_after_prefix=$(export_root)
topology_after_prefix=$(printf '%s\n' "$layout_after_prefix" | topology_signature)
test "$topology_after_prefix" = "$topology_before"
kill -0 "$first_pid"
kill -0 "$second_pid"

cli pane send-text "$initial" "source $prototype/herdr_nav.fish" >/dev/null
cli pane send-keys "$initial" return >/dev/null
sleep 0.15
cli pane resize --pane "$initial" --direction right --amount 0.15 >/dev/null
cli pane send-keys "$initial" alt+= >/dev/null
wait_for "Alt-= equalized layout" layout_is_equalized
layout_after_alt=$(export_root)
topology_after_alt=$(printf '%s\n' "$layout_after_alt" | topology_signature)
test "$topology_after_alt" = "$topology_before"
kill -0 "$first_pid"
kill -0 "$second_pid"
record equalize "$(jq -cn --argjson before "$layout_before" \
  --argjson prefix "$layout_after_prefix" --argjson alt "$layout_after_alt" \
  --argjson topology "$topology_before" \
  --argjson pids "[$first_pid,$second_pid]" \
  '{prefix_binding:"prefix+=",shell_binding:"Alt-=",topology_preserved:true,topology_signature:$topology,processes_survived:true,sentinel_pids:$pids,before:$before,after_prefix:$prefix,after_alt:$alt}')"
cli pane close "$first" >/dev/null
cli pane close "$second" >/dev/null
wait_for "equalize fixture cleanup" pane_count_is 1

create_sleep_siblings
send_action close-other-panes
test "$(cli pane list | jq --arg tab "$tab" '[.result.panes[] | select(.tab_id == $tab)] | length')" -eq 3
kill -0 "$first_pid"
kill -0 "$second_pid"
send_action close-other-panes
wait_for "prefix close siblings" pane_count_is 1
wait_for "prefix first process exit" sh -c '! kill -0 "$1" 2>/dev/null' _ "$first_pid"
wait_for "prefix second process exit" sh -c '! kill -0 "$1" 2>/dev/null' _ "$second_pid"
record prefix_close_others "$(jq -cn --arg survivor "$initial" \
  --argjson closed_pids "[$first_pid,$second_pid]" \
  '{binding:"prefix+o",survivor:$survivor,first_press_preserved:true,second_press_closed:true,closed_process_pids:$closed_pids}')"

rm -rf "$HERDR_PANE_CLOSE_OTHERS_STATE_DIR"
cli pane send-text "$initial" "source $prototype/herdr_nav.fish" >/dev/null
cli pane send-keys "$initial" return >/dev/null
sleep 0.15
create_sleep_siblings
cli pane send-keys "$initial" alt+o >/dev/null
sleep 0.2
test "$(cli pane list | jq --arg tab "$tab" '[.result.panes[] | select(.tab_id == $tab)] | length')" -eq 3
kill -0 "$first_pid"
kill -0 "$second_pid"
cli pane send-keys "$initial" alt+o >/dev/null
wait_for "Alt-o close siblings" pane_count_is 1
wait_for "Alt-o first process exit" sh -c '! kill -0 "$1" 2>/dev/null' _ "$first_pid"
wait_for "Alt-o second process exit" sh -c '! kill -0 "$1" 2>/dev/null' _ "$second_pid"
record shell_close_others "$(jq -cn --arg survivor "$initial" \
  --argjson closed_pids "[$first_pid,$second_pid]" \
  '{binding:"Alt-o",application_owner:"Fish",survivor:$survivor,first_press_preserved:true,second_press_closed:true,closed_process_pids:$closed_pids}')"

rm -rf "$HERDR_PANE_CLOSE_OTHERS_STATE_DIR"
send_action close-other-panes
test "$(cli pane list | jq --arg tab "$tab" '[.result.panes[] | select(.tab_id == $tab)] | length')" -eq 1
record no_siblings "$(jq -cn --arg pane "$initial" \
  '{pane:$pane,pane_count:1,no_op:true}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
artifact_hashes=$(jq -cn \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg helper "$(shasum -a 256 "$prototype/equalize_panes.sh" | awk '{print $1}')" \
  --arg nav "$(shasum -a 256 "$prototype/herdr_nav.fish" | awk '{print $1}')" \
  --arg client "$(shasum -a 256 "$prototype/tab_client.py" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{config:$config,helper:$helper,nav:$nav,client:$client,validator:$validator}')
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" --argjson artifacts "$artifact_hashes" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before == $after),artifact_hashes:$artifacts}')"
record result "$(jq -cn --arg session "$session" \
  '{status:"PASS",session:$session,production_configuration_modified:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr pane lifecycle validation: PASS (%s)\n' "$evidence"
