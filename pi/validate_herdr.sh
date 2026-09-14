#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$pi_dir/.." && pwd)
# shellcheck disable=SC1091
. "$pi_dir/version.env"
prototype="$root/herdr/prototype"
herdr="$prototype/.runtime/bin/herdr"
runtime_root=${PI_PILOT_HERDR_RUNTIME_ROOT:-/tmp}
mkdir -p "$runtime_root"
runtime=$(mktemp -d "$runtime_root/pi-herdr.XXXXXX")
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
  if [ "$status" -ne 0 ] && [ -s "$driver_log" ]; then
    cat "$driver_log" >&2
  fi
  if [ "$status" -ne 0 ] && [ -n "${pane:-}" ] && [ -S "$socket" ]; then
    cli pane read "$pane" --source recent-unwrapped --lines 80 --format text \
      >&2 || true
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

# Production settings deliberately name the main checkout. This fixture must
# exercise the extension in the current worktree instead of silently validating
# an older installed copy.
jq --arg extension "$pi_dir/extensions/eddy-compat.ts" '
  .extensions = [$extension]
' "$pi_dir/settings.json" >"$runtime/pi-settings.json"
ln -sfn "$runtime/pi-settings.json" \
  "$PI_PILOT_STATE_DIR/config/settings.json"

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

pid_dead() {
  ! kill -0 "$1" 2>/dev/null
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
before_session_kind=$(printf '%s\n' "$before_agent" |
  jq -er '.agent_session.kind')
before_session_id=$(printf '%s\n' "$before_agent" |
  jq -er '.agent_session.value')
[ "$before_session_kind" = id ] || {
  echo "pi-pilot: Herdr recovery locator is not an isolated session ID" >&2
  exit 1
}
case "$before_session_id" in
  ''|*[!A-Za-z0-9._-]*)
    echo "pi-pilot: Herdr recovery locator is not an isolated session ID" >&2
    exit 1
    ;;
esac
before_session=$(find "$runtime/pi-state/sessions" -maxdepth 1 -type f \
  -name "*_${before_session_id}.jsonl" -print -quit)
wait_for "persisted original Pi session" test -s "$before_session"

# Herdr replays the reported locator after a server restart. Prove the
# production isolation boundary accepts the emitted ID, still rejects the
# corresponding absolute path, and leaves the saved history untouched.
before_session_sha=$(shasum -a 256 "$before_session" | awk '{print $1}')
ln -sfn "$pi_dir/settings.json" \
  "$PI_PILOT_STATE_DIR/config/settings.json"
"$pi_dir/pilot.sh" --session "$before_session_id" --version \
  >"$runtime/id-locator-version"
grep -Fxq "$PI_PILOT_VERSION" "$runtime/id-locator-version"
if "$pi_dir/pilot.sh" --session "$before_session" --version \
    >"$runtime/path-locator-version" 2>"$runtime/path-locator-error"; then
  echo "pi-pilot: absolute recovery path bypassed isolated locator policy" >&2
  exit 1
fi
grep -Fxq 'pi-pilot: session and fork locators must be isolated IDs' \
  "$runtime/path-locator-error"
test "$(shasum -a 256 "$before_session" | awk '{print $1}')" = \
  "$before_session_sha"
ln -sfn "$runtime/pi-settings.json" \
  "$PI_PILOT_STATE_DIR/config/settings.json"

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
wait_for "footer model preserved after clear-screen shortcut" \
  visible_contains "fixture"
# The physical failure appeared after the first redraw. Require the restored
# editor/footer to remain present after another render interval.
sleep 0.75
wait_for "editor remains after forced clear-screen redraw" \
  editor_contains '❯ unsent clear marker'
wait_for "footer model remains after forced clear-screen redraw" \
  visible_contains "fixture"
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
after_session_kind=$(printf '%s\n' "$after_agent" |
  jq -er '.agent_session.kind')
after_session_id=$(printf '%s\n' "$after_agent" |
  jq -er '.agent_session.value')
test "$after_session_kind" = id
after_session=$(find "$runtime/pi-state/sessions" -maxdepth 1 -type f \
  -name "*_${after_session_id}.jsonl" -print -quit)
wait_for "persisted replacement Pi session" test -s "$after_session"

