#!/bin/sh
set -eu

# Add a second new-tab chord without replacing Herdr's native Prefix+c binding.

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

if [ -n "$cwd" ]; then
  exec $herdr tab create --workspace "$workspace" --cwd "$cwd" --focus
fi
exec $herdr tab create --workspace "$workspace" --focus
