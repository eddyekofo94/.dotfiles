#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/u"
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
session=pu
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/popup-validation.jsonl"
evidence_tmp="$runtime/popup-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
popup_log="$runtime/popups.tsv"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "popup validation requires the prototype Herdr binary; run ./herdr/prototype/run.sh cli config check first" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_POPUP_LOG="$popup_log"

cli() {
  "$herdr" --session "$session" "$@"
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
    --arg fe "$(shasum -a 256 "$root/fish/functions/fe.fish" | awk '{print $1}')" \
    --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
    --arg neovim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
    '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"fish/functions/fe.fish":$fe,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$neovim}'
}

wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 100 ]; then
      echo "popup validation timed out: $description" >&2
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

screen_has() {
  grep -Fq "$1" "$screen"
}

screen_lacks() {
  ! grep -Fq "$1" "$screen"
}

popup_count_is() {
  [ "$(wc -l <"$popup_log" | tr -d ' ')" -eq "$1" ]
}

pane_inventory() {
  cli pane list | jq -Sc '.result.panes'
}

tab_inventory() {
  cli tab list | jq -Sc '.result.tabs'
}

workspace_inventory() {
  cli workspace list | jq -Sc '.result.workspaces'
}

layout_snapshot() {
  cli pane layout --pane "$1" | jq -Sc '.result.layout'
}

sentinel_ready() {
  cli pane process-info --pane "$1" 2>/dev/null |
    jq -e 'any(.result.process_info.foreground_processes[]?; .name == "sleep")' >/dev/null
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
sed \
  -e 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  -e 's|^command = "exec \\"${SHELL:-sh}\\""$|command = "exec \\"$HERDR_PROTOTYPE_DIR/popup_fixture.sh\\" scratch"|' \
  -e 's|^command = "command -v lazygit.*$|command = "exec \\"$HERDR_PROTOTYPE_DIR/popup_fixture.sh\\" lazygit"|' \
  "$prototype/config.toml" >"$config"
: >"$evidence_tmp"
: >"$popup_log"
production_before=$(production_hashes)

config_result=$(cli config check 2>&1)
grep -Fq 'key = "prefix+enter"' "$config"
grep -Fq 'command = "exec \"$HERDR_PROTOTYPE_DIR/popup_fixture.sh\" scratch"' "$config"
grep -Fq 'width = "80%"' "$config"
grep -Fq 'height = "80%"' "$config"
grep -Fq 'key = "prefix+g"' "$config"
grep -Fq 'command = "exec \"$HERDR_PROTOTYPE_DIR/popup_fixture.sh\" lazygit"' "$config"
grep -Fq 'width = "85%"' "$config"
grep -Fq 'height = "85%"' "$config"
record config "$(jq -cn --arg result "$config_result" '{result:$result,scratch:{binding:"prefix+Enter",width:"80%",height:"80%"},lazygit:{binding:"prefix+g",width:"85%",height:"85%"}}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "popup gate socket" test -S "$socket"

rm -f "$driver_fifo"
mkfifo "$driver_fifo"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "Herdr popup client" grep -q '^READY$' "$driver_log"

pane=$(cli pane list | jq -er '.result.panes[] | select(.focused).pane_id')
cli pane run "$pane" "cd \"$root\" && exec sleep 300" >/dev/null
wait_for "tiled sentinel" sentinel_ready "$pane"
sentinel_pid=$(cli pane process-info --pane "$pane" |
  jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
panes_before=$(pane_inventory)
tabs_before=$(tab_inventory)
workspaces_before=$(workspace_inventory)
layout_before=$(layout_snapshot "$pane")

send_action scratch-popup
wait_for "scratch fixture invocation" popup_count_is 1
screen_has '┌ popup'
scratch=$(awk -F '\t' 'NR == 1 {printf "{\"kind\":\"%s\",\"pid\":%s,\"rows\":%s,\"cols\":%s,\"cwd\":\"%s\"}", $1,$2,$3,$4,$5}' "$popup_log")
test "$(printf '%s\n' "$scratch" | jq -r '.kind')" = scratch
test "$(printf '%s\n' "$scratch" | jq -r '.rows')" -eq 30
test "$(printf '%s\n' "$scratch" | jq -r '.cols')" -eq 72
test "$(printf '%s\n' "$scratch" | jq -r '.cwd')" = "$root"
test "$(pane_inventory)" = "$panes_before"
test "$(tab_inventory)" = "$tabs_before"
test "$(workspace_inventory)" = "$workspaces_before"
test "$(layout_snapshot "$pane")" = "$layout_before"
kill -0 "$sentinel_pid"
send_action enter
wait_for "scratch popup dismissal" screen_lacks '┌ popup'
record scratch "$(printf '%s\n' "$scratch" | jq -c --argjson parent_pid "$sentinel_pid" '. + {parent_pane_pid:$parent_pid,tiled_objects_unchanged:true,dismissed_on_process_exit:true}')"

send_action lazygit-popup
wait_for "lazygit fixture invocation" popup_count_is 2
screen_has '┌ popup'
lazygit=$(awk -F '\t' 'NR == 2 {printf "{\"kind\":\"%s\",\"pid\":%s,\"rows\":%s,\"cols\":%s,\"cwd\":\"%s\"}", $1,$2,$3,$4,$5}' "$popup_log")
test "$(printf '%s\n' "$lazygit" | jq -r '.kind')" = lazygit
test "$(printf '%s\n' "$lazygit" | jq -r '.rows')" -eq 32
test "$(printf '%s\n' "$lazygit" | jq -r '.cols')" -eq 76
test "$(printf '%s\n' "$lazygit" | jq -r '.cwd')" = "$root"
test "$(pane_inventory)" = "$panes_before"
test "$(tab_inventory)" = "$tabs_before"
test "$(workspace_inventory)" = "$workspaces_before"
test "$(layout_snapshot "$pane")" = "$layout_before"
kill -0 "$sentinel_pid"
send_action enter
wait_for "lazygit popup dismissal" screen_lacks '┌ popup'
record lazygit "$(printf '%s\n' "$lazygit" | jq -c --argjson parent_pid "$sentinel_pid" '. + {parent_pane_pid:$parent_pid,tiled_objects_unchanged:true,dismissed_on_process_exit:true}')"

test "$(pane_inventory)" = "$panes_before"
test "$(tab_inventory)" = "$tabs_before"
test "$(workspace_inventory)" = "$workspaces_before"
test "$(layout_snapshot "$pane")" = "$layout_before"
kill -0 "$sentinel_pid"
production_after=$(production_hashes)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn \
  --arg config_hash "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg fixture_hash "$(shasum -a 256 "$prototype/popup_fixture.sh" | awk '{print $1}')" \
  --arg client_hash "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg validator_hash "$(shasum -a 256 "$prototype/validate_popups.sh" | awk '{print $1}')" \
  --argjson production "$production_after" \
  '{config_sha256:$config_hash,fixture_sha256:$fixture_hash,client_sha256:$client_hash,validator_sha256:$validator_hash,production_sha256:$production}')"
record result "$(jq -cn --arg session "$session" '{status:"PASS",session:$session,production_configuration_modified:false,migration_authorized:false}')"

mv "$evidence_tmp" "$evidence"
printf 'Herdr popup validation: PASS (%s)\n' "$evidence"
