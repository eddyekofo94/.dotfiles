#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/cr"
config_home="$runtime/config"
config="$config_home/herdr/config.toml"
session=gate-rp
herdr="$prototype/.runtime/bin/herdr"
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/ready-prompt-validation.jsonl"
evidence_tmp="$runtime/ready-prompt-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client-driver.log"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "ready-prompt validation requires the prototype Herdr binary" >&2
  exit 2
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
      echo "ready-prompt validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}

cleanup() {
  status=$?
  trap - EXIT INT TERM
  exec 3>&- 2>/dev/null || true
  if [ -n "${driver_pid:-}" ]; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  if [ -S "$socket" ]; then
    "$herdr" --session "$session" session stop "$session" --json >/dev/null 2>&1 || true
  fi
  if [ -n "${server_pid:-}" ]; then
    wait "$server_pid" 2>/dev/null || true
  fi
  "$herdr" --session "$session" session delete "$session" --json >/dev/null 2>&1 || true
  rm -f "$driver_fifo" "$evidence_tmp"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir" "$runtime/mock-state"
: >"$evidence_tmp"
production_before=$(production_hashes)

sed -e 's|^default_shell = .*$|default_shell = "'"$prototype"'/ready_prompt_agent_fixture.sh"|' \
  "$prototype/config.toml" >"$config"

config_result=$(XDG_CONFIG_HOME="$config_home" HERDR_CONFIG_PATH="$config" \
  "$herdr" --session "$session" config check 2>&1)
record config "$(jq -cn --arg result "$config_result" \
  --arg replay "prefix+b" --arg clear "prefix+shift+b" \
  '{result:$result,replay_binding:$replay,clear_binding:$clear}')"

# The Herdr port intentionally reuses the already-tested handoff grammar.
parser_log="$runtime/parser-tests.log"
"$root/tmux/tests/ready_prompt_test.sh" >"$parser_log"
parser_count=$(sed -n 's/^1\.\.//p' "$parser_log" | tail -n 1)
record parser "$(jq -cn --argjson checks "$parser_count" \
  '{source:"tmux/scripts/ready_prompt.sh --extract",checks:$checks,status:"PASS"}')"

mock="$runtime/mock-herdr"
cat >"$mock" <<'MOCK'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$MOCK_HERDR_STATE/calls"
case "$1 $2" in
  "pane current")
    printf '%s\n' '{"result":{"pane":{"pane_id":"w1:p1"}}}'
    ;;
  "pane process-info")
    jq -cn --arg agent "${MOCK_AGENT:-codex}" \
      '{result:{process_info:{foreground_processes:[{argv:[$agent],argv0:$agent,name:$agent,pid:42}]}}}'
    ;;
  "pane read")
    case " $* " in
      *" --source recent-unwrapped "*) jq -Rs '{result:{text:.}}' "$MOCK_HISTORY" ;;
      *" --format ansi "*) jq -cn --arg text "${MOCK_STYLED_READY_SCREEN:-${MOCK_READY_SCREEN:-›}}" '{result:{text:$text}}' ;;
      *) jq -cn --arg text "${MOCK_READY_SCREEN:-›}" '{result:{text:$text}}' ;;
    esac
    ;;
  "pane send-text")
    text=$4
    if [ "$text" = /clear ]; then
      printf '%s' "$text" >"$MOCK_HERDR_STATE/clear-text"
    else
      printf '%s' "$text" >"$MOCK_HERDR_STATE/inserted-raw"
      printf '%s' "$text" | perl -0pe \
        's/^\e\[200~//; s/\e\[201~$//' >"$MOCK_HERDR_STATE/inserted"
      count=0
      [ ! -f "$MOCK_HERDR_STATE/insert-count" ] || count=$(cat "$MOCK_HERDR_STATE/insert-count")
      printf '%s\n' "$((count + 1))" >"$MOCK_HERDR_STATE/insert-count"
    fi
    printf '%s\n' '{"result":{}}'
    ;;
  "pane send-keys")
    printf '%s\n' "$4" >>"$MOCK_HERDR_STATE/keys"
    printf '%s\n' '{"result":{}}'
    ;;
  "notification show")
    printf '%s\n' '{"result":{}}'
    ;;
  *)
    echo "unexpected mock Herdr call: $*" >&2
    exit 2
    ;;
esac
MOCK
chmod +x "$mock"

history="$runtime/mock-history.txt"
expected="$runtime/expected-prompt.txt"
printf '%s\n' '**Ready-to-paste prompt:**' '```text' \
  'Continue from the Herdr gate.' 'Do not submit automatically.' '```' >"$history"
printf '%s\n' 'Continue from the Herdr gate.' \
  'Do not submit automatically.' | perl -0pe 's/\n\z//' >"$expected"

mock_state="$runtime/mock-state"
run_mock() {
  MOCK_HERDR_STATE="$mock_state" MOCK_HISTORY="$history" \
    HERDR_BIN_PATH="$mock" HERDR_PANE_ID=w1:p1 \
    HERDR_READY_PROMPT_STATE_DIR="$runtime/mock-consume" \
    HERDR_READY_PROMPT_READY_INTERVAL=0 \
    HERDR_READY_PROMPT_CLEAR_CONFIRM_INTERVAL=0 \
    "$prototype/ready_prompt.sh" "$@"
}

run_mock
cmp -s "$mock_state/inserted" "$expected"
perl -0ne 'exit(/^\e\[200~.*\e\[201~$/s ? 0 : 1)' \
  "$mock_state/inserted-raw"
