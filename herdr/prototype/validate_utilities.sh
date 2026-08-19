#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/server_lifecycle.sh"
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/ut"
config_home="$runtime/config"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
session=ut
socket="$config_home/herdr/sessions/$session/herdr.sock"
picker_fixture="$prototype/fixtures/pane_transfer_picker_fixture.sh"
history_swap_fixture="$prototype/fixtures/history_path_swap_fixture.sh"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/utility-parity-validation.jsonl"
evidence_tmp="$runtime/utility-parity-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "utility validation requires the prototype Herdr binary" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_SOCKET_PATH="$socket"
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
      echo "utility validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}
sentinel_ready() {
  cli pane process-info --pane "$1" 2>/dev/null |
    jq -e 'any(.result.process_info.foreground_processes[]?; .name == "sleep")' >/dev/null
}
sentinel_pid() {
  cli pane process-info --pane "$1" |
    jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid'
}
sentinel_stopped() {
  ! sentinel_ready "$1"
}
focused_pane() {
  cli pane list | jq -er '.result.panes[] | select(.focused).pane_id'
}
focused_tab() {
  cli tab list | jq -er '.result.tabs[] | select(.focused).tab_id'
}
send_action() {
  action=$1
  before=$(wc -l <"$driver_log" | tr -d ' ')
  printf '%s\n' "$action" >&3
  wait_for "client action $action" sh -c \
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "$3" ]' \
    sh "$driver_log" "$before" "SENT $action"
}
screen_has() { grep -Fq "$1" "$screen"; }
screen_lacks() { ! grep -Fq "$1" "$screen"; }
production_hashes() {
  jq -cn \
    --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
    --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
    --arg fe "$(shasum -a 256 "$root/fish/functions/fe.fish" | awk '{print $1}')" \
    --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
    --arg neovim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
    '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,
      "fish/functions/fe.fish":$fe,"ghostty/config":$ghostty,
      "~/.config/nvim/lua/plugin/tmux.lua":$neovim}'
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
mkdir -p "$config_home/herdr" "$evidence_dir" "$runtime/output"
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  "$prototype/config.toml" >"$config"
: >"$evidence_tmp"
production_before=$(production_hashes)
config_result=$(cli config check 2>&1)
record config "$(jq -cn --arg result "$config_result" '{
  result:$result,
  pane_transfer:{binding:"prefix+Shift+p",width:"80%",height:"70%"},
  history_export:{binding:"prefix+Shift+u",width:"80%",height:10},
  first_tab:"prefix+^",last_tab:"prefix+$",last_pane_preserved:["prefix+Tab","Ctrl+^"]
}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "utility socket" test -S "$socket"
rm -f "$driver_fifo"
mkfifo "$driver_fifo"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "utility client" grep -q '^READY$' "$driver_log"

source=$(focused_pane)
original_workspace=$(cli pane get "$source" | jq -er '.result.pane.workspace_id')
receive_source=$(cli pane split "$source" --direction down --ratio 0.5 --no-focus |
  jq -er '.result.pane.pane_id')
destination_tab=$(cli tab create --cwd "$root" --label transfer-target --no-focus |
  jq -er '.result.tab.tab_id')
destination=$(cli pane list | jq -er --arg tab "$destination_tab" \
  '.result.panes[] | select(.tab_id == $tab).pane_id')
cli pane run "$source" "exec sleep 300" >/dev/null
cli pane run "$receive_source" "sleep 300" >/dev/null
cli pane run "$destination" "exec sleep 300" >/dev/null
wait_for "source sentinel" sentinel_ready "$source"
wait_for "receive sentinel" sentinel_ready "$receive_source"
wait_for "destination sentinel" sentinel_ready "$destination"
source_terminal=$(cli pane get "$source" | jq -er '.result.pane.terminal_id')
source_pid=$(sentinel_pid "$source")
source_cwd=$(cli pane get "$source" | jq -er '.result.pane.foreground_cwd // .result.pane.cwd')

