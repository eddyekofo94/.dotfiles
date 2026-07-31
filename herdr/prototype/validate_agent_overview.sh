#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/agent-overview"
state="$runtime/state"
fixture="$prototype/fixtures/agent_overview_herdr_fixture.sh"
overview="$prototype/agent_overview.sh"
composer="$prototype/agent_message_composer.py"
evidence="$prototype/evidence/agent-overview-validation.jsonl"
evidence_tmp="$runtime/evidence.jsonl"

cleanup() {
  rm -f "$evidence_tmp"
}
trap cleanup EXIT HUP INT TERM

rm -rf "$runtime"
mkdir -p "$state" "$prototype/evidence"
: >"$state/calls"
: >"$state/focus"
: >"$evidence_tmp"

record() {
  jq -cn --arg check "$1" --argjson evidence "$2" \
    '{check:$check,evidence:$evidence}' >>"$evidence_tmp"
}

run_overview() {
  HERDR_BIN_PATH="$fixture" \
  HERDR_AGENT_OVERVIEW_FIXTURE_STATE="$state" \
  HERDR_AGENT_OVERVIEW_ALLOW_NONSOCKET=1 \
    "$overview" "$@"
}

test -x "$overview"
test -x "$composer"
test -x "$fixture"
sh -n "$overview"
sh -n "$fixture"
python3 -m py_compile "$composer"
python3 -c '
import importlib.util
import sys
spec = importlib.util.spec_from_file_location("composer", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
for value, expected in [
    ("ascii".encode(), b"asci"),
    ("café".encode(), b"caf"),
    ("漢字".encode(), "漢".encode()),
    ("🙂!".encode(), "🙂".encode()),
]:
    content = bytearray(value)
    module.remove_character(content)
    assert bytes(content) == expected
    bytes(content).decode("utf-8")
' "$composer"

inventory=$(run_overview --inventory)
test "$(printf '%s\n' "$inventory" | wc -l | tr -d ' ')" -eq 3
printf '%s\n' "$inventory" | grep -Fq 'alpha	codex	idle	/work/alpha	'
printf '%s\n' "$inventory" | grep -Fq 'beta	codex	working	/work/beta	'
printf '%s\n' "$inventory" | grep -Fq 'gamma	pi	idle	/work/gamma	'
alpha_token=$(printf '%s\n' "$inventory" | awk -F '\t' '$1 == "alpha" {print $5}')
beta_token=$(printf '%s\n' "$inventory" | awk -F '\t' '$1 == "beta" {print $5}')
gamma_token=$(printf '%s\n' "$inventory" | awk -F '\t' '$1 == "gamma" {print $5}')
test -n "$alpha_token"
test -n "$beta_token"
test -n "$gamma_token"
test "$alpha_token" != "$beta_token"
printf '%s' "$alpha_token" | base64 -D | jq -e '
  .session == "alpha" and .pane_id == "w1:p1" and
  .terminal_id == "term-alpha" and .agent_session.value == "alpha-id"
' >/dev/null
printf '%s' "$beta_token" | base64 -D | jq -e '
  .session == "beta" and .pane_id == "w1:p1" and
  .terminal_id == "term-beta" and .agent_session.value == "beta-id"
' >/dev/null
printf '%s' "$gamma_token" | base64 -D | jq -e '
  .session == "gamma" and .agent == "pi" and
  .terminal_id == "term-gamma" and
  .agent_session.source == "herdr:pi"
' >/dev/null
record inventory "$(jq -cn '{
  sessions:3,fields:["session","agent","status","cwd"],
  pi_discoverable:true,
  duplicate_labels_unambiguous:true,
  duplicate_pane_ids_unambiguous:true,
  on_demand:true
}')"

: >"$state/calls"
: >"$state/focus"
readback=$(run_overview --read-token "$beta_token")
test "$(printf '%s\n' "$readback" | wc -l | tr -d ' ')" -eq 200
printf '%s\n' "$readback" | grep -Fq 'beta output line 1'
printf '%s\n' "$readback" | grep -Fq 'beta output line 200'
test ! -s "$state/focus"
grep -Fq 'beta	agent read term-beta --source recent-unwrapped --lines 200 --format text' \
  "$state/calls"
record read "$(jq -cn '{bounded_lines:200,read_only:true,focus_unchanged:true}')"

: >"$state/calls"
: >"$state/focus"
run_overview --focus-token "$beta_token" >/dev/null
test "$(cat "$state/focus")" = 'beta:term-beta'
test "$(grep -c 'agent focus' "$state/calls")" -eq 1
record focus "$(jq -cn '{
  owning_session:"beta",terminal_id:"term-beta",
  current_window_reattached:false,macos_window_raised:false
}')"

