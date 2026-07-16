#!/bin/sh
set -eu

key=${1:?navigation key required}
direction=${2:?Herdr direction required}
herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_PANE_ID:?smart navigation must run inside a Herdr pane}

process_info=$($herdr pane process-info --pane "$pane")
if printf '%s\n' "$process_info" | jq -e '
  .result.process_info.foreground_processes[]?
  | select(.name == "nvim" or .name == "vim")
' >/dev/null; then
  # Inject into the PTY after Herdr consumed the direct chord. Neovim then
  # moves locally or invokes the temporary edge-handoff adapter.
  exec "$herdr" pane send-keys "$pane" "alt+$key"
fi

exec "$herdr" pane focus --direction "$direction" --pane "$pane" >/dev/null
