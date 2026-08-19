#!/bin/sh
set -eu

# PROTOTYPE ONLY: focus the tab at the given left-to-right position.
#
# Purely positional (like tmux select-window with base-index 1): digit N
# focuses the Nth tab in the current workspace's tab bar, digit 0 means
# position 10. It never creates a tab — new_tab.sh (prefix+c) and
# new_tab.sh (prefix+shift+j) own tab creation, always appending at the
# end, so pressing a digit ahead of the actual tab count is a silent no-op
# rather than spawning a stray tab.

digit=${1:?expected a digit from 0 through 9}
case "$digit" in
  [0-9]) ;;
  *) echo "numbered-tab: expected a digit from 0 through 9" >&2; exit 2 ;;
esac

position=$digit
[ "$digit" = "0" ] && position=10

herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_PANE_ID:-}
if [ -n "$pane" ]; then
  current=$($herdr pane current --pane "$pane")
else
  current=$($herdr pane current --current)
fi
workspace=$(printf '%s\n' "$current" | jq -er '.result.pane.workspace_id')
tabs=$($herdr tab list --workspace "$workspace")
target=$(printf '%s\n' "$tabs" | jq -r --argjson pos "$position" \
  '.result.tabs[$pos - 1].tab_id // empty')

if [ -n "$target" ]; then
  exec $herdr tab focus "$target"
fi
exit 0
