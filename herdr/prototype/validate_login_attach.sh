#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/la"
config_home="$runtime/config"
fish_config="$config_home/fish/config.fish"
fixture="$prototype/login_attach_fixture.sh"
adapter="$prototype/herdr_login_attach.fish"
allocator="$root/herdr/window_session.sh"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/login-attach-validation.jsonl"
evidence_tmp="$runtime/login-attach-validation.jsonl.tmp"
log="$runtime/launches.jsonl"
cwd_log="$runtime/launch-cwd"
default_file="$runtime/default-multiplexer"
session_runtime="$runtime/herdr-window-sessions-test"
session_state="$runtime/herdr-window-sessions-state"
herdr_config_root="$runtime/herdr-config"
process_fixture="$runtime/processes"
hold_dir="$runtime/hold"
background_pids=

cleanup() {
  exit_code=$?
  trap - EXIT HUP INT TERM
  mkdir -p "$hold_dir"
  : >"$hold_dir/release"
  for background_pid in $background_pids; do
    kill "$background_pid" 2>/dev/null || true
    wait "$background_pid" 2>/dev/null || true
  done
  rm -f -- "$evidence_tmp"
  exit "$exit_code"
}
trap cleanup EXIT HUP INT TERM

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

launch_count() {
  wc -l <"$log" | tr -d ' '
}

run_case() {
  expected_delta=$1
  shift
  before=$(launch_count)
  env -u TMUX -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_NO_AUTO_ATTACH \
    -u HERDR_LOGIN_SESSION XDG_CONFIG_HOME="$config_home" HERDR_BIN_PATH="$fixture" \
    HERDR_DEFAULT_FILE="$default_file" HERDR_LOGIN_ATTACH_LOG="$log" \
    HERDR_LOGIN_SESSION_ALLOCATOR="$allocator" \
    HERDR_LOGIN_SESSION_RUNTIME="$session_runtime" \
    HERDR_LOGIN_SESSION_STATE="$session_state" \
    HERDR_LOGIN_CONFIG_ROOT="$herdr_config_root" \
    HERDR_LOGIN_PROCESS_FIXTURE="$process_fixture" \
    HERDR_SKIP_PLUGIN_ENSURE=1 \
    "$@" </dev/null >/dev/null 2>&1
  after=$(launch_count)
  test $((after - before)) -eq "$expected_delta"
}

rm -rf "$runtime"
mkdir -p "$config_home/fish" "$evidence_dir" "$hold_dir"
: >"$evidence_tmp"
: >"$log"
: >"$process_fixture"
printf 'herdr\n' >"$default_file"
printf 'source "%s"\n' "$adapter" >"$fish_config"
production_before=$(production_hashes)

fish --no-config -n "$adapter"
sh -n "$fixture"
sh -n "$allocator"
if HERDR_LOGIN_SESSION_RUNTIME=/ \
  HERDR_LOGIN_SESSION_STATE="$session_state" \
  HERDR_LOGIN_CONFIG_ROOT="$herdr_config_root" \
  "$allocator" "$$" "$fixture" \
  >/dev/null 2>&1; then
  echo "window-session allocator accepted a broad runtime directory" >&2
  exit 1
fi
unsafe_runtime="$runtime/herdr-window-sessions-unsafe"
mkdir -m 755 "$unsafe_runtime"
if HERDR_LOGIN_SESSION_RUNTIME="$unsafe_runtime" \
  HERDR_LOGIN_SESSION_STATE="$session_state" \
  HERDR_LOGIN_CONFIG_ROOT="$herdr_config_root" \
  "$allocator" "$$" "$fixture" >/dev/null 2>&1; then
  echo "window-session allocator accepted an unsafe existing runtime" >&2
  exit 1
fi
rm -rf "$unsafe_runtime"
unsafe_state="$runtime/herdr-window-sessions-unsafe-state"
mkdir -m 755 "$unsafe_state"
if HERDR_LOGIN_SESSION_RUNTIME="$session_runtime" \
  HERDR_LOGIN_SESSION_STATE="$unsafe_state" \
  HERDR_LOGIN_CONFIG_ROOT="$herdr_config_root" \
  "$allocator" "$$" "$fixture" >/dev/null 2>&1; then
  echo "window-session allocator accepted unsafe persistent state" >&2
  exit 1
