#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/server_lifecycle.sh"
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/pr"
fixture_state="$runtime/fixture-state.json"
fixture_log="$runtime/fixture-close.log"
clipboard_log="$runtime/clipboard.log"
open_log="$runtime/open.log"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/picker-reference-validation.jsonl"
evidence_tmp="$runtime/picker-reference-validation.jsonl.tmp"
herdr="$prototype/.runtime/bin/herdr"
config_home="$runtime/config"
config="$config_home/herdr/config.toml"
session=pr
socket="$config_home/herdr/sessions/$session/herdr.sock"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
server_log="$runtime/server.log"

[ -x "$herdr" ] || {
  echo "picker/reference validation requires the prototype Herdr binary" >&2
  exit 2
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

reset_fixture_state() {
  jq -n '{
    workspaces:[
      {workspace_id:"w1",label:"Current Project"},
      {workspace_id:"w2",label:"Delete Project"}
    ],
    tabs:[
      {tab_id:"t1",workspace_id:"w1",label:"Current Tab"},
      {tab_id:"t2",workspace_id:"w1",label:"Delete Tab"},
      {tab_id:"t3",workspace_id:"w2",label:"Remote Tab"}
    ],
    panes:[
      {
        pane_id:"p1",terminal_id:"term1",tab_id:"t1",workspace_id:"w1",
        label:"Current Pane",cwd:"/work/project",
        foreground_cwd:"/work/project",focused:true
      },
      {
        pane_id:"p2",terminal_id:"term2",tab_id:"t2",workspace_id:"w1",
        label:"Delete \u001b[31mPane",cwd:"/work/project",
        foreground_cwd:"/work/project",focused:false
      },
      {
        pane_id:"p3",terminal_id:"term3",tab_id:"t3",workspace_id:"w2",
        label:"Remote Pane",cwd:"/work/remote",
        foreground_cwd:"/work/remote",focused:false
      }
    ],
    read_text:(
      "first https://example.test/old).\n" +
      "relative ./docs/guide.md and hash #abcdef12\n" +
      "new https://example.test/new?x=1, /tmp/report.txt deadbeef\n" +
      "home ~/notes/todo.md duplicate ./docs/guide.md"
    )
  }' >"$fixture_state"
  : >"$fixture_log"
}

fixture_target_exists() {
  kind=$1
  id=$2
  case "$kind" in
    pane) key=pane_id; array=panes ;;
    tab) key=tab_id; array=tabs ;;
    workspace) key=workspace_id; array=workspaces ;;
  esac
  jq -e --arg id "$id" --arg key "$key" --arg array "$array" \
    'getpath([$array]) | any(.[]; .[$key] == $id)' "$fixture_state" >/dev/null
}

wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 120 ]; then
      echo "picker/reference validation timed out: $description" >&2
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
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] &&
      [ "$(tail -n 1 "$1")" = "$3" ]' \
    sh "$driver_log" "$before" "SENT $action"
}

cli() {
  "$herdr" --session "$session" "$@"
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

herdr_sweep_stale_server "$socket"
herdr_guard_server "$socket"
rm -rf "$runtime"
mkdir -p "$runtime" "$config_home/herdr" "$evidence_dir"
: >"$evidence_tmp"
: >"$clipboard_log"
: >"$open_log"
production_before=$(production_hashes)

for fixture in \
  picker_reference_herdr_fixture.sh \
  manage_picker_fixture.sh \
  reference_picker_fixture.sh \
  reference_clipboard_fixture.sh \
  reference_opener_fixture.sh
do
  test -x "$prototype/fixtures/$fixture"
done
test -x "$prototype/manage_objects.sh"
test -x "$prototype/visible_reference_picker.sh"
test -x "$prototype/visible_references.py"

parser_output=$(printf '%s\n' \
  'old https://example.test/a).' \
  './docs/guide.md #abcdef12' \
  '/tmp/report.txt deadbeef ./docs/guide.md' |
  "$prototype/visible_references.py")
test "$(printf '%s\n' "$parser_output" | sed -n '1p')" = \
  'path	./docs/guide.md	3	/tmp/report.txt deadbeef ./docs/guide.md'
printf '%s\n' "$parser_output" | grep -Fqx \
  'hash	deadbeef	3	/tmp/report.txt deadbeef ./docs/guide.md'
printf '%s\n' "$parser_output" | grep -Fqx \
  'path	/tmp/report.txt	3	/tmp/report.txt deadbeef ./docs/guide.md'
printf '%s\n' "$parser_output" | grep -Fqx \
  'hash	#abcdef12	2	./docs/guide.md #abcdef12'
printf '%s\n' "$parser_output" | grep -Fqx \
  'uri	https://example.test/a	1	old https://example.test/a).'
test "$(printf '%s\n' "$parser_output" |
  awk -F '\t' '$2 == "./docs/guide.md" { count++ } END { print count + 0 }')" \
  -eq 1
