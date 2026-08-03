#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
export PI_PILOT_FIXTURE=1
cd "$root"
exec "$root/pi/pilot.sh" --offline --session-id pi-herdr-original \
  --name pi-herdr-original \
  --extension "$root/pi/tests/mock_provider.ts" \
  --model eddy-fixture/fixture
