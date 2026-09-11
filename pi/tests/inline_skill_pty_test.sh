#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
  echo 'usage: inline_skill_pty_test.sh PILOT STATE_DIR' >&2
  exit 2
}
pilot=$1
state_dir=$2
pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runtime=$(mktemp -d "$pi_dir/.runtime/inline-skill.XXXXXX")
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
  sleep 4
  printf '/todo /bug\r'
  sleep 5
  printf '/eddy-pilot-fixture-show-active-skill\r'
  sleep 3
  printf 'Open the current work and /goals restore its tabs\r'
  sleep 5
  printf '/eddy-pilot-fixture-show-active-skill\r'
  sleep 2
  printf '\004'
  sleep 1
  printf '\004'
) | PI_PILOT_FIXTURE=1 \
  PI_PILOT_DATA_DIR="$data_dir" \
  PI_PILOT_STATE_DIR="$state_dir" \
  script -q /dev/null "$pilot" --no-session --offline \
  --extension "$pi_dir/tests/mock_provider.ts" \
  --model eddy-fixture/fixture \
  >"$runtime/capture"

python3 - "$runtime/capture" <<'PY'
import pathlib
import re
import sys

data = pathlib.Path(sys.argv[1]).read_bytes()
plain = re.sub(
    rb"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))",
    b"",
    data,
)
if b"Pi pilot accepts exactly one skill per prompt" not in plain:
    raise SystemExit(f"Leading alias bypassed multiple-skill rejection\n{plain[-4000:]!r}")
if b"Active fixture skill: No interactive Pi skill recorded" not in plain:
    raise SystemExit(f"Rejected alias changed active-skill state\n{plain[-4000:]!r}")
if b"Active fixture skill: goals" not in plain:
    raise SystemExit(f"Inline /goals did not become active in fresh Pi PTY\n{plain[-3000:]!r}")
if b"Fixture response recorded without a network provider." not in plain:
    raise SystemExit(f"Inline /goals did not complete through fixture provider\n{plain[-3000:]!r}")
PY

echo 'Pi inline workflow skill PTY: PASS'
