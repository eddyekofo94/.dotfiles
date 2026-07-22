#!/bin/sh
set -eu

# PROTOTYPE ONLY: equalize pane areas in place through Herdr split-ratio APIs.

herdr=${HERDR_BIN_PATH:-herdr}
socket=${HERDR_SOCKET_PATH:?equalize-panes requires the Herdr socket}
pane=${HERDR_TARGET_PANE_ID:-${HERDR_PANE_ID:-}}
if [ -n "$pane" ]; then
  current=$("$herdr" pane current --pane "$pane")
else
  current=$("$herdr" pane current --current)
fi
tab=$(printf '%s\n' "$current" | jq -er '.result.pane.tab_id')

export_id="prototype-layout-export-$$"
exported=$(jq -cn --arg id "$export_id" --arg tab "$tab" \
  '{id:$id,method:"layout.export",params:{tab_id:$tab}}' |
  nc -U -w 2 "$socket")
root=$(printf '%s\n' "$exported" | jq -cer --arg id "$export_id" '
  select(.id == $id and has("result")) | .result.layout.root
')
updates=$(printf '%s\n' "$root" | jq -c '
  def leaves:
    if .type == "pane" then 1
    else ((.first | leaves) + (.second | leaves))
    end;
  def updates($path):
    if .type == "split" then
      (.first | leaves) as $first_leaves |
      (.second | leaves) as $second_leaves |
      [{path:$path,ratio:($first_leaves / ($first_leaves + $second_leaves))}] +
      (.first | updates($path + [false])) +
      (.second | updates($path + [true]))
    else []
    end;
  updates([])[]
')

count=0
printf '%s\n' "$updates" | while IFS= read -r update; do
  [ -n "$update" ] || continue
  count=$((count + 1))
  request_id="prototype-layout-ratio-$$-$count"
  response=$(printf '%s\n' "$update" | jq -c --arg id "$request_id" \
    --arg tab "$tab" \
    '{id:$id,method:"layout.set_split_ratio",params:{tab_id:$tab,path:.path,ratio:.ratio}}' |
    nc -U -w 2 "$socket")
  printf '%s\n' "$response" | jq -e --arg id "$request_id" \
    '.id == $id and has("result")' >/dev/null
done

update_count=$(printf '%s\n' "$updates" | sed '/^$/d' | wc -l | tr -d ' ')
jq -cn --arg tab "$tab" --argjson updates "$update_count" \
  '{result:{tab_id:$tab,updated_splits:$updates,processes_preserved:true}}'
