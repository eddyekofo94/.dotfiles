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

"$prototype/prepare_live_trial.sh" &
exec "$prototype/run.sh" --border focused
