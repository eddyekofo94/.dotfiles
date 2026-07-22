#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_PANE_ID:-${HERDR_TARGET_PANE_ID:-}}
[ -n "$pane" ] || pane=$($herdr pane current --current | jq -er '.result.pane.pane_id')
log=${HERDR_LAYOUT_MENU_LOG:-"$prototype/.runtime/layout-menu.log"}
mkdir -p "$(dirname -- "$log")"
saved_stty=$(stty -g)
trap 'stty "$saved_stty" 2>/dev/null || true' EXIT HUP INT TERM
stty -echo -icanon min 1 time 0

printf 'Herdr layout actions\r\n\r\n'
printf '  e  Equalize current topology\r\n'
printf '  z  Toggle focused-pane zoom\r\n'
printf '  a  Adaptive split\r\n'
printf '  v  Split right\r\n'
printf '  q  Cancel\r\n\r\n'
printf 'Choice: '

choice=$(dd bs=1 count=1 2>/dev/null || true)
case "$choice" in
  e)
    printf 'equalize\t%s\n' "$pane" >>"$log"
    HERDR_TARGET_PANE_ID="$pane" exec "$prototype/equalize_panes.sh"
    ;;
  z)
    printf 'zoom\t%s\n' "$pane" >>"$log"
    exec "$herdr" pane zoom "$pane" --toggle
    ;;
  a)
    printf 'adaptive-split\t%s\n' "$pane" >>"$log"
    HERDR_TARGET_PANE_ID="$pane" exec "$prototype/adaptive_split.sh"
    ;;
  v)
    printf 'split-right\t%s\n' "$pane" >>"$log"
    exec "$herdr" pane split "$pane" --direction right --ratio 0.5 --focus
    ;;
  q|""|"$(printf '\033')")
    printf 'cancel\t%s\n' "$pane" >>"$log"
    exit 0
    ;;
  *)
    printf 'invalid:%s\t%s\n' "$choice" "$pane" >>"$log"
    exit 4
    ;;
esac
