#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$prototype/run.sh --border focused cli"
export HERDR_BIN_PATH="$prototype/.runtime/bin/herdr"
export HERDR_SESSION=trial-focused
export XDG_CONFIG_HOME="$prototype/.runtime/cf"
export HERDR_PROTOTYPE_DIR="$prototype"
socket="$XDG_CONFIG_HOME/herdr/sessions/$HERDR_SESSION/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/binding-validation.jsonl"
evidence_tmp="$prototype/.runtime/binding-validation.jsonl.tmp"
url_log="$evidence_dir/opened-urls.log"
mkdir -p "$evidence_dir"
rm -rf "$prototype/.runtime/close-confirm"
rm -rf "$prototype/.runtime/pane-close-others-confirm"
: >"$evidence_tmp"
: >"$url_log"

record() {
  name=$1
  value=$2
  jq -cn --arg name "$name" --argjson value "$value" \
    '{check:$name,evidence:$value}' >>"$evidence_tmp"
}

production_hashes() {
  jq -cn \
    --arg tmux "$(shasum -a 256 "$prototype/../../tmux/tmux.conf" | awk '{print $1}')" \
    --arg fish "$(shasum -a 256 "$prototype/../../fish/config.fish" | awk '{print $1}')" \
    --arg ghostty "$(shasum -a 256 "$prototype/../../ghostty/config" | awk '{print $1}')" \
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
      echo "binding validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}

tab_absent() {
  tab=$1
  [ "$($runner tab list | jq --arg tab "$tab" '[.result.tabs[] | select(.tab_id == $tab)] | length')" -eq 0 ]
}

workspace_tab_count_is() {
  workspace=$1
  expected=$2
  [ "$($runner tab list | jq --arg workspace "$workspace" '[.result.tabs[] | select(.workspace_id == $workspace)] | length')" -eq "$expected" ]
}

pid_dead() {
  ! kill -0 "$1" 2>/dev/null
}

cleanup() {
  exit_code=$?
  trap - EXIT INT TERM
  $runner session stop "$HERDR_SESSION" --json >/dev/null 2>&1 || true
  if [ -n "${server_pid:-}" ]; then
    wait "$server_pid" 2>/dev/null || true
  fi
  $runner session delete "$HERDR_SESSION" --json >/dev/null 2>&1 || true
  rm -f "$evidence_tmp"
  exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

production_before=$(production_hashes)

# Always start from the disposable focused prototype session. This validator
# must be repeatable and must never depend on residue from an earlier pass.
$runner session stop "$HERDR_SESSION" --json >/dev/null 2>&1 || true
$runner session delete "$HERDR_SESSION" --json >/dev/null 2>&1 || true
$runner server >"$prototype/.runtime/binding-server.log" 2>&1 &
server_pid=$!
wait_for "binding server socket" test -S "$socket"
$runner workspace create --cwd "$prototype" --label Binding --focus >/dev/null

panes=$($runner pane list)
initial=$(printf '%s\n' "$panes" | jq -er '.result.panes | select(length == 1) | .[0].pane_id') || {
  echo "validation requires a fresh one-pane trial-focused session" >&2
  exit 2
}

before=$($runner pane layout --pane "$initial" | jq -c '.result.layout')
right=$($runner pane split "$initial" --direction right --ratio 0.5 --focus | jq -er '.result.pane.pane_id')
$runner pane send-text "$right" "printf '\\nRIGHT_SENTINEL_READY\\n'" >/dev/null
$runner pane send-keys "$right" return >/dev/null
sleep 0.2
after_fixed=$($runner pane layout --pane "$right" | jq -c '.result.layout')
record fixed_split "$(jq -cn --argjson before "$before" --argjson after "$after_fixed" '{before:$before,after:$after}')"

adaptive=$(HERDR_TARGET_PANE_ID="$right" "$prototype/adaptive_split.sh" | jq -er '.result.pane.pane_id')
after_adaptive=$($runner pane layout --pane "$adaptive" | jq -c '.result.layout')
record adaptive_split "$(jq -cn --arg pane "$adaptive" --argjson layout "$after_adaptive" '{new_pane:$pane,layout:$layout}')"

swap_before=$($runner pane layout --pane "$initial" | jq -c '.result.layout.panes')
HERDR_TARGET_PANE_ID="$initial" "$prototype/swap_pane.sh" right >/dev/null
swap_after=$($runner pane layout --pane "$initial" | jq -c '.result.layout.panes')
record swap "$(jq -cn --arg pane "$initial" --argjson before "$swap_before" --argjson after "$swap_after" '{pane:$pane,before:$before,after:$after}')"

resize_before=$($runner pane layout --pane "$initial" | jq -c '.result.layout')
$runner pane resize --pane "$initial" --direction right --amount 0.1 >/dev/null
resize_after=$($runner pane layout --pane "$initial" | jq -c '.result.layout')
record resize "$(jq -cn --argjson before "$resize_before" --argjson after "$resize_after" '{before:$before,after:$after}')"

move_before=$($runner pane current --pane "$adaptive" | jq -c '.result.pane')
move_new=$($runner pane move "$adaptive" --new-tab --label binding-move --focus | jq -c '.result')
move_mid=$($runner pane current --pane "$adaptive" | jq -c '.result.pane')
new_tab=$(printf '%s\n' "$move_mid" | jq -er '.tab_id')
original_tab=$(printf '%s\n' "$move_before" | jq -er '.tab_id')
$runner pane move "$adaptive" --tab "$original_tab" --split down --target-pane "$right" --focus >/dev/null
move_after=$($runner pane current --pane "$adaptive" | jq -c '.result.pane')
record move "$(jq -cn --arg temporary_tab "$new_tab" --argjson before "$move_before" --argjson middle "$move_mid" --argjson after "$move_after" '{temporary_tab:$temporary_tab,before:$before,middle:$middle,after:$after}')"

# A disposable foreground sentinel must survive smart-close; a bare-shell pane
# in the same tab must close immediately.
$runner pane send-text "$right" "exec sleep 300" >/dev/null
$runner pane send-keys "$right" return >/dev/null
sleep 0.2
process_before=$($runner pane process-info --pane "$right" | jq -c '.result.process_info')
set +e
HERDR_TARGET_PANE_ID="$right" "$prototype/smart_close.sh" >/dev/null 2>&1
protected_status=$?
set -e
process_after=$($runner pane process-info --pane "$right" | jq -c '.result.process_info')
HERDR_TARGET_PANE_ID="$right" "$prototype/smart_close.sh" >/dev/null
confirmed_exists=$($runner pane list | jq --arg pane "$right" '[.result.panes[] | select(.pane_id == $pane)] | length')
shell_pane=$($runner pane split "$initial" --direction down --ratio 0.5 --no-focus | jq -er '.result.pane.pane_id')
sleep 0.2
HERDR_TARGET_PANE_ID="$shell_pane" "$prototype/smart_close.sh" >/dev/null
shell_exists=$($runner pane list | jq --arg pane "$shell_pane" '[.result.panes[] | select(.pane_id == $pane)] | length')
last_tab=$($runner tab create --label last-pane-close --focus | jq -er '.result.tab.tab_id // .result.tab_id')
last_pane=$($runner pane current --current | jq -er '.result.pane.pane_id')
set +e
HERDR_TARGET_PANE_ID="$last_pane" "$prototype/smart_close.sh" >/dev/null 2>&1
last_status=$?
set -e
last_exists=$($runner pane list | jq --arg pane "$last_pane" '[.result.panes[] | select(.pane_id == $pane)] | length')
$runner tab close "$last_tab" >/dev/null
record smart_close "$(jq -cn --argjson status "$protected_status" --argjson before "$process_before" --argjson after "$process_after" --argjson confirmed_exists "$confirmed_exists" --arg shell_pane "$shell_pane" --argjson shell_exists "$shell_exists" --arg last_pane "$last_pane" --argjson last_status "$last_status" --argjson last_exists "$last_exists" '{protected_exit:$status,process_before:$before,process_after_first_press:$after,confirmed_process_pane_exists_after_second_press:$confirmed_exists,bare_shell_pane:$shell_pane,bare_shell_exists_after:$shell_exists,last_pane:$last_pane,last_pane_exit:$last_status,last_pane_exists_after:$last_exists}')"

zoom_before=$($runner pane layout --pane "$initial" | jq '.result.layout.zoomed')
$runner pane zoom "$initial" --on >/dev/null
zoom_on=$($runner pane layout --pane "$initial" | jq '.result.layout.zoomed')
$runner pane zoom "$initial" --off >/dev/null
zoom_after=$($runner pane layout --pane "$initial" | jq '.result.layout.zoomed')
record zoom "$(jq -cn --argjson before "$zoom_before" --argjson on "$zoom_on" --argjson after "$zoom_after" '{before:$before,on:$on,after:$after}')"

# Use three disposable panes so each URL fixture is independently visible.
url_results='[]'
for fixture in zero one multiple; do
  pane=$($runner pane split "$initial" --direction down --ratio 0.5 --focus | jq -er '.result.pane.pane_id')
  case "$fixture" in
    zero) text='NO_URL_FIXTURE' ;;
    one) text='ONE http://a' ;;
    multiple) text='http://a http://b' ;;
  esac
  $runner pane send-text "$pane" "printf '\\n%s\\n' '$text'" >/dev/null
  $runner pane send-keys "$pane" return >/dev/null
  sleep 0.15
  set +e
  output=$(HERDR_TARGET_PANE_ID="$pane" HERDR_URL_OPENER="$prototype/url_opener_fixture.sh" HERDR_URL_OPEN_LOG="$url_log" "$prototype/open_visible_url.sh" 2>&1)
  status=$?
  set -e
  url_results=$(printf '%s\n' "$url_results" | jq -c --arg fixture "$fixture" --argjson status "$status" --arg output "$output" '. + [{fixture:$fixture,status:$status,output:$output}]')
  $runner pane close "$pane" >/dev/null
