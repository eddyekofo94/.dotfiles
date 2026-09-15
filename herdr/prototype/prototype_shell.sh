#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
user_config_home=${HERDR_PROTOTYPE_USER_CONFIG_HOME:-"$HOME/.config"}
fish_bin=$(command -v fish)

# The Herdr server needs its isolated XDG_CONFIG_HOME, but pane shells need the
# user's real Fish config. Suppress production tmux auto-attach only while Fish
# reads config.fish, then remove the guard before the prompt and child apps run.
export XDG_CONFIG_HOME="$user_config_home"
export TMUX=HERDR_PROTOTYPE_STARTUP_GUARD
# Agent runners may set NO_COLOR for their own logs, and a Ghostty launched from
# one passes it to the server. Panes must never inherit that policy.
unset NO_COLOR
exec "$fish_bin" --init-command \
  "set -e TMUX; source '$prototype/herdr_nav.fish'"
