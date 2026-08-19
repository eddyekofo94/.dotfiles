#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/server_lifecycle.sh"
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/m"
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
session=cm
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/copy-mode-validation.jsonl"
evidence_tmp="$runtime/copy-mode-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
server_log="$runtime/server.log"
clipboard_before="$runtime/clipboard-before"

[ -x "$herdr" ] || {
  echo "copy-mode validation requires the prototype Herdr binary" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_PROTOTYPE_DIR="$prototype"

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
    if [ "$attempts" -ge 100 ]; then
      echo "copy-mode validation timed out: $description" >&2
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
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "$3" ]' \
    sh "$driver_log" "$before" "SENT $action"
}
screen_min() {
  grep -Eo 'COPY_LINE_[0-9]{3}' "$screen" | sed 's/.*_//' | sort -n | sed -n '1p'
}
screen_max() {
  grep -Eo 'COPY_LINE_[0-9]{3}' "$screen" | sed 's/.*_//' | sort -n | tail -n 1
}
screen_has_line() {
  grep -Fq "COPY_LINE_$1" "$screen"
}
sentinel_ready() {
  cli pane process-info --pane "$1" 2>/dev/null |
    jq -e 'any(.result.process_info.foreground_processes[]?; .name == "sleep")' >/dev/null
}
focused_pane_ready() {
  cli pane list 2>/dev/null |
    jq -e 'any(.result.panes[]?; .focused == true)' >/dev/null
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
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  cli session delete "$session" --json >/dev/null 2>&1 || true
  if [ -f "$clipboard_before" ]; then
    pbcopy <"$clipboard_before"
  fi
  rm -f "$driver_fifo" "$evidence_tmp"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

herdr_sweep_stale_server "$socket"
herdr_guard_server "$socket"
rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir"
pbpaste >"$clipboard_before"
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' "$prototype/config.toml" >"$config"
: >"$evidence_tmp"
production_before=$(production_hashes)
config_result=$(cli config check 2>&1)
record config "$(jq -cn --arg result "$config_result" '{result:$result,binding:"prefix+s",native_half_page:["Ctrl-u","Ctrl-d"],native_full_page:["PageUp","PageDown"]}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "copy-mode socket" test -S "$socket"
rm -f "$driver_fifo"
mkfifo "$driver_fifo"
"$prototype/copy_mode_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "copy-mode client" grep -q '^READY$' "$driver_log"
wait_for "focused copy-mode pane" focused_pane_ready

pane=$(cli pane list | jq -er '.result.panes[] | select(.focused).pane_id')
cli pane run "$pane" 'i=1; while [ "$i" -le 120 ]; do printf "COPY_LINE_%03d payload-%03d\n" "$i" "$i"; i=$((i + 1)); done; exec sleep 300' >/dev/null
wait_for "copy fixture sentinel" sentinel_ready "$pane"
send_action snapshot
wait_for "latest copy line visible" screen_has_line 120
pid=$(cli pane process-info --pane "$pane" | jq -er '.result.process_info.foreground_processes[] | select(.name == "sleep").pid')
initial_min=$(screen_min)
initial_max=$(screen_max)
test "$initial_max" -eq 120

send_action copy-mode
copy_min=$(screen_min)
copy_max=$(screen_max)
send_action copy-half-up
half_up_min=$(screen_min)
half_up_max=$(screen_max)
test "$half_up_max" -lt "$copy_max"
send_action copy-half-down
half_down_min=$(screen_min)
half_down_max=$(screen_max)
test "$half_down_min" -gt "$half_up_min"
test "$half_down_max" -gt "$half_up_max"

send_action copy-page-up
page_up_min=$(screen_min)
page_up_max=$(screen_max)
test "$page_up_max" -lt "$half_down_max"
send_action copy-page-down
page_down_min=$(screen_min)
page_down_max=$(screen_max)
test "$page_down_min" -gt "$page_up_min"
test "$page_down_max" -gt "$page_up_max"
send_action copy-quit
kill -0 "$pid"
record paging "$(jq -cn \
  --argjson pid "$pid" \
  --argjson initial_min "$initial_min" --argjson initial_max "$initial_max" \
  --argjson copy_min "$copy_min" --argjson copy_max "$copy_max" \
  --argjson half_up_min "$half_up_min" --argjson half_up_max "$half_up_max" \
  --argjson half_down_min "$half_down_min" --argjson half_down_max "$half_down_max" \
  --argjson page_up_min "$page_up_min" --argjson page_up_max "$page_up_max" \
  --argjson page_down_min "$page_down_min" --argjson page_down_max "$page_down_max" \
  '{sentinel_pid:$pid,initial:{min:$initial_min,max:$initial_max},copy_entry:{min:$copy_min,max:$copy_max},half_up:{min:$half_up_min,max:$half_up_max},half_down:{min:$half_down_min,max:$half_down_max},page_up:{min:$page_up_min,max:$page_up_max},page_down:{min:$page_down_min,max:$page_down_max},process_survived:true}')"

clipboard_sentinel=COPY_MODE_NO_COPY_SENTINEL
for alias in a i; do
  printf '%s' "$clipboard_sentinel" | pbcopy
  send_action copy-mode
  send_action copy-up
  send_action copy-select
  send_action "copy-exit-$alias"
  test "$(pbpaste)" = "$clipboard_sentinel"
  kill -0 "$pid"
done

printf '%s' "$clipboard_sentinel" | pbcopy
send_action copy-mode
send_action copy-up
send_action copy-line-yank
wait_for "whole-line clipboard" sh -c \
  '[ "$(pbpaste)" = "COPY_LINE_120 payload-120" ]'
kill -0 "$pid"
record vim_aliases "$(jq -cn \
  --arg no_copy "$clipboard_sentinel" \
  --arg line "$(pbpaste)" \
  --argjson pid "$pid" \
  '{exit_without_copy:{a:$no_copy,i:$no_copy},whole_line:$line,sentinel_pid:$pid,process_survived:true,input_emulation_installed:false}')"

# Alt+/ reaches copy mode without the prefix, and a typed count makes Y linewise
# over that many lines the way Vim's 2yy does.
printf '%s' "$clipboard_sentinel" | pbcopy
send_action copy-mode-alt
send_action copy-up
send_action copy-up
send_action copy-count-2
send_action copy-line-yank
wait_for "counted whole-line clipboard" sh -c \
  '[ "$(pbpaste)" = "COPY_LINE_119 payload-119
COPY_LINE_120 payload-120" ]'
counted_yank=$(pbpaste)
kill -0 "$pid"

# Esc discards a half-typed count instead of leaving copy mode, so the Y that
# follows is the plain one-line yank again.
printf '%s' "$clipboard_sentinel" | pbcopy
send_action copy-mode
send_action copy-up
send_action copy-count-2
send_action copy-esc
send_action copy-line-yank
wait_for "pending-count discarded clipboard" sh -c \
  '[ "$(pbpaste)" = "COPY_LINE_120 payload-120" ]'
pending_cleared_yank=$(pbpaste)
kill -0 "$pid"

# Alt+b opens copy mode with the backward search prompt already accepting input.
printf '%s' "$clipboard_sentinel" | pbcopy
send_action copy-search-alt
send_action type:payload-118
send_action enter
send_action copy-line-yank
wait_for "backward search clipboard" sh -c \
  '[ "$(pbpaste)" = "COPY_LINE_118 payload-118" ]'
search_yank=$(pbpaste)
kill -0 "$pid"

# zz pulls the cursor's line to the middle of the viewport, so the window slides
# toward the newer lines it was sitting above.
send_action copy-mode
send_action copy-page-up
center_before_min=$(screen_min)
center_before_max=$(screen_max)
send_action copy-center
center_after_min=$(screen_min)
center_after_max=$(screen_max)
test "$center_after_min" -gt "$center_before_min"
test "$center_after_max" -gt "$center_before_max"
send_action copy-quit
kill -0 "$pid"
record vim_pending_commands "$(jq -cn \
  --arg counted "$counted_yank" \
  --arg pending_cleared "$pending_cleared_yank" \
  --arg search "$search_yank" \
  --argjson center_before_min "$center_before_min" \
  --argjson center_before_max "$center_before_max" \
  --argjson center_after_min "$center_after_min" \
  --argjson center_after_max "$center_after_max" \
  --argjson pid "$pid" \
  '{alt_slash_entry_counted_yank:$counted,escape_discards_count:$pending_cleared,alt_b_backward_search:$search,center:{before:{min:$center_before_min,max:$center_before_max},after:{min:$center_after_min,max:$center_after_max}},sentinel_pid:$pid,process_survived:true,input_emulation_installed:false}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn \
  --arg config_hash "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg client_hash "$(shasum -a 256 "$prototype/copy_mode_client.py" | awk '{print $1}')" \
  --arg validator_hash "$(shasum -a 256 "$prototype/validate_copy_mode.sh" | awk '{print $1}')" \
  --argjson production "$production_after" \
  '{config_sha256:$config_hash,client_sha256:$client_hash,validator_sha256:$validator_hash,production_sha256:$production}')"
record result "$(jq -cn --arg version "$("$herdr" --version)" '{status:"PASS",version:$version,session:"cm",production_configuration_modified:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr copy-mode validation: PASS (%s)\n' "$evidence"
