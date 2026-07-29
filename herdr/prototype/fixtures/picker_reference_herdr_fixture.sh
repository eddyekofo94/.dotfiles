#!/bin/sh
set -eu

state=${HERDR_PICKER_REFERENCE_STATE:?}
log=${HERDR_PICKER_REFERENCE_LOG:?}

case "${1:-} ${2:-}" in
  "workspace list")
    jq -c '{result:{workspaces:.workspaces}}' "$state"
    ;;
  "tab list")
    jq -c '{result:{tabs:.tabs}}' "$state"
    ;;
  "pane list")
    jq -c '{result:{panes:.panes}}' "$state"
    ;;
  "pane current")
    current=${HERDR_FIXTURE_CURRENT_PANE:-p1}
    jq -cer --arg pane "$current" \
      '{result:{pane:(.panes[] | select(.pane_id == $pane))}}' "$state"
    ;;
  "pane read")
    jq -c '{result:{read:{text:.read_text}}}' "$state"
    ;;
  "pane close")
    id=${3:?}
    tmp="$state.tmp"
    jq --arg id "$id" '.panes |= map(select(.pane_id != $id))' \
      "$state" >"$tmp"
    mv "$tmp" "$state"
    printf 'pane\t%s\n' "$id" >>"$log"
    ;;
  "tab close")
    id=${3:?}
    tmp="$state.tmp"
    jq --arg id "$id" '
      .tabs |= map(select(.tab_id != $id)) |
      .panes |= map(select(.tab_id != $id))
    ' "$state" >"$tmp"
    mv "$tmp" "$state"
    printf 'tab\t%s\n' "$id" >>"$log"
    ;;
  "workspace close")
    id=${3:?}
    tmp="$state.tmp"
    jq --arg id "$id" '
      .workspaces |= map(select(.workspace_id != $id)) |
      .tabs |= map(select(.workspace_id != $id)) |
      .panes |= map(select(.workspace_id != $id))
    ' "$state" >"$tmp"
    mv "$tmp" "$state"
    printf 'workspace\t%s\n' "$id" >>"$log"
    ;;
  *)
    printf 'unexpected Herdr fixture call: %s\n' "$*" >&2
    exit 64
    ;;
esac