send_result=$(
  HERDR_TARGET_PANE_ID="$source" \
  HERDR_PANE_TRANSFER_PICKER="$picker_fixture" \
  HERDR_TRANSFER_MODE=send \
  HERDR_TRANSFER_SOURCE="$source" \
  HERDR_TRANSFER_TARGET="$destination" \
    "$prototype/pane_transfer.sh"
)
test "$(printf '%s\n' "$send_result" | jq -r '.result.mode')" = send
test "$(sentinel_pid "$source")" = "$source_pid"
send_state=$(cli pane get "$source" | jq -c '.result.pane')
printf '%s\n' "$send_state" | jq -e \
  --arg terminal "$source_terminal" --arg cwd "$source_cwd" \
  --arg tab "$destination_tab" '
  .terminal_id == $terminal and .foreground_cwd == $cwd and
  .tab_id == $tab and .focused == true
' >/dev/null
record transfer_send "$(jq -cn --arg source "$source" --arg target "$destination" \
  --arg terminal "$source_terminal" --arg cwd "$source_cwd" \
  --arg tab "$destination_tab" --argjson pid "$source_pid" '{
    source:$source,target:$target,target_tab:$tab,terminal_id:$terminal,
    sentinel_pid:$pid,cwd:$cwd,terminal_preserved:true,process_preserved:true,
    cwd_preserved:true,focused_after:true
  }')"

receive_terminal=$(cli pane get "$receive_source" | jq -er '.result.pane.terminal_id')
receive_pid=$(sentinel_pid "$receive_source")
receive_cwd=$(cli pane get "$receive_source" | jq -er '.result.pane.foreground_cwd // .result.pane.cwd')
receive_result=$(
  HERDR_TARGET_PANE_ID="$source" \
  HERDR_PANE_TRANSFER_PICKER="$picker_fixture" \
  HERDR_TRANSFER_MODE=receive \
  HERDR_TRANSFER_SOURCE="$receive_source" \
  HERDR_TRANSFER_TARGET="$source" \
    "$prototype/pane_transfer.sh"
)
test "$(printf '%s\n' "$receive_result" | jq -r '.result.mode')" = receive
test "$(sentinel_pid "$receive_source")" = "$receive_pid"
receive_state=$(cli pane get "$receive_source" | jq -c '.result.pane')
printf '%s\n' "$receive_state" | jq -e \
  --arg terminal "$receive_terminal" --arg cwd "$receive_cwd" \
  --arg tab "$destination_tab" '
  .terminal_id == $terminal and .foreground_cwd == $cwd and
  .tab_id == $tab and .focused == true
' >/dev/null
record transfer_receive "$(jq -cn --arg source "$receive_source" --arg target "$source" \
  --arg terminal "$receive_terminal" --arg cwd "$receive_cwd" \
  --arg tab "$destination_tab" --argjson pid "$receive_pid" '{
    source:$source,target:$target,target_tab:$tab,terminal_id:$terminal,
    sentinel_pid:$pid,cwd:$cwd,terminal_preserved:true,process_preserved:true,
    cwd_preserved:true,focused_after:true
  }')"

panes_before_rejections=$(cli pane list | jq -c '[.result.panes[] | {pane_id,tab_id,terminal_id}]')
HERDR_TARGET_PANE_ID="$receive_source" \
HERDR_PANE_TRANSFER_PICKER="$picker_fixture" \
HERDR_TRANSFER_CANCEL=1 \
  "$prototype/pane_transfer.sh"
if HERDR_TARGET_PANE_ID="$receive_source" \
   HERDR_PANE_TRANSFER_PICKER="$picker_fixture" \
   HERDR_TRANSFER_RAW_SELECTION="$(printf 'send\t%s\t%s\tself' "$receive_source" "$receive_source")" \
     "$prototype/pane_transfer.sh" >/dev/null 2>&1; then
  echo "utility validation: self transfer unexpectedly succeeded" >&2
  exit 1
