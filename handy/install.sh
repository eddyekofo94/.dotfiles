#!/bin/sh
set -eu

handy_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$handy_dir/.." && pwd)
source_file="$handy_dir/settings_store.json"
target_file=${HANDY_CONFIG_TARGET:-"$HOME/Library/Application Support/com.pais.handy/settings_store.json"}
backup_dir=${HANDY_BACKUP_DIR:-"$repo_dir/.backups/handy"}

[ -f "$source_file" ] || {
  echo "handy: tracked settings are missing: $source_file" >&2
  exit 1
}

if [ -z "${HANDY_CONFIG_TARGET:-}" ] && pgrep -f '^/Applications/Handy.app/Contents/MacOS/handy$' >/dev/null 2>&1; then
  echo "handy: quit Handy before installing settings" >&2
  exit 1
fi

mkdir -p "$(dirname -- "$target_file")" "$backup_dir"
if [ -f "$target_file" ]; then
  backup="$backup_dir/settings_store.pre-install.$(date +%Y%m%d-%H%M%S).json"
  cp -p "$target_file" "$backup"
  echo "handy: backed up live settings to $backup"
fi

python3 - "$source_file" "$target_file" <<'PY'
import json
import os
import pathlib
import sys
import tempfile

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
tracked = json.loads(source.read_text())

# API credentials are machine-local. Preserve existing values without ever
# copying them into the repository settings file.
if target.is_file():
    live = json.loads(target.read_text())
    live_keys = live.get("settings", {}).get("post_process_api_keys", {})
    tracked_keys = tracked["settings"].get("post_process_api_keys", {})
    tracked["settings"]["post_process_api_keys"] = {
        provider_id: live_keys.get(provider_id, value)
        for provider_id, value in tracked_keys.items()
    }

fd, temporary_name = tempfile.mkstemp(prefix=".settings_store.", suffix=".json", dir=target.parent)
try:
    with os.fdopen(fd, "w") as temporary:
        json.dump(tracked, temporary, indent=2, ensure_ascii=False)
        temporary.write("\n")
    os.chmod(temporary_name, 0o600)
    os.replace(temporary_name, target)
finally:
    if os.path.exists(temporary_name):
        os.unlink(temporary_name)
PY

"$handy_dir/verify.sh"
echo "handy config installation: PASS"