: >"$state/calls"
: >"$state/focus"
message="$runtime/message.txt"
expected="$runtime/expected.bin"
printf 'first line\nsecond line\n' >"$message"
printf '\033[200~first line\nsecond line\n\033[201~' >"$expected"
run_overview --message-token "$beta_token" "$message" >/dev/null
cmp -s "$state/inserted" "$expected"
test ! -s "$state/focus"
grep -Fq 'beta	pane send-text w1:p1 ' "$state/calls"
! grep -Fq 'send-keys' "$state/calls"
record message "$(jq -cn '{
  exact_multiline_bracketed_paste:true,submitted:false,
  send_return:false,focus_unchanged:true,empty_is_noop:true,
  unicode_backspace_valid:true
}')"

before_calls=$(wc -l <"$state/calls" | tr -d ' ')
: >"$runtime/empty.txt"
run_overview --message-token "$beta_token" "$runtime/empty.txt"
test "$(wc -l <"$state/calls" | tr -d ' ')" -eq "$before_calls"

for action in read focus message; do
  : >"$state/calls"
  : >"$state/focus"
  rm -f "$state/inserted"
  set +e
  case "$action" in
    read)
      HERDR_AGENT_OVERVIEW_FIXTURE_MODE=stale-agent \
        run_overview --read-token "$beta_token" >/dev/null 2>&1
      ;;
    focus)
      HERDR_AGENT_OVERVIEW_FIXTURE_MODE=stale-agent \
        run_overview --focus-token "$beta_token" >/dev/null 2>&1
      ;;
    message)
      HERDR_AGENT_OVERVIEW_FIXTURE_MODE=stale-agent \
        run_overview --message-token "$beta_token" "$message" >/dev/null 2>&1
      ;;
  esac
  status=$?
  set -e
  test "$status" -ne 0
  test ! -s "$state/focus"
  test ! -e "$state/inserted"
done

: >"$state/calls"
set +e
HERDR_AGENT_OVERVIEW_FIXTURE_MODE=session-missing \
  run_overview --focus-token "$beta_token" >/dev/null 2>&1
missing_status=$?
run_overview --focus-token 'not-base64!' >/dev/null 2>&1
invalid_status=$?
set -e
test "$missing_status" -ne 0
test "$invalid_status" -ne 0
record stale_safety "$(jq -cn \
  --argjson missing_status "$missing_status" \
  --argjson invalid_status "$invalid_status" '{
    changed_identity_failed_closed:true,
    missing_session_status:$missing_status,
    untrusted_token_status:$invalid_status,
    replacement_dispatch:false
  }')"

for config in "$root/herdr/config.toml" "$prototype/config.toml"; do
  test "$(rg -Fxc 'key = "prefix+shift+a"' "$config")" -eq 1
  rg -Fq 'command = "exec \"$HERDR_PROTOTYPE_DIR/agent_overview.sh\""' "$config"
  test "$(rg -Fxc 'workspace_picker = "prefix+w"' "$config")" -eq 1
  test "$(rg -Fxc 'goto = "prefix+f"' "$config")" -eq 1
  test "$(rg -Fxc 'key = "prefix+a"' "$config")" -eq 1
  test "$(rg -Fxc 'pane_history = false' "$config")" -eq 1
done
! rg -q 'super\+(v|c|a|f|n|w)' "$root/ghostty/config"
record bindings "$(jq -cn '{
  overview:"prefix+shift+a",adaptive_split:"prefix+a",
  workspace_picker:"prefix+w",goto:"prefix+f",
  command_keys:"Ghostty-owned",pane_history:false
}')"

lesskey="$runtime/read.lesskey"
printf '#command\n\\e[27;5;27~ quit\n\\e quit\n' >"$lesskey"
LESSKEY_SRC="$lesskey" expect <<'EXPECT' >/dev/null
log_user 0
set timeout 3
spawn sh -c "seq 1 500 | less -R --lesskey-src=$env(LESSKEY_SRC)"
after 200
send "\033"
expect eof
spawn sh -c "seq 1 500 | less -R --lesskey-src=$env(LESSKEY_SRC)"
after 200
send "\033\[27;5;27~"
expect eof
EXPECT
record read_escape "$(jq -cn '{
  escape_returns_to_palette:true,
  kitty_csi_u_escape_consumed:true,
  reader:"less"
}')"

record implementation "$(jq -cn \
  --arg overview "$(shasum -a 256 "$overview" | awk '{print $1}')" \
  --arg composer "$(shasum -a 256 "$composer" | awk '{print $1}')" \
  --arg fixture "$(shasum -a 256 "$fixture" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  --arg production "$(shasum -a 256 "$root/herdr/config.toml" | awk '{print $1}')" \
  --arg prototype_config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" '{
    hashes:{
      overview:$overview,composer:$composer,fixture:$fixture,validator:$validator,
      production_config:$production,prototype_config:$prototype_config
    },
    remote_aggregation:false,destructive_actions:false,
    polling:false,commit_or_push:false
  }')"

cp "$evidence_tmp" "$evidence"
echo "Cross-session agent overview validation: PASS"