fi
stale=$(cli pane split "$source" --direction right --ratio 0.5 --no-focus |
  jq -er '.result.pane.pane_id')
if HERDR_TARGET_PANE_ID="$receive_source" \
   HERDR_PANE_TRANSFER_PICKER="$picker_fixture" \
   HERDR_TRANSFER_MODE=send \
   HERDR_TRANSFER_SOURCE="$receive_source" \
   HERDR_TRANSFER_TARGET="$stale" \
   HERDR_TRANSFER_CLOSE_BEFORE_OUTPUT="$stale" \
     "$prototype/pane_transfer.sh" >/dev/null 2>&1; then
  echo "utility validation: stale transfer unexpectedly succeeded" >&2
  exit 1
fi
panes_after_rejections=$(cli pane list | jq -c '[.result.panes[] | {pane_id,tab_id,terminal_id}]')
test "$panes_after_rejections" = "$panes_before_rejections"
record transfer_rejections "$(jq -cn --argjson panes "$panes_after_rejections" '{
  cancel_no_op:true,self_rejected:true,stale_rejected:true,panes:$panes
}')"

cross_workspace=$(cli workspace create --cwd "$root" --label transfer-cross --no-focus |
  jq -er '.result.workspace.workspace_id // .result.workspace_id')
cross_target=$(cli pane list | jq -er --arg workspace "$cross_workspace" \
  '.result.panes[] | select(.workspace_id == $workspace).pane_id')
cross_before_id="$receive_source"
cross_result=$(
  HERDR_TARGET_PANE_ID="$receive_source" \
  HERDR_PANE_TRANSFER_PICKER="$picker_fixture" \
  HERDR_TRANSFER_MODE=send \
  HERDR_TRANSFER_SOURCE="$receive_source" \
  HERDR_TRANSFER_TARGET="$cross_target" \
    "$prototype/pane_transfer.sh"
)
history_pane=$(printf '%s\n' "$cross_result" | jq -er '.result.pane_id_after')
test "$(printf '%s\n' "$cross_result" | jq -r '.result.cross_workspace')" = true
cli workspace focus "$cross_workspace" >/dev/null
test "$(sentinel_pid "$history_pane")" = "$receive_pid"
cross_state=$(cli pane get "$history_pane" | jq -c '.result.pane')
printf '%s\n' "$cross_state" | jq -e \
  --arg terminal "$receive_terminal" --arg cwd "$receive_cwd" \
  --arg workspace "$cross_workspace" '
  .terminal_id == $terminal and .foreground_cwd == $cwd and
  .workspace_id == $workspace and .focused == true
' >/dev/null
record transfer_cross_workspace "$(jq -cn \
  --arg before "$cross_before_id" --arg after "$history_pane" \
  --arg workspace "$cross_workspace" --arg terminal "$receive_terminal" \
  --arg cwd "$receive_cwd" --argjson pid "$receive_pid" '{
    pane_id_before:$before,pane_id_after:$after,target_workspace:$workspace,
    pane_id_namespace_remap:($before != $after),terminal_id:$terminal,
    sentinel_pid:$pid,cwd:$cwd,terminal_preserved:true,
    process_preserved:true,cwd_preserved:true,focused_after:true
  }')"

cross_receive_result=$(
  HERDR_TARGET_PANE_ID="$history_pane" \
  HERDR_PANE_TRANSFER_PICKER="$picker_fixture" \
  HERDR_TRANSFER_MODE=receive \
  HERDR_TRANSFER_SOURCE="$source" \
  HERDR_TRANSFER_TARGET="$history_pane" \
    "$prototype/pane_transfer.sh"
)
cross_receive_pane=$(printf '%s\n' "$cross_receive_result" |
  jq -er '.result.pane_id_after')
test "$(printf '%s\n' "$cross_receive_result" |
  jq -r '.result.cross_workspace')" = true
