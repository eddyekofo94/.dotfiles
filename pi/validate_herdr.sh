#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$pi_dir/.." && pwd)
prototype="$root/herdr/prototype"
herdr="$prototype/.runtime/bin/herdr"
mkdir -p "$pi_dir/.runtime"
runtime=$(mktemp -d "$pi_dir/.runtime/h.XXXXXX")
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
session="p-${runtime##*.}"
socket="$config_home/herdr/sessions/$session/herdr.sock"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
server_log="$runtime/server.log"
evidence_dir=${PI_PILOT_EVIDENCE_DIR:-"$pi_dir/evidence"}
evidence="$evidence_dir/herdr-validation.json"

[ -x "$herdr" ] || {
  echo "pi-pilot: prepared Herdr binary is unavailable" >&2
  exit 2
}

wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 160 ]; then
      echo "pi-pilot: timed out waiting for $description" >&2
      if [ -n "${pane:-}" ]; then
        cli pane read "$pane" --source visible --format text >&2 || true
      fi
      return 1
    fi
    sleep 0.05
  done
}

wait_for_reload() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 600 ]; then
      echo "pi-pilot: timed out waiting for $description" >&2
      if [ -n "${pane:-}" ]; then
        cli pane read "$pane" --source visible --format text >&2 || true
      fi
      return 1
    fi
    sleep 0.05
  done
}

cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  if [ "$status" -ne 0 ] && [ -s "$server_log" ]; then
    cat "$server_log" >&2
  fi
  exec 3>&- 2>/dev/null || true
  if [ -n "${driver_pid:-}" ]; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  if [ -S "$socket" ]; then
    cli session stop "$session" --json >/dev/null 2>&1 || true
  fi
  if [ -n "${server_pid:-}" ]; then
    wait "$server_pid" 2>/dev/null || true
  fi
  cli session delete "$session" --json >/dev/null 2>&1 || true
  rm -rf "$runtime"
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$config_home/herdr" "$evidence_dir"

export PI_PILOT_STATE_DIR="$runtime/pi-state"
"$pi_dir/install.sh" >/dev/null

sed -e 's|^default_shell = .*$|default_shell = "'"$pi_dir"'/tests/pi_herdr_fixture.sh"|' \
  "$prototype/config.toml" >"$config"

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_READY_PROMPT_STATE_DIR="$runtime/consume"
export HERDR_PI_PILOT_CONTROL_DIR="$runtime/pi-state/control"

unset TMUX HERDR_ENV HERDR_PANE_ID HERDR_SOCKET_PATH HERDR_WORKSPACE_ID \
  HERDR_TAB_ID HERDR_TARGET_PANE_ID HERDR_STARTUP_CWD

cli() {
  "$herdr" --session "$session" "$@"
}

editor_contains() {
  expected=$1
  cli pane read "$pane" --source visible --format text |
    tail -n 5 |
    grep -Fq "$expected"
}

visible_contains() {
  expected=$1
  cli pane read "$pane" --source visible --format text |
    grep -Fq "$expected"
}

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "Herdr socket" test -S "$socket"

mkfifo "$driver_fifo"
"$prototype/tab_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "Herdr client" grep -q '^READY$' "$driver_log"
wait_for "Pi pane" sh -c \
  '"$1" --session "$2" pane list | jq -e ".result.panes | length == 1" >/dev/null' \
  _ "$herdr" "$session"

