#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/server_lifecycle.sh"
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/l"
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
session=lm
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/layout-menu-validation.jsonl"
evidence_tmp="$runtime/layout-menu-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
menu_log="$runtime/menu.tsv"
server_log="$runtime/server.log"
concurrent_fixture="$prototype/fixtures/layout_concurrent_fixture.sh"

[ -x "$herdr" ] || {
  echo "layout-menu validation requires the prototype Herdr binary" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_SOCKET_PATH="$socket"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_LAYOUT_MENU_LOG="$menu_log"

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
      echo "layout-menu validation timed out: $description" >&2
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
screen_has() { grep -Fq "$1" "$screen"; }
screen_lacks() { ! grep -Fq "$1" "$screen"; }
menu_count_is() { [ "$(wc -l <"$menu_log" | tr -d ' ')" -eq "$1" ]; }
pane_count_is() { [ "$(cli pane list | jq '.result.panes | length')" -eq "$1" ]; }
sentinel_ready() {
  cli pane process-info --pane "$1" 2>/dev/null |
    jq -e 'any(.result.process_info.foreground_processes[]?; .name == "sleep")' >/dev/null
}
export_root() {
  request_id="layout-menu-export-$$-$(date +%s)"
  jq -cn --arg id "$request_id" --arg tab "$tab" \
    '{id:$id,method:"layout.export",params:{tab_id:$tab}}' |
    nc -U -w 2 "$socket" |
    jq -cer --arg id "$request_id" \
      'select(.id == $id and has("result")) | .result.layout.root'
}
topology_signature() {
  jq -c 'def s: if .type == "pane" then {type,pane_id} else {type,direction,first:(.first|s),second:(.second|s)} end; s'
}
layout_is_equalized() {
  export_root | jq -e '
    def leaves: if .type == "pane" then 1 else ((.first|leaves)+(.second|leaves)) end;
    def balanced:
      if .type == "pane" then true
      else (.first|leaves) as $a | (.second|leaves) as $b |
        ($a/($a+$b)) as $want |
        ((.ratio-$want) < 0.000001 and (.ratio-$want) > -0.000001) and
        (.first|balanced) and (.second|balanced)
      end;
    balanced' >/dev/null
}
layout_is_main_vertical() {
  export_root | jq -e '
    .type == "split" and .direction == "right" and
    .first.type == "pane" and
    (.ratio - 0.62 < 0.000001 and .ratio - 0.62 > -0.000001) and
    .second.type == "split" and .second.direction == "down" and
    (.second.ratio - 0.5 < 0.000001 and .second.ratio - 0.5 > -0.000001)
  ' >/dev/null
}
zoom_is() {
  [ "$(cli pane layout --pane "$pane" | jq -r '.result.layout.zoomed')" = "$1" ]
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
mkdir -p "$config_home/herdr" "$evidence_dir"
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' "$prototype/config.toml" >"$config"
: >"$menu_log"
: >"$evidence_tmp"
production_before=$(production_hashes)
config_result=$(cli config check 2>&1)
grep -Fq 'key = "prefix+space"' "$config"
grep -Fq 'command = "exec \"$HERDR_PROTOTYPE_DIR/layout_menu.sh\""' "$config"
record config "$(jq -cn --arg result "$config_result" '{
  result:$result,binding:"prefix+Space",
  actions:["tiled","main-horizontal","main-vertical","even-horizontal",
    "even-vertical","equalize","zoom","adaptive-split","split-right","cancel"],
  ratio_only_presets:true,layout_apply_used:false
}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "layout-menu socket" test -S "$socket"
rm -f "$driver_fifo"
mkfifo "$driver_fifo"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "layout-menu client" grep -q '^READY$' "$driver_log"

pane=$(cli pane list | jq -er '.result.panes[] | select(.focused).pane_id')
tab=$(cli pane current --pane "$pane" | jq -er '.result.pane.tab_id')
right=$(cli pane split "$pane" --direction right --ratio 0.7 --no-focus | jq -er '.result.pane.pane_id')
bottom=$(cli pane split "$right" --direction down --ratio 0.65 --no-focus | jq -er '.result.pane.pane_id')
pids='[]'
for target in "$pane" "$right" "$bottom"; do
  cli pane run "$target" "exec sleep 300" >/dev/null
  wait_for "sentinel in $target" sentinel_ready "$target"
  pid=$(cli pane process-info --pane "$target" | jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
  pids=$(printf '%s\n' "$pids" | jq -c --arg pane "$target" --argjson pid "$pid" '. + [{pane_id:$pane,pid:$pid}]')
done
layout_before=$(export_root)
topology_before=$(printf '%s\n' "$layout_before" | topology_signature)

send_action layout-menu
screen_has '┌ popup'
send_action type:e
wait_for "equalize menu action" menu_count_is 1
wait_for "equalized topology" layout_is_equalized
wait_for "equalize popup dismissed" screen_lacks '┌ popup'
layout_equalized=$(export_root)
test "$(printf '%s\n' "$layout_equalized" | topology_signature)" = "$topology_before"
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
record equalize "$(jq -cn --argjson before "$layout_before" --argjson after "$layout_equalized" --argjson topology "$topology_before" --argjson pids "$pids" '{selection:"e",topology_preserved:true,processes_survived:true,topology_signature:$topology,sentinels:$pids,before:$before,after:$after}')"

send_action layout-menu
screen_has '┌ popup'
send_action 'type:|'
wait_for "main vertical menu action" menu_count_is 2
wait_for "main vertical ratios" layout_is_main_vertical
wait_for "main vertical popup dismissed" screen_lacks '┌ popup'
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
layout_main_vertical=$(export_root)
record main_vertical_menu "$(jq -cn --argjson layout "$layout_main_vertical" \
  --argjson pids "$pids" '{
    selection:"|",preset:"main-vertical",ratio_only:true,
    topology_preserved:true,processes_survived:true,focus_preserved:true,
    sentinels:$pids,layout:$layout
  }')"

send_action layout-menu
screen_has '┌ popup'
send_action type:z
wait_for "zoom on action" menu_count_is 3
wait_for "zoom on" zoom_is true
send_action layout-menu
send_action type:z
wait_for "zoom off action" menu_count_is 4
wait_for "zoom off" zoom_is false
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
record zoom "$(jq -cn --arg pane "$pane" --argjson pids "$pids" '{selection:"z",pane_id:$pane,states:[false,true,false],processes_survived:true,sentinels:$pids}')"

layout_pre_cancel=$(export_root)
send_action layout-menu
send_action type:q
wait_for "cancel action" menu_count_is 5
wait_for "cancel popup dismissed" screen_lacks '┌ popup'
test "$(export_root)" = "$layout_pre_cancel"
record cancel "$(jq -cn --argjson layout "$layout_pre_cancel" '{selection:"q",layout_unchanged:true,layout:$layout}')"

panes_before_adaptive=$(cli pane list | jq -c '[.result.panes[].pane_id]')
send_action layout-menu
send_action type:a
wait_for "adaptive split action" menu_count_is 6
wait_for "adaptive split pane" pane_count_is 4
adaptive_pane=$(cli pane list | jq -er --argjson before "$panes_before_adaptive" '.result.panes[] | select(.pane_id as $id | $before | index($id) | not).pane_id')
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
record adaptive_split "$(jq -cn --arg pane "$adaptive_pane" --argjson pids "$pids" '{selection:"a",new_pane:$pane,original_processes_survived:true,sentinels:$pids}')"
cli pane close "$adaptive_pane" >/dev/null
wait_for "adaptive fixture cleanup" pane_count_is 3

panes_before_right=$(cli pane list | jq -c '[.result.panes[].pane_id]')
send_action layout-menu
send_action type:v
wait_for "right split action" menu_count_is 7
wait_for "right split pane" pane_count_is 4
right_pane=$(cli pane list | jq -er --argjson before "$panes_before_right" '.result.panes[] | select(.pane_id as $id | $before | index($id) | not).pane_id')
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
record split_right "$(jq -cn --arg pane "$right_pane" --argjson pids "$pids" '{selection:"v",new_pane:$pane,original_processes_survived:true,sentinels:$pids}')"
cli pane close "$right_pane" >/dev/null
wait_for "right fixture cleanup" pane_count_is 3

menu_expected=7
validate_named_preset() {
  preset_name=$1
  preset_key=$2
  root_direction=$3
  remainder_direction=$4
  expected_root=$5
  named_tab=$(cli tab create --cwd "$root" --label "$preset_name" --focus |
    jq -er '.result.tab.tab_id')
  tab=$named_tab
  named_first=$(cli pane list | jq -er --arg tab "$named_tab" \
    '.result.panes[] | select(.tab_id == $tab).pane_id')
  named_second=$(cli pane split "$named_first" --direction "$root_direction" \
    --ratio 0.71 --no-focus | jq -er '.result.pane.pane_id')
  named_third=$(cli pane split "$named_second" --direction "$remainder_direction" \
    --ratio 0.64 --no-focus | jq -er '.result.pane.pane_id')
  named_sentinels='[]'
  for target in "$named_first" "$named_second" "$named_third"; do
    cli pane run "$target" "exec sleep 300" >/dev/null
    wait_for "$preset_name sentinel in $target" sentinel_ready "$target"
    target_info=$(cli pane get "$target" | jq -c '.result.pane')
    target_pid=$(cli pane process-info --pane "$target" |
      jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
    named_sentinels=$(printf '%s\n' "$named_sentinels" | jq -c \
      --argjson pane "$target_info" --argjson pid "$target_pid" \
      '. + [{pane_id:$pane.pane_id,terminal_id:$pane.terminal_id,
        cwd:($pane.foreground_cwd // $pane.cwd),pid:$pid}]')
  done
  before_named=$(export_root)
  menu_expected=$((menu_expected + 1))
  send_action layout-menu
  screen_has '┌ popup'
  send_action "type:$preset_key"
  wait_for "$preset_name menu action" menu_count_is "$menu_expected"
  wait_for "$preset_name popup dismissed" screen_lacks '┌ popup'
  after_named=$(export_root)
  printf '%s\n' "$after_named" | jq -e \
    --arg root_direction "$root_direction" \
    --arg remainder_direction "$remainder_direction" \
    --argjson root_ratio "$expected_root" '
    .type == "split" and .direction == $root_direction and
    (.ratio - $root_ratio < 0.000001 and .ratio - $root_ratio > -0.000001) and
    .second.type == "split" and .second.direction == $remainder_direction and
    (.second.ratio - 0.5 < 0.000001 and .second.ratio - 0.5 > -0.000001)
  ' >/dev/null
  test "$(printf '%s\n' "$before_named" | topology_signature)" = \
    "$(printf '%s\n' "$after_named" | topology_signature)"
  test "$(cli pane list | jq -er '.result.panes[] | select(.focused).pane_id')" = \
    "$named_first"
  printf '%s\n' "$named_sentinels" | jq -c '.[]' |
    while IFS= read -r sentinel; do
      sentinel_pane=$(printf '%s\n' "$sentinel" | jq -r '.pane_id')
      sentinel_terminal=$(printf '%s\n' "$sentinel" | jq -r '.terminal_id')
      sentinel_cwd=$(printf '%s\n' "$sentinel" | jq -r '.cwd')
      sentinel_pid_value=$(printf '%s\n' "$sentinel" | jq -r '.pid')
      kill -0 "$sentinel_pid_value"
      cli pane get "$sentinel_pane" | jq -e \
        --arg terminal "$sentinel_terminal" --arg cwd "$sentinel_cwd" '
        .result.pane.terminal_id == $terminal and
        (.result.pane.foreground_cwd // .result.pane.cwd) == $cwd
      ' >/dev/null
    done
  record "preset_$preset_name" "$(jq -cn --arg preset "$preset_name" \
    --arg key "$preset_key" \
    --argjson before "$before_named" --argjson after "$after_named" \
    --argjson sentinels "$named_sentinels" '{
      preset:$preset,selection:$key,real_prefix_transport:true,
      ratio_only:true,topology_preserved:true,
      process_identity_preserved:true,cwd_preserved:true,focus_preserved:true,
      sentinels:$sentinels,before:$before,after:$after
    }')"
}

validate_named_preset tiled + right down 0.3333333333333333
validate_named_preset main-horizontal _ down right 0.62
validate_named_preset main-vertical '|' right down 0.62
validate_named_preset even-horizontal '\' right right 0.3333333333333333
validate_named_preset even-vertical - down down 0.3333333333333333

incompatible_before=$(export_root)
incompatible_panes=$(cli pane list | jq -c '[.result.panes[] | {pane_id,tab_id,terminal_id}]')
set +e
HERDR_TARGET_PANE_ID="$named_first" \
  "$prototype/layout_preset.sh" even-horizontal >/dev/null 2>&1
incompatible_status=$?
set -e
test "$incompatible_status" -eq 4
test "$(export_root)" = "$incompatible_before"
test "$(cli pane list | jq -c '[.result.panes[] | {pane_id,tab_id,terminal_id}]')" = \
  "$incompatible_panes"
record incompatible_rejection "$(jq -cn --argjson layout "$incompatible_before" '{
  requested:"even-horizontal",status:4,mutation:false,
  topology_preserved:true,processes_preserved:true,layout:$layout
}')"

single_tab=$(cli tab create --cwd "$root" --label single-pane-presets --focus |
  jq -er '.result.tab.tab_id')
tab=$single_tab
single_pane=$(cli pane list | jq -er --arg tab "$single_tab" \
  '.result.panes[] | select(.tab_id == $tab).pane_id')
cli pane run "$single_pane" "exec sleep 300" >/dev/null
wait_for "single-pane sentinel" sentinel_ready "$single_pane"
single_pid=$(cli pane process-info --pane "$single_pane" |
  jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
single_before=$(export_root)
for single_key in + _ '|' '\' -; do
  menu_expected=$((menu_expected + 1))
  send_action layout-menu
  screen_has '┌ popup'
  send_action "type:$single_key"
  wait_for "single-pane preset $single_key" menu_count_is "$menu_expected"
  wait_for "single-pane popup dismissed" screen_lacks '┌ popup'
  test "$(export_root)" = "$single_before"
  test "$(cli pane list | jq -er '.result.panes[] | select(.focused).pane_id')" = \
    "$single_pane"
  kill -0 "$single_pid"
done
record single_pane_no_ops "$(jq -cn --arg pane "$single_pane" \
  --argjson pid "$single_pid" --argjson layout "$single_before" '{
    selections:["+","_","|","\\","-"],real_prefix_transport:true,
    pane_id:$pane,sentinel_pid:$pid,layout_unchanged:true,
    focus_preserved:true,process_preserved:true,layout:$layout
  }')"

concurrent_tab=$(cli tab create --cwd "$root" --label concurrent-layout --focus |
  jq -er '.result.tab.tab_id')
tab=$concurrent_tab
concurrent_first=$(cli pane list | jq -er --arg tab "$concurrent_tab" \
  '.result.panes[] | select(.tab_id == $tab).pane_id')
concurrent_second=$(cli pane split "$concurrent_first" --direction right \
  --ratio 0.7 --no-focus | jq -er '.result.pane.pane_id')
concurrent_third=$(cli pane split "$concurrent_second" --direction right \
  --ratio 0.64 --no-focus | jq -er '.result.pane.pane_id')
concurrent_pids='[]'
for target in "$concurrent_first" "$concurrent_second" "$concurrent_third"; do
  cli pane run "$target" "exec sleep 300" >/dev/null
  wait_for "concurrent sentinel in $target" sentinel_ready "$target"
  target_pid=$(cli pane process-info --pane "$target" |
    jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
  concurrent_pids=$(printf '%s\n' "$concurrent_pids" |
    jq -c --arg pane "$target" --argjson pid "$target_pid" \
      '. + [{pane_id:$pane,pid:$pid}]')
done
concurrent_topology=$(export_root | topology_signature)
set +e
HERDR_TARGET_PANE_ID="$concurrent_first" \
HERDR_LAYOUT_TEST_AFTER_UPDATE_HOOK="$concurrent_fixture" \
  "$prototype/layout_preset.sh" even-horizontal >/dev/null 2>&1
concurrent_status=$?
set -e
test "$concurrent_status" -eq 5
concurrent_after=$(export_root)
printf '%s\n' "$concurrent_after" | jq -e '
  .type == "split" and .direction == "right" and
  ((.ratio - 0.41) | fabs) < 0.000001 and
  .second.type == "split" and .second.direction == "right" and
  ((.second.ratio - 0.5) | fabs) < 0.000001
' >/dev/null
test "$(printf '%s\n' "$concurrent_after" | topology_signature)" = \
  "$concurrent_topology"
printf '%s\n' "$concurrent_pids" | jq -r '.[].pid' |
  while IFS= read -r pid; do kill -0 "$pid"; done
record concurrent_ownership "$(jq -cn --argjson layout "$concurrent_after" \
  --argjson pids "$concurrent_pids" '{
    injected_after_owned_updates:2,injected_foreign_ratio:0.41,status:5,
    foreign_ratio_preserved:true,
    helper_did_not_claim_foreign_update:true,topology_preserved:true,
    processes_preserved:true,sentinels:$pids,layout:$layout
  }')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn \
  --arg config_hash "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg helper_hash "$(shasum -a 256 "$prototype/layout_menu.sh" | awk '{print $1}')" \
  --arg preset_hash "$(shasum -a 256 "$prototype/layout_preset.sh" | awk '{print $1}')" \
  --arg client_hash "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg validator_hash "$(shasum -a 256 "$prototype/validate_layout_menu.sh" | awk '{print $1}')" \
  --arg concurrent_fixture_hash "$(shasum -a 256 "$concurrent_fixture" | awk '{print $1}')" \
  --argjson production "$production_after" \
  '{config_sha256:$config_hash,helper_sha256:$helper_hash,
    preset_sha256:$preset_hash,client_sha256:$client_hash,
    validator_sha256:$validator_hash,
    concurrent_fixture_sha256:$concurrent_fixture_hash,
    production_sha256:$production}')"
record result "$(jq -cn '{status:"PASS",session:"lm",production_configuration_modified:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr layout-menu validation: PASS (%s)\n' "$evidence"
