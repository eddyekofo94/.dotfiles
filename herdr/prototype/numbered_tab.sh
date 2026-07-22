#!/bin/sh
set -eu

# PROTOTYPE ONLY: focus a numeric tab or create one labeled with that digit.

digit=${1:?expected a digit from 0 through 9}
case "$digit" in
  [0-9]) ;;
  *) echo "numbered-tab: expected a digit from 0 through 9" >&2; exit 2 ;;
esac

herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_PANE_ID:-}
if [ -n "$pane" ]; then
  current=$($herdr pane current --pane "$pane")
else
  current=$($herdr pane current --current)
fi
workspace=$(printf '%s\n' "$current" | jq -er '.result.pane.workspace_id')
cwd=$(printf '%s\n' "$current" | jq -er \
  '.result.pane.foreground_cwd // .result.pane.cwd // empty')
tabs=$($herdr tab list --workspace "$workspace")
target=$(printf '%s\n' "$tabs" | jq -r --arg digit "$digit" '
  ([.result.tabs[] | select(.label == $digit)][0] //
   [.result.tabs[] | select((.number | tostring) == $digit)][0] // {}) |
  .tab_id // empty
')

if [ -n "$target" ]; then
  exec $herdr tab focus "$target"
fi

if [ -n "$cwd" ]; then
  exec $herdr tab create --workspace "$workspace" --cwd "$cwd" \
    --label "$digit" --focus
fi
exec $herdr tab create --workspace "$workspace" --label "$digit" --focus
