#!/bin/sh
set -eu

target=${1:?preview path required}
cols=${FZF_PREVIEW_COLUMNS:-60}
rows=${FZF_PREVIEW_LINES:-24}

exec chafa -f symbols --colors full --animate=off --polite=on \
  --size="${cols}x${rows}" -- "$target"