fi
rm -rf "$unsafe_state"

blocked_home="$runtime/blocked-home"
mkdir "$blocked_home"
chmod 000 "$blocked_home"
(cd / && run_case 0 HOME="$blocked_home" \
  fish --login --interactive --command 'exit 0')
test ! -e "$session_runtime/main.lease"
chmod 700 "$blocked_home"

run_case 1 fish --login --interactive --command 'exit 99'
default_args=$(sed -n '1p' "$log")
test "$default_args" = '["--session","main"]'

run_case 1 HERDR_LOGIN_SESSION=project-alpha fish --login --interactive --command 'exit 99'
custom_args=$(sed -n '2p' "$log")
test "$custom_args" = '["--session","project-alpha"]'

meaningful_cwd="$runtime/meaningful-cwd"
mkdir "$meaningful_cwd"
(cd "$meaningful_cwd" && run_case 1 \
  HERDR_LOGIN_ATTACH_CWD_LOG="$cwd_log" \
  fish --login --interactive --command 'exit 99')
test "$(cat "$cwd_log")" = "$HOME"

(cd / && run_case 1 HERDR_LOGIN_ATTACH_CWD_LOG="$cwd_log" \
  fish --login --interactive --command 'exit 99')
test "$(cat "$cwd_log")" = "$HOME"

rm -rf "$session_runtime" "$session_state" "$herdr_config_root"

start_held_case() {
  env -u TMUX -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_NO_AUTO_ATTACH \
    -u HERDR_LOGIN_SESSION XDG_CONFIG_HOME="$config_home" HERDR_BIN_PATH="$fixture" \
    HERDR_DEFAULT_FILE="$default_file" HERDR_LOGIN_ATTACH_LOG="$log" \
    HERDR_LOGIN_SESSION_ALLOCATOR="$allocator" \
    HERDR_LOGIN_SESSION_RUNTIME="$session_runtime" \
    HERDR_LOGIN_SESSION_STATE="$session_state" \
    HERDR_LOGIN_CONFIG_ROOT="$herdr_config_root" \
    HERDR_LOGIN_PROCESS_FIXTURE="$process_fixture" \
    HERDR_LOGIN_ATTACH_HOLD_DIR="$hold_dir" \
    HERDR_SKIP_PLUGIN_ENSURE=1 \
    fish --login --interactive --command 'exit 99' </dev/null >/dev/null 2>&1 &
  background_pids="$background_pids $!"
}

for client_number in 1 2 3; do
  start_held_case
done

ready_count=0
for wait_attempt in $(jot 250 1); do
  ready_count=$(find "$hold_dir" -type f -name 'ready.*' | wc -l | tr -d ' ')
  [ "$ready_count" -eq 3 ] && break
  sleep 0.02
done
test "$ready_count" -eq 3
concurrent_sessions=$(
  tail -n 3 "$log" |
    jq -sc 'map(.[1]) | sort'
)
test "$concurrent_sessions" = '["main","window-2","window-3"]'

printf 'sentinel\n' >"$session_state/last-session"
: >"$hold_dir/release"
for background_pid in $background_pids; do
  wait "$background_pid"
done
background_pids=
rm -rf "$hold_dir"
mkdir -p "$hold_dir"
for wait_attempt in $(jot 250 1); do
  lease_count=$(find "$session_runtime" -type f -name '*.lease' |
    wc -l | tr -d ' ')
  [ "$lease_count" -eq 0 ] && break
  sleep 0.02
done
test "$lease_count" -eq 0

printf 'window-3\n' >"$session_state/last-session"
start_held_case
ready_count=0
for wait_attempt in $(jot 250 1); do
  ready_count=$(find "$hold_dir" -type f -name 'ready.*' |
    wc -l | tr -d ' ')
  [ "$ready_count" -eq 1 ] && break
  sleep 0.02
