#!/bin/sh
# Session (S) and weekly (W) allowance left must use Pi's footer colour boundaries
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

# Fable is a model_scoped weekly window, not a top-level rate_limits key,
# matched on display_name (case-insensitively) rather than a fixed field.
expect_fable_allowance() {
  used=$1
  colour=$2
  left=$3
  output=$(render ",\"rate_limits\":{\"model_scoped\":[{\"display_name\":\"Fable\",\"utilization\":$used}]}")
  case "$output" in
    *"${esc}[${colour}mF: ${left}%${esc}[0m"*) ;;
    *)
      echo "statusline: model_scoped Fable used $used should show F: $left% in $colour" >&2
      exit 1
      ;;
  esac
}
expect_fable_allowance 79 "$muted" 21
expect_fable_allowance 80 "$yellow" 20
expect_fable_allowance 89 "$yellow" 11
expect_fable_allowance 90.4 "$maroon" 10

case "$(render ',"rate_limits":{"model_scoped":[{"display_name":"fable","utilization":40}]}')" in
  *"${esc}[${muted}mF: 60%${esc}[0m"*) ;;
  *)
    echo 'statusline: display_name match should be case-insensitive' >&2
    exit 1
    ;;
esac

case "$(render ',"rate_limits":{"model_scoped":[{"display_name":"Opus","utilization":10}],"five_hour":{"used_percentage":10}}')" in
  *"F: "*)
    echo 'statusline: F segment shown without a model_scoped Fable entry' >&2
    exit 1
    ;;
esac

both=$(render ',"rate_limits":{"model_scoped":[{"display_name":"Fable","utilization":10}],"five_hour":{"used_percentage":50},"seven_day":{"used_percentage":35}}')
case "$both" in
  *"${esc}[${muted}mF: 90%${esc}[0m ${esc}[${muted}mS: 50%${esc}[0m ${esc}[${muted}mW: 65%${esc}[0m"*) ;;
  *)
    echo 'statusline: F, S, and W should show "F: 90% S: 50% W: 65%" in that order' >&2
    exit 1
    ;;
esac

# Reset countdown: an hour or more shows "Xh", under an hour shows "Xm", and
# a due-or-past reset shows "now". S/W resets_at is an epoch integer;
# Fable's (model_scoped) is always an ISO 8601 string.
now=$(date +%s)
case "$(render ",\"rate_limits\":{\"five_hour\":{\"used_percentage\":50,\"resets_at\":$((now + 7200))}}")" in
  *"S: 50% (2h)"*) ;;
  *)
    echo 'statusline: a two-hour-out epoch reset should show "(2h)"' >&2
    exit 1
    ;;
esac
case "$(render ",\"rate_limits\":{\"seven_day\":{\"used_percentage\":50,\"resets_at\":$((now - 60))}}")" in
  *"W: 50% (now)"*) ;;
  *)
    echo 'statusline: a past epoch reset should show "(now)"' >&2
    exit 1
    ;;
esac
fable_iso=$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp($now + 1800, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")
case "$(render ",\"rate_limits\":{\"model_scoped\":[{\"display_name\":\"Fable\",\"utilization\":50,\"resets_at\":\"$fable_iso\"}]}")" in
  *"F: 50% (30m)"*) ;;
  *)
    echo 'statusline: a 30-minute-out ISO reset should show "(30m)"' >&2
    exit 1
    ;;
esac
case "$(render ',"rate_limits":{"five_hour":{"used_percentage":50}}')" in
  *"S: 50% ("*)
    echo 'statusline: no reset countdown should be shown without resets_at' >&2
    exit 1
    ;;
esac

case "$(render ',"rate_limits":{"seven_day":{"used_percentage":35}}')" in
  *"S: "*)
    echo 'statusline: session segment shown without a five-hour limit' >&2
    exit 1
    ;;
esac

case "$(render ',"rate_limits":{"five_hour":{"used_percentage":50},"seven_day":{"used_percentage":null}}')" in
  *"W: "*)
    echo 'statusline: weekly segment shown without a seven-day limit' >&2
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
