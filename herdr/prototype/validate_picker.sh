#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/p"
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
session_a=pa
session_b=pb
socket_a="$config_home/herdr/sessions/$session_a/herdr.sock"
socket_b="$config_home/herdr/sessions/$session_b/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/picker-validation.jsonl"
evidence_tmp="$runtime/picker-validation.jsonl.tmp"
driver_fifo_a="$runtime/client-a.fifo"
driver_fifo_b="$runtime/client-b.fifo"
driver_log_a="$runtime/client-a.log"
driver_log_b="$runtime/client-b.log"
screen_a="$runtime/screen-a.txt"
screen_b="$runtime/screen-b.txt"
server_log_a="$runtime/server-a.log"
server_log_b="$runtime/server-b.log"

[ -x "$herdr" ] || {
  echo "picker validation requires the prototype Herdr binary; run ./herdr/prototype/run.sh cli config check first" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_PROTOTYPE_DIR="$prototype"

production_hashes() {
  jq -cn \
    --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
    --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
    --arg fe "$(shasum -a 256 "$root/fish/functions/fe.fish" | awk '{print $1}')" \
    --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
    --arg neovim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
    '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"fish/functions/fe.fish":$fe,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$neovim}'
}

cli_a() {
  "$herdr" --session "$session_a" "$@"
}

cli_b() {
  "$herdr" --session "$session_b" "$@"
}

record() {
  name=$1
  value=$2
  jq -cn --arg name "$name" --argjson value "$value" \
    '{check:$name,evidence:$value}' >>"$evidence_tmp"
}

wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 100 ]; then
      echo "picker validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}

focused_workspace() {
  cli_a workspace list | jq -er '.result.workspaces[] | select(.focused).workspace_id'
}

focused_tab() {
  cli_a tab list | jq -er '.result.tabs[] | select(.focused).tab_id'
}

focused_pane() {
  cli_a pane list | jq -er '.result.panes[] | select(.focused).pane_id'
}

workspace_is() {
  [ "$(focused_workspace)" = "$1" ]
}

tab_is() {
  [ "$(focused_tab)" = "$1" ]
}

pane_is() {
  [ "$(focused_pane)" = "$1" ]
}

pane_for_tab() {
  tab=$1
  cli_a pane list | jq -er --arg tab "$tab" \
    '.result.panes[] | select(.tab_id == $tab) | .pane_id' | sed -n '1p'
}

pane_absent() {
  pane=$1
  [ "$(cli_a pane list | jq --arg pane "$pane" '[.result.panes[] | select(.pane_id == $pane)] | length')" -eq 0 ]
}

pane_status_is() {
  pane=$1
  expected=$2
  [ "$(cli_a pane list | jq -r --arg pane "$pane" '.result.panes[] | select(.pane_id == $pane).agent_status')" = "$expected" ]
}

sentinel_ready() {
  pane=$1
  cli_a pane process-info --pane "$pane" 2>/dev/null |
    jq -e 'any(.result.process_info.foreground_processes[]?; .name == "sleep")' >/dev/null
}

start_sentinel() {
  pane=$1
  cli_a pane run "$pane" "exec sleep 300" >/dev/null
  wait_for "sentinel process in $pane" sentinel_ready "$pane"
  cli_a pane process-info --pane "$pane" |
    jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid'
}

pid_alive() {
  kill -0 "$1" 2>/dev/null
}

send_a() {
  action=$1
  before=$(wc -l <"$driver_log_a" | tr -d ' ')
  printf '%s\n' "$action" >&3
  wait_for "client A action $action" sh -c \
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "$3" ]' \
    sh "$driver_log_a" "$before" "SENT $action"
}

send_b() {
  action=$1
  before=$(wc -l <"$driver_log_b" | tr -d ' ')
  printf '%s\n' "$action" >&4
  wait_for "client B action $action" sh -c \
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "$3" ]' \
    sh "$driver_log_b" "$before" "SENT $action"
}

