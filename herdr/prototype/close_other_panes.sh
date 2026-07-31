#!/bin/sh
set -eu

# PROTOTYPE ONLY: require an identical second press before closing sibling panes.

herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_TARGET_PANE_ID:-${HERDR_PANE_ID:-}}
prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state_dir=${HERDR_PANE_CLOSE_OTHERS_STATE_DIR:-"$prototype/.runtime/pane-close-others-confirm"}
window=5

if [ -n "$pane" ]; then
  current_pane=$($herdr pane current --pane "$pane")
else
  current_pane=$($herdr pane current --current)
fi
current=$(printf '%s\n' "$current_pane" | jq -er '.result.pane.pane_id')
tab=$(printf '%s\n' "$current_pane" | jq -er '.result.pane.tab_id')
panes=$($herdr pane list)
targets=$(printf '%s\n' "$panes" | jq -r --arg tab "$tab" --arg current "$current" '
  .result.panes[] |
  select(.tab_id == $tab and .pane_id != $current) |
  .pane_id
' | sort)

if [ -z "$targets" ]; then
  echo "close-other-panes: no sibling panes in the active tab" >&2
  exit 4
fi

fingerprint=$(printf '%s\n%s\n' "$current" "$targets" |
  shasum -a 256 | awk '{print $1}')
pane_key=$(printf '%s' "$current" | tr -c '[:alnum:]_.-' '_')
state="$state_dir/$pane_key"
now=$(date +%s)
mkdir -p "$state_dir"

if [ -f "$state" ]; then
  IFS=' ' read -r previous_time previous_fingerprint <"$state" || true
  age=$((now - ${previous_time:-0}))
  if [ "${previous_fingerprint:-}" = "$fingerprint" ] &&
     [ "$age" -ge 0 ] && [ "$age" -le "$window" ]; then
    rm -f "$state"
    printf '%s\n' "$targets" | while IFS= read -r target; do
      [ -n "$target" ] && $herdr pane close "$target" >/dev/null
    done
    printf 'close-other-panes: kept %s and closed %s sibling pane(s)\n' \
      "$current" "$(printf '%s\n' "$targets" | wc -l | tr -d ' ')"
    exit 0
  fi
fi

printf '%s %s\n' "$now" "$fingerprint" >"$state"
$herdr notification show "Close OTHER panes? Press Alt+o again within 5s" \
  --body "keeps the focused pane" \
  --sound none >/dev/null 2>&1 || true
echo "close-other-panes: press again within five seconds to confirm" >&2
exit 75
