#!/bin/sh
set -eu

herdr=${HERDR_BIN_PATH:-herdr}
state_dir=${HERDR_PLUGIN_STATE_DIR:?tab history requires plugin state}
current_file="$state_dir/current-tab"
previous_file="$state_dir/previous-tab"
log="$state_dir/history.log"
mkdir -p "$state_dir"

case "${HERDR_PLUGIN_ACTION_ID:-}" in
  last|prototype.tab-history.last)
    current=${HERDR_TAB_ID:?last-tab action requires the active tab}
    [ -f "$previous_file" ] || exit 4
    previous=$(sed -n '1p' "$previous_file")
    [ -n "$previous" ] && [ "$previous" != "$current" ] || exit 4
    "$herdr" tab get "$previous" >/dev/null
    printf 'action current=%s previous=%s\n' "$current" "$previous" >>"$log"
    exec "$herdr" tab focus "$previous"
    ;;
esac

event_json=${HERDR_PLUGIN_EVENT_JSON:-'{}'}
printf 'event_json=%s env_tab=%s\n' "$event_json" "${HERDR_TAB_ID:-}" >>"$log"
event_tab=$(printf '%s\n' "$event_json" |
  jq -er '.tab_id // .tab.tab_id // .data.tab_id // .payload.tab_id // empty')
old=''
if [ -f "$current_file" ]; then
  old=$(sed -n '1p' "$current_file")
fi
if [ -n "$old" ] && [ "$old" != "$event_tab" ]; then
  printf '%s\n' "$old" >"$previous_file"
fi
printf '%s\n' "$event_tab" >"$current_file"
printf 'event current=%s previous=%s\n' "$event_tab" "$old" >>"$log"
