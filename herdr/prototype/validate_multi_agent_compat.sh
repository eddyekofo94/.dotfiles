#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/server_lifecycle.sh"
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/mac"
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
helper="$prototype/semantic_agent_state.py"
model="$root/tmux/scripts/agent_status.py"
session=mac
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/multi-agent-compat-validation.jsonl"
evidence_tmp="$runtime/multi-agent-compat-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "multi-agent validation requires the prototype Herdr binary" >&2
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
      echo "multi-agent validation timed out: $description" >&2
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

report_event() {
  agent=$1
  pane=$2
  event=$3
  payload=$4
  printf '%s\n' "$payload" |
    HERDR_ENV=1 HERDR_TARGET_PANE_ID="$pane" \
      HERDR_SEMANTIC_TTL_MS=3600000 \
      "$helper" hook --agent "$agent" --event "$event" >/dev/null
}

snapshot() {
  agent=$1
  pane=$2
  semantic=$3
  lifecycle=$4
  cli pane get "$pane" | jq -ec --arg agent "$agent" \
    --arg semantic "$semantic" --arg lifecycle "$lifecycle" '
    .result.pane |
    select(.agent == $agent and .agent_status == $lifecycle and
      .tokens.semantic_state == $semantic and .tokens.summary == $semantic and
      ([.state_labels[]] | index($semantic)) != null) |
    {agent,agent_status,semantic_state:.tokens.semantic_state}
  '
}

send_action() {
  action=$1
  before=$(wc -l <"$driver_log" | tr -d ' ')
  printf '%s\n' "$action" >&3
  wait_for "client action $action" sh -c \
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "$3" ]' \
    sh "$driver_log" "$before" "SENT $action"
}

cleanup() {
  exit_code=$?
  trap - EXIT INT TERM
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
  exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

herdr_sweep_stale_server "$socket"
herdr_guard_server "$socket"
rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir"
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  "$prototype/config.toml" >"$config"
: >"$evidence_tmp"
production_before=$(production_hashes)

config_result=$(cli config check 2>&1)
record config "$(jq -cn --arg result "$config_result" \
  '{result:$result,isolation:"prototype-only",existing_agent_state_evidence_replaced:false}')"

availability='[]'
for agent in claude opencode agy gemini; do
  executable=$(command -v "$agent" 2>/dev/null || true)
  if [ -n "$executable" ]; then
    version=$($executable --version 2>&1 | sed -n '1p')
    entry=$(jq -cn --arg agent "$agent" --arg executable "$executable" \
      --arg version "$version" \
      '{agent:$agent,status:"available",executable:$executable,version:$version,model_call_made:false}')
  else
    entry=$(jq -cn --arg agent "$agent" \
      '{agent:$agent,status:"unavailable",fail_closed:true,model_call_made:false}')
  fi
  availability=$(jq -cn --argjson values "$availability" --argjson entry "$entry" \
    '$values + [$entry]')
done
record availability "$(jq -cn --argjson agents "$availability" '{agents:$agents}')"

detection=$(python3 - "$model" <<'PY'
import importlib.util
import json
import sys

path = sys.argv[1]
spec = importlib.util.spec_from_file_location("agent_status", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
cases = [
    ("claude", "claude", ""),
    ("opencode", "opencode", ""),
    ("agy", "antigravity", ""),
    ("gemini", "node", 'exec gemini --legacy'),
]
results = []
for expected, current, start in cases:
    detected = module.agent_from_process(current, start)
    results.append({
        "expected": expected,
        "current_command": current,
        "start_command": start,
        "detected": detected,
        "passed": detected == expected,
    })
unsupported = module.agent_from_process("python3", "exec unsupported-agent")
print(json.dumps({
    "cases": results,
    "all_passed": all(item["passed"] for item in results),
    "unsupported": {"detected": unsupported, "fail_closed": unsupported == ""},
}, separators=(",", ":")))
PY
)
printf '%s\n' "$detection" | jq -e '.all_passed and .unsupported.fail_closed' >/dev/null
record detection "$detection"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "multi-agent socket" test -S "$socket"
mkfifo "$driver_fifo"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "multi-agent client" grep -q '^READY$' "$driver_log"

workspace=$(cli workspace list | jq -er '.result.workspaces[0].workspace_id')
initial_tab=$(cli tab list | jq -er '.result.tabs[0].tab_id')
cli tab rename "$initial_tab" Claude >/dev/null
for label in OpenCode AGY Gemini Unsupported; do
  cli tab create --workspace "$workspace" --cwd "$prototype" --label "$label" --no-focus >/dev/null
done

# Completed work is promoted to Herdr's sticky `done` rollup only after focus
# leaves the agent pane. Keep the neutral control focused during transitions.
unsupported=$(pane_for_label Unsupported)
unsupported_tab=$(cli pane get "$unsupported" | jq -er '.result.pane.tab_id')
cli tab focus "$unsupported_tab" >/dev/null

transitions='[]'
for pair in "claude:Claude" "opencode:OpenCode" "agy:AGY" "gemini:Gemini"; do
  agent=${pair%%:*}
  label=${pair#*:}
  pane=$(pane_for_label "$label")
  cli pane rename "$pane" "$label AGENT" >/dev/null

  case "$agent" in
    claude)
      running_event=prompt
      question_event=stop
      finished_event=stop
      failure_event=failure
      ;;
    opencode)
      running_event=prompt
      question_event=question
      finished_event=complete
      failure_event=failure
      ;;
    agy)
      running_event=pre-invocation
      question_event=question
      finished_event=stop
      failure_event=stop
      ;;
    gemini)
      running_event=before-agent
      question_event=after-agent
      finished_event=after-agent
      failure_event=after-agent
      ;;
  esac

  cli pane report-agent "$pane" --source gate:multi-agent --agent "$agent" --state working >/dev/null
  report_event "$agent" "$pane" "$running_event" '{}'
  running=$(snapshot "$agent" "$pane" running working)

  cli pane report-agent "$pane" --source gate:multi-agent --agent "$agent" --state blocked >/dev/null
  report_event "$agent" "$pane" "$question_event" '{"last_assistant_message":"Which option should I use?"}'
  question=$(snapshot "$agent" "$pane" question blocked)

  report_event "$agent" "$pane" permission '{}'
  approval=$(snapshot "$agent" "$pane" approval blocked)

  cli pane report-agent "$pane" --source gate:multi-agent --agent "$agent" --state working >/dev/null
  cli pane report-agent "$pane" --source gate:multi-agent --agent "$agent" --state idle >/dev/null
  report_event "$agent" "$pane" "$finished_event" '{"last_assistant_message":"Done."}'
  finished=$(snapshot "$agent" "$pane" finished done)

  cli pane report-agent "$pane" --source gate:multi-agent --agent "$agent" --state working >/dev/null
  cli pane report-agent "$pane" --source gate:multi-agent --agent "$agent" --state idle >/dev/null
  report_event "$agent" "$pane" "$failure_event" '{"error":"fixture error"}'
  failure=$(snapshot "$agent" "$pane" failure done)

  item=$(jq -cn --arg agent "$agent" --arg pane "$pane" \
    --arg running_event "$running_event" --arg question_event "$question_event" \
    --arg finished_event "$finished_event" --arg failure_event "$failure_event" \
    --argjson running "$running" --argjson question "$question" \
    --argjson approval "$approval" --argjson finished "$finished" \
    --argjson failure "$failure" \
    '{agent:$agent,pane_id:$pane,
      events:{running:$running_event,question:$question_event,approval:"permission",finished:$finished_event,failure:$failure_event},
      states:[$running,$question,$approval,$finished,$failure],deterministic:true}')
  transitions=$(jq -cn --argjson values "$transitions" --argjson item "$item" '$values + [$item]')