done
record visible_urls "$(jq -cn --argjson cases "$url_results" --rawfile opened "$url_log" '{cases:$cases,opened:($opened|split("\n")|map(select(length>0)))}')"
printf '%s\n' "$url_results" | jq -e '
  (map(select(.fixture == "zero"))[0].status == 4) and
  (map(select(.fixture == "one"))[0].status == 0) and
  (map(select(.fixture == "multiple"))[0].status == 0)
' >/dev/null
test "$(sed -n '1p' "$url_log")" = "http://a"
test "$(sed -n '2p' "$url_log")" = "http://b"
test "$(wc -l <"$url_log" | tr -d ' ')" -eq 2

# Exercise the real Herdr -> Kitty CSI-u -> Fish binding path. This is distinct
# from invoking the helper scripts directly and prevents transport regressions.
$runner pane send-text "$initial" "source $prototype/herdr_nav.fish" >/dev/null
$runner pane send-keys "$initial" return >/dev/null
sleep 0.15
transport_before=$($runner pane list | jq '.result.panes | length')
transport_ids=$($runner pane list | jq -c '[.result.panes[].pane_id]')
$runner pane send-keys "$initial" alt+n >/dev/null
sleep 0.2
transport_after_json=$($runner pane list)
transport_adaptive=$(printf '%s\n' "$transport_after_json" | jq '.result.panes | length')
transport_pane=$(printf '%s\n' "$transport_after_json" | jq -er --argjson before "$transport_ids" '.result.panes[].pane_id | select(. as $id | $before | index($id) | not)')
transport_child_process=$($runner pane process-info --pane "$transport_pane" | jq -c '.result.process_info.foreground_processes')
printf '%s\n' "$transport_child_process" | jq -e \
  --arg adapter "$prototype/herdr_nav.fish" \
  'any(.[]; .name == "fish" and ((.argv // []) | join(" ") | contains($adapter)))' >/dev/null