stop_disposable_server() {
  disposable_session=$1
  disposable_socket=$2
  if [ -S "$disposable_socket" ]; then
    "$herdr" --session "$disposable_session" session stop \
      "$disposable_session" --json >/dev/null 2>&1 || true
  fi
  pgrep -f "^$herdr --session $disposable_session server$" 2>/dev/null |
    while IFS= read -r pid; do
      [ -n "$pid" ] || continue
      kill "$pid" 2>/dev/null || true
      attempt=0
      while kill -0 "$pid" 2>/dev/null && [ "$attempt" -lt 20 ]; do
        sleep 0.05
        attempt=$((attempt + 1))
      done
      kill -KILL "$pid" 2>/dev/null || true
    done
}

screen_has() {
  screen=$1
  text=$2
  grep -Fq "$text" "$screen"
}

screen_lacks() {
  screen=$1
  text=$2
  ! grep -Fq "$text" "$screen"
}

screen_line() {
  screen=$1
  text=$2
  grep -F "$text" "$screen" | sed -n '1p'
}

overlay_text() {
  screen=$1
  awk '/┌/{inside=1} inside{print} /└/{inside=0}' "$screen"
}

overlay_has() {
  screen=$1
  text=$2
  overlay_text "$screen" | grep -Fq "$text"
}

overlay_lacks() {
  screen=$1
  text=$2
  ! overlay_text "$screen" | grep -Fq "$text"
}

overlay_line() {
  screen=$1
  text=$2
  overlay_text "$screen" | grep -F "$text" | sed -n '1p'
}

overlay_result_lacks() {
  screen=$1
  text=$2
  ! overlay_text "$screen" | grep -F "$text" | grep -Eq '├─|└─|▾|▸'
}

overlay_result_has() {
  screen=$1
  text=$2
  overlay_text "$screen" | grep -F "$text" | grep -Eq '├─|└─|▾|▸'
}