test "$(sentinel_pid "$cross_receive_pane")" = "$source_pid"
record transfer_cross_workspace_receive "$(jq -cn \
  --arg before "$source" --arg after "$cross_receive_pane" \
  --argjson pid "$source_pid" '{
    mode:"receive",pane_id_before:$before,pane_id_after:$after,
    sentinel_pid:$pid,terminal_preserved:true,process_preserved:true,
    cwd_preserved:true,focused_after:true
  }')"

cli workspace focus "$original_workspace" >/dev/null
rollback_target=$(cli pane list | jq -er --arg workspace "$original_workspace" '
  [.result.panes[] | select(.workspace_id == $workspace).pane_id][0]
')
rollback_source=$(cli pane split "$rollback_target" --direction down \
  --ratio 0.5 --no-focus | jq -er '.result.pane.pane_id')
cli pane run "$rollback_source" "sleep 300" >/dev/null
wait_for "rollback sentinel" sentinel_ready "$rollback_source"
rollback_terminal=$(cli pane get "$rollback_source" |
  jq -er '.result.pane.terminal_id')
rollback_pid=$(sentinel_pid "$rollback_source")
rollback_cwd=$(cli pane get "$rollback_source" |
  jq -er '.result.pane.foreground_cwd // .result.pane.cwd')
rollback_tab=$(cli pane get "$rollback_source" | jq -er '.result.pane.tab_id')
set +e
HERDR_TARGET_PANE_ID="$rollback_source" \
HERDR_PANE_TRANSFER_PICKER="$picker_fixture" \
HERDR_TRANSFER_MODE=send \
HERDR_TRANSFER_SOURCE="$rollback_source" \
HERDR_TRANSFER_TARGET="$history_pane" \
HERDR_TRANSFER_TEST_AFTER_MOVE_FAIL=1 \
  "$prototype/pane_transfer.sh" >/dev/null 2>&1
rollback_status=$?
set -e
test "$rollback_status" -eq 5
rollback_restored=$(cli pane list | jq -c \
  --arg terminal "$rollback_terminal" \
  '.result.panes[] | select(.terminal_id == $terminal)')
printf '%s\n' "$rollback_restored" | jq -e \
  --arg workspace "$original_workspace" \
  --arg tab "$rollback_tab" --arg cwd "$rollback_cwd" '
  .workspace_id == $workspace and .tab_id == $tab and
  .foreground_cwd == $cwd and .focused == true
' >/dev/null
restored_rollback_pane=$(printf '%s\n' "$rollback_restored" |
  jq -er '.pane_id')
test "$(sentinel_pid "$restored_rollback_pane")" = "$rollback_pid"
record transfer_post_move_rollback "$(jq -cn \
  --arg pane "$restored_rollback_pane" --arg tab "$rollback_tab" \
  --arg terminal "$rollback_terminal" --argjson pid "$rollback_pid" '{
    injected_post_move_failure:true,status:5,pane_id_after_rollback:$pane,
    source_tab_restored:$tab,terminal_id:$terminal,sentinel_pid:$pid,
    terminal_preserved:true,process_preserved:true,cwd_preserved:true
  }')"

sole_workspace=$(cli workspace create --cwd "$root" --label sole-move-failure \
  --focus | jq -er '.result.workspace.workspace_id // .result.workspace_id')
