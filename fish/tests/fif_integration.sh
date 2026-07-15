#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/fif-integration.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

printf '%s\n' 'fixture' >"$temp_dir/fixture.txt"
export PATH="$package_dir/tests/fixtures/bin:$PATH"
export FIF_RG_LOG="$temp_dir/rg.log"
export FIF_FUNCTIONS_DIR="$package_dir/functions"
export TMPDIR="$temp_dir/"

run_fif() {
    fish --no-config --command \
        "set -g fish_function_path '$package_dir/functions' \$fish_function_path; fif \$argv" \
        -- "$@"
}

assert_no_search() {
    description=$1
    if test -s "$FIF_RG_LOG"; then
        echo "fif integration: FAIL: $description launched ripgrep" >&2
        exit 1
    fi
}

assert_search() {
    description=$1
    if ! test -s "$FIF_RG_LOG"; then
        echo "fif integration: FAIL: $description did not launch ripgrep" >&2
        exit 1
    fi
}

: >"$FIF_RG_LOG"
FIF_FZF_EVENT=start FIF_FZF_QUERY='' run_fif .
assert_no_search 'an empty query'

: >"$FIF_RG_LOG"
FIF_FZF_EVENT=start FIF_FZF_QUERY=a run_fif . a
assert_no_search 'an initial one-character query'

: >"$FIF_RG_LOG"
FIF_FZF_EVENT=start FIF_FZF_QUERY=ab run_fif . ab
assert_search 'an initial two-character query'

: >"$FIF_RG_LOG"
FIF_FZF_EVENT=change FIF_FZF_QUERY=a run_fif .
assert_no_search 'a one-character query'

: >"$FIF_RG_LOG"
FIF_FZF_EVENT=change FIF_FZF_QUERY=ab run_fif .
assert_search 'a two-character query'
grep -q -- '-e ab' "$FIF_RG_LOG"
if grep -q -- '--follow' "$FIF_RG_LOG"; then
    echo 'fif integration: FAIL: ripgrep followed symlinks by default' >&2
    exit 1
fi

: >"$FIF_RG_LOG"
FIF_FZF_EVENT=change FIF_FZF_QUERY=ab run_fif --follow .
assert_search 'an explicit --follow search'
grep -q -- '--follow' "$FIF_RG_LOG"

: >"$FIF_RG_LOG"
FIF_FZF_EVENT=change FIF_FZF_QUERY=ab run_fif --path .
assert_search 'an explicit --path search'
grep -q -- '-- \.' "$FIF_RG_LOG"

if run_fif --path "$temp_dir/missing" 2>/dev/null; then
    echo 'fif integration: FAIL: an invalid --path was accepted' >&2
    exit 1
fi

stale_dir="$temp_dir/fif-state.stale"
mkdir "$stale_dir"
touch -t 202001010000 "$stale_dir"
FIF_FZF_EVENT=start FIF_FZF_QUERY='' run_fif .
if test -d "$stale_dir"; then
    echo 'fif integration: FAIL: stale state directory was not pruned' >&2
    exit 1
fi

FIF_FZF_EVENT=interrupt FIF_FZF_QUERY='' run_fif . 2>/dev/null || true
if find "$temp_dir" -maxdepth 1 -type d -name 'fif-state.*' | grep -q .; then
    echo 'fif integration: FAIL: state directory remained after interruption' >&2
    exit 1
fi

mkdir -p "$temp_dir/config/fish"
printf '%s\n' \
    'set fish_function_path "$FIF_FUNCTIONS_DIR" $fish_function_path' \
    'sleep 1' >"$temp_dir/config/fish/config.fish"
export XDG_CONFIG_HOME="$temp_dir/config"
export FIF_PREVIEW_TIMING_LOG="$temp_dir/preview-seconds"
FIF_FZF_EVENT=preview FIF_FZF_QUERY=ab run_fif .
preview_seconds=$(cat "$FIF_PREVIEW_TIMING_LOG")
if ! awk -v elapsed="$preview_seconds" 'BEGIN { exit !(elapsed < 0.5) }'; then
    echo "fif integration: FAIL: preview loaded the slow Fish config (${preview_seconds}s)" >&2
    exit 1
fi

echo 'fif integration: PASS'
