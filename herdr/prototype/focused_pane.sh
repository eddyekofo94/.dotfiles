#!/bin/sh
set -eu

herdr=${HERDR_BIN_PATH:-herdr}

if [ -n "${HERDR_PANE_ID:-}" ]; then
  printf '%s\n' "$HERDR_PANE_ID"
  exit 0
fi

"$herdr" pane current --current | jq -er '.result.pane.pane_id'