done
test "$ready_count" -eq 1
monitor_case_args=$(tail -n 1 "$log")
test "$monitor_case_args" = '["--session","window-3"]'
printf 'sentinel\n' >"$session_state/last-session"
: >"$hold_dir/release"
for background_pid in $background_pids; do
  wait "$background_pid"
done
background_pids=
for wait_attempt in $(jot 250 1); do
  remembered_after_exit=$(cat "$session_state/last-session")
  [ "$remembered_after_exit" = window-3 ] &&
    [ ! -e "$session_runtime/window-3.lease" ] && break
  sleep 0.02
done
test "$remembered_after_exit" = window-3
test ! -e "$session_runtime/window-3.lease"
rm -rf "$hold_dir"
mkdir -p "$hold_dir"

run_case 1 fish --login --interactive --command 'exit 99'
restore_args=$(tail -n 1 "$log")
test "$restore_args" = '["--session","window-3"]'

printf '4242 %s --session main\n' "$fixture" >"$process_fixture"
run_case 1 fish --login --interactive --command 'exit 99'
active_new_args=$(tail -n 1 "$log")
test "$active_new_args" = '["--session","window-4"]'

printf '4243 %s\n' "$fixture" >"$process_fixture"
run_case 1 fish --login --interactive --command 'exit 99'
bare_client_new_args=$(tail -n 1 "$log")
test "$bare_client_new_args" = '["--session","window-5"]'

printf '4242 %s --session main\n' "$fixture" >"$process_fixture"
mkdir -p "$herdr_config_root/sessions/main"
occupied_slot=1
while [ "$occupied_slot" -le 9 ]; do
  if [ "$occupied_slot" -gt 1 ]; then
    mkdir -p "$herdr_config_root/sessions/window-$occupied_slot"
  fi
  occupied_slot=$((occupied_slot + 1))
done
run_case 1 fish --login --interactive --command 'exit 99'
window_ten_args=$(tail -n 1 "$log")
test "$window_ten_args" = '["--session","window-10"]'

rm -rf "$session_runtime" "$session_state" "$herdr_config_root"
: >"$process_fixture"
mkdir -p "$herdr_config_root/sessions/main" \
  "$herdr_config_root/sessions/window-2" \
  "$herdr_config_root/sessions/window-7"
run_case 1 fish --login --interactive --command 'exit 99'
migration_restore_args=$(tail -n 1 "$log")
test "$migration_restore_args" = '["--session","window-7"]'

printf '7007 %s --session window-7\n' "$fixture" >"$process_fixture"
run_case 1 fish --login --interactive --command 'exit 99'
migration_new_args=$(tail -n 1 "$log")
test "$migration_new_args" = '["--session","window-8"]'
: >"$process_fixture"

for wait_attempt in $(jot 250 1); do
  [ ! -e "$session_runtime/window-8.lease" ] && break
  sleep 0.02
done
test ! -e "$session_runtime/window-8.lease"
printf '%s\t%s\n' "$$" 'reused-pid-wrong-start' \
  >"$session_runtime/window-8.lease"
run_case 1 fish --login --interactive --command 'exit 99'
reused_pid_restore_args=$(tail -n 1 "$log")
test "$reused_pid_restore_args" = '["--session","window-8"]'

for wait_attempt in $(jot 250 1); do
  [ ! -e "$session_runtime/window-8.lease" ] && break
  sleep 0.02
done
test ! -e "$session_runtime/window-8.lease"
ln -s "$runtime/symlink-target" "$session_runtime/window-8.lease"
run_case 0 fish --login --interactive --command 'exit 0'
test -L "$session_runtime/window-8.lease"
rm "$session_runtime/window-8.lease"

owner_start=$(ps -p "$$" -o lstart= | awk '{$1=$1; print}')
if HERDR_LOGIN_SESSION_RUNTIME="$session_runtime" \
  HERDR_LOGIN_SESSION_STATE="$session_state" \
  HERDR_LOGIN_CONFIG_ROOT="$herdr_config_root" \
  "$allocator" --locked "$$" "$owner_start" "$fixture" \
    "$session_runtime" "$session_state" "$herdr_config_root" \
    >/dev/null 2>&1; then
  echo "window-session internal allocation bypassed its lock" >&2
  exit 1
