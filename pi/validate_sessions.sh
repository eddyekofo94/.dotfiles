#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$pi_dir/.runtime"
runtime=$(mktemp -d "$pi_dir/.runtime/sessions.XXXXXX")
cleanup() { rm -rf "$runtime"; }
trap cleanup EXIT HUP INT TERM
export PI_PILOT_STATE_DIR="$runtime/state"
"$pi_dir/install.sh" >/dev/null

# Use a disposable low threshold so the validator can exercise real compaction
# mechanics without changing the pilot's production settings.
jq '.compaction.reserveTokens = 20000 | .compaction.keepRecentTokens = 1' \
  "$pi_dir/settings.json" >"$runtime/settings.json"
ln -sfn "$runtime/settings.json" "$PI_PILOT_STATE_DIR/config/settings.json"

python3 "$pi_dir/tests/session_validation.py"
