#!/bin/sh
set -eu

# Open tmux in a fresh top-level Ghostty login. Never nest tmux inside Herdr.
ghostty_open=${HERDR_GHOSTTY_OPEN:-/usr/bin/open}
fallback_fish=${HERDR_FALLBACK_FISH:-/opt/homebrew/bin/fish}

exec "$ghostty_open" -na Ghostty --args -e \
  /usr/bin/env -u TMUX -u HERDR_ENV -u HERDR_PANE_ID \
  HERDR_NO_AUTO_ATTACH=1 "$fallback_fish" --login
