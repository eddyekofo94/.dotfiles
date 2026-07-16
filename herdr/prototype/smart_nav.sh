#!/bin/sh
set -eu

key=${1:?navigation key required}
direction=${2:?Herdr direction required}
herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_PANE_ID:?smart navigation must run inside a Herdr pane}
log=${HERDR_NAV_LOG:-/tmp/herdr-prototype-nav.log}

process_info=$($herdr pane process-info --pane "$pane")
if printf '%s\n' "$process_info" | jq -e '
  .result.process_info.foreground_processes[]?
  | select(.name == "nvim" or .name == "vim" or .name == "vimdiff" or .name == "ssh")
' >/dev/null; then
  # Inject into the PTY after Herdr consumed the direct chord. Neovim then
  # moves locally or invokes the temporary edge-handoff adapter.
  exec "$herdr" pane send-keys "$pane" "alt+$key"
fi

printf '%s app %s herdr-pane\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$key" >>"$log"
exec "$herdr" pane focus --direction "$direction" --pane "$pane" >/dev/null