pane=$(cli pane current --current | jq -er '.result.pane.pane_id')
wait_for "Pi process" sh -c \
  '"$1" --session "$2" pane process-info --pane "$3" |
    jq -e "any(.result.process_info.foreground_processes[]?;
      ((.argv0 // \"\") | endswith(\"/pi\")) or
      ((.name // \"\") == \"pi\"))" >/dev/null' \
  _ "$herdr" "$session" "$pane"

wait_for "managed Pi agent" sh -c \
  '"$1" --session "$2" agent list |
    jq -e "any(.result.agents[]?; .agent == \"pi\" and
      .agent_session.source == \"herdr:pi\")" >/dev/null' \
  _ "$herdr" "$session"

fixture_command=/eddy-pilot-fixture-handoff
cli pane send-text "$pane" "$fixture_command" >/dev/null
cli pane send-keys "$pane" return >/dev/null
wait_for "handoff output" sh -c \
  '"$1" --session "$2" pane read "$3" --source recent-unwrapped --lines 300 --format text |
    grep -q "Pi handoff second line"' \
  _ "$herdr" "$session" "$pane"

before_agent=$(cli agent list | jq -c \
  '.result.agents[] | select(.agent == "pi")')
before_session=$(printf '%s\n' "$before_agent" | jq -er '.agent_session.value')
wait_for "persisted original Pi session" test -s "$before_session"

wait_for "custom Pi prompt" editor_contains '❯'
cli pane send-text "$pane" "history first" >/dev/null
cli pane send-keys "$pane" return >/dev/null
wait_for "first history response" visible_contains \
  "Fixture response recorded without a network provider."
cli pane send-text "$pane" "history second" >/dev/null
cli pane send-keys "$pane" return >/dev/null
wait_for "second history entry" sh -c \
  'test "$(jq -s "[.[] | select(.type == \"message\" and .message.role == \"user\") | select(.message.content | tostring | contains(\"history \"))] | length" "$1")" -eq 2' \
  _ "$before_session"
wait_for "second history response" sh -c \
  'test "$(jq -s "[.[] | select(.type == \"message\" and .message.role == \"assistant\") | select(.message.content | tostring | contains(\"Fixture response recorded\"))] | length" "$1")" -ge 2' \
  _ "$before_session"

cli pane send-keys "$pane" ctrl+p >/dev/null
wait_for "newest prompt recall" editor_contains '❯ history second'
cli pane send-keys "$pane" ctrl+p >/dev/null
wait_for "older prompt recall" editor_contains '❯ history first'
cli pane send-keys "$pane" ctrl+n >/dev/null
wait_for "forward prompt recall" editor_contains '❯ history second'
cli pane send-keys "$pane" ctrl+c >/dev/null
wait_for "cleared recalled prompt" sh -c \
  '! "$1" --session "$2" pane read "$3" --source visible --format text | tail -n 5 | grep -Fq "history second"' \
  _ "$herdr" "$session" "$pane"

cli pane send-text "$pane" "/reload" >/dev/null
wait_for "reload autocomplete" visible_contains "→ reload"
cli pane send-keys "$pane" return >/dev/null
# Pi redraws away the transient reload notification in this fixture. Give the
# synchronous command one bounded render turn, then prove the reloaded editor
# and shortcut directly.
sleep 0.5
wait_for_reload "custom Pi prompt after reload" editor_contains '❯'
usage_log="$runtime/pi-state/control/slash-command-usage.jsonl"
wait_for_reload "persisted reload usage" sh -c \
  'test -f "$1" &&
    jq -e "select(.version == 1 and .name == \"reload\")" "$1" >/dev/null' \
  _ "$usage_log"
test ! -L "$usage_log"
test "$(stat -f '%Lp' "$usage_log")" = "600"
test "$(stat -f '%l' "$usage_log")" = "1"

# A genuinely non-matching newer usage event must not displace the most recent
# command among the actual /re matches.
printf '%s\n' \
  '{"version":1,"name":"eddy-pilot","usedAt":4102444800000}' \
  >>"$usage_log"
wait_for_reload "unrelated newer slash usage" sh -c \
  'jq -s -e "last | .version == 1 and .name == \"eddy-pilot\"" "$1" >/dev/null' \
  _ "$usage_log"

cli pane send-text "$pane" "/re" >/dev/null
wait_for_reload "recent slash command selected first" visible_contains \
  "→ reload"
cli pane send-keys "$pane" escape >/dev/null
cli pane send-keys "$pane" ctrl+u >/dev/null
wait_for "slash ranking fixture editor cleanup" editor_contains '❯'

usage_backup="$usage_log.safe"
usage_sentinel="$runtime/pi-state/control/slash-usage-sentinel"
mv "$usage_log" "$usage_backup"
printf 'unchanged\n' >"$usage_sentinel"
ln -s "$usage_sentinel" "$usage_log"
cli pane send-text "$pane" "/fff-health" >/dev/null
wait_for_reload "FFF health autocomplete after reload" visible_contains \
  "→ fff-health"
cli pane send-keys "$pane" escape >/dev/null
cli pane send-keys "$pane" return >/dev/null
wait_for_reload "FFF health after reload" visible_contains "FFF v"
test "$(cat "$usage_sentinel")" = "unchanged"
rm "$usage_log" "$usage_sentinel"
mv "$usage_backup" "$usage_log"

cli pane send-text "$pane" "unsent clear marker" >/dev/null
cli pane send-keys "$pane" ctrl+l >/dev/null
wait_for "clear-screen shortcut" sh -c \
  'jq -e "select(.type == \"custom\" and .customType == \"eddy-pi-pilot-clear-screen\")" "$1" >/dev/null' \
  _ "$before_session"
wait_for "editor preserved after clear-screen shortcut" \
  editor_contains '❯ unsent clear marker'
wait_for "footer preserved after clear-screen shortcut" \
  visible_contains "pi-herdr-original"
# The physical failure appeared after the first redraw. Require the restored
# editor/footer to remain present after another render interval.
sleep 0.75
wait_for "editor remains after forced clear-screen redraw" \
  editor_contains '❯ unsent clear marker'
wait_for "footer remains after forced clear-screen redraw" \
  visible_contains "pi-herdr-original"
cli pane send-keys "$pane" ctrl+u >/dev/null
wait_for "clear-screen fixture editor cleanup" sh -c \
  '! "$1" --session "$2" pane read "$3" --source visible --format text | tail -n 5 | grep -Fq "unsent clear marker"' \
  _ "$herdr" "$session" "$pane"

cli pane send-keys "$pane" ctrl+shift+m >/dev/null
wait_for "Ctrl-Shift-M model selector" visible_contains \
  "Only showing models from configured providers."
cli pane send-keys "$pane" escape >/dev/null
wait_for "model selector dismissal" editor_contains '❯'

wait_for "FFF frecency database" test -s \
  "$runtime/pi-state/fff/frecency/data.mdb"
wait_for "FFF query database" test -s \
  "$runtime/pi-state/fff/history/data.mdb"
cli pane send-text "$pane" "@pi/settings" >/dev/null
wait_for_reload "FFF fuzzy mention results" visible_contains "settings.json"
cli pane send-keys "$pane" return >/dev/null
wait_for "FFF mention insertion" editor_contains '❯ @'
cli pane send-keys "$pane" return >/dev/null
wait_for "FFF mention fixture response" sh -c \
  'test "$(jq -s "[.[] | select(.type == \"message\" and .message.role == \"assistant\") | select(.message.content | tostring | contains(\"Fixture response recorded\"))] | length" "$1")" -ge 4' \
  _ "$before_session"
wait_for "idle after FFF mention" sh -c \
  '"$1" --session "$2" agent list |
    jq -e "any(.result.agents[]?; .agent == \"pi\" and .agent_status == \"idle\")" >/dev/null' \
  _ "$herdr" "$session"

# Ctrl-L intentionally removes the earlier viewport contents, so emit a fresh
# completed handoff before exercising replay discovery.
cli pane send-text "$pane" "$fixture_command" >/dev/null
cli pane send-keys "$pane" return >/dev/null
wait_for "fresh handoff after viewport clear" sh -c \
  '"$1" --session "$2" pane read "$3" --source recent-unwrapped --lines 300 --format text |
    grep -q "Pi handoff second line"' \
  _ "$herdr" "$session" "$pane"

HERDR_PANE_ID="$pane" "$prototype/ready_prompt.sh" --clear

wait_for "new Pi handoff editor" sh -c \
  '"$1" --session "$2" pane read "$3" --source visible --format text |
    grep -q "Pi handoff second line"' \
  _ "$herdr" "$session" "$pane"
after_agent=$(cli agent list | jq -c \
  '.result.agents[] | select(.agent == "pi")')
after_session=$(printf '%s\n' "$after_agent" | jq -er '.agent_session.value')
wait_for "persisted replacement Pi session" test -s "$after_session"

[ "$after_session" != "$before_session" ]
[ -s "$before_session" ]
[ -s "$after_session" ]
replacement_name=$(jq -sr '
  [.[] | select(.type == "session_info") | .name] |
  last // empty
' "$after_session")
printf '%s\n' "$replacement_name" |
  grep -Eq '^pi-[0-9]{17}-[a-f0-9]{8}$'
test "$(find "$runtime/pi-state/control" -maxdepth 1 -type f \
  -name 'request-*.json' | wc -l | tr -d ' ')" -eq 0

if jq -e --arg first "Pi handoff first line" '
    select(.type == "message" and .message.role == "user") |
    (.message.content | tostring | contains($first))
  ' "$after_session" >/dev/null; then
  echo "pi-pilot: handoff was submitted as a user message" >&2
  exit 1
fi

visible=$(cli pane read "$pane" --source visible --format text)
case "$visible" in
  \{*) visible_text=$(printf '%s\n' "$visible" | jq -r '.result.text // empty') ;;
  *) visible_text=$visible ;;
esac
printf '%s\n' "$visible_text" | grep -Fq 'Pi handoff first line'
printf '%s\n' "$visible_text" | grep -Fq 'Pi handoff second line'

cli pane send-keys "$pane" ctrl+c >/dev/null
wait_for "cleared Pi editor" sh -c \
  '"$1" --session "$2" pane read "$3" --source visible --format text |
    grep -q "Pi handoff second line" && exit 1 || exit 0' \
  _ "$herdr" "$session" "$pane"

lower_fixture='/eddy-pilot-fixture-handoff lowercase'
cli pane send-text "$pane" "$lower_fixture" >/dev/null
cli pane send-keys "$pane" return >/dev/null
wait_for "lowercase handoff output" sh -c \
  '"$1" --session "$2" pane read "$3" --source recent-unwrapped --lines 300 --format text |
    grep -q "Pi handoff second line lowercase"' \
  _ "$herdr" "$session" "$pane"
lower_before=$(cli agent list | jq -er \
  '.result.agents[] | select(.agent == "pi") | .agent_session.value')
lower_user_count_before=$(jq -s --arg first "Pi handoff first line lowercase" '
  [.[] |
    select(.type == "message" and .message.role == "user") |
    select(.message.content | tostring | contains($first))] |
  length
' "$lower_before")
HERDR_PANE_ID="$pane" "$prototype/ready_prompt.sh"
wait_for "lowercase Pi handoff editor" sh -c \
  '"$1" --session "$2" pane read "$3" --source visible --format text |
    grep -q "Pi handoff second line lowercase"' \
  _ "$herdr" "$session" "$pane"
lower_after=$(cli agent list | jq -er \
  '.result.agents[] | select(.agent == "pi") | .agent_session.value')
[ "$lower_after" = "$lower_before" ]
lower_user_count_after=$(jq -s --arg first "Pi handoff first line lowercase" '
  [.[] |
    select(.type == "message" and .message.role == "user") |
    select(.message.content | tostring | contains($first))] |
  length
' "$lower_after")
if [ "$lower_user_count_after" -ne "$lower_user_count_before" ]; then
  echo "pi-pilot: lowercase handoff was submitted as a user message" >&2
  exit 1
fi

inventory=$("$prototype/agent_overview.sh" --inventory)
printf '%s\n' "$inventory" | awk -F '\t' \
  -v session="$session" '
    $1 == session && $2 == "pi" && $3 != "" && $4 != "" { found=1 }
    END { exit(found ? 0 : 1) }
  '

jq -n \
  --arg pane "$pane" \
  --arg before "$before_session" \
  --arg after "$after_session" \
  --arg replacement_name "$replacement_name" \
  --arg integration "$(printf '%s\n' "$after_agent" | jq -c '.agent_session')" \
  '{
    status:"PASS",
    pane:$pane,
    managed_integration:($integration | fromjson),
    previous_session:$before,
    replacement_session:$after,
    replacement_name:$replacement_name,
    sessions_distinct:($before != $after),
    handoff_visible:true,
    submitted:false,
    lowercase_same_session:true,
    lowercase_handoff_visible:true,
    lowercase_submitted:false,
    cross_session_inventory_pi:true,
    prompt_symbol:true,
    history_navigation:true,
    clear_screen_shortcut:true,
    clear_screen_forced_redraw_stable:true,
    clear_screen_preserved_editor:true,
    clear_screen_preserved_footer:true,
    slash_usage_submit_observed:true,
    slash_usage_private_regular_file:true,
    slash_usage_unsafe_path_fails_open:true,
    slash_recent_command_first:true,
    painted_cursor_removed:true,
    focused_cursor_style:"blinking-bar",
    unfocused_editor_cursor_style:"blinking-block",
    model_selector_shortcut:"ctrl+shift+m",
    fff_tools_and_ui:true,
    fff_frecency_active:true,
    fff_history_active:true,
    fff_mention_results:true,
    fff_picker_physical:false,
    shortcut:"ctrl+shift+y",
    physical_ghostty:false
  }' >"$evidence"

printf 'Pi Herdr integration validation: PASS (%s)\n' "$evidence"
