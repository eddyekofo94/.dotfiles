#!/bin/sh
set -eu

# PROTOTYPE ONLY: reorder the active tab through Herdr's supported socket API.

direction=${1:?expected left or right}
prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
log=${HERDR_TAB_MOVE_LOG:-"$prototype/.runtime/tab-move.log"}
printf 'start direction=%s pane=%s tab=%s socket=%s\n' "$direction" \
  "${HERDR_PANE_ID:-}" "${HERDR_TAB_ID:-}" "${HERDR_SOCKET_PATH:-}" >>"$log"
case "$direction" in
  left) delta=-1 ;;
  # tab.move uses a pre-removal insertion boundary. Moving one slot right
  # therefore inserts after the next tab, two boundaries from the source.
  right) delta=2 ;;
  *) echo "tab-move: expected left or right" >&2; exit 2 ;;
esac

herdr=${HERDR_BIN_PATH:-herdr}
socket=${HERDR_SOCKET_PATH:?tab-move requires the Herdr socket}
pane=${HERDR_PANE_ID:-}
if [ -n "$pane" ]; then
  current=$("$herdr" pane current --pane "$pane")
else
  current=$("$herdr" pane current --current)
fi
tab=$(printf '%s\n' "$current" | jq -er '.result.pane.tab_id')
tabs=$("$herdr" tab list)
workspace=$(printf '%s\n' "$tabs" | jq -er --arg tab "$tab" \
  '.result.tabs[] | select(.tab_id == $tab).workspace_id')
ordered=$(printf '%s\n' "$tabs" | jq -c --arg workspace "$workspace" \
  '[.result.tabs[] | select(.workspace_id == $workspace)]')
index=$(printf '%s\n' "$ordered" | jq -er --arg tab "$tab" \
  'map(.tab_id) | index($tab)')
count=$(printf '%s\n' "$ordered" | jq 'length')
target=$((index + delta))

if [ "$target" -lt 0 ] || [ "$target" -gt "$count" ] ||
   { [ "$direction" = right ] && [ "$index" -eq $((count - 1)) ]; }; then
  echo "tab-move: active tab is already at the $direction boundary" >&2
  exit 4
fi

request_id="prototype-tab-move-$$"
response=$(jq -cn --arg id "$request_id" --arg tab "$tab" \
  --argjson index "$target" \
  '{id:$id,method:"tab.move",params:{tab_id:$tab,insert_index:$index}}' |
  nc -U -w 2 "$socket")
printf 'request tab=%s index=%s response=%s\n' "$tab" "$target" "$response" >>"$log"

printf '%s\n' "$response" | jq -e --arg id "$request_id" \
  '.id == $id and has("result")' >/dev/null
printf '%s\n' "$response"
