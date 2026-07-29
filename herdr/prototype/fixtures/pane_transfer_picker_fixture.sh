#!/bin/sh
set -eu

if [ "${HERDR_TRANSFER_CANCEL:-0}" = 1 ]; then
  cat >/dev/null
  exit 130
fi

if [ -n "${HERDR_TRANSFER_RAW_SELECTION:-}" ]; then
  cat >/dev/null
  printf '%s\n' "$HERDR_TRANSFER_RAW_SELECTION"
  exit 0
fi

mode=${HERDR_TRANSFER_MODE:?fixture requires HERDR_TRANSFER_MODE}
source=${HERDR_TRANSFER_SOURCE:?fixture requires HERDR_TRANSFER_SOURCE}
target=${HERDR_TRANSFER_TARGET:?fixture requires HERDR_TRANSFER_TARGET}
selection=$(awk -F '\t' -v mode="$mode" -v source="$source" -v target="$target" '
  $1 == mode && $2 == source && $3 == target { print; found = 1; exit }
  END { if (!found) exit 1 }
')

if [ -n "${HERDR_TRANSFER_CLOSE_BEFORE_OUTPUT:-}" ]; then
  "$HERDR_BIN_PATH" --session "$HERDR_SESSION" pane close \
    "$HERDR_TRANSFER_CLOSE_BEFORE_OUTPUT" >/dev/null
fi
printf '%s\n' "$selection"
