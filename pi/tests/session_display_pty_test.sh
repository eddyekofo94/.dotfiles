#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
  echo 'usage: session_display_pty_test.sh PILOT STATE_DIR' >&2
  exit 2
}
pilot=$1
state_dir=$2
pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runtime=$(mktemp -d "$pi_dir/.runtime/session-display.XXXXXX")
settings="$state_dir/config/settings.json"
original_settings=$(readlink "$settings")
data_dir=${PI_PILOT_DATA_DIR:-"$(dirname "$state_dir")/data"}

cleanup() {
  rm -rf "$runtime"
  rm -f "$settings"
  ln -s "$original_settings" "$settings"
}
trap cleanup EXIT HUP INT TERM

rm "$settings"
jq \
  --arg extension "$pi_dir/extensions/eddy-compat.ts" \
  --arg provider "$pi_dir/tests/mock_provider.ts" '
    .extensions = [$extension, $provider] |
    .defaultProvider = "eddy-fixture" |
    .defaultModel = "fixture"
  ' "$pi_dir/settings.json" >"$runtime/settings.json"
ln -s "$runtime/settings.json" "$settings"

(
  sleep 5
  printf '\004'
  sleep 1
  printf '\004'
) | PI_PILOT_FIXTURE=1 \
  PI_CODEX_WEEKLY_LEFT=72 \
  PI_PILOT_DATA_DIR="$data_dir" \
  PI_PILOT_STATE_DIR="$state_dir" \
  script -q /dev/null "$pilot" --no-session --offline \
  --extension "$pi_dir/tests/mock_provider.ts" \
  --model eddy-fixture/fixture \
  >"$runtime/capture"

expected_session_name=$(node --input-type=module -e '
  import { contextualSessionName } from "./pi/extensions/session-name-core.mjs";
  process.stdout.write(contextualSessionName(process.argv[1]));
' "$(pwd)")

python3 - "$runtime/capture" "$expected_session_name" <<'PY'
import pathlib
import re
import sys

data = pathlib.Path(sys.argv[1]).read_bytes()
expected_session_name = sys.argv[2].encode()
plain = re.sub(
    rb"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))",
    b"",
    data,
)
for preserved in (
    b"fixture",
    b".dotfiles",
    b"weekly 72% left",
):
    if preserved not in plain:
        raise SystemExit(
            f"Pi compact footer missing: {preserved!r}\n{plain[-2000:]!r}"
        )
rendered_session_name = (
    expected_session_name
    if len(expected_session_name) <= 11
    else expected_session_name[:11] + b"..."
)
if rendered_session_name not in plain:
    raise SystemExit(
        f"Pi compact footer missing resolved session name: "
        f"{rendered_session_name!r}\n{plain[-2000:]!r}"
    )
if not re.search(rb"\.dotfiles \xc2\xb7 (?:main|pi-session|p?\.\.\.)", plain):
    raise SystemExit(f"Pi compact footer missing branch/worktree identity\n{plain[-2000:]!r}")
if not re.search(rb"~[0-9]+(?:\.[0-9])?k?/32\.8k \xc2\xb7 [0-9]+%", plain):
    raise SystemExit(f"Pi compact footer missing startup token estimate\n{plain[-2000:]!r}")
for startup_heading in (b"[Context]", b"[Skills]", b"[Extensions]", b"[Themes]"):
    if startup_heading in plain:
        raise SystemExit(f"Pi quiet startup rendered inventory: {startup_heading!r}")
if b"0.0%/33k" in plain:
    raise SystemExit("Pi rendered the native multi-line footer")
for rgb in (
    b"\x1b[38;2;127;132;156m",
    b"\x1b[38;2;203;166;247m",
    b"\x1b[38;2;166;227;161m",
):
    if rgb not in data:
        raise SystemExit(f"Pi compact footer missing ANSI colour: {rgb!r}")
PY

echo 'Pi compact footer PTY: PASS'
