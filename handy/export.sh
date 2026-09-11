#!/bin/sh
set -eu

handy_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
live_file=${HANDY_CONFIG_TARGET:-"$HOME/Library/Application Support/com.pais.handy/settings_store.json"}
tracked_file="$handy_dir/settings_store.json"

[ -f "$live_file" ] || {
  echo "handy: live settings are missing: $live_file" >&2
  exit 1
}

if [ -z "${HANDY_CONFIG_TARGET:-}" ] && pgrep -f '^/Applications/Handy.app/Contents/MacOS/handy$' >/dev/null 2>&1; then
  echo "handy: quit Handy before exporting settings" >&2
  exit 1
fi

python3 - "$live_file" "$tracked_file" <<'PY'
import json
import os
import pathlib
import sys
import tempfile

live = pathlib.Path(sys.argv[1])
tracked = pathlib.Path(sys.argv[2])
data = json.loads(live.read_text())
settings = data["settings"]
settings["post_process_api_keys"] = {
    provider["id"]: "" for provider in settings.get("post_process_providers", [])
}

fd, temporary_name = tempfile.mkstemp(prefix=".settings_store.", suffix=".json", dir=tracked.parent)
try:
    with os.fdopen(fd, "w") as temporary:
        json.dump(data, temporary, indent=2, ensure_ascii=False)
        temporary.write("\n")
    os.replace(temporary_name, tracked)
finally:
    if os.path.exists(temporary_name):
        os.unlink(temporary_name)
PY

"$handy_dir/verify.sh"
echo "handy config export: PASS"
