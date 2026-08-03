#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/pi-verification-concurrency.XXXXXX")
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT HUP INT TERM

PI_PILOT_EVIDENCE_DIR="$fixture/evidence-a" \
  "$pi_dir/validate_sessions.sh" >"$fixture/a.log" 2>&1 &
pid_a=$!
PI_PILOT_EVIDENCE_DIR="$fixture/evidence-b" \
  "$pi_dir/validate_sessions.sh" >"$fixture/b.log" 2>&1 &
pid_b=$!

status=0
wait "$pid_a" || status=1
wait "$pid_b" || status=1
if [ "$status" -ne 0 ]; then
  cat "$fixture/a.log" "$fixture/b.log" >&2
  exit 1
fi

jq -e '.status == "PASS"' \
  "$fixture/evidence-a/session-validation.json" >/dev/null
jq -e '.status == "PASS"' \
  "$fixture/evidence-b/session-validation.json" >/dev/null

echo 'Pi concurrent verification state: PASS'
