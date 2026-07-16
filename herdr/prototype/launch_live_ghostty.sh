#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Restore the first trial's near-working input path: Ghostty's normal
# Option-as-Alt encoding reaches the pane application unchanged.
exec /usr/bin/open -na Ghostty --args \
  "--macos-option-as-alt=left" \
  -e "$prototype/live_ghostty.sh"
