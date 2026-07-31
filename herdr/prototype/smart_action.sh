#!/bin/sh
set -eu

# Global tmux-style action dispatch. Herdr intercepts an Alt chord before any app;
# if the focused pane runs nvim/vim/ssh we forward the chord so the editor keeps
# its own mapping, otherwise we perform the Herdr action. Mirrors tmux bindings
# like `bind -n M-n if "$fwd" 'send M-n' 'split-window'`.

fwd_key=${1:?alt key suffix required (e.g. v, n, shift+x)}
action=${2:?herdr action required}
prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
log=${HERDR_NAV_LOG:-/tmp/herdr-prototype-nav.log}

pane=${HERDR_TARGET_PANE_ID:-$("$prototype/focused_pane.sh")}
process_info=$("$herdr" pane process-info --pane "$pane" 2>/dev/null || echo '{}')

if printf '%s\n' "$process_info" | jq -e '
  .result.process_info.foreground_processes[]?
  | select(
      (.name    // "" | test("^(n?vim|vimdiff|view)$")) or
      (.argv0   // "" | test("(^|/)(n?vim|vimdiff|view|ssh)$")) or
      (.cmdline // "" | test("(^|/)(n?vim|vimdiff|view|ssh)( |$)"))
    )
' >/dev/null 2>&1; then
  printf '%s vim-forward pane=%s key=alt+%s action=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pane" "$fwd_key" "$action" >>"$log"
  exec "$herdr" pane send-keys "$pane" "alt+$fwd_key"
fi

printf '%s action pane=%s key=alt+%s action=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pane" "$fwd_key" "$action" >>"$log"
HERDR_TARGET_PANE_ID=$pane exec "$prototype/shell_action.sh" "$action"