cleanup() {
  status=$?
  trap - EXIT INT TERM
  exec 3>&- 2>/dev/null || true
  exec 4>&- 2>/dev/null || true
  for pid in ${driver_pid_a:-} ${driver_pid_b:-}; do
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  cli_a session stop "$session_a" --json >/dev/null 2>&1 || true
  cli_b session stop "$session_b" --json >/dev/null 2>&1 || true
  for pid in ${server_pid_a:-} ${server_pid_b:-}; do
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  stop_disposable_server "$session_a" "$socket_a"
  stop_disposable_server "$session_b" "$socket_b"
  cli_a session delete "$session_a" --json >/dev/null 2>&1 || true
  cli_b session delete "$session_b" --json >/dev/null 2>&1 || true
  rm -f "$driver_fifo_a" "$driver_fifo_b"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Gate-only config and state live under herdr/prototype/.runtime.
stop_disposable_server "$session_a" "$socket_a"
stop_disposable_server "$session_b" "$socket_b"
rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir"
cp "$prototype/config.toml" "$config"
: >"$evidence_tmp"
production_before=$(production_hashes)

config_result=$(cli_a config check 2>&1)
for expected_line in \
  'prefix = "ctrl+a"' \
  'new_tab = "prefix+c"' \
  'next_tab = "prefix+n"' \
  'previous_tab = "prefix+p"' \
  'close_tab = "prefix+shift+x"' \
  'workspace_picker = "prefix+w"' \
  'goto = "prefix+f"' \
  'focus_pane_left = "prefix+h"' \
  'focus_pane_down = "prefix+j"' \
  'focus_pane_up = "prefix+k"' \
  'focus_pane_right = "prefix+l"' \
  'split_vertical = "prefix+v"' \
  'split_horizontal = ""' \
  'close_pane = ""' \
  'zoom = "prefix+z"' \
  'resize_mode = "prefix+r"' \
  'copy_mode = "prefix+s"' \
  'toggle_sidebar = "prefix+shift+s"' \
  'previous_workspace = "prefix+("' \
  'next_workspace = "prefix+)"' \
  'last_pane = ["prefix+tab", "ctrl+^"]' \
  'key = "prefix+a"' \
  'key = "prefix+shift+h"' \
  'key = "prefix+shift+j"' \
  'key = "prefix+shift+k"' \
  'key = "prefix+shift+l"' \
  'key = "prefix+x"' \
  'key = "prefix+u"' \
  'key = "prefix+enter"' \
  'key = "prefix+g"' \
  'key = "prefix+space"'
do
  grep -Fqx "$expected_line" "$config"
done
test "$(grep -c '^key = ' "$config")" -eq 24
grep -q '^key = "prefix+b"$' "$config"
grep -q '^key = "prefix+shift+b"$' "$config"
for digit in 0 1 2 3 4 5 6 7 8 9; do
  grep -q "^key = \"prefix+$digit\"$" "$config"
done
if grep -Eiq '(^|["[:space:]])(alt\+ctrl\+f|ctrl\+alt\+f)(["[:space:]]|$)' "$config"; then
  echo "direct Alt-Ctrl-f must remain absent from the picker prototype" >&2
  exit 1
fi
approved_bindings=$(jq -cn '["prefix=ctrl+a","focus=prefix+h/j/k/l","swap=prefix+H/J/K/L","resize=prefix+r","fixed_split=prefix+v","adaptive_split=prefix+a","equalize=prefix+=/Alt-=","copy_search=prefix+s","smart_close=prefix+x","close_other_panes=prefix+o/Alt-o","close_tab=prefix+X","tabs=prefix+c/n/p","numbered_tabs=prefix+0..9","zoom=prefix+z","sidebar=prefix+S","ready_prompt=prefix+b/B","open_url=prefix+u","workspace_picker=prefix+w","workspace_cycle=prefix+(/)/Ctrl-^","goto=prefix+f","scratch_popup=prefix+Enter","lazygit_popup=prefix+g","layout_menu=prefix+Space"]')
record config "$(jq -cn --arg result "$config_result" --argjson approved "$approved_bindings" '{result:$result,workspace_picker:"prefix+w",goto:"prefix+f",direct_alt_ctrl_f:false,prefix_enter_preserved:true,prefix_g_preserved:true,prefix_space_preserved:true,approved_bindings:$approved}')"

cli_a server >"$server_log_a" 2>&1 &
server_pid_a=$!
cli_b server >"$server_log_b" 2>&1 &
server_pid_b=$!
wait_for "session A socket" test -S "$socket_a"
wait_for "session B socket" test -S "$socket_b"

# Attaching the real clients creates each session's initial workspace. Keep both
# attached so later screen assertions observe live server-driven updates.
rm -f "$driver_fifo_a" "$driver_fifo_b"
mkfifo "$driver_fifo_a" "$driver_fifo_b"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session_a" "$prototype" "$screen_a" <"$driver_fifo_a" >"$driver_log_a" 2>&1 &
driver_pid_a=$!
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session_b" "$prototype" "$screen_b" <"$driver_fifo_b" >"$driver_log_b" 2>&1 &
driver_pid_b=$!
exec 3>"$driver_fifo_a"
exec 4>"$driver_fifo_b"
wait_for "Herdr picker client A" grep -q '^READY$' "$driver_log_a"
wait_for "Herdr picker client B" grep -q '^READY$' "$driver_log_b"
wait_for "session A initial workspace" sh -c \
  '"$1" --session "$2" workspace list | jq -e ".result.workspaces | length == 1" >/dev/null' \
  sh "$herdr" "$session_a"
wait_for "session B initial workspace" sh -c \
  '"$1" --session "$2" workspace list | jq -e ".result.workspaces | length == 1" >/dev/null' \
  sh "$herdr" "$session_b"

alpha=$(cli_a workspace list | jq -er '.result.workspaces[0].workspace_id')
cli_a workspace rename "$alpha" "Alpha Project" >/dev/null
overview=$(cli_a tab list | jq -er '.result.tabs[0].tab_id')
cli_a tab rename "$overview" "Overview" >/dev/null
blocked_pane=$(pane_for_tab "$overview")
cli_a pane rename "$blocked_pane" "BLOCKED SENTINEL" >/dev/null

cli_a tab create --workspace "$alpha" --cwd "$prototype" --label "Weekly Review" --no-focus >/dev/null
weekly=$(cli_a tab list | jq -er '.result.tabs[] | select(.label == "Weekly Review").tab_id')
working_pane=$(pane_for_tab "$weekly")
cli_a pane rename "$working_pane" "WORKING SENTINEL" >/dev/null
idle_pane=$(cli_a pane split "$working_pane" --direction down --ratio 0.5 --no-focus | jq -er '.result.pane.pane_id // .result.pane_id')
cli_a pane rename "$idle_pane" "IDLE SENTINEL" >/dev/null

cli_a workspace create --cwd "$prototype" --label "Beta Project" --no-focus >/dev/null
beta=$(cli_a workspace list | jq -er '.result.workspaces[] | select(.label == "Beta Project").workspace_id')
done_tab=$(cli_a tab list --workspace "$beta" | jq -er '.result.tabs[0].tab_id')
cli_a tab rename "$done_tab" "Done Queue" >/dev/null
done_pane=$(pane_for_tab "$done_tab")
cli_a pane rename "$done_pane" "DONE SENTINEL" >/dev/null

foreign=$(cli_b workspace list | jq -er '.result.workspaces[0].workspace_id')
cli_b workspace rename "$foreign" "Foreign Session B" >/dev/null
foreign_tab=$(cli_b tab list | jq -er '.result.tabs[0].tab_id')
foreign_pane=$(cli_b pane list | jq -er '.result.panes[0].pane_id')
cli_b tab rename "$foreign_tab" "Foreign Tab" >/dev/null
cli_b pane rename "$foreign_pane" "FOREIGN ONLY" >/dev/null

blocked_pid=$(start_sentinel "$blocked_pane")
working_pid=$(start_sentinel "$working_pane")
idle_pid=$(start_sentinel "$idle_pane")
done_pid=$(start_sentinel "$done_pane")
sentinels=$(jq -cn \
  --arg blocked_pane "$blocked_pane" --argjson blocked_pid "$blocked_pid" \
  --arg working_pane "$working_pane" --argjson working_pid "$working_pid" \
  --arg idle_pane "$idle_pane" --argjson idle_pid "$idle_pid" \
  --arg done_pane "$done_pane" --argjson done_pid "$done_pid" \
  '[{pane:$blocked_pane,pid:$blocked_pid},{pane:$working_pane,pid:$working_pid},{pane:$idle_pane,pid:$idle_pid},{pane:$done_pane,pid:$done_pid}]')

cli_a pane report-agent "$blocked_pane" --source picker-gate --agent PickerBlocked --state blocked >/dev/null
cli_a pane report-agent "$working_pane" --source picker-gate --agent PickerWorking --state working >/dev/null
cli_a pane report-agent "$idle_pane" --source picker-gate --agent PickerIdle --state idle >/dev/null
cli_a pane report-agent "$done_pane" --source picker-gate --agent PickerDone --state working >/dev/null
cli_a pane report-agent "$done_pane" --source picker-gate --agent PickerDone --state idle >/dev/null
cli_a agent focus "$blocked_pane" >/dev/null

wait_for "blocked fixture state" pane_status_is "$blocked_pane" blocked
wait_for "working fixture state" pane_status_is "$working_pane" working
wait_for "idle fixture state" pane_status_is "$idle_pane" idle
wait_for "done fixture state" pane_status_is "$done_pane" done

topology=$(jq -cn \
  --arg alpha "$alpha" --arg beta "$beta" --arg overview "$overview" --arg weekly "$weekly" \
  --arg blocked "$blocked_pane" --arg working "$working_pane" --arg idle "$idle_pane" --arg done "$done_pane" \
  --argjson sentinels "$sentinels" \
  '{workspaces:[{id:$alpha,label:"Alpha Project"},{id:$beta,label:"Beta Project"}],tabs:[{id:$overview,label:"Overview"},{id:$weekly,label:"Weekly Review"}],panes:[{id:$blocked,label:"BLOCKED SENTINEL",status:"blocked"},{id:$working,label:"WORKING SENTINEL",status:"working"},{id:$idle,label:"IDLE SENTINEL",status:"idle"},{id:$done,label:"DONE SENTINEL",status:"done"}],sentinels:$sentinels}')
record topology "$topology"
objects_before=$(jq -cn \
  --argjson workspaces "$(cli_a workspace list | jq -c '[.result.workspaces[].workspace_id] | sort')" \
  --argjson tabs "$(cli_a tab list | jq -c '[.result.tabs[].tab_id] | sort')" \
  --argjson panes "$(cli_a pane list | jq -c '[.result.panes[].pane_id] | sort')" \
  '{workspaces:$workspaces,tabs:$tabs,panes:$panes}')

send_a workspace
screen_has "$screen_a" "Alpha Project"
screen_has "$screen_a" "Beta Project"
screen_lacks "$screen_a" "search panes"
workspace_line=$(screen_line "$screen_a" "Alpha Project")
send_a down
send_a enter
wait_for "workspace picker native selection" workspace_is "$beta"
workspace_picker_focus=$(focused_workspace)
cli_a agent focus "$blocked_pane" >/dev/null
cli_a pane report-agent "$done_pane" --source picker-gate --agent PickerDone --state working >/dev/null
cli_a pane report-agent "$done_pane" --source picker-gate --agent PickerDone --state idle >/dev/null
wait_for "done fixture reset after workspace picker" pane_status_is "$done_pane" done

send_a goto
overlay_has "$screen_a" "search panes"
overlay_result_has "$screen_a" "Alpha Project"
overlay_result_has "$screen_a" "Beta Project"
overlay_lacks "$screen_a" "Foreign Session B"
overlay_result_has "$screen_a" "BLOCKED SENTINEL"
overlay_result_has "$screen_a" "DONE SENTINEL"
current_line=$(overlay_line "$screen_a" "BLOCKED SENTINEL")
printf '%s\n' "$current_line" | grep -q '→.*◆'
record open_bindings "$(jq -cn --arg workspace_line "$workspace_line" --arg workspace_focus "$workspace_picker_focus" --arg current_line "$current_line" '{workspace_picker:{binding:"prefix+w",line:$workspace_line,search_overlay:false,focused_workspace_after_down_enter:$workspace_focus},goto:{binding:"prefix+f",line:$current_line,search_overlay:true,current_selected:true}}')"

send_a search
send_a 'type:ALPHA PROJECT'
overlay_result_has "$screen_a" "Alpha Project"
overlay_result_lacks "$screen_a" "Beta Project"
alpha_line=$(overlay_line "$screen_a" "Alpha Project")
send_a clear
send_a 'type:weekly review'
overlay_result_has "$screen_a" "Weekly Review"
overlay_result_lacks "$screen_a" "Done Queue"
weekly_line=$(overlay_line "$screen_a" "Weekly Review")
send_a clear
send_a 'type:idle sentinel'
overlay_result_has "$screen_a" "IDLE SENTINEL"
overlay_result_lacks "$screen_a" "BLOCKED SENTINEL"
idle_search_line=$(overlay_line "$screen_a" "IDLE SENTINEL")
send_a clear
send_a esc
record search "$(jq -cn --arg alpha "$alpha_line" --arg weekly "$weekly_line" --arg idle "$idle_search_line" '{case_insensitive_multi_term:{query:"ALPHA PROJECT",match:$alpha,nonmatch:"Beta Project"},tab_query:{query:"weekly review",match:$weekly,nonmatch:"Done Queue"},pane_query:{query:"idle sentinel",match:$idle,nonmatch:"BLOCKED SENTINEL"}}')"

send_a blocked
overlay_result_has "$screen_a" "BLOCKED SENTINEL"
overlay_result_lacks "$screen_a" "WORKING SENTINEL"
overlay_result_lacks "$screen_a" "IDLE SENTINEL"
overlay_result_lacks "$screen_a" "DONE SENTINEL"
blocked_line=$(overlay_line "$screen_a" "BLOCKED SENTINEL")
send_a all
send_a working
overlay_result_has "$screen_a" "WORKING SENTINEL"
overlay_result_lacks "$screen_a" "BLOCKED SENTINEL"
overlay_result_lacks "$screen_a" "IDLE SENTINEL"
overlay_result_lacks "$screen_a" "DONE SENTINEL"
working_line=$(overlay_line "$screen_a" "WORKING SENTINEL")
send_a all
send_a idle
overlay_result_has "$screen_a" "IDLE SENTINEL"
overlay_result_lacks "$screen_a" "BLOCKED SENTINEL"
overlay_result_lacks "$screen_a" "WORKING SENTINEL"
overlay_result_lacks "$screen_a" "DONE SENTINEL"
idle_line=$(overlay_line "$screen_a" "IDLE SENTINEL")
send_a all
send_a done
overlay_result_has "$screen_a" "DONE SENTINEL"
overlay_result_lacks "$screen_a" "BLOCKED SENTINEL"
overlay_result_lacks "$screen_a" "WORKING SENTINEL"
overlay_result_lacks "$screen_a" "IDLE SENTINEL"
done_line=$(overlay_line "$screen_a" "DONE SENTINEL")
send_a all
overlay_result_has "$screen_a" "BLOCKED SENTINEL"
overlay_result_has "$screen_a" "WORKING SENTINEL"
overlay_result_has "$screen_a" "IDLE SENTINEL"
overlay_result_has "$screen_a" "DONE SENTINEL"
record state_filters "$(jq -cn --arg blocked "$blocked_line" --arg working "$working_line" --arg idle "$idle_line" --arg done "$done_line" '{blocked:$blocked,working:$working,idle:$idle,done:$done,clear_restored:true}')"

send_a search
send_a 'type:Beta Project'
selection_reset=0
while [ "$selection_reset" -lt 8 ]; do
  send_a up
  selection_reset=$((selection_reset + 1))
done
send_a enter
wait_for "workspace selection" workspace_is "$beta"
workspace_focus=$(focused_workspace)
screen_lacks "$screen_a" "search panes"

send_a goto
send_a search
send_a 'type:Weekly Review'
selection_reset=0
while [ "$selection_reset" -lt 8 ]; do
  send_a up
  selection_reset=$((selection_reset + 1))
done
send_a down
send_a enter
wait_for "tab selection" tab_is "$weekly"
tab_focus=$(focused_tab)
screen_lacks "$screen_a" "search panes"

send_a goto
send_a search
send_a 'type:IDLE SENTINEL'
selection_reset=0
while [ "$selection_reset" -lt 8 ]; do
  send_a up
  selection_reset=$((selection_reset + 1))
done
send_a down
send_a down
send_a enter
wait_for "pane selection" pane_is "$idle_pane"
pane_focus=$(focused_pane)
screen_lacks "$screen_a" "search panes"
record selection "$(jq -cn --arg workspace "$workspace_focus" --arg tab "$tab_focus" --arg pane "$pane_focus" '{workspace:{focused:$workspace,terminal_mode:true},tab:{focused:$tab,terminal_mode:true},pane:{focused:$pane,terminal_mode:true}}')"

cli_a agent focus "$blocked_pane" >/dev/null
send_a goto
send_a search
send_a 'type:BLOCKED SENTINEL'
send_a esc
overlay_has "$screen_a" "BLOCKED SENTINEL"
test "$(focused_pane)" = "$blocked_pane"
search_back_line=$(overlay_line "$screen_a" "BLOCKED SENTINEL")
send_a esc
screen_lacks "$screen_a" "search panes"
test "$(focused_pane)" = "$blocked_pane"

send_a goto
send_a search
send_a 'type:NO MATCH TARGET'
overlay_lacks "$screen_a" "BLOCKED SENTINEL"
send_a enter
overlay_has "$screen_a" "NO MATCH TARGET"
test "$(focused_pane)" = "$blocked_pane"
send_a esc
send_a esc

stale_pane=$(cli_a pane split "$blocked_pane" --direction down --ratio 0.5 --no-focus | jq -er '.result.pane.pane_id // .result.pane_id')
cli_a pane rename "$stale_pane" "STALE TARGET" >/dev/null
send_a goto
send_a search
send_a 'type:STALE TARGET'
overlay_has "$screen_a" "STALE TARGET"
cli_a pane close "$stale_pane" >/dev/null
wait_for "stale target removal" pane_absent "$stale_pane"
send_a snapshot
overlay_result_lacks "$screen_a" "STALE TARGET"
send_a enter
test "$(focused_pane)" = "$blocked_pane"
send_a esc
send_a esc
record return_paths "$(jq -cn --arg search_back "$search_back_line" --arg pane "$blocked_pane" '{search_escape:{returned_to_navigator:true,focus_unchanged:$pane,line:$search_back},outer_escape:{returned_to_terminal:true,focus_unchanged:$pane},no_match_enter:{no_op:true,focus_unchanged:$pane},stale_target_enter:{no_op:true,focus_unchanged:$pane}}')"

printf '%s\n' "$sentinels" | jq -r '.[].pid' | while IFS= read -r pid; do
  pid_alive "$pid"
done
objects_after=$(jq -cn \
  --argjson workspaces "$(cli_a workspace list | jq -c '[.result.workspaces[].workspace_id] | sort')" \
  --argjson tabs "$(cli_a tab list | jq -c '[.result.tabs[].tab_id] | sort')" \
  --argjson panes "$(cli_a pane list | jq -c '[.result.panes[].pane_id] | sort')" \
  '{workspaces:$workspaces,tabs:$tabs,panes:$panes}')
test "$objects_after" = "$objects_before"
record process_safety "$(jq -cn --argjson sentinels "$sentinels" --argjson before "$objects_before" --argjson after "$objects_after" '{sentinels:$sentinels,all_alive_after_picker_paths:true,objects_before:$before,objects_after:$after,runtime_objects_unchanged:($before == $after)}')"

send_b goto
overlay_has "$screen_b" "Foreign Session B"
overlay_has "$screen_b" "FOREIGN ONLY"
overlay_lacks "$screen_b" "Alpha Project"
foreign_line=$(overlay_line "$screen_b" "FOREIGN ONLY")
sessions=$($herdr session list --json | jq -c '[.sessions[] | select(.name == "pa" or .name == "pb") | .name] | sort')
test "$sessions" = '["pa","pb"]'
record session_boundary "$(jq -cn --argjson sessions "$sessions" --arg a_current "$current_line" --arg b_current "$foreign_line" '{named_sessions:$sessions,session_a_navigator:{contains:"Alpha Project",excludes:"Foreign Session B",line:$a_current},explicit_attach_session_b:{contains:"Foreign Session B",excludes:"Alpha Project",line:$b_current}}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn --argjson before "$production_before" --argjson after "$production_after" '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before == $after)}')"

artifact_hashes=$(jq -cn \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg client "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$prototype/validate_picker.sh" | awk '{print $1}')" \
  '{"config.toml":$config,"picker_client.py":$client,"validate_picker.sh":$validator}')
record result "$(jq -cn --arg version "$($herdr --version)" --argjson hashes "$artifact_hashes" '{status:"PASS",version:$version,session:"pa",production_configuration_modified:false,migration_authorized:false,validation_plan_steps:7,artifact_hashes:$hashes}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr searchable picker validation: PASS (%s)\n' "$evidence"
