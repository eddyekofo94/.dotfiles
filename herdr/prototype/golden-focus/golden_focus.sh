#!/bin/sh
set -eu

herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_PANE_ID:?golden focus requires a Herdr pane}
state_dir=${HERDR_PLUGIN_STATE_DIR:?golden focus requires plugin state}
disabled="$state_dir/disabled"
log="$state_dir/last-state.log"
target=0.62

mkdir -p "$state_dir"

case "${HERDR_PLUGIN_ACTION_ID:-}" in
  toggle|prototype.golden-focus.toggle)
    if [ -e "$disabled" ]; then
      rm -f "$disabled"
    else
      : >"$disabled"
      target=0.50
    fi
    ;;
  *)
    if [ -e "$disabled" ]; then
      exit 0
    fi
    ;;
esac

layout=$($herdr pane layout --pane "$pane")
snapshot=$(printf '%s\n' "$layout" | jq -c '.result.layout')

printf 'event=%s action=%s pane=%s target=%s\nbefore=%s\n' \
  "${HERDR_PLUGIN_EVENT:-manual}" "${HERDR_PLUGIN_ACTION_ID:-event}" \
  "$pane" "$target" "$snapshot" >"$log"

# This acceptance layout has one root left/right split and one nested
# top/bottom split. Set each split containing the focused pane so its child is
# target-sized. Direction right/down increases a split ratio; left/up lowers it.
printf '%s\n' "$snapshot" | jq -r --arg pane "$pane" --argjson target "$target" '
  . as $layout
  | ($layout.panes[] | select(.pane_id == $pane).rect) as $pane_rect
  | $layout.splits[]
  | select(
      $pane_rect.x >= .rect.x and $pane_rect.y >= .rect.y and
      ($pane_rect.x + $pane_rect.width) <= (.rect.x + .rect.width) and
      ($pane_rect.y + $pane_rect.height) <= (.rect.y + .rect.height)
    )
  | if .direction == "right" then
      ["horizontal", .ratio,
       (if $pane_rect.x == .rect.x then $target else (1 - $target) end)]
    else
      ["vertical", .ratio,
       (if $pane_rect.y == .rect.y then $target else (1 - $target) end)]
    end
  | @tsv
' | while IFS="$(printf '\t')" read -r axis current desired; do
  amount=$(awk -v current="$current" -v desired="$desired" 'BEGIN {
    delta = desired - current
    if (delta < 0) delta = -delta
    printf "%.6f", delta
  }')
  if awk -v amount="$amount" 'BEGIN { exit !(amount >= 0.005) }'; then
    if awk -v current="$current" -v desired="$desired" 'BEGIN { exit !(desired > current) }'; then
      if [ "$axis" = horizontal ]; then direction=right; else direction=down; fi
    else
      if [ "$axis" = horizontal ]; then direction=left; else direction=up; fi
    fi
    "$herdr" pane resize --pane "$pane" --direction "$direction" \
      --amount "$amount" >/dev/null
  fi
done

after=$($herdr pane layout --pane "$pane" | jq -c '.result.layout')
printf 'after=%s\n' "$after" >>"$log"