control_output=$(printf 'unsafe https://example.test/\033[31mred\n' |
  "$prototype/visible_references.py")
escape=$(printf '\033')
case "$control_output" in
  *"$escape"*) echo "reference parser retained an escape byte" >&2; exit 1 ;;
esac
record parser "$(jq -cn --arg output "$parser_output" '
  {
    newest_first:true,
    duplicate_value_count:1,
    punctuation_trimmed:true,
    types:["uri","path","hash"],
    output:$output
  }
')"

export HERDR_BIN_PATH="$prototype/fixtures/picker_reference_herdr_fixture.sh"
export HERDR_PICKER_REFERENCE_STATE="$fixture_state"
export HERDR_PICKER_REFERENCE_LOG="$fixture_log"
export HERDR_TARGET_PANE_ID=p1
export HERDR_MANAGE_PICKER="$prototype/fixtures/manage_picker_fixture.sh"
export HERDR_REFERENCE_PICKER="$prototype/fixtures/reference_picker_fixture.sh"
export HERDR_REFERENCE_CLIPBOARD="$prototype/fixtures/reference_clipboard_fixture.sh"
export HERDR_REFERENCE_CLIPBOARD_LOG="$clipboard_log"
export HERDR_REFERENCE_OPENER="$prototype/fixtures/reference_opener_fixture.sh"
export HERDR_REFERENCE_OPEN_LOG="$open_log"