test ! -f "$mock_state/keys"
set +e
run_mock >/dev/null 2>&1
duplicate_status=$?
set -e
test "$duplicate_status" -ne 0
test "$(cat "$mock_state/insert-count")" -eq 1
mkdir -p "$runtime/mock-consume/w1_p1/active"
set +e
run_mock >/dev/null 2>&1
concurrent_status=$?
set -e
rmdir "$runtime/mock-consume/w1_p1/active"
test "$concurrent_status" -eq 75
run_mock --clear
test "$(cat "$mock_state/clear-text")" = /clear
test "$(grep -c '^return$' "$mock_state/keys")" -eq 1
test "$(cat "$mock_state/insert-count")" -eq 2

rm -f "$runtime/mock-consume/w1_p1/fingerprint"
MOCK_READY_SCREEN='› Summarize recent commits' \
MOCK_STYLED_READY_SCREEN="$(printf '\033[1m›\033[0m \033[2mSummarize recent commits\033[0m')" \
  run_mock --clear
test "$(cat "$mock_state/clear-text")" = /clear
test "$(grep -c '^return$' "$mock_state/keys")" -eq 2
test "$(cat "$mock_state/insert-count")" -eq 3

rm -f "$runtime/mock-consume/w1_p1/fingerprint"
MOCK_AGENT=claude MOCK_READY_SCREEN='❯ /clear
❯' MOCK_STYLED_READY_SCREEN='❯ /clear
❯' run_mock --clear
test "$(cat "$mock_state/clear-text")" = /clear
test "$(grep -c '^return$' "$mock_state/keys")" -eq 3
test "$(cat "$mock_state/insert-count")" -eq 4

before_calls=$(wc -l <"$mock_state/calls" | tr -d ' ')
set +e
MOCK_AGENT=gemini run_mock --clear >/dev/null 2>&1
unsupported_status=$?
set -e
after_calls=$(wc -l <"$mock_state/calls" | tr -d ' ')
test "$unsupported_status" -ne 0
test "$after_calls" -eq $((before_calls + 2))
record mock_replay "$(jq -cn --argjson duplicate_status "$duplicate_status" \
  --argjson concurrent_status "$concurrent_status" \
  --argjson unsupported_status "$unsupported_status" \
  '{multiline_insert_exact:true,submitted:false,consume_once:true,duplicate_status:$duplicate_status,concurrent_status:$concurrent_status,clear_then_insert:true,codex_dim_placeholder_clear_then_insert:true,claude_clear_then_insert:true,unsupported_clear_status:$unsupported_status}')"

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_READY_PROMPT_STATE_DIR="$runtime/live-consume"

cli() {
  "$herdr" --session "$session" "$@"
}

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "ready-prompt socket" test -S "$socket"
rm -f "$driver_fifo"
mkfifo "$driver_fifo"
"$prototype/tab_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "Herdr ready-prompt client" grep -q '^READY$' "$driver_log"
wait_for "initial pane" sh -c '"$1" --session "$2" pane list | jq -e ".result.panes | length == 1" >/dev/null' _ "$herdr" "$session"
pane=$(cli pane current --current | jq -er '.result.pane.pane_id')
process_info=$(cli pane process-info --pane "$pane" | jq -c '.result.process_info')
printf '%s\n' "$process_info" | jq -e \
  'any(.foreground_processes[]?; .argv0 == "codex" or .argv[0] == "codex")' >/dev/null

marker="$runtime/SHOULD_NOT_EXIST"
cli pane send-text "$pane" \
  "printf '\\nReady-to-paste prompt: \`touch $marker\`\\n'" >/dev/null
cli pane send-keys "$pane" return >/dev/null
wait_for "handoff in pane history" sh -c \
  '"$1" --session "$2" pane read "$3" --source recent-unwrapped --lines 200 --format text | grep -q "Ready-to-paste prompt"' \
  _ "$herdr" "$session" "$pane"

HERDR_PANE_ID="$pane" "$prototype/ready_prompt.sh"
sleep 0.2
test ! -e "$marker"
visible=$(cli pane read "$pane" --source visible --format text)
case "$visible" in
  \{*) visible_text=$(printf '%s\n' "$visible" | jq -r '.result.text // .result.content // empty') ;;
  *) visible_text=$visible ;;
esac
printf '%s\n' "$visible_text" >"$runtime/live-visible.txt"
printf '%s\n' "$visible_text" | grep -Fq 'SHOULD_NOT_EXIST'
record live_transport "$(jq -cn --arg pane "$pane" --argjson process_info "$process_info" \
  '{pane:$pane,agent_argv0:"codex",prompt_visible:true,submitted:false,marker_absent:true,process_info:$process_info}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
artifact_hashes=$(jq -cn \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg helper "$(shasum -a 256 "$prototype/ready_prompt.sh" | awk '{print $1}')" \
  --arg fixture "$(shasum -a 256 "$prototype/ready_prompt_agent_fixture.sh" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$prototype/validate_ready_prompt.sh" | awk '{print $1}')" \
  '{config:$config,helper:$helper,fixture:$fixture,validator:$validator}')
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" --argjson artifacts "$artifact_hashes" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before == $after),artifact_hashes:$artifacts}')"

record result "$(jq -cn --arg session "$session" \
  '{status:"PASS",session:$session,production_configuration_modified:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr ready-prompt validation: PASS (%s)\n' "$evidence"
