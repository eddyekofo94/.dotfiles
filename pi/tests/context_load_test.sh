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

# macOS script(1) supplies a real controlling terminal. Expand loaded
# resources, then exit from the still-empty editor. No prompt is submitted.
(
  sleep 5
  printf '\017'
  sleep 5
  printf '\004'
) | script -q /dev/null "$pilot" --no-session >"$capture"

displayed=$expected
case "$displayed" in
  "$HOME"/*) displayed="~/${displayed#"$HOME"/}" ;;
esac
grep -F "$displayed" "$capture" >/dev/null || {
  echo "Pi did not report expected context: $expected" >&2
  exit 1
}

echo 'Pi no-provider context load: PASS'
