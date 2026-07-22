#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runtime="$prototype/.runtime/url"
config_home="$runtime/c"
config="$config_home/herdr/config.toml"
herdr="$prototype/.runtime/bin/herdr"
session=url
socket="$config_home/herdr/sessions/$session/herdr.sock"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/url-validation.jsonl"
evidence_tmp="$runtime/url-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
server_log="$runtime/server.log"
url_log="$runtime/opened-urls.log"

[ -x "$herdr" ] || {
  echo "URL validation requires the prototype Herdr binary" >&2
  exit 2
}

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_SESSION="$session"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_URL_OPENER="$prototype/url_opener_fixture.sh"
export HERDR_URL_OPEN_LOG="$url_log"

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
      echo "URL validation timed out: $description" >&2
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

log_line_count_is() {
  expected=$1
  [ "$(wc -l <"$url_log" | tr -d ' ')" -eq "$expected" ]
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

rm -rf "$runtime"
mkdir -p "$config_home/herdr" "$evidence_dir"
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  "$prototype/config.toml" >"$config"
: >"$evidence_tmp"
: >"$url_log"
production_before=$(production_hashes)

config_result=$(cli config check 2>&1)
grep -A3 -F 'key = "prefix+u"' "$config" | grep -Fq 'open_visible_url.sh'
record config "$(jq -cn --arg result "$config_result" \
  '{result:$result,binding:"prefix+u",transport:"real PTY input"}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "URL socket" test -S "$socket"
mkfifo "$driver_fifo"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "URL client" grep -q '^READY$' "$driver_log"

pane=$(cli pane current --current | jq -er '.result.pane.pane_id')

cli pane send-text "$pane" "printf '\\nNO_URL_FIXTURE\\n'" >/dev/null
cli pane send-keys "$pane" return >/dev/null
sleep 0.15
send_action open-url
sleep 0.15
test "$(wc -l <"$url_log" | tr -d ' ')" -eq 0

cli pane send-text "$pane" "printf '\\nONE_URL https://example.test/one).\\n'" >/dev/null
cli pane send-keys "$pane" return >/dev/null
sleep 0.15
send_action open-url
wait_for "one URL opened" log_line_count_is 1
test "$(sed -n '1p' "$url_log")" = "https://example.test/one"

cli pane send-text "$pane" "printf '\\nTWO_URLS https://example.test/old https://example.test/new?x=1,\\n'" >/dev/null
cli pane send-keys "$pane" return >/dev/null
sleep 0.15
send_action open-url
wait_for "newest URL opened" log_line_count_is 2
test "$(sed -n '2p' "$url_log")" = "https://example.test/new?x=1"

record transport "$(jq -cn --arg pane "$pane" --rawfile opened "$url_log" \
  '{pane_id:$pane,cases:{zero:{opened:false},one:{opened:"https://example.test/one"},multiple:{opened_newest:"https://example.test/new?x=1"}},opened:($opened|split("\n")|map(select(length>0))),input_submitted_via:"prefix+u"}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
artifact_hashes=$(jq -cn \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg helper "$(shasum -a 256 "$prototype/open_visible_url.sh" | awk '{print $1}')" \
  --arg opener "$(shasum -a 256 "$prototype/url_opener_fixture.sh" | awk '{print $1}')" \
  --arg client "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{config:$config,helper:$helper,opener:$opener,client:$client,validator:$validator}')
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" --argjson artifacts "$artifact_hashes" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before==$after),artifact_hashes:$artifacts}')"
record result "$(jq -cn --arg version "$("$herdr" --version)" \
  '{status:"PASS",version:$version,session:"url",production_configuration_modified:false,migration_authorized:false}')"
mv "$evidence_tmp" "$evidence"
printf 'Herdr URL validation: PASS (%s)\n' "$evidence"