transport_ids=$($runner pane list | jq -c '[.result.panes[].pane_id]')
$runner pane send-keys "$transport_pane" alt+v >/dev/null
sleep 0.2
transport_after_json=$($runner pane list)
transport_fixed=$(printf '%s\n' "$transport_after_json" | jq '.result.panes | length')
transport_grandchild=$(printf '%s\n' "$transport_after_json" | jq -er --argjson before "$transport_ids" '.result.panes[].pane_id | select(. as $id | $before | index($id) | not)')
transport_grandchild_process=$($runner pane process-info --pane "$transport_grandchild" | jq -c '.result.process_info.foreground_processes')
printf '%s\n' "$transport_grandchild_process" | jq -e \
  --arg adapter "$prototype/herdr_nav.fish" \
  'any(.[]; .name == "fish" and ((.argv // []) | join(" ") | contains($adapter)))' >/dev/null
$runner pane close "$transport_grandchild" >/dev/null
$runner pane close "$transport_pane" >/dev/null
zoom_transport_before=$($runner pane layout --pane "$initial" | jq '.result.layout.zoomed')
$runner pane send-keys "$initial" alt+z >/dev/null
sleep 0.1
zoom_transport_on=$($runner pane layout --pane "$initial" | jq '.result.layout.zoomed')
$runner pane send-keys "$initial" alt+z >/dev/null
sleep 0.1
zoom_transport_after=$($runner pane layout --pane "$initial" | jq '.result.layout.zoomed')
close_transport=$($runner pane split "$initial" --direction down --ratio 0.5 --focus | jq -er '.result.pane.pane_id')
$runner pane send-text "$close_transport" "source $prototype/herdr_nav.fish" >/dev/null
$runner pane send-keys "$close_transport" return >/dev/null
sleep 0.15
$runner pane send-keys "$close_transport" alt+q >/dev/null
sleep 0.2
close_transport_exists=$($runner pane list | jq --arg pane "$close_transport" '[.result.panes[] | select(.pane_id == $pane)] | length')
test "$transport_adaptive" -eq $((transport_before + 1))
test "$transport_fixed" -eq $((transport_before + 2))
test "$zoom_transport_before" = false
test "$zoom_transport_on" = true
test "$zoom_transport_after" = false
test "$close_transport_exists" -eq 0
record alt_transport "$(jq -cn --argjson before "$transport_before" --argjson adaptive "$transport_adaptive" --argjson fixed "$transport_fixed" --argjson child_process "$transport_child_process" --argjson grandchild_process "$transport_grandchild_process" --argjson zoom_before "$zoom_transport_before" --argjson zoom_on "$zoom_transport_on" --argjson zoom_after "$zoom_transport_after" --argjson close_exists "$close_transport_exists" '{pane_count_before:$before,after_alt_n:$adaptive,after_nested_alt_v:$fixed,child_process:$child_process,grandchild_process:$grandchild_process,zoom_before:$zoom_before,zoom_on:$zoom_on,zoom_after:$zoom_after,alt_q_pane_exists_after:$close_exists}')"

