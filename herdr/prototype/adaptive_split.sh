#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_TARGET_PANE_ID:-$("$prototype/focused_pane.sh")}
layout=$($herdr pane layout --pane "$pane")

dimensions=$(printf '%s\n' "$layout" | jq -er --arg pane "$pane" '
  .result.layout.panes[] | select(.pane_id == $pane) | [.rect.width, .rect.height] | @tsv
')
IFS="$(printf '\t')" read -r width height <<EOF
$dimensions
EOF

# Match the approved focus.split_nicely policy: wide panes split right;
# squarer/taller panes split down. Terminal-cell aspect makes phi a useful,
# deterministic threshold without depending on Ghostty pixel measurements.
direction=$(awk -v width="$width" -v height="$height" \
  'BEGIN { print (width > height * 1.61803398875) ? "right" : "down" }')

$herdr pane split "$pane" --direction "$direction" --ratio 0.5 --focus
