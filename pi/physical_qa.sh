#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$pi_dir/.." && pwd)
qa_root="$pi_dir/.runtime/physical-qa"

export PI_PILOT_FIXTURE=1
export PI_PILOT_DATA_DIR="$qa_root/data"
export PI_PILOT_STATE_DIR="$qa_root/state"

scenario=${1:-normal}
case "$scenario" in
  normal) ;;
  context-69|context-70|context-84|context-85)
    export PI_PILOT_CONTEXT_PERCENT=${scenario#context-}
    ;;
  weekly-21|weekly-20|weekly-11|weekly-10)
    export PI_CODEX_WEEKLY_LEFT=${scenario#weekly-}
    ;;
  *)
    echo 'usage: physical_qa.sh [normal|context-69|context-70|context-84|context-85|weekly-21|weekly-20|weekly-11|weekly-10]' >&2
    exit 2
    ;;
esac

"$pi_dir/install.sh" >/dev/null
cd "$root"
exec "$pi_dir/pilot.sh" \
  --offline \
  --session-id pi-session-info-physical-qa \
  --name pi-session-info-physical-qa \
  --extension "$pi_dir/tests/mock_provider.ts" \
  --model eddy-fixture/fixture
