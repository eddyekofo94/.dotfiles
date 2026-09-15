#!/bin/sh
# Session (S) and weekly (W) allowance left must match Pi's footer boundaries
# (pi/MANUAL_QA.md): muted at 21%, yellow at 20% and 11%, maroon at 10%, and
# each half absent when Claude does not report that window.
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

expect_allowance() {
  window=$1
  label=$2
  used=$3
  colour=$4
  left=$5
  output=$(render ",\"rate_limits\":{\"$window\":{\"used_percentage\":$used}}")
  case "$output" in
    *"${esc}[${colour}m${label}: ${left}%${esc}[0m"*) ;;
    *)
      echo "statusline: $window used $used should show $label: $left% in $colour" >&2
      exit 1
      ;;
  esac
}

for pair in "five_hour S" "seven_day W"; do
  expect_allowance "${pair% *}" "${pair#* }" 79 "$muted" 21
  expect_allowance "${pair% *}" "${pair#* }" 80 "$yellow" 20
  expect_allowance "${pair% *}" "${pair#* }" 89 "$yellow" 11
  expect_allowance "${pair% *}" "${pair#* }" 90.4 "$maroon" 10
done

both=$(render ',"rate_limits":{"five_hour":{"used_percentage":50},"seven_day":{"used_percentage":35}}')
case "$both" in
  *"${esc}[${muted}mS: 50%${esc}[0m ${esc}[${muted}mW: 65%${esc}[0m"*) ;;
  *)
    echo 'statusline: both windows should show "S: 50% W: 65%" in that order' >&2
    exit 1
    ;;
esac

case "$(render ',"rate_limits":{"seven_day":{"used_percentage":35}}')" in
  *"S: "*)
    echo 'statusline: session segment shown without a five-hour limit' >&2
    exit 1
    ;;
esac

case "$(render '')" in
  *"S: "*|*"W: "*)
    echo 'statusline: allowance segment shown without rate limits' >&2
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

echo 'statusline session/weekly colours and context window: PASS'