[ "$after_session_id" != "$before_session_id" ]
[ -s "$before_session" ]
[ -s "$after_session" ]
replacement_name=$(jq -sr '
  [.[] | select(.type == "session_info") | .name] |
  last // empty
' "$after_session")
expected_replacement_name=$(node --input-type=module -e '
  import { contextualSessionName } from "./pi/extensions/session-name-core.mjs";
  process.stdout.write(contextualSessionName(process.argv[1]));
' "$root")
test "$replacement_name" = "$expected_replacement_name"
reservation_dir="$runtime/pi-state/sessions/.session-name-reservations"
if [ -d "$reservation_dir" ]; then
  test -z "$(find "$reservation_dir" -mindepth 1 -maxdepth 1 -type f -print -quit)"
fi
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
lower_before_id=$(cli agent list | jq -er \
  '.result.agents[] | select(.agent == "pi") | .agent_session.value')
lower_user_count_before=$(jq -s --arg first "Pi handoff first line lowercase" '
  [.[] |
    select(.type == "message" and .message.role == "user") |
    select(.message.content | tostring | contains($first))] |
  length
' "$after_session")
HERDR_PANE_ID="$pane" "$prototype/ready_prompt.sh"
wait_for "lowercase Pi handoff editor" sh -c \
  '"$1" --session "$2" pane read "$3" --source visible --format text |
    grep -q "Pi handoff second line lowercase"' \
  _ "$herdr" "$session" "$pane"
lower_after_id=$(cli agent list | jq -er \
  '.result.agents[] | select(.agent == "pi") | .agent_session.value')
[ "$lower_after_id" = "$lower_before_id" ]
lower_user_count_after=$(jq -s --arg first "Pi handoff first line lowercase" '
  [.[] |
    select(.type == "message" and .message.role == "user") |
    select(.message.content | tostring | contains($first))] |
  length
' "$after_session")
if [ "$lower_user_count_after" -ne "$lower_user_count_before" ]; then
  echo "pi-pilot: lowercase handoff was submitted as a user message" >&2
  exit 1
fi

# Exercise the original failure path: stop the persisted Herdr session, start
# it again, and let Herdr replay the managed Pi agent command. The restored
# process must receive the isolated ID, report that same session, and retain
# the conversation marker in both the TUI and its original JSONL file.
recovery_marker="Pi handoff first line lowercase"
restart_session_id=$lower_after_id
restart_session=$after_session
restart_history_count=$lower_user_count_after
test "$restart_history_count" -eq 1
wait_for "idle after recovery marker" sh -c \
  '"$1" --session "$2" agent list |
    jq -e "any(.result.agents[]?; .agent == \"pi\" and
      .agent_status == \"idle\")" >/dev/null' \
  _ "$herdr" "$session"
restart_history_count=1
before_restart_pid=$(cli pane process-info --pane "$pane" |
  jq -er '.result.process_info.shell_pid')
ln -sfn "$pi_dir/settings.json" \
  "$PI_PILOT_STATE_DIR/config/settings.json"

cli session stop "$session" --json >/dev/null
wait "$server_pid" 2>/dev/null || true
server_pid=
exec 3>&-
kill "$driver_pid" 2>/dev/null || true
wait "$driver_pid" 2>/dev/null || true
driver_pid=
rm -f "$driver_fifo"
wait_for "original Pi process exit" pid_dead "$before_restart_pid"
test -f "$config_home/herdr/sessions/$session/session.json"

# Initial setup launches Pi directly so the interaction fixture can drive it.
# Recovery, like production, must start from a shell that can execute Herdr's
# persisted `pi --session <ID>` command.
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  "$config" >"$runtime/restart-config.toml"
mv "$runtime/restart-config.toml" "$config"
PATH="$PI_PILOT_COMMAND_DIR:$PATH"
export PATH

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "restored Herdr socket" test -S "$socket"
mkfifo "$driver_fifo"
"$prototype/tab_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "restored Herdr client" grep -q '^READY$' "$driver_log"
wait_for "restored Pi pane" sh -c \
  '"$1" --session "$2" pane list | jq -e ".result.panes | length == 1" >/dev/null' \
  _ "$herdr" "$session"
pane=$(cli pane current --current | jq -er '.result.pane.pane_id')
wait_for "restored Pi process" sh -c \
  '"$1" --session "$2" pane process-info --pane "$3" |
    jq -e "any(.result.process_info.foreground_processes[]?;
      ((.argv0 // \"\") | endswith(\"/pi\")) or
      ((.name // \"\") == \"pi\"))" >/dev/null' \
  _ "$herdr" "$session" "$pane"
after_restart_pid=$(cli pane process-info --pane "$pane" |
  jq -er '.result.process_info.shell_pid')
test "$after_restart_pid" != "$before_restart_pid"
wait_for "restored Pi session ID" sh -c \
  '"$1" --session "$2" agent list |
    jq -e --arg id "$3" "any(.result.agents[]?;
      .agent == \"pi\" and .agent_session.kind == \"id\" and
      .agent_session.value == \$id)" >/dev/null' \
  _ "$herdr" "$session" "$restart_session_id"
wait_for "restored Pi history" visible_contains \
  "Pi handoff second line lowercase"
test -s "$restart_session"
test "$(jq -s --arg marker "$recovery_marker" '[.[] |
  select(.type == "message" and .message.role == "user") |
  select(.message.content | tostring | contains($marker))] |
  length' "$restart_session")" -eq "$restart_history_count"

inventory=$("$prototype/agent_overview.sh" --inventory)
printf '%s\n' "$inventory" | awk -F '\t' \
  -v session="$session" '
    $1 == session && $2 == "pi" && $3 != "" && $4 != "" { found=1 }
    END { exit(found ? 0 : 1) }
  '

jq -n \
  --arg pane "$pane" \
  --arg before "$before_session" \
  --arg before_id "$before_session_id" \
  --arg after "$after_session" \
  --arg after_id "$after_session_id" \
  --arg replacement_name "$replacement_name" \
  --arg integration "$(printf '%s\n' "$after_agent" | jq -c '.agent_session')" \
  '{
    status:"PASS",
    pane:$pane,
    managed_integration:($integration | fromjson),
    previous_session:$before,
    previous_session_id:$before_id,
    replacement_session:$after,
    replacement_session_id:$after_id,
    replacement_name:$replacement_name,
    sessions_distinct:($before != $after),
    recovery_locator_id:true,
    recovery_path_rejected:true,
    recovery_history_preserved:true,
    herdr_restart_replayed_session_id:true,
    herdr_restart_history_visible:true,
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
