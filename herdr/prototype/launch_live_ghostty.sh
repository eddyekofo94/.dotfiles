#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Ghostty normally encodes Option as a conventional Alt/ESC prefix. Herdr's
# direct custom-command matcher does not see that physical path reliably when
# Neovim enables enhanced keyboard reporting. Translate only this scratch
# window's physical Alt chords to otherwise-unused Ctrl-Alt CSI-u chords.
exec /usr/bin/open -na Ghostty --args \
  "--keybind=alt+h=csi:104;7u" \
  "--keybind=alt+j=csi:106;7u" \
  "--keybind=alt+k=csi:107;7u" \
  "--keybind=alt+l=csi:108;7u" \
  -e "$prototype/live_ghostty.sh"
