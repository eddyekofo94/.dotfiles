#!/bin/sh
set -eu

session=${1:-main}
case "$session" in
  *[!A-Za-z0-9._-]*|'') echo "unsafe Herdr session name" >&2; exit 64 ;;
esac

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
herdr_bin=${HERDR_BIN_PATH:-"$HOME/.local/bin/herdr"}

# Every plugin config.toml binds a key to, as `<id>:<prototype directory>`. A
# missing one is silent: the binding still parses, and pressing it does nothing.
plugins="prototype.golden-focus:golden-focus prototype.tab-history:tab-history"

test -x "$herdr_bin"

enabled() {
  "$herdr_bin" --session "$session" plugin list \
    --plugin "$1" --json 2>/dev/null |
    jq -e --arg id "$1" \
      '.result.plugins[]? | select(.plugin_id == $id and .enabled == true)' \
      >/dev/null 2>&1
}

provision() {
  plugin_id=$1
  plugin_root="$root/herdr/prototype/$2"

  # A first login starts the server concurrently. Wait only in this short-lived
  # background helper; subsequent logins normally find the plugin immediately.
  attempt=0
  while [ "$attempt" -lt 50 ]; do
    enabled "$plugin_id" && return 0

    if "$herdr_bin" --session "$session" plugin link "$plugin_root" \
        >/dev/null 2>&1; then
      enabled "$plugin_id" && return 0
    fi

    attempt=$((attempt + 1))
    sleep 0.1
  done

  echo "could not provision $plugin_id for Herdr session $session" >&2
  return 75
}

status=0
for entry in $plugins; do
  # Provision the rest even after one fails: reporting every missing plugin at
  # once beats one login per discovery.
  provision "${entry%%:*}" "${entry#*:}" || status=75
done

exit "$status"
