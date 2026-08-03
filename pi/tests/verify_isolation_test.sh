#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verify="$pi_dir/verify.sh"

grep -Fq 'runtime=$(mktemp -d "$pi_dir/.runtime/verify.XXXXXX")' "$verify"
! grep -Fq 'runtime="$pi_dir/.runtime/verify"' "$verify"
grep -Fq 'trap cleanup EXIT HUP INT TERM' "$verify"
grep -Fq 'runtime=$(mktemp -d "$pi_dir/.runtime/sessions.XXXXXX")' \
  "$pi_dir/validate_sessions.sh"
grep -Fq 'runtime=$(mktemp -d "$pi_dir/.runtime/h.XXXXXX")' \
  "$pi_dir/validate_herdr.sh"
! grep -Fq 'runtime="$pi_dir/.runtime/sessions"' "$pi_dir/validate_sessions.sh"
! grep -Fq 'runtime="$pi_dir/.runtime/herdr"' "$pi_dir/validate_herdr.sh"

export_line=$(grep -nF 'export PI_PILOT_STATE_DIR="$runtime/pilot-state"' \
  "$verify" | cut -d: -f1)
source_line=$(grep -nF '. "$pi_dir/pilot_paths.sh"' \
  "$verify" | cut -d: -f1)
install_line=$(grep -nF '"$pi_dir/install.sh" >/dev/null' \
  "$verify" | head -n 1 | cut -d: -f1)

[ -n "$export_line" ]
[ -n "$source_line" ]
[ -n "$install_line" ]
[ "$export_line" -lt "$source_line" ]
[ "$source_line" -lt "$install_line" ]
[ "$(grep -c '^export PI_PILOT_STATE_DIR=' "$verify")" -eq 1 ]
! grep -Eq '^unset PI_PILOT_STATE_DIR' "$verify"
grep -Fq 'LC_ALL=en_US.UTF-8 "$pi_dir/pilot.sh" --version' "$verify"
grep -Fq 'LC_ALL=C sort -z' "$pi_dir/pilot_paths.sh"

mkdir -p "$pi_dir/.runtime"
runtime_a=$(mktemp -d "$pi_dir/.runtime/verify-test.XXXXXX")
runtime_b=$(mktemp -d "$pi_dir/.runtime/verify-test.XXXXXX")
cleanup() { rm -rf "$runtime_a" "$runtime_b"; }
trap cleanup EXIT HUP INT TERM
[ "$runtime_a" != "$runtime_b" ]
: >"$runtime_a/owner-a"
: >"$runtime_b/owner-b"
rm -rf "$runtime_a"
test -f "$runtime_b/owner-b"

printf 'Pi verification isolation: PASS\n'
