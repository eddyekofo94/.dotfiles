#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
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

[ -x "$herdr" ] || {
  echo "layout-menu validation requires the prototype Herdr binary" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
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

rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir"
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' "$prototype/config.toml" >"$config"
: >"$menu_log"
: >"$evidence_tmp"
production_before=$(production_hashes)
config_result=$(cli config check 2>&1)
grep -Fq 'key = "prefix+space"' "$config"
grep -Fq 'command = "exec \"$HERDR_PROTOTYPE_DIR/layout_menu.sh\""' "$config"
record config "$(jq -cn --arg result "$config_result" '{result:$result,binding:"prefix+Space",actions:["equalize","zoom","adaptive-split","split-right","cancel"],layout_apply_used:false}')"

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
screen_lacks '┌ popup'
layout_equalized=$(export_root)
test "$(printf '%s\n' "$layout_equalized" | topology_signature)" = "$topology_before"
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
record equalize "$(jq -cn --argjson before "$layout_before" --argjson after "$layout_equalized" --argjson topology "$topology_before" --argjson pids "$pids" '{selection:"e",topology_preserved:true,processes_survived:true,topology_signature:$topology,sentinels:$pids,before:$before,after:$after}')"

send_action layout-menu
screen_has '┌ popup'
send_action type:z
wait_for "zoom on action" menu_count_is 2
wait_for "zoom on" zoom_is true
send_action layout-menu
send_action type:z
wait_for "zoom off action" menu_count_is 3
wait_for "zoom off" zoom_is false
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
record zoom "$(jq -cn --arg pane "$pane" --argjson pids "$pids" '{selection:"z",pane_id:$pane,states:[false,true,false],processes_survived:true,sentinels:$pids}')"

layout_pre_cancel=$(export_root)
send_action layout-menu
send_action type:q
wait_for "cancel action" menu_count_is 4
screen_lacks '┌ popup'
test "$(export_root)" = "$layout_pre_cancel"
record cancel "$(jq -cn --argjson layout "$layout_pre_cancel" '{selection:"q",layout_unchanged:true,layout:$layout}')"

panes_before_adaptive=$(cli pane list | jq -c '[.result.panes[].pane_id]')
send_action layout-menu
send_action type:a
wait_for "adaptive split action" menu_count_is 5
wait_for "adaptive split pane" pane_count_is 4
adaptive_pane=$(cli pane list | jq -er --argjson before "$panes_before_adaptive" '.result.panes[] | select(.pane_id as $id | $before | index($id) | not).pane_id')
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
record adaptive_split "$(jq -cn --arg pane "$adaptive_pane" --argjson pids "$pids" '{selection:"a",new_pane:$pane,original_processes_survived:true,sentinels:$pids}')"
cli pane close "$adaptive_pane" >/dev/null
wait_for "adaptive fixture cleanup" pane_count_is 3

panes_before_right=$(cli pane list | jq -c '[.result.panes[].pane_id]')
send_action layout-menu
send_action type:v
wait_for "right split action" menu_count_is 6
wait_for "right split pane" pane_count_is 4
right_pane=$(cli pane list | jq -er --argjson before "$panes_before_right" '.result.panes[] | select(.pane_id as $id | $before | index($id) | not).pane_id')
printf '%s\n' "$pids" | jq -r '.[].pid' | while IFS= read -r pid; do kill -0 "$pid"; done
record split_right "$(jq -cn --arg pane "$right_pane" --argjson pids "$pids" '{selection:"v",new_pane:$pane,original_processes_survived:true,sentinels:$pids}')"
cli pane close "$right_pane" >/dev/null
wait_for "right fixture cleanup" pane_count_is 3

production_after=$(production_hashes)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn \
  --arg config_hash "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg helper_hash "$(shasum -a 256 "$prototype/layout_menu.sh" | awk '{print $1}')" \
  --arg client_hash "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg validator_hash "$(shasum -a 256 "$prototype/validate_layout_menu.sh" | awk '{print $1}')" \
  --argjson production "$production_after" \
  '{config_sha256:$config_hash,helper_sha256:$helper_hash,client_sha256:$client_hash,validator_sha256:$validator_hash,production_sha256:$production}')"
record result "$(jq -cn '{status:"PASS",session:"lm",production_configuration_modified:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr layout-menu validation: PASS (%s)\n' "$evidence"
