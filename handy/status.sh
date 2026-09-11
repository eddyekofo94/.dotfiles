#!/bin/sh
set -eu

handy_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
live_file=${HANDY_CONFIG_TARGET:-"$HOME/Library/Application Support/com.pais.handy/settings_store.json"}
tracked_file="$handy_dir/settings_store.json"

"$handy_dir/verify.sh" >/dev/null

if [ ! -f "$live_file" ]; then
  echo "Handy config: live settings missing"
  echo "Next action: $handy_dir/install.sh"
  exit 1
fi

python3 - "$live_file" "$tracked_file" <<'PY'
import json
import pathlib
import sys

live = json.loads(pathlib.Path(sys.argv[1]).read_text())
tracked = json.loads(pathlib.Path(sys.argv[2]).read_text())
providers = live.get("settings", {}).get("post_process_providers", [])
live["settings"]["post_process_api_keys"] = {
    provider["id"]: "" for provider in providers
}

if live == tracked:
    print("Handy config: tracked and live settings match")
else:
    print("Handy config: live settings differ from the tracked sanitized settings")
    print("Next action: quit Handy, then run handy/export.sh or handy/install.sh")
    raise SystemExit(1)
PY
