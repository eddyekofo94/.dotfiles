#!/bin/sh
# herdr-master-socket: print the socket of the live herdr session whose tab is labelled
# master (`N ✻ master`), or nothing when no master sits. Master plan B5: the fills
# open new tabs there, so a build landing in a detached window (window-113, 2026-11-12)
# never opens its successor where Eddy cannot see it.
herdr_bin=${HERDR_BIN_PATH:-herdr}
command -v "$herdr_bin" >/dev/null 2>&1 || herdr_bin="$HOME/.local/bin/herdr"
is_master='(.label // "") | sub("^\\[?[0-9]+\\]? *"; "") | ltrimstr("✻ ") | ltrimstr("✼ ") | ltrimstr("✽ ") == "master"'
for sock in "${HERDR_SESSIONS_DIR:-$HOME/.config/herdr/sessions}"/*/herdr.sock; do
  [ -S "$sock" ] || continue
  if HERDR_SOCKET_PATH="$sock" perl -e 'alarm 5; exec @ARGV' "$herdr_bin" tab list 2>/dev/null |
      jq -e ".result.tabs[]? | select($is_master)" >/dev/null 2>&1; then
    printf '%s\n' "$sock"
    exit 0
  fi
done
exit 0
