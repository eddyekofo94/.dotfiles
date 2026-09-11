#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
  echo 'usage: context_load_test.sh PILOT EXPECTED_CONTEXT' >&2
  exit 2
}
pilot=$1
expected=$2
capture=$(mktemp "${TMPDIR:-/tmp}/pi-context-load.XXXXXX")
cleanup() { rm -f "$capture"; }
trap cleanup EXIT HUP INT TERM

# macOS script(1) supplies a real controlling terminal. --verbose uses Pi's
# supported override so this diagnostic can inspect resources while production
# quietStartup remains enabled. No prompt is submitted.
if (
  sleep 5
  printf '\004'
) | script -q /dev/null "$pilot" --verbose --no-session >"$capture"; then
  :
else
  pilot_status=$?
  [ "$pilot_status" -eq 1 ] || exit "$pilot_status"
fi

logical_expected=$expected
expected_dir=$(CDPATH= cd -P -- "$(dirname "$expected")" && pwd)
physical_expected="$expected_dir/$(basename "$expected")"
logical_display=$logical_expected
physical_display=$physical_expected
case $logical_display in
  "$HOME"/*) logical_display="~/${logical_display#"$HOME"/}" ;;
esac
case $physical_display in
  "$HOME"/*) physical_display="~/${physical_display#"$HOME"/}" ;;
esac
python3 - "$capture" \
  "$logical_expected" "$physical_expected" \
  "$logical_display" "$physical_display" <<'PY'
import pathlib
import re
import sys

raw = pathlib.Path(sys.argv[1]).read_bytes()
plain = re.sub(
    rb"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))",
    b"",
    raw,
).decode("utf-8", "replace")
normalized = "".join(plain.split())
expected = ["".join(value.split()) for value in sys.argv[2:]]
if not any(value in normalized for value in expected):
    marker = plain.find("[Context]")
    context = plain[marker : marker + 500] if marker >= 0 else plain[-500:]
    raise SystemExit(
        f"Pi did not report expected context: {sys.argv[2]} "
        f"(physical: {sys.argv[3]})\n{context!r}"
    )
PY

echo 'Pi no-provider context load: PASS'