fi

supervised_session=$(
  HERDR_LOGIN_SESSION_RUNTIME="$session_runtime" \
    HERDR_LOGIN_SESSION_STATE="$session_state" \
    HERDR_LOGIN_CONFIG_ROOT="$herdr_config_root" \
    HERDR_LOGIN_PROCESS_FIXTURE="$process_fixture" \
    "$allocator" "$$" "$fixture"
)
test "$supervised_session" = window-8
rm -rf "$hold_dir"
mkdir -p "$hold_dir"
supervisor_stdin="$runtime/supervisor-stdin"
supervisor_stdin_log="$runtime/supervisor-stdin-log"
printf 'HERDR_STDIN_REACHES_CLIENT\n' >"$supervisor_stdin"
HERDR_LOGIN_SESSION_RUNTIME="$session_runtime" \
  HERDR_LOGIN_SESSION_STATE="$session_state" \
  HERDR_LOGIN_ATTACH_LOG="$log" \
  HERDR_LOGIN_ATTACH_STDIN_LOG="$supervisor_stdin_log" \
  HERDR_LOGIN_ATTACH_HOLD_DIR="$hold_dir" \
  "$allocator" --supervise "$$" "$supervised_session" "$fixture" \
  <"$supervisor_stdin" >/dev/null 2>&1 &
supervisor_pid=$!
background_pids="$background_pids $supervisor_pid"
for wait_attempt in $(jot 250 1); do
  supervisor_client=$(pgrep -P "$supervisor_pid" | head -n 1 || true)
  [ -n "$supervisor_client" ] &&
    [ -n "$(find "$hold_dir" -type f -name 'ready.*' -print -quit)" ] &&
    break
  sleep 0.02
done
test -n "$supervisor_client"
test "$(cat "$supervisor_stdin_log")" = HERDR_STDIN_REACHES_CLIENT
test "$(pgrep -P "$supervisor_pid" | tr -d ' ')" = "$supervisor_client"
printf 'sentinel\n' >"$session_state/last-session"
kill -HUP "$supervisor_pid" "$supervisor_client"
wait "$supervisor_pid"
background_pids=
test "$(cat "$session_state/last-session")" = window-8
test ! -e "$session_runtime/window-8.lease"
test -z "$(rg -n 'sleep 0\\.1|--monitor|/usr/bin/nohup' "$allocator" || true)"
rg -Fq 'wait "$client_pid"' "$allocator"

interrupt_runtime="$runtime/herdr-window-sessions-interrupt"
interrupt_state="$runtime/herdr-window-sessions-interrupt-state"
interrupt_processes="$runtime/interrupt-processes"
mkfifo "$interrupt_processes"
HERDR_LOGIN_SESSION_RUNTIME="$interrupt_runtime" \
  HERDR_LOGIN_SESSION_STATE="$interrupt_state" \
  HERDR_LOGIN_CONFIG_ROOT="$herdr_config_root" \
  HERDR_LOGIN_PROCESS_FIXTURE="$interrupt_processes" \
  "$allocator" "$$" "$fixture" >/dev/null 2>&1 &
interrupt_parent=$!
interrupt_child=
for wait_attempt in $(jot 250 1); do
  interrupt_child=$(pgrep -P "$interrupt_parent" | head -n 1 || true)
  [ -n "$interrupt_child" ] && break
  sleep 0.02
done
test -n "$interrupt_child"
kill -TERM "$interrupt_child"
# The allocator may be blocked opening the process snapshot FIFO. Let that read
# finish so the shell can deliver its pending TERM trap and clean up atomically.
: >"$interrupt_processes"
set +e
wait "$interrupt_parent"
interrupt_status=$?
set -e
test "$interrupt_status" -ne 0
test ! -e "$interrupt_state/last-session"
lease_count=$(find "$interrupt_runtime" -type f -name '*.lease' |
  wc -l | tr -d ' ')
test "$lease_count" -eq 0

