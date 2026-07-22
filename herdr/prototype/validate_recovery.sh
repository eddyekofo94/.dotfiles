#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/r"
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
session=rc
session_dir="$config_home/herdr/sessions/$session"
socket="$session_dir/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/recovery-validation.jsonl"
evidence_tmp="$runtime/recovery-validation.jsonl.tmp"
server_log_1="$runtime/server-before.log"
server_log_2="$runtime/server-after.log"
agent_log="$runtime/agent-resume.args"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"

[ -x "$herdr" ] || {
  echo "recovery validation requires the prototype Herdr binary" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_RECOVERY_AGENT_LOG="$agent_log"
export CODEX_HOME="$runtime/codex"

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
    if [ "$attempts" -ge 120 ]; then
      echo "recovery validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}
pid_dead() { ! kill -0 "$1" 2>/dev/null; }
sentinel_ready() {
  cli pane process-info --pane "$1" 2>/dev/null |
    jq -e 'any(.result.process_info.foreground_processes[]?; .name == "sleep")' >/dev/null
}
history_has() {
  cli pane read "$1" --source recent --lines 200 --format text 2>/dev/null |
    grep -Fxq "$2"
}
structure() {
  workspaces=$(cli workspace list | jq -c '[.result.workspaces[] | {workspace_id,label,cwd}]')
  tabs=$(cli tab list | jq -c '[.result.tabs[] | {tab_id,workspace_id,label,number,pane_count}]')
  panes=$(cli pane list | jq -c '[.result.panes[] | {pane_id,tab_id,workspace_id,label,cwd}]')
  layout_first=$(cli pane layout --pane "$pane_one" | jq -c '.result.layout | {tab_id,panes,splits,zoomed}')
  layout_second=$(cli pane layout --pane "$pane_three" | jq -c '.result.layout | {tab_id,panes,splits,zoomed}')
  jq -cn --argjson workspaces "$workspaces" --argjson tabs "$tabs" \
    --argjson panes "$panes" --argjson first "$layout_first" --argjson second "$layout_second" \
    '{workspaces:$workspaces,tabs:$tabs,panes:$panes,layouts:[$first,$second]}'
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
start_client() {
  rm -f "$driver_fifo" "$driver_log"
  mkfifo "$driver_fifo"
  "$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
    "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
  driver_pid=$!
  exec 3>"$driver_fifo"
  wait_for "recovery client" grep -q '^READY$' "$driver_log"
}
stop_client() {
  exec 3>&-
  if [ -n "${driver_pid:-}" ]; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
    driver_pid=
  fi
  rm -f "$driver_fifo"
}
refresh_client() {
  before=$(wc -l <"$driver_log" | tr -d ' ')
  printf 'snapshot\n' >&3
  wait_for "recovery client snapshot" sh -c \
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "SENT snapshot" ]' \
    sh "$driver_log" "$before"
}
cleanup() {
  status=$?
  trap - EXIT INT TERM
  stop_client
  cli session stop "$session" --json >/dev/null 2>&1 || true
  for pid in ${server_pid_1:-} ${server_pid_2:-}; do
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  if [ "$status" -eq 0 ]; then
    cli session delete "$session" --json >/dev/null 2>&1 || true
  fi
  if [ "$status" -eq 0 ]; then
    rm -f "$evidence_tmp"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir" "$runtime/project-one" "$runtime/project-two"
mkdir -p "$runtime/bin" "$CODEX_HOME"
ln -s "$prototype/recovery_agent_fixture.sh" "$runtime/bin/codex"
PATH="$runtime/bin:$PATH"
export PATH
sed \
  -e 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  -e 's/^pane_history = false$/pane_history = true/' \
  "$prototype/config.toml" >"$config"
: >"$evidence_tmp"
production_before=$(production_hashes)
config_result=$(cli config check 2>&1)
grep -q '^pane_history = true$' "$config"
integration_result=$($herdr integration install codex 2>&1)
grep -q 'HERDR_INTEGRATION_ID=codex' "$CODEX_HOME/herdr-agent-state.sh"
grep -q 'HERDR_INTEGRATION_VERSION=6' "$CODEX_HOME/herdr-agent-state.sh"
record config "$(jq -cn --arg result "$config_result" --arg integration "$integration_result" '{result:$result,pane_history:true,resume_agents_on_restore:true,isolated_codex_integration:{version:6,installed:true,output:$integration},agent_fixture_installed_in_runtime_only:true}')"

cli server >"$server_log_1" 2>&1 &
server_pid_1=$!
wait_for "recovery socket before restart" test -S "$socket"
start_client
workspace=$(cli workspace list | jq -er '.result.workspaces[0].workspace_id')
cli workspace rename "$workspace" "Recovery Workspace" >/dev/null
tab_one=$(cli tab list | jq -er '.result.tabs[0].tab_id')
cli tab rename "$tab_one" "Primary" >/dev/null
pane_one=$(cli pane list | jq -er '.result.panes[0].pane_id')
cli pane rename "$pane_one" "RECOVERY ONE" >/dev/null
pane_two=$(cli pane split "$pane_one" --direction right --ratio 0.62 --no-focus | jq -er '.result.pane.pane_id')
cli pane rename "$pane_two" "RECOVERY TWO" >/dev/null
tab_two=$(cli tab create --workspace "$workspace" --cwd "$runtime/project-two" --label "Secondary" --no-focus | jq -er '.result.tab.tab_id // .result.tab_id')
pane_three=$(cli pane list | jq -er --arg tab "$tab_two" '.result.panes[] | select(.tab_id == $tab).pane_id')
cli pane rename "$pane_three" "RECOVERY THREE" >/dev/null

index=1
for pane in "$pane_one" "$pane_two" "$pane_three"; do
  if [ "$index" -le 2 ]; then cwd="$runtime/project-one"; else cwd="$runtime/project-two"; fi
  cli pane run "$pane" "cd \"$cwd\" && n=1; while [ \"\$n\" -le 80 ]; do printf 'RECOVERY_%s_%s_LINE_%03d\\n' HISTORY $index \"\$n\"; n=\$((n + 1)); done; exec sleep 300" >/dev/null
  wait_for "sentinel $index before restart" sentinel_ready "$pane"
  refresh_client
  wait_for "history $index before restart" history_has "$pane" "RECOVERY_HISTORY_${index}_LINE_001"
  pid=$(cli pane process-info --pane "$pane" | jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
  eval "pid_$index=$pid"
  index=$((index + 1))
done

agent_session=recovery-codex-session
printf '%s\n' "$(jq -cn --arg session "$agent_session" '{hook_event_name:"SessionStart",session_id:$session,source:"cli"}')" |
  HERDR_ENV=1 HERDR_SOCKET_PATH="$socket" HERDR_PANE_ID="$pane_three" \
  "$CODEX_HOME/herdr-agent-state.sh" session

before=$(structure)
record before_restart "$(jq -cn --argjson structure "$before" --argjson pids "[$pid_1,$pid_2,$pid_3]" --arg agent_session "$agent_session" '{structure:$structure,live_process_pids:$pids,history_markers:["RECOVERY_HISTORY_1_LINE_001","RECOVERY_HISTORY_2_LINE_001"],agent_session:{pane_id:$structure.panes[2].pane_id,agent:"codex",session_id:$agent_session}}')"

cli session stop "$session" --json >/dev/null
wait "$server_pid_1" 2>/dev/null || true
server_pid_1=
stop_client
wait_for "first process stopped" pid_dead "$pid_1"
wait_for "second process stopped" pid_dead "$pid_2"
wait_for "third process stopped" pid_dead "$pid_3"
test -f "$session_dir/session.json"
test -f "$session_dir/session-history.json"

cli server >"$server_log_2" 2>&1 &
server_pid_2=$!
wait_for "recovery socket after restart" test -S "$socket"
start_client
wait_for "three restored panes" sh -c \
  '[ "$("$1" --session "$2" pane list | jq ".result.panes | length")" -eq 3 ]' \
  sh "$herdr" "$session"
after=$(structure)
test "$after" = "$before"
wait_for "restored first history" history_has "$pane_one" RECOVERY_HISTORY_1_LINE_001
cli pane focus --pane "$pane_one" --direction right >/dev/null
wait_for "restored second history" history_has "$pane_two" RECOVERY_HISTORY_2_LINE_001
cli tab focus "$tab_two" >/dev/null
wait_for "native Codex resume" test -s "$agent_log"
test "$(sed -n '1p' "$agent_log")" = resume
test "$(sed -n '2p' "$agent_log")" = "$agent_session"
new_processes='[]'
for restored_pane in "$pane_one" "$pane_two" "$pane_three"; do
  shell_pid=$(cli pane process-info --pane "$restored_pane" | jq -er '.result.process_info.shell_pid')
  reused=$(jq -n --argjson pid "$shell_pid" --argjson old "[$pid_1,$pid_2,$pid_3]" '$old | index($pid) != null')
  new_processes=$(printf '%s\n' "$new_processes" | jq -c \
    --arg pane "$restored_pane" --argjson pid "$shell_pid" --argjson reused "$reused" \
    '. + [{pane_id:$pane,shell_pid:$pid,old_pid_reused:$reused}]')
done
printf '%s\n' "$new_processes" | jq -e '
  length == 3 and all(.[]; (.shell_pid | type == "number" and . > 0) and .old_pid_reused == false)
' >/dev/null
record after_restart "$(jq -cn --argjson structure "$after" --argjson processes "$new_processes" --arg session "$agent_session" '{structure:$structure,original_processes_gone:true,restored_processes:$processes,history_replayed:true,native_agent_resume:{agent:"codex",args:["resume",$session]},arbitrary_processes_resumed:false}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn \
  --arg config_hash "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg fixture_hash "$(shasum -a 256 "$prototype/recovery_agent_fixture.sh" | awk '{print $1}')" \
  --arg validator_hash "$(shasum -a 256 "$prototype/validate_recovery.sh" | awk '{print $1}')" \
  --argjson production "$production_after" \
  '{config_sha256:$config_hash,fixture_sha256:$fixture_hash,validator_sha256:$validator_hash,production_sha256:$production}')"
record result "$(jq -cn '{status:"PASS",version:"herdr 0.7.4",session:"rc",snapshot_restored:true,pane_history_replayed:true,native_agent_resumed:true,arbitrary_process_resume:false,production_configuration_modified:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr recovery validation: PASS (%s)\n' "$evidence"