done
record lifecycle "$(jq -cn --argjson agents "$transitions" \
  '{agents:$agents,lifecycle_authority:"herdr",semantic_metadata:"display-only"}')"

unsupported_before=$(cli pane get "$unsupported" | jq -c '.result.pane | {agent,agent_status,state_labels,tokens}')
report_event unsupported-agent "$unsupported" prompt '{}'
unsupported_after=$(cli pane get "$unsupported" | jq -c '.result.pane | {agent,agent_status,state_labels,tokens}')
test "$unsupported_before" = "$unsupported_after"
record unsupported "$(jq -cn --arg pane "$unsupported" \
  --argjson before "$unsupported_before" --argjson after "$unsupported_after" \
  '{pane_id:$pane,before:$before,after:$after,unchanged:($before==$after),hook_exit_safe:true,input_sent:false}')"

# Leave one distinct semantic state per named agent for real navigator readback.
claude_pane=$(pane_for_label Claude)
opencode_pane=$(pane_for_label OpenCode)
agy_pane=$(pane_for_label AGY)
gemini_pane=$(pane_for_label Gemini)
cli pane report-agent "$claude_pane" --source gate:multi-agent --agent claude --state working >/dev/null
report_event claude "$claude_pane" prompt '{}'
cli pane report-agent "$opencode_pane" --source gate:multi-agent --agent opencode --state blocked >/dev/null
report_event opencode "$opencode_pane" question '{"last_assistant_message":"Question?"}'
cli pane report-agent "$agy_pane" --source gate:multi-agent --agent agy --state blocked >/dev/null
report_event agy "$agy_pane" permission '{}'
cli pane report-agent "$gemini_pane" --source gate:multi-agent --agent gemini --state working >/dev/null
cli pane report-agent "$gemini_pane" --source gate:multi-agent --agent gemini --state idle >/dev/null
report_event gemini "$gemini_pane" after-agent '{"last_assistant_message":"Done."}'

send_action goto
for label in Claude OpenCode AGY Gemini; do
  grep -Fq "$label AGENT" "$screen"
done
for state in running question approval finished; do
  grep -Fq "$state" "$screen"
done
navigator=$(jq -cn \
  --arg claude "$(grep -F 'Claude AGENT' "$screen" | sed -n '1p')" \
  --arg opencode "$(grep -F 'OpenCode AGENT' "$screen" | sed -n '1p')" \
  --arg agy "$(grep -F 'AGY AGENT' "$screen" | sed -n '1p')" \
  --arg gemini "$(grep -F 'Gemini AGENT' "$screen" | sed -n '1p')" \
  '{surface:"prefix+f",lines:{claude:$claude,opencode:$opencode,agy:$agy,gemini:$gemini},all_visible:true}')
record visibility "$navigator"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
artifact_hashes=$(jq -cn \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg helper "$(shasum -a 256 "$helper" | awk '{print $1}')" \
  --arg model "$(shasum -a 256 "$model" | awk '{print $1}')" \
  --arg client "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{config:$config,helper:$helper,model:$model,client:$client,validator:$validator}')
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" --argjson artifacts "$artifact_hashes" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before==$after),artifact_hashes:$artifacts,prior_evidence_replaced:false}')"
record result "$(jq -cn --arg version "$("$herdr" --version)" \
  '{status:"PASS",version:$version,session:"mac",named_agents:["claude","opencode","agy","gemini"],production_configuration_modified:false,integration_installed:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr multi-agent compatibility validation: PASS (%s)\n' "$evidence"
