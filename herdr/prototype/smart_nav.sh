#!/bin/sh
set -eu

key=${1:?navigation key required}
direction=${2:?Herdr direction required}
prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
log=${HERDR_NAV_LOG:-/tmp/herdr-prototype-nav.log}

# Herdr injects HERDR_TARGET_PANE_ID for command bindings (see adaptive_split.sh);
# focused_pane.sh falls back to HERDR_PANE_ID then the focused pane.
pane=${HERDR_TARGET_PANE_ID:-$("$prototype/focused_pane.sh")}

process_info=$("$herdr" pane process-info --pane "$pane" 2>/dev/null || echo '{}')

# Forward to a terminal editor / ssh the same way tmux's $running_vim guard did:
# match the command line, not just the (unreliable) reported process name.
if printf '%s\n' "$process_info" | jq -e '
  .result.process_info.foreground_processes[]?
  | select(
      (.name    // "" | test("^(n?vim|vimdiff|view)$")) or
      (.argv0   // "" | test("(^|/)(n?vim|vimdiff|view|ssh)$")) or
      (.cmdline // "" | test("(^|/)(n?vim|vimdiff|view|ssh)( |$)"))
    )
' >/dev/null 2>&1; then
  # Inject into the PTY after Herdr consumed the direct chord. Neovim then moves
  # a window locally, or hands the edge off to Herdr via its own keymap.
  printf '%s vim-forward pane=%s key=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pane" "$key" >>"$log"
  exec "$herdr" pane send-keys "$pane" "alt+$key"
fi

printf '%s move pane=%s key=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pane" "$key" >>"$log"
exec "$herdr" pane focus --direction "$direction" --pane "$pane" >/dev/null