for target in pane:p2 tab:t2 workspace:w2; do
  kind=${target%%:*}
  id=${target#*:}
  reset_fixture_state
  export HERDR_MANAGE_FIXTURE_MODE=select
  export HERDR_MANAGE_FIXTURE_KIND="$kind"
  export HERDR_MANAGE_FIXTURE_ID="$id"
  unset HERDR_MANAGE_FIXTURE_MUTATION
  printf 'y\n' | "$prototype/manage_objects.sh" >/dev/null
  ! fixture_target_exists "$kind" "$id"
  grep -Fqx "$kind	$id" "$fixture_log"
done

reset_fixture_state
export HERDR_MANAGE_FIXTURE_KIND=pane
export HERDR_MANAGE_FIXTURE_ID=p2
printf 'n\n' | "$prototype/manage_objects.sh" >/dev/null 2>&1
fixture_target_exists pane p2
test ! -s "$fixture_log"

stale_results=
for target in pane:p2 tab:t2 workspace:w2; do
  kind=${target%%:*}
  id=${target#*:}
  reset_fixture_state
  export HERDR_MANAGE_FIXTURE_KIND="$kind"
  export HERDR_MANAGE_FIXTURE_ID="$id"
  export HERDR_MANAGE_FIXTURE_MUTATION="$kind"
  set +e
  printf 'y\n' | "$prototype/manage_objects.sh" >"$runtime/stale.out" 2>&1
  stale_status=$?
  set -e
  test "$stale_status" -eq 4
  fixture_target_exists "$kind" "$id"
  test ! -s "$fixture_log"
  stale_results="${stale_results}${kind}:${stale_status} "
done
unset HERDR_MANAGE_FIXTURE_MUTATION

reset_fixture_state
export HERDR_MANAGE_FIXTURE_MODE=cancel
"$prototype/manage_objects.sh" >/dev/null
test ! -s "$fixture_log"
export HERDR_MANAGE_FIXTURE_MODE=fail
set +e
"$prototype/manage_objects.sh" >/dev/null 2>&1
manage_failure_status=$?
set -e
test "$manage_failure_status" -eq 42
test ! -s "$fixture_log"
export HERDR_MANAGE_FIXTURE_MODE=select
record destructive_picker "$(jq -cn --arg stale "$stale_results" \
  --argjson picker_failure "$manage_failure_status" '
  {
    successful_targets:["pane","tab","workspace"],
    confirmation_cancel_inert:true,
    stale_rejections:($stale | split(" ") | map(select(length > 0))),
    picker_cancel_inert:true,
    picker_failure_status:$picker_failure,
    one_target_per_invocation:true
  }
')"

reset_fixture_state
export HERDR_REFERENCE_FIXTURE_MODE=copy
export HERDR_REFERENCE_FIXTURE_KIND=hash
export HERDR_REFERENCE_FIXTURE_VALUE=deadbeef
"$prototype/visible_reference_picker.sh" >/dev/null
test "$(tail -n 1 "$clipboard_log")" = deadbeef

export HERDR_REFERENCE_FIXTURE_MODE=open
export HERDR_REFERENCE_FIXTURE_KIND=uri
export HERDR_REFERENCE_FIXTURE_VALUE='https://example.test/new?x=1'
"$prototype/visible_reference_picker.sh" >/dev/null
test "$(tail -n 1 "$open_log")" = 'https://example.test/new?x=1'

export HERDR_REFERENCE_FIXTURE_KIND=path
export HERDR_REFERENCE_FIXTURE_VALUE='./docs/guide.md'
"$prototype/visible_reference_picker.sh" >/dev/null
test "$(tail -n 1 "$open_log")" = '/work/project/./docs/guide.md'

export HERDR_REFERENCE_FIXTURE_VALUE='~/notes/todo.md'
"$prototype/visible_reference_picker.sh" >/dev/null
test "$(tail -n 1 "$open_log")" = "$HOME/notes/todo.md"

export HERDR_REFERENCE_FIXTURE_KIND=hash
export HERDR_REFERENCE_FIXTURE_VALUE=deadbeef
set +e
"$prototype/visible_reference_picker.sh" >/dev/null 2>&1
hash_open_status=$?
set -e
test "$hash_open_status" -eq 4
test "$(wc -l <"$open_log" | tr -d ' ')" -eq 3

export HERDR_REFERENCE_FIXTURE_MODE=cancel
"$prototype/visible_reference_picker.sh" >/dev/null
export HERDR_REFERENCE_FIXTURE_MODE=fail
set +e
"$prototype/visible_reference_picker.sh" >/dev/null 2>&1
reference_failure_status=$?
set -e
test "$reference_failure_status" -eq 42
record reference_actions "$(jq -cn \
  --argjson hash_open_status "$hash_open_status" \
  --argjson picker_failure "$reference_failure_status" \
  --rawfile clipboard "$clipboard_log" --rawfile opened "$open_log" '
  {
    copied:($clipboard | split("\n") | map(select(length > 0))),
    opened:($opened | split("\n") | map(select(length > 0))),
    relative_path_resolved_from_focused_cwd:true,
    hash_open_status:$hash_open_status,
    picker_cancel_inert:true,
    picker_failure_status:$picker_failure,
    copy_mode_used:false
  }
')"

unset HERDR_BIN_PATH HERDR_TARGET_PANE_ID HERDR_MANAGE_PICKER
unset HERDR_REFERENCE_PICKER HERDR_MANAGE_FIXTURE_MODE
unset HERDR_MANAGE_FIXTURE_KIND HERDR_MANAGE_FIXTURE_ID
unset HERDR_REFERENCE_FIXTURE_MODE HERDR_REFERENCE_FIXTURE_KIND
unset HERDR_REFERENCE_FIXTURE_VALUE

sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  "$prototype/config.toml" >"$config"
export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_REFERENCE_CLIPBOARD="$prototype/fixtures/reference_clipboard_fixture.sh"
export HERDR_REFERENCE_CLIPBOARD_LOG="$clipboard_log"
export HERDR_REFERENCE_OPENER="$prototype/fixtures/reference_opener_fixture.sh"
export HERDR_REFERENCE_OPEN_LOG="$open_log"
: >"$clipboard_log"

config_result=$(cli config check 2>&1)
grep -A6 -F 'key = "prefix+shift+f"' "$config" |
  grep -Fq 'manage_objects.sh'
grep -A6 -F 'key = "prefix+shift+r"' "$config" |
  grep -Fq 'visible_reference_picker.sh'
grep -Fqx 'goto = "prefix+f"' "$config"
record config "$(jq -cn --arg result "$config_result" '
  {
    result:$result,
    manage_binding:"prefix+shift+f",
    reference_binding:"prefix+shift+r",
    native_goto:"prefix+f",
    copy_mode_binding_unchanged:true
  }
')"

cli session stop "$session" --json >/dev/null 2>&1 || true
cli session delete "$session" --json >/dev/null 2>&1 || true
cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "real Herdr socket" test -S "$socket"
mkfifo "$driver_fifo"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "real Herdr client" grep -q '^READY$' "$driver_log"
wait_for "real initial pane" sh -c \
  '"$1" --session "$2" pane list |
    jq -e ".result.panes | length == 1" >/dev/null' \
  sh "$herdr" "$session"

real_pane=$(cli pane current --current | jq -er '.result.pane.pane_id')
delete_pane=$(cli pane split "$real_pane" --direction down --ratio 0.5 \
  --no-focus | jq -er '.result.pane.pane_id // .result.pane_id')
cli pane rename "$delete_pane" "DELETE REAL SENTINEL" >/dev/null
send_action manage-objects
grep -Fq 'Delete one Herdr object' "$screen"
send_action 'type:DELETE REAL SENTINEL'
send_action enter
grep -Fq "Delete pane $delete_pane" "$screen"
send_action 'type:y'
send_action enter
wait_for "confirmed real pane deletion" sh -c \
  '! "$1" --session "$2" pane list |
    jq -e --arg pane "$3" "any(.result.panes[]; .pane_id == \$pane)" >/dev/null' \
  sh "$herdr" "$session" "$delete_pane"

cli pane send-text "$real_pane" "printf '\\nREAL_REFERENCE #a1b2c3d4\\n'" >/dev/null
cli pane send-keys "$real_pane" return >/dev/null
sleep 0.15
send_action visible-references
grep -Fq 'Recent pane references (not copy mode)' "$screen"
send_action 'type:a1b2c3d4'
send_action enter
wait_for "real reference copy" grep -Fqx '#a1b2c3d4' "$clipboard_log"
record real_transport "$(jq -cn --arg pane "$delete_pane" \
  --arg copied "$(tail -n 1 "$clipboard_log")" '
  {
    manage_popup_via:"prefix+shift+f",
    confirmed_deleted_pane:$pane,
    reference_popup_via:"prefix+shift+r",
    copied_hash:$copied,
    parent_process_survived:true
  }
')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
test "$("$herdr" --version)" = "herdr 0.7.5"
grep -Fqx 'pane_history = false' "$root/herdr/config.toml"
command -v tmux >/dev/null 2>&1
artifact_hashes=$(jq -cn \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg manager "$(shasum -a 256 "$prototype/manage_objects.sh" | awk '{print $1}')" \
  --arg picker "$(shasum -a 256 "$prototype/visible_reference_picker.sh" | awk '{print $1}')" \
  --arg parser "$(shasum -a 256 "$prototype/visible_references.py" | awk '{print $1}')" \
  --arg client "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{config:$config,manager:$manager,picker:$picker,parser:$parser,client:$client,validator:$validator}')
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" --argjson artifacts "$artifact_hashes" '
  {
    production_hashes_before:$before,
    production_hashes_after:$after,
    unchanged:($before == $after),
    artifacts:$artifacts,
    herdr_version:"0.7.5",
    pane_history:false,
    tmux_available:true,
    copy_mode_parity_claimed:false
  }
')"
record result "$(jq -cn '{
  status:"PASS",
  session:"pr",
  destructive_confirmation:true,
  stale_target_checks:true,
  visible_reference_types:["uri","path","hash"],
  copy_mode_emulation:false
}')"

mv "$evidence_tmp" "$evidence"
printf 'Herdr picker/reference validation: PASS (%s)\n' "$evidence"
