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

echo 'statusline weekly colours: PASS'
