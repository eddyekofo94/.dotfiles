#!/bin/sh
set -eu

session=${1:-main}
case "$session" in
  *[!A-Za-z0-9._-]*|'') echo "unsafe Herdr session name" >&2; exit 64 ;;
esac

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
herdr_bin=${HERDR_BIN_PATH:-"$HOME/.local/bin/herdr"}
plugin_id=prototype.golden-focus
plugin_root="$root/herdr/prototype/golden-focus"

test -x "$herdr_bin"

# A first login starts the server concurrently. Wait only in this short-lived
# background helper; subsequent logins normally find the plugin immediately.
attempt=0
while [ "$attempt" -lt 50 ]; do
  plugin_json=$(
    "$herdr_bin" --session "$session" plugin list \
      --plugin "$plugin_id" --json 2>/dev/null || true
  )
  if printf '%s' "$plugin_json" |
      jq -e --arg id "$plugin_id" \
        '.result.plugins[]? | select(.plugin_id == $id and .enabled == true)' \
        >/dev/null 2>&1; then
    exit 0
  fi

  if "$herdr_bin" --session "$session" plugin link "$plugin_root" \
      >/dev/null 2>&1; then
    plugin_json=$(
      "$herdr_bin" --session "$session" plugin list \
        --plugin "$plugin_id" --json 2>/dev/null || true
    )
    if printf '%s' "$plugin_json" |
        jq -e --arg id "$plugin_id" \
          '.result.plugins[]? | select(.plugin_id == $id and .enabled == true)' \
          >/dev/null 2>&1; then
      exit 0
    fi
  fi

  attempt=$((attempt + 1))
  sleep 0.1
done

echo "could not provision $plugin_id for Herdr session $session" >&2
exit 75
