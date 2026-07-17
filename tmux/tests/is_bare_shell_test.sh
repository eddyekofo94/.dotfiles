#!/usr/bin/env bash

set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HELPER="$ROOT/tmux/scripts/is_bare_shell.sh"
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/tmux-is-bare-shell.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT

cat >"$TEST_TMP/ps" <<'MOCK_PS'
#!/bin/sh
printf '%s\n' "$BARE_SHELL_PS_FIXTURE"
MOCK_PS
chmod +x "$TEST_TMP/ps"

assert_shell() {
    fixture=$1
    if ! BARE_SHELL_PS_BIN="$TEST_TMP/ps" BARE_SHELL_PS_FIXTURE="$fixture" \
        "$HELPER" /dev/ttys-test; then
        printf 'FAIL: expected a bare shell\n' >&2
        exit 1
    fi
}

assert_tui() {
    fixture=$1
    if BARE_SHELL_PS_BIN="$TEST_TMP/ps" BARE_SHELL_PS_FIXTURE="$fixture" \
        "$HELPER" /dev/ttys-test; then
        printf 'FAIL: expected a foreground TUI\n' >&2
        exit 1
    fi
}

assert_shell '100 100 -fish'
assert_shell '100 100 /opt/homebrew/bin/fish'
assert_tui '100 200 fish
200 200 claude
300 200 /opt/homebrew/bin/fish'
assert_tui '100 400 fish
400 400 codex
500 400 node'
assert_tui '100 999 fish
200 999 fish'

printf 'bare-shell detection tests: PASS\n'
