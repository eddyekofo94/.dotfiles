#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PI_PILOT_REPO=$(CDPATH= cd -- "$pi_dir/.." && pwd)
export PI_PILOT_REPO
# shellcheck disable=SC1091
. "$pi_dir/pilot_paths.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/pi-xcodebuildmcp-fixture.XXXXXX")
simulator_id=
bundle_id=dev.eddy.pi-pilot-fixture
xbm="$pi_dir/xcodebuildmcp"
export PI_PILOT_XCODE_FIXTURE=1
export PI_PILOT_XCODE_FIXTURE_IDLE_TIMEOUT_MS=1000

cleanup() {
  if [ -n "$simulator_id" ]; then
    (cd "$fixture" && "$xbm" simulator stop \
      --simulator-id "$simulator_id" --bundle-id "$bundle_id" \
      --output json >/dev/null 2>&1) || true
  fi
  (cd "$fixture" && "$xbm" daemon stop >/dev/null 2>&1) || true
  rm -rf "$fixture"
}
trap cleanup EXIT HUP INT TERM

run_json() {
  output_file=$1
  shift
  (cd "$fixture" && "$xbm" "$@" --output json) >"$output_file"
  jq -e '.didError == false' "$output_file" >/dev/null
}

(cd "$fixture" && "$xbm" doctor) >"$fixture/doctor.txt" 2>&1
grep -q 'Server Version: 2.7.0' "$fixture/doctor.txt"
grep -q 'Sentry enabled: No' "$fixture/doctor.txt"

run_json "$fixture/scaffold.json" project-scaffolding scaffold-ios \
  --project-name PiPilotFixture --output-path "$fixture" \
  --bundle-identifier "$bundle_id" --display-name PiPilotFixture \
  --deployment-target 18.0
patch -s -V none -d "$fixture" -p1 \
  <"$pi_dir/tests/fixtures/xcodebuildmcp-content-view.patch"
patch -s -V none -d "$fixture" -p1 \
  <"$pi_dir/tests/fixtures/xcodebuildmcp-test-plan.patch"

run_json "$fixture/discovery.json" project-discovery discover-projects \
  --workspace-root "$fixture" --scan-path "$fixture" --max-depth 3
jq -e '.data.projects | length == 1' "$fixture/discovery.json" >/dev/null
jq -e '.data.workspaces | length == 1' "$fixture/discovery.json" >/dev/null

run_json "$fixture/simulators.json" simulator list
simulator_id=$(
  jq -r '
    [.data.simulators[] |
      select(.isAvailable == true and (.runtime | startswith("iOS ")))] |
    (map(select(.state == "Booted")) + .) | first | .simulatorId
  ' "$fixture/simulators.json"
)
[ -n "$simulator_id" ] && [ "$simulator_id" != null ]

workspace="$fixture/PiPilotFixture.xcworkspace"
derived_data="$fixture/DerivedData"
run_json "$fixture/build.json" simulator build \
  --workspace-path "$workspace" --scheme PiPilotFixture \
  --simulator-id "$simulator_id" --derived-data-path "$derived_data"
run_json "$fixture/test.json" simulator test \
  --workspace-path "$workspace" --scheme PiPilotFixture \
  --simulator-id "$simulator_id" --derived-data-path "$derived_data"
jq -e '.data.summary.status == "SUCCEEDED"' "$fixture/test.json" >/dev/null
run_json "$fixture/run.json" simulator build-and-run \
  --workspace-path "$workspace" --scheme PiPilotFixture \
  --simulator-id "$simulator_id" --derived-data-path "$derived_data"

run_json "$fixture/screenshot-before.json" ui-automation screenshot \
  --simulator-id "$simulator_id" --return-format path
before_path=$(jq -r '.data.artifacts.screenshotPath' "$fixture/screenshot-before.json")
[ -s "$before_path" ]
run_json "$fixture/gesture.json" ui-automation gesture \
  --simulator-id "$simulator_id" --preset scroll-up \
  --screen-width 402 --screen-height 874
jq -e '.data.action.gesture == "scroll-up"' "$fixture/gesture.json" >/dev/null
run_json "$fixture/screenshot-after.json" ui-automation screenshot \
  --simulator-id "$simulator_id" --return-format path
after_path=$(jq -r '.data.artifacts.screenshotPath' "$fixture/screenshot-after.json")
[ -s "$after_path" ]
[ "$(shasum -a 256 "$before_path" | awk '{print $1}')" != \
  "$(shasum -a 256 "$after_path" | awk '{print $1}')" ]

(cd "$fixture" && "$xbm" daemon status) >"$fixture/daemon-running.txt"
grep -q 'Daemon Status: Running' "$fixture/daemon-running.txt"
daemon_pid=$(sed -n 's/^  PID: //p' "$fixture/daemon-running.txt")
[ -n "$daemon_pid" ]
idle_wait=0
while kill -0 "$daemon_pid" 2>/dev/null && [ "$idle_wait" -lt 45 ]; do
  sleep 1
  idle_wait=$((idle_wait + 1))
done
if kill -0 "$daemon_pid" 2>/dev/null; then
  echo "pi-pilot: XcodeBuildMCP daemon did not stop after idle timeout" >&2
  exit 1
fi
(cd "$fixture" && "$xbm" daemon status) >"$fixture/daemon-stopped.txt"
grep -q 'Daemon Status: Not running' "$fixture/daemon-stopped.txt"
if find "$pi_pilot_xcode_runtime_dir/run" -type s | grep -q .; then
  echo "pi-pilot: XcodeBuildMCP daemon socket survived cleanup" >&2
  exit 1
fi

printf 'Pi XcodeBuildMCP disposable SwiftUI validation: PASS\n'