run_case 0 fish --interactive --command 'exit 0'
run_case 0 fish --login --command 'exit 0'
run_case 0 HERDR_ENV=1 fish --login --interactive --command 'exit 0'
run_case 0 HERDR_PANE_ID=w1:p1 fish --login --interactive --command 'exit 0'
run_case 0 TMUX=production fish --login --interactive --command 'exit 0'
run_case 0 HERDR_NO_AUTO_ATTACH=1 fish --login --interactive --command 'exit 0'
run_case 0 HERDR_LOGIN_SESSION='../bad' fish --login --interactive --command 'exit 0'
invalid_session_cwd_log="$runtime/invalid-session-cwd"
(cd / && run_case 0 HERDR_LOGIN_SESSION='../bad' \
  fish --login --interactive \
    --command "pwd -P >'$invalid_session_cwd_log'")
test "$(cat "$invalid_session_cwd_log")" = /
run_case 0 HERDR_LOGIN_SESSION_ALLOCATOR=/usr/bin/false \
  fish --login --interactive --command 'exit 0'
printf 'tmux\n' >"$default_file"
run_case 0 fish --login --interactive --command 'exit 0'
printf 'invalid\n' >"$default_file"
run_case 0 fish --login --interactive --command 'exit 0'
rm -f "$default_file"
run_case 0 fish --login --interactive --command 'exit 0'

record decisions "$(jq -cn --argjson default "$default_args" --argjson custom "$custom_args" \
  --argjson concurrent "$concurrent_sessions" --argjson restore "$restore_args" \
  --argjson active_new "$active_new_args" --argjson window_ten "$window_ten_args" \
  --argjson bare_new "$bare_client_new_args" \
  --argjson reused_pid_restore "$reused_pid_restore_args" \
  --argjson migration_restore "$migration_restore_args" \
  --argjson migration_new "$migration_new_args" '
  {top_level_login:{launched:true,args:$default},
   custom_session:{launched:true,args:$custom},
   cwd_policy:{automatic_launch_home:true,restored_panes_keep_session_cwd:true},
   independent_windows:{concurrent_sessions:$concurrent,
     no_client_restores_last:$restore,
     active_client_creates_new:$active_new,
     bare_client_creates_new:$bare_new,
     final_client_exit_updates_last:true,
     double_digit_boundary:$window_ten,
     migration_restores_highest_existing:$migration_restore,
     migration_active_creates_next:$migration_new,
     reused_pid_restores_last:$reused_pid_restore,
     persistent_servers_not_stopped:true},
   guards:{non_login:true,non_interactive:true,herdr_env:true,herdr_pane:true,
     tmux:true,opt_out:true,invalid_session:true,allocator_failure:true,
     invalid_session_cwd_unchanged:true,
     broad_runtime_rejected:true,unsafe_existing_runtime_rejected:true,
     unsafe_persistent_state_rejected:true,
     symlink_lease_rejected:true,
     concurrent_cold_start:true,
     home_cd_failure_without_lease:true,
     event_driven_supervisor_hup:true,
     supervisor_no_polling:true,
     supervisor_preserves_client_stdin:true,
     interrupted_allocation_no_state:true,
     internal_mode_requires_lock:true,
     tmux_default:true,invalid_default:true,missing_default:true},
   total_launches:16}
')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
artifact_hashes=$(jq -cn \
  --arg adapter "$(shasum -a 256 "$adapter" | awk '{print $1}')" \
  --arg allocator "$(shasum -a 256 "$allocator" | awk '{print $1}')" \
  --arg fixture "$(shasum -a 256 "$fixture" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{adapter:$adapter,allocator:$allocator,fixture:$fixture,validator:$validator}')
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" --argjson artifacts "$artifact_hashes" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before==$after),artifact_hashes:$artifacts}')"
record result "$(jq -cn \
  '{status:"PASS",independent_window_sessions:true,
    session_policy:"restore-last-or-create-monotonic",
    production_fish_modified:false,installed:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
trap - EXIT HUP INT TERM
printf 'Herdr Fish login-attach validation: PASS (%s)\n' "$evidence"
