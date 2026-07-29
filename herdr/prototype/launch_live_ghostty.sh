#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Agent runners may set NO_COLOR for their own logs. Do not leak that policy
# into the real Ghostty/Fish visual trial.
unset NO_COLOR

# Restore the first trial's near-working input path: Ghostty's normal
# Option-as-Alt encoding reaches the pane application unchanged.
exec /usr/bin/open -na Ghostty --args \
  "--macos-option-as-alt=left" \
  -e "$prototype/live_ghostty.sh"