sole_source=$(cli pane list | jq -er --arg workspace "$sole_workspace" '
  .result.panes[] | select(.workspace_id == $workspace).pane_id
')
cli pane run "$sole_source" "sleep 300" >/dev/null
wait_for "sole-source sentinel" sentinel_ready "$sole_source"
sole_terminal=$(cli pane get "$sole_source" | jq -er '.result.pane.terminal_id')
sole_pid=$(sentinel_pid "$sole_source")
sole_cwd=$(cli pane get "$sole_source" |
  jq -er '.result.pane.foreground_cwd // .result.pane.cwd')
sole_tab=$(cli pane get "$sole_source" | jq -er '.result.pane.tab_id')
sole_panes_before=$(cli pane list | jq -c \
  --arg workspace "$sole_workspace" '
  [.result.panes[] | select(.workspace_id == $workspace) |
    {pane_id,tab_id,terminal_id}]
')
set +e
HERDR_TARGET_PANE_ID="$sole_source" \
HERDR_PANE_TRANSFER_PICKER="$picker_fixture" \
HERDR_TRANSFER_MODE=send \
HERDR_TRANSFER_SOURCE="$sole_source" \
HERDR_TRANSFER_TARGET="$history_pane" \
HERDR_TRANSFER_TEST_MOVE_STATUS=42 \
  "$prototype/pane_transfer.sh" >/dev/null 2>&1
sole_failure_status=$?
set -e
test "$sole_failure_status" -eq 5
sole_panes_after=$(cli pane list | jq -c \
  --arg workspace "$sole_workspace" '
  [.result.panes[] | select(.workspace_id == $workspace) |
    {pane_id,tab_id,terminal_id}]
')
test "$sole_panes_after" = "$sole_panes_before"
sole_state=$(cli pane get "$sole_source" | jq -c '.result.pane')
printf '%s\n' "$sole_state" | jq -e \
  --arg tab "$sole_tab" --arg terminal "$sole_terminal" --arg cwd "$sole_cwd" '
  .tab_id == $tab and .terminal_id == $terminal and
  .foreground_cwd == $cwd and .focused == true
' >/dev/null
test "$(sentinel_pid "$sole_source")" = "$sole_pid"
record transfer_native_failure_no_op "$(jq -cn \
  --arg pane "$sole_source" --arg tab "$sole_tab" \
  --arg terminal "$sole_terminal" --argjson pid "$sole_pid" '{
    injected_native_move_status:42,status:5,sole_source:true,
    guard_cleaned:true,pane_id:$pane,source_tab:$tab,terminal_id:$terminal,
    sentinel_pid:$pid,placement_unchanged:true,process_preserved:true
  }')"
cli workspace focus "$cross_workspace" >/dev/null

cli pane send-keys "$history_pane" ctrl+c >/dev/null
wait_for "history sentinel stopped" sentinel_stopped "$history_pane"
cli pane run "$history_pane" \
  "printf '{UTILITY-JSON-LIKE}\\n'; i=1; while [ \$i -le 320 ]; do printf 'UTILITY-HISTORY-%03d\\n' \"\$i\"; i=\$((i + 1)); done; printf 'UTILITY-HISTORY-END\\n'; sleep 300" >/dev/null
wait_for "history sentinel" sentinel_ready "$history_pane"
history_path="$runtime/output/history.txt"
printf '%s\n' "$history_path" |
  HERDR_TARGET_PANE_ID="$history_pane" "$prototype/export_history.sh" >/dev/null
grep -Fq 'UTILITY-HISTORY-001' "$history_path"
grep -Fq 'UTILITY-HISTORY-320' "$history_path"
grep -Fq '{UTILITY-JSON-LIKE}' "$history_path"
test "$(tail -c 1 "$history_path" | od -An -tuC | tr -d ' ')" = 10
history_sequence=$(awk '
  /^UTILITY-HISTORY-[0-9][0-9][0-9]$/ { print }
' "$history_path")
expected_history_sequence=$(awk 'BEGIN {
  for (i = 1; i <= 320; i++) printf "UTILITY-HISTORY-%03d\n", i
}')
test "$history_sequence" = "$expected_history_sequence"
test "$(printf '%s\n' "$history_sequence" | wc -l | tr -d ' ')" -eq 320
test "$(grep -Fxc '{UTILITY-JSON-LIKE}' "$history_path")" -eq 1
test "$(grep -Fxc 'UTILITY-HISTORY-END' "$history_path")" -eq 1
test "$(stat -f '%Lp' "$history_path")" = 600
history_hash=$(shasum -a 256 "$history_path" | awk '{print $1}')
set +e
printf '%s\nn\n' "$history_path" |
  HERDR_TARGET_PANE_ID="$history_pane" "$prototype/export_history.sh" >/dev/null 2>&1
refusal_status=$?
set -e
test "$refusal_status" -eq 3
test "$(shasum -a 256 "$history_path" | awk '{print $1}')" = "$history_hash"
race_path="$runtime/output/history-race.txt"
printf 'UTILITY-CONFIRMED-ORIGINAL\n' >"$race_path"
chmod 0600 "$race_path"
set +e
printf '%s\ny\n' "$race_path" |
  HERDR_TARGET_PANE_ID="$history_pane" \
  HERDR_HISTORY_TEST_AFTER_OPEN_HOOK="$history_swap_fixture" \
    "$prototype/export_history.sh" >/dev/null 2>&1
race_status=$?
set -e
test "$race_status" -eq 4
test "$(cat "$race_path")" = 'UTILITY-UNCONFIRMED-REPLACEMENT'
preopen_path="$runtime/output/history-preopen-race.txt"
printf 'UTILITY-PREOPEN-CONFIRMED\n' >"$preopen_path"
chmod 0600 "$preopen_path"
set +e
printf '%s\ny\n' "$preopen_path" |
  HERDR_TARGET_PANE_ID="$history_pane" \
  HERDR_HISTORY_TEST_BEFORE_OPEN_HOOK="$history_swap_fixture" \
  HERDR_HISTORY_SWAP_MODE=dangling \
    "$prototype/export_history.sh" >/dev/null 2>&1
preopen_status=$?
set -e
test "$preopen_status" -eq 4
test -L "$preopen_path"
test ! -e "$preopen_path"
test ! -e "$preopen_path.referent"
test "$(cat "$preopen_path.confirmed")" = 'UTILITY-PREOPEN-CONFIRMED'
cli pane send-keys "$history_pane" ctrl+c >/dev/null
wait_for "updated history sentinel stopped" sentinel_stopped "$history_pane"
cli pane run "$history_pane" \
  "printf 'UTILITY-HISTORY-GAMMA\\n'; sleep 300" >/dev/null
wait_for "updated history sentinel" sentinel_ready "$history_pane"
history_pid=$(sentinel_pid "$history_pane")
printf '%s\ny\n' "$history_path" |
  HERDR_TARGET_PANE_ID="$history_pane" "$prototype/export_history.sh" >/dev/null
grep -Fq 'UTILITY-HISTORY-GAMMA' "$history_path"
record history_export "$(jq -cn --arg path "$history_path" \
  --argjson bytes "$(wc -c <"$history_path" | tr -d ' ')" '{
    path:$path,bytes:$bytes,explicit_path:true,mode:"0600",
    terminal_text_preserved:true,json_like_text_preserved:true,
    trailing_newline_preserved:true,full_scrollback_over_200:true,
    no_clobber_refusal:true,
    confirmed_overwrite:true,path_swap_rejected:true,
    unconfirmed_replacement_preserved:true,
    before_open_dangling_swap_rejected:true,
    dangling_referent_not_created:true,pane_history_enabled:false
  }')"

edge_workspace=$(cli pane get "$history_pane" | jq -er '.result.pane.workspace_id')
edge_tabs=$(cli tab list --workspace "$edge_workspace" | jq -c '[.result.tabs[].tab_id]')
while [ "$(printf '%s\n' "$edge_tabs" | jq 'length')" -lt 4 ]; do
  cli tab create --workspace "$edge_workspace" --cwd "$root" --no-focus >/dev/null
  edge_tabs=$(cli tab list --workspace "$edge_workspace" | jq -c '[.result.tabs[].tab_id]')
done
first_tab=$(printf '%s\n' "$edge_tabs" | jq -er '.[0]')
last_tab=$(printf '%s\n' "$edge_tabs" | jq -er '.[-1]')
middle_tab=$(printf '%s\n' "$edge_tabs" | jq -er '.[1]')
cli tab focus "$middle_tab" >/dev/null
send_action first-tab
wait_for "first-tab binding" sh -c '[ "$("$1" --session "$2" tab list | jq -r ".result.tabs[] | select(.focused).tab_id")" = "$3" ]' \
  sh "$herdr" "$session" "$first_tab"
send_action last-tab
wait_for "last-tab binding" sh -c '[ "$("$1" --session "$2" tab list | jq -r ".result.tabs[] | select(.focused).tab_id")" = "$3" ]' \
  sh "$herdr" "$session" "$last_tab"
kill -0 "$source_pid"
kill -0 "$history_pid"
record tab_edges "$(jq -cn --arg first "$first_tab" --arg last "$last_tab" \
  --arg middle "$middle_tab" --argjson order "$edge_tabs" '{
    api_order:$order,start:$middle,first:$first,last:$last,
    real_prefix_transport:true,prefix_tab_last_pane_preserved:true,
    sentinel_processes_survived:true
  }')"

popup_panes_before=$(cli pane list | jq -c '[.result.panes[] | {pane_id,tab_id,terminal_id}]')
send_action pane-transfer
screen_has 'Pane transfer'
send_action interrupt
wait_for "pane transfer popup dismissed" screen_lacks 'Transfer> '
send_action history-export
screen_has 'Save focused-pane scrollback to file:'
send_action interrupt
wait_for "history popup dismissed" screen_lacks 'Save focused-pane scrollback to file:'
popup_panes_after=$(cli pane list | jq -c '[.result.panes[] | {pane_id,tab_id,terminal_id}]')
test "$popup_panes_after" = "$popup_panes_before"
record popup_transport "$(jq -cn '{
  pane_transfer:{binding:"prefix+Shift+p",real_fzf:true,cancelled:true},
  history_export:{binding:"prefix+Shift+u",prompted:true,cancelled:true},
  tiled_objects_unchanged:true
}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
test "$(rg -c '^pane_history = ' "$prototype/config.toml")" -eq 1
test "$(rg -c '^pane_history = ' "$root/herdr/config.toml")" -eq 1
prototype_pane_history=$(awk '$1 == "pane_history" { print $3 }' \
  "$prototype/config.toml")
