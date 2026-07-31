#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
action=${1:?shell action required}
pane=${HERDR_TARGET_PANE_ID:-$("$prototype/focused_pane.sh")}

case "$action" in
split-right)
  exec $herdr pane split "$pane" --direction right --ratio 0.5 --focus
  ;;
split-down)
  exec $herdr pane split "$pane" --direction down --ratio 0.5 --focus
  ;;
split-adaptive)
  HERDR_TARGET_PANE_ID=$pane exec "$prototype/adaptive_split.sh"
  ;;
close-pane)
  HERDR_TARGET_PANE_ID=$pane exec "$prototype/smart_close.sh"
  ;;
close-other-panes)
  HERDR_TARGET_PANE_ID=$pane exec "$prototype/close_other_panes.sh"
  ;;
equalize-panes)
  HERDR_TARGET_PANE_ID=$pane exec "$prototype/equalize_panes.sh"
  ;;
close-tab)
  tab=$($herdr pane current --pane "$pane" | jq -er '.result.pane.tab_id')
  exec $herdr tab close "$tab"
  ;;
close-other-tabs)
  HERDR_PANE_ID=$pane exec "$prototype/close_other_tabs.sh"
  ;;
zoom)
  exec $herdr pane zoom "$pane" --toggle
  ;;
*)
  printf 'unknown prototype shell action: %s\n' "$action" >&2
  exit 2
  ;;
esac
