#!/bin/sh
# herdr-master-socket: print the socket of the live herdr session whose tab is labelled
# master (`N ✻ master`), or nothing when no master sits. Master plan B5: the fills
# open new tabs there, so a build landing in a detached window (window-113, 2026-11-12)
# never opens its successor where Eddy cannot see it. `--pane` (B8) prints the socket,
# a tab, and the master tab's root pane id, for wake-master and `ready judge`.
herdr_bin=${HERDR_BIN_PATH:-herdr}
command -v "$herdr_bin" >/dev/null 2>&1 || herdr_bin="$HOME/.local/bin/herdr"
is_master='(.label // "") | sub("^\\[?[0-9]+\\]? *"; "") | ltrimstr("✻ ") | ltrimstr("✼ ") | ltrimstr("✽ ") == "master"'
for sock in "${HERDR_SESSIONS_DIR:-$HOME/.config/herdr/sessions}"/*/herdr.sock; do
  [ -S "$sock" ] || continue
  tab=$(HERDR_SOCKET_PATH="$sock" perl -e 'alarm 5; exec @ARGV' "$herdr_bin" tab list 2>/dev/null |
      jq -r "[.result.tabs[]? | select($is_master)][0].tab_id // empty" 2>/dev/null)
  if [ -n "$tab" ]; then
    if [ "${1:-}" = "--pane" ]; then
      pane=$(HERDR_SOCKET_PATH="$sock" perl -e 'alarm 5; exec @ARGV' "$herdr_bin" pane list 2>/dev/null |
        jq -r --arg t "$tab" '[.result.panes[]? | select(.tab_id == $t)][0].pane_id // empty' 2>/dev/null)
      printf '%s\t%s\n' "$sock" "$pane"
    else
      printf '%s\n' "$sock"
    fi
    exit 0
  fi
done
exit 0
