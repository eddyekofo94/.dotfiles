#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
direction=${1:?swap direction required}
pane=${HERDR_TARGET_PANE_ID:-$("$prototype/focused_pane.sh")}

case "$direction" in left|right|up|down) ;; *) exit 2 ;; esac
exec $herdr pane swap --direction "$direction" --pane "$pane"
