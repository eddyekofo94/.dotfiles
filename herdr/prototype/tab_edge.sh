#!/bin/sh
set -eu

edge=${1:?expected first or last}
case "$edge" in
  first|last) ;;
  *) echo "tab-edge: expected first or last" >&2; exit 64 ;;
esac

herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_TARGET_PANE_ID:-${HERDR_PANE_ID:-}}
if [ -n "$pane" ]; then
  current=$("$herdr" pane current --pane "$pane")
else
  current=$("$herdr" pane current --current)
fi
workspace=$(printf '%s\n' "$current" | jq -er '
  .result.pane.workspace_id |
  select(type == "string" and length > 0)
')
attempt=0
while [ "$attempt" -lt 3 ]; do
  attempt=$((attempt + 1))
  tabs=$("$herdr" tab list --workspace "$workspace")
  printf '%s\n' "$tabs" | jq -e --arg workspace "$workspace" '
    .result.tabs | type == "array" and length > 0 and
    all(.[];
      (.tab_id | type == "string" and length > 0) and
      .workspace_id == $workspace
    )
  ' >/dev/null
  case "$edge" in
    first) target=$(printf '%s\n' "$tabs" | jq -er '.result.tabs[0].tab_id') ;;
    last) target=$(printf '%s\n' "$tabs" | jq -er '.result.tabs[-1].tab_id') ;;
  esac
  "$herdr" tab focus "$target" >/dev/null
  after=$("$herdr" tab list --workspace "$workspace")
  if printf '%s\n' "$after" | jq -e --arg target "$target" --arg edge "$edge" '
    (.result.tabs | if $edge == "first" then .[0] else .[-1] end) as $edge_tab |
    $edge_tab.tab_id == $target and $edge_tab.focused == true
  ' >/dev/null; then
    jq -cn --arg edge "$edge" --arg workspace "$workspace" --arg tab "$target" \
      --argjson attempts "$attempt" \
      '{result:{edge:$edge,workspace_id:$workspace,tab_id:$tab,attempts:$attempts}}'
    exit 0
  fi
done
echo "tab-edge: tab order kept changing; no stable edge could be focused" >&2
exit 4