production_pane_history=$(awk '$1 == "pane_history" { print $3 }' \
  "$root/herdr/config.toml")
test "$prototype_pane_history" = false
test "$production_pane_history" = false
tmux_path=$(command -v tmux)
tmux_version=$("$tmux_path" -V)
record scope_audit "$(jq -cn \
  --arg pane_transfer "$(shasum -a 256 "$prototype/pane_transfer.sh" | awk '{print $1}')" \
  --arg history "$(shasum -a 256 "$prototype/export_history.sh" | awk '{print $1}')" \
  --arg tab_edge "$(shasum -a 256 "$prototype/tab_edge.sh" | awk '{print $1}')" \
  --arg fixture "$(shasum -a 256 "$picker_fixture" | awk '{print $1}')" \
  --arg history_swap_fixture "$(shasum -a 256 "$history_swap_fixture" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$prototype/validate_utilities.sh" | awk '{print $1}')" \
  --argjson production "$production_after" '{
    artifact_sha256:{pane_transfer:$pane_transfer,history_export:$history,
      tab_edge:$tab_edge,picker_fixture:$fixture,
      history_swap_fixture:$history_swap_fixture,validator:$validator},
    production_sha256:$production,unchanged:true
  }')"
record result "$(jq -cn --arg version "$("$herdr" --version)" \
  --arg prototype_pane_history "$prototype_pane_history" \
  --arg production_pane_history "$production_pane_history" \
  --arg tmux_path "$tmux_path" --arg tmux_version "$tmux_version" '{
  status:"PASS",version:$version,session:"ut",
  pane_history:{
    prototype:($prototype_pane_history == "false"),
    production:($production_pane_history == "false")
  },
  tmux:{available:($tmux_path | length > 0),path:$tmux_path,version:$tmux_version},
  production_configuration_modified:false
}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr utility parity validation: PASS (%s)\n' "$evidence"
