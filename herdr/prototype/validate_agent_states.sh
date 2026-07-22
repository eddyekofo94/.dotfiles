#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/as"
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
helper="$prototype/semantic_agent_state.py"
session=gas
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/agent-state-validation.jsonl"
evidence_tmp="$runtime/agent-state-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "agent-state validation requires the prototype Herdr binary" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_PROTOTYPE_DIR="$prototype"

cli() {
  "$herdr" --session "$session" "$@"
}

record() {
  jq -cn --arg check "$1" --argjson evidence "$2" \
    '{check:$check,evidence:$evidence}' >>"$evidence_tmp"
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
      echo "agent-state validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}

pane_for_label() {
  tab=$(cli tab list | jq -er --arg label "$1" \
    '.result.tabs[] | select(.label == $label).tab_id')
  cli pane list | jq -er --arg tab "$tab" \
    '.result.panes[] | select(.tab_id == $tab).pane_id'
}

pane_status_is() {
  cli pane get "$1" | jq -e --arg expected "$2" \
    '.result.pane.agent_status == $expected' >/dev/null
}

pane_metadata_is() {
  cli pane get "$1" | jq -e --arg expected "$2" '
    .result.pane.tokens.semantic_state == $expected and
    .result.pane.tokens.summary == $expected and
    (.result.pane.state_labels | to_entries | map(.value) | index($expected)) != null
  ' >/dev/null
}

send_action() {
  action=$1
  before=$(wc -l <"$driver_log" | tr -d ' ')
  printf '%s\n' "$action" >&3
  wait_for "client action $action" sh -c \
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "$3" ]' \
    sh "$driver_log" "$before" "SENT $action"
}

report_event() {
  pane=$1
  event=$2
  payload=$3
  printf '%s\n' "$payload" |
    HERDR_ENV=1 HERDR_TARGET_PANE_ID="$pane" \
      HERDR_SEMANTIC_TTL_MS=3600000 \
      "$helper" hook --agent codex --event "$event" >/dev/null
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
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  "$prototype/config.toml" >"$config"
: >"$evidence_tmp"
production_before=$(production_hashes)

config_result=$(cli config check 2>&1)
grep -Fq 'rows = [["state_icon", "workspace", "tab"], ["agent", "$semantic_state"]]' "$config"
schema=$("$herdr" api schema --json)
printf '%s\n' "$schema" | jq -e '
  .schemas.request["$defs"].AgentStatus.enum == ["idle","working","blocked","done","unknown"] and
  .schemas.request["$defs"].PaneReportMetadataParams.properties.state_labels.type == "object" and
  .schemas.request["$defs"].PaneReportMetadataParams.properties.tokens.maxProperties == 16
' >/dev/null
record config "$(jq -cn --arg result "$config_result" \
  '{result:$result,sidebar_rows:[["state_icon","workspace","tab"],["agent","$semantic_state"]],metadata_api:true}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "agent-state socket" test -S "$socket"
mkfifo "$driver_fifo"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "agent-state client" grep -q '^READY$' "$driver_log"

workspace=$(cli workspace list | jq -er '.result.workspaces[0].workspace_id')
initial_tab=$(cli tab list | jq -er '.result.tabs[0].tab_id')
cli tab rename "$initial_tab" Running >/dev/null
for label in Question Approval Finished Failure; do
  cli tab create --workspace "$workspace" --cwd "$prototype" --label "$label" --no-focus >/dev/null
done

running=$(pane_for_label Running)
question=$(pane_for_label Question)
approval=$(pane_for_label Approval)
finished=$(pane_for_label Finished)
failure=$(pane_for_label Failure)
for pair in "Running:$running" "Question:$question" "Approval:$approval" \
  "Finished:$finished" "Failure:$failure"; do
  label=${pair%%:*}
  pane=${pair#*:}
  cli pane rename "$pane" "$label STATE" >/dev/null
done

cli pane report-agent "$running" --source gate:lifecycle --agent codex --state working >/dev/null
cli pane report-agent "$question" --source gate:lifecycle --agent codex --state blocked >/dev/null
cli pane report-agent "$approval" --source gate:lifecycle --agent codex --state blocked >/dev/null
for pane in "$finished" "$failure"; do
  cli pane report-agent "$pane" --source gate:lifecycle --agent codex --state working >/dev/null
  cli pane report-agent "$pane" --source gate:lifecycle --agent codex --state idle >/dev/null
done
cli agent focus "$running" >/dev/null

wait_for "running lifecycle" pane_status_is "$running" working
wait_for "question lifecycle" pane_status_is "$question" blocked
wait_for "approval lifecycle" pane_status_is "$approval" blocked
wait_for "finished lifecycle" pane_status_is "$finished" done
wait_for "failure lifecycle" pane_status_is "$failure" done

report_event "$running" prompt '{}'
report_event "$question" stop '{"last_assistant_message":"Which layout should I use?"}'
report_event "$approval" permission '{}'
report_event "$finished" stop '{"last_assistant_message":"Done."}'
report_event "$failure" failure '{"error":"rate limit"}'

wait_for "running metadata" pane_metadata_is "$running" running
wait_for "question metadata" pane_metadata_is "$question" question
wait_for "approval metadata" pane_metadata_is "$approval" approval
wait_for "finished metadata" pane_metadata_is "$finished" finished
wait_for "failure metadata" pane_metadata_is "$failure" failure

states=$(cli pane list | jq -c --arg running "$running" --arg question "$question" \
  --arg approval "$approval" --arg finished "$finished" --arg failure "$failure" '
  [.result.panes[] | select(.pane_id == $running or .pane_id == $question or
    .pane_id == $approval or .pane_id == $finished or .pane_id == $failure) |
    {pane_id,agent,agent_status,state_labels,tokens}] | sort_by(.tokens.semantic_state)
')
record metadata "$(jq -cn --argjson panes "$states" \
  '{panes:$panes,semantic_states:($panes|map(.tokens.semantic_state)|sort),lifecycle_authority_preserved:true}')"

send_action goto
for label in Running Question Approval Finished Failure; do
  grep -Fq "$label STATE" "$screen"
done
for state in running question approval finished failure; do
  grep -Fq "$state" "$screen"
done
lines=$(jq -cn \
  --arg running "$(grep -F 'Running STATE' "$screen" | sed -n '1p')" \
  --arg question "$(grep -F 'Question STATE' "$screen" | sed -n '1p')" \
  --arg approval "$(grep -F 'Approval STATE' "$screen" | sed -n '1p')" \
  --arg finished "$(grep -F 'Finished STATE' "$screen" | sed -n '1p')" \
  --arg failure "$(grep -F 'Failure STATE' "$screen" | sed -n '1p')" \
  '{running:$running,question:$question,approval:$approval,finished:$finished,failure:$failure}')
printf '%s\n' "$lines" | jq -e 'all(.[]; length > 0)' >/dev/null
record navigator "$(jq -cn --argjson lines "$lines" \
  '{surface:"prefix+f",distinct_labels:true,lines:$lines}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
artifact_hashes=$(jq -cn \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg helper "$(shasum -a 256 "$helper" | awk '{print $1}')" \
  --arg client "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{config:$config,helper:$helper,client:$client,validator:$validator}')
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" --argjson artifacts "$artifact_hashes" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before==$after),artifact_hashes:$artifacts}')"
record result "$(jq -cn --arg version "$("$herdr" --version)" \
  '{status:"PASS",version:$version,session:"gas",production_configuration_modified:false,integration_installed:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr semantic agent-state validation: PASS (%s)\n' "$evidence"
