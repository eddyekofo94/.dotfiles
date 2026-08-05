#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)

"$prototype/run.sh" --border focused cli server stop >/dev/null 2>&1 || true
rm -rf "$prototype/.runtime/cf/herdr/sessions/trial-focused"
cd "$root"

# This session must be direct. Inheriting either variable would reproduce the
# outer-tmux interception that invalidated the previous Alt-navigation trial.
unset TMUX TMUX_PANE

# `open -na Ghostty -e ...` inherits the environment of the already-running
# Ghostty instance, so a trial launched from inside a Herdr session arrives
# carrying that session's HERDR_* variables. The client then refuses to start
# ("nested herdr is disabled by default") and the window closes before the
# trial is ready. Clearing them here makes the launcher work from any parent.
unset HERDR_ENV HERDR_SESSION HERDR_SOCKET_PATH HERDR_PANE_ID HERDR_TAB_ID \
  HERDR_BIN_PATH

"$prototype/prepare_live_trial.sh" &
exec "$prototype/run.sh" --border focused
