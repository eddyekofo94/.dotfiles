#!/bin/sh
set -eu

# PROTOTYPE ONLY: require an identical second press before closing other tabs.

herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_PANE_ID:-}
prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state_dir=${HERDR_TAB_CLOSE_STATE_DIR:-"$prototype/.runtime/tab-close-confirm"}
session=${HERDR_SESSION:?close-other-tabs requires a Herdr session identity}
socket=${HERDR_SOCKET_PATH:?close-other-tabs requires a Herdr socket identity}
session_key=$(printf '%s' "$session" | tr -c '[:alnum:]_.-' '_')
socket_key=$(printf '%s' "$socket" | shasum -a 256 | awk '{print substr($1, 1, 16)}')
state="$state_dir/$session_key-$socket_key.pending"
window=5

if [ -n "$pane" ]; then
  current_pane=$("$herdr" pane current --pane "$pane")
else
  current_pane=$("$herdr" pane current --current)
fi
current=$(printf '%s\n' "$current_pane" | jq -er '.result.pane.tab_id')
tabs=$("$herdr" tab list)
workspace=$(printf '%s\n' "$tabs" | jq -er --arg tab "$current" \
  '.result.tabs[] | select(.tab_id == $tab).workspace_id')
targets=$(printf '%s\n' "$tabs" | jq -r --arg workspace "$workspace" \
  --arg current "$current" \
  '.result.tabs[] | select(.workspace_id == $workspace and .tab_id != $current) | .tab_id' |
  sort)

if [ -z "$targets" ]; then
  echo "close-other-tabs: no other tabs in the active workspace" >&2
  exit 4
fi

fingerprint=$(printf '%s\n%s\n' "$current" "$targets" | shasum -a 256 | awk '{print $1}')
now=$(date +%s)
mkdir -p "$state_dir"

if [ -f "$state" ]; then
  IFS=' ' read -r previous_time previous_fingerprint <"$state" || true
  age=$((now - ${previous_time:-0}))
  if [ "${previous_fingerprint:-}" = "$fingerprint" ] &&
     [ "$age" -ge 0 ] && [ "$age" -le "$window" ]; then
    rm -f "$state"
    printf '%s\n' "$targets" | while IFS= read -r tab; do
      [ -n "$tab" ] && "$herdr" tab close "$tab" >/dev/null
    done
    printf 'close-other-tabs: kept %s and closed %s other tab(s)\n' \
      "$current" "$(printf '%s\n' "$targets" | wc -l | tr -d ' ')"
    exit 0
  fi
fi

printf '%s %s\n' "$now" "$fingerprint" >"$state"
"$herdr" notification show "Close OTHER tabs? Press Alt+Ctrl+x again within 5s" \
  --body "keeps the current tab" \
  --sound none >/dev/null 2>&1 || true
echo "close-other-tabs: press again within five seconds to confirm" >&2
exit 75
