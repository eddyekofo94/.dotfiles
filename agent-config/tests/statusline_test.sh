#!/bin/sh
# Weekly allowance must match Pi's footer boundaries (pi/MANUAL_QA.md): muted at
# 21%, yellow at 20% and 11%, maroon at 10%, and absent without rate limits.
set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
statusline="$config_dir/claude/statusline-command.sh"
esc=$(printf '\033')
muted="38;2;127;132;156"
yellow="38;2;249;226;175"
maroon="38;2;235;160;172"

render() {
  printf '{"model":{"display_name":"Opus 5","id":"claude-opus-5"},"workspace":{"current_dir":"/"}%s}\n' "$1" |
    bash "$statusline"
}

expect_weekly() {
  used=$1
  colour=$2
  left=$3
  output=$(render ",\"rate_limits\":{\"seven_day\":{\"used_percentage\":$used}}")
  case "$output" in
    *"${esc}[${colour}mweekly ${left}% left${esc}[0m"*) ;;
    *)
      echo "statusline: used $used should show weekly $left% left in $colour" >&2
      exit 1
      ;;
  esac
}

expect_weekly 79 "$muted" 21
expect_weekly 80 "$yellow" 20
expect_weekly 89 "$yellow" 11
expect_weekly 90.4 "$maroon" 10

case "$(render '')" in
  *weekly*)
    echo 'statusline: weekly segment shown without rate limits' >&2
    exit 1
    ;;
esac

# Context percentage must use the model's real window, not a fixed 200k.
transcript="$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX")/t.jsonl"
trap 'rm -rf -- "$(dirname -- "$transcript")"' EXIT HUP INT TERM
printf '{"message":{"usage":{"input_tokens":1000,"cache_read_input_tokens":38000}}}\n' >"$transcript"
expect_context() {
  model=$1
  extra=$2
  want=$3
  output=$(printf '{"model":{"display_name":"M","id":"%s"},"workspace":{"current_dir":"/"},"transcript_path":"%s"%s}\n' \
    "$model" "$transcript" "$extra" | bash "$statusline")
  case "$output" in
    *"$want"*) ;;
    *)
      echo "statusline: $model $extra should show $want" >&2
      exit 1
      ;;
  esac
}
expect_context 'claude-opus-5' '' '39k/20%'
expect_context 'claude-opus-5[1m]' '' '39k/4%'
expect_context 'claude-opus-5' ',"context_window":{"context_window_size":1000000}' '39k/4%'

echo 'statusline weekly colours and context window: PASS'