# Alt-o is application-owned. In a Fish pane it uses the same confirmation-
# protected Herdr helper as prefix+o; Neovim keeps its existing <M-o> mapping.
only_tab=$($runner tab create --label close-other-pane-gate --focus | jq -er '.result.tab.tab_id // .result.tab_id')
only_survivor=$($runner pane current --current | jq -er '.result.pane.pane_id')
$runner pane send-text "$only_survivor" "source $prototype/herdr_nav.fish" >/dev/null
$runner pane send-keys "$only_survivor" return >/dev/null
sleep 0.15
only_a=$($runner pane split "$only_survivor" --direction right --ratio 0.5 --no-focus | jq -er '.result.pane.pane_id')
only_b=$($runner pane split "$only_a" --direction down --ratio 0.5 --no-focus | jq -er '.result.pane.pane_id')
for target in "$only_a" "$only_b"; do
  $runner pane send-text "$target" "exec sleep 300" >/dev/null
  $runner pane send-keys "$target" return >/dev/null
done
sleep 0.2
only_a_pid=$($runner pane process-info --pane "$only_a" | jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
only_b_pid=$($runner pane process-info --pane "$only_b" | jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
$runner pane send-keys "$only_survivor" alt+o >/dev/null
sleep 0.2
only_first_count=$($runner pane list | jq --arg tab "$only_tab" '[.result.panes[] | select(.tab_id == $tab)] | length')
kill -0 "$only_a_pid"
kill -0 "$only_b_pid"
$runner pane send-keys "$only_survivor" alt+o >/dev/null
sleep 0.3
only_second_count=$($runner pane list | jq --arg tab "$only_tab" '[.result.panes[] | select(.tab_id == $tab)] | length')
test "$only_first_count" -eq 3
test "$only_second_count" -eq 1
! kill -0 "$only_a_pid" 2>/dev/null
! kill -0 "$only_b_pid" 2>/dev/null
record close_other_panes "$(jq -cn --arg survivor "$only_survivor" \
  --argjson first_count "$only_first_count" --argjson second_count "$only_second_count" \
  --argjson closed_pids "[$only_a_pid,$only_b_pid]" \
  '{binding:"Alt-o",survivor:$survivor,first_press_pane_count:$first_count,second_press_pane_count:$second_count,confirmation_required:true,closed_process_pids:$closed_pids}')"
$runner tab close "$only_tab" >/dev/null

# Application-owned Alt-X closes exactly the focused tab through the real
# Herdr -> Kitty CSI-u -> Fish adapter path.
alt_close_tab=$($runner tab create --label alt-close-tab --focus | jq -er '.result.tab.tab_id // .result.tab_id')
alt_close_pane=$($runner pane current --current | jq -er '.result.pane.pane_id')
alt_close_pid=$($runner pane process-info --pane "$alt_close_pane" | jq -er '.result.process_info.shell_pid')
$runner pane send-keys "$alt_close_pane" alt+shift+x >/dev/null
wait_for "Alt-X tab close" tab_absent "$alt_close_tab"
wait_for "Alt-X shell exit" pid_dead "$alt_close_pid"
record alt_close_tab "$(jq -cn --arg tab "$alt_close_tab" --arg pane "$alt_close_pane" \
  --argjson pid "$alt_close_pid" \
  '{binding:"Alt-X",application_owner:"Fish",closed_tab:$tab,pane_id:$pane,shell_pid:$pid,tab_absent:true,process_dead:true}')"

# Application-owned Alt-Ctrl-x uses the same session/socket-scoped two-press
# confirmation as prefix+Ctrl-x and must terminate only the sibling tabs.
alt_other_survivor=$($runner tab create --label alt-close-others-survivor --focus | jq -er '.result.tab.tab_id // .result.tab_id')
alt_other_pane=$($runner pane current --current | jq -er '.result.pane.pane_id')
alt_other_workspace=$($runner tab get "$alt_other_survivor" | jq -er '.result.tab.workspace_id')
for label in alt-close-others-a alt-close-others-b; do
  target_tab=$($runner tab create --workspace "$alt_other_workspace" --label "$label" --no-focus | jq -er '.result.tab.tab_id // .result.tab_id')
  target_pane=$($runner pane list | jq -er --arg tab "$target_tab" '.result.panes[] | select(.tab_id == $tab).pane_id')
  $runner pane send-text "$target_pane" "exec sleep 300" >/dev/null
  $runner pane send-keys "$target_pane" return >/dev/null
done
sleep 0.2
alt_other_pids=$($runner pane list | jq -r --arg workspace "$alt_other_workspace" --arg survivor "$alt_other_survivor" \
  '.result.panes[] | select(.workspace_id == $workspace and .tab_id != $survivor).pane_id' |
  while IFS= read -r pane; do
    $runner pane process-info --pane "$pane" | jq -r '.result.process_info.foreground_processes[] | select(.name == "sleep").pid'
  done | jq -sc '.')
alt_other_before=$($runner tab list | jq --arg workspace "$alt_other_workspace" '[.result.tabs[] | select(.workspace_id == $workspace)] | length')
$runner pane send-keys "$alt_other_pane" alt+ctrl+x >/dev/null
sleep 0.2
alt_other_first=$($runner tab list | jq --arg workspace "$alt_other_workspace" '[.result.tabs[] | select(.workspace_id == $workspace)] | length')
test "$alt_other_first" -eq "$alt_other_before"
$runner pane send-keys "$alt_other_pane" alt+ctrl+x >/dev/null
wait_for "Alt-Ctrl-x close other tabs" workspace_tab_count_is "$alt_other_workspace" 1
printf '%s\n' "$alt_other_pids" | jq -r '.[]' | while IFS= read -r pid; do
  wait_for "Alt-Ctrl-x sibling process $pid" pid_dead "$pid"
done
record alt_close_other_tabs "$(jq -cn --arg survivor "$alt_other_survivor" \
  --arg pane "$alt_other_pane" --argjson before "$alt_other_before" \
  --argjson first "$alt_other_first" --argjson pids "$alt_other_pids" \
  '{binding:"Alt-Ctrl-x",application_owner:"Fish",survivor_tab:$survivor,pane_id:$pane,tabs_before:$before,tabs_after_first_press:$first,tabs_after_confirmation:1,confirmation_required:true,closed_process_pids:$pids}')"

config=$($runner config check 2>&1)
record config "$(jq -cn --arg result "$config" '{result:$result}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
artifact_hashes=$(jq -cn \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg nav "$(shasum -a 256 "$prototype/herdr_nav.fish" | awk '{print $1}')" \
  --arg shell_action "$(shasum -a 256 "$prototype/shell_action.sh" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{config:$config,nav:$nav,shell_action:$shell_action,validator:$validator}')
record scope_audit "$(jq -cn --argjson before "$production_before" --argjson after "$production_after" \
  --argjson artifacts "$artifact_hashes" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before==$after),artifact_hashes:$artifacts}')"
record result "$(jq -cn '{status:"PASS",session:"trial-focused",production_configuration_modified:false,migration_authorized:false}')"

mv "$evidence_tmp" "$evidence"
printf 'Herdr binding validation: PASS (%s)\n' "$evidence"
