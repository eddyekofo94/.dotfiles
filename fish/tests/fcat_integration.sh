#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/fcat-integration.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

mock_bin="$temp_dir/bin"
fd_args="$temp_dir/fd.args"
real_fd=$(command -v fd)
test_home="$temp_dir/home"
home_fixture="$test_home/path with spaces/fixture.txt"
outside_fixture="$temp_dir/outside fixture.txt"
mkdir -p "$mock_bin" "$(dirname -- "$home_fixture")"
printf 'HOME CONTENT\n' >"$home_fixture"
printf 'OUTSIDE CONTENT\n' >"$outside_fixture"

printf '%s\n' \
    '#!/bin/sh' \
    'target=' \
    'for arg in "$@"; do' \
    '    case "$arg" in' \
    '        --query=*) target=${arg#--query=} ;;' \
    '    esac' \
    'done' \
    'if test -n "${FCAT_SELECTION:-}"; then' \
    '    printf "%s\n" "$FCAT_SELECTION"' \
    'elif test -n "$target"; then' \
    '    /bin/sh -c "$FZF_DEFAULT_COMMAND" | awk -v target="$target" '\''$0 == target { print; exit }'\''' \
    'fi' >"$mock_bin/fzf"
chmod +x "$mock_bin/fzf"

printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$@" >"$FCAT_FD_ARGS_LOG"' \
    'exec "$FCAT_REAL_FD" "$@"' >"$mock_bin/fd"
chmod +x "$mock_bin/fd"

run_fcat() {
    working_dir=$1
    selection=$2
    filter=$3
    output=$4
    (
        cd "$working_dir"
        HOME="$test_home" PATH="$mock_bin:$PATH" FCAT_SELECTION="$selection" \
            FCAT_FD_ARGS_LOG="$fd_args" FCAT_REAL_FD="$real_fd" \
            fish --no-config --command '
                set --prepend fish_function_path "$argv[1]/functions"
                function cat
                    command cat $argv
                end
                fcat "$argv[2]"
            ' -- "$package_dir" "$filter"
    ) >"$output"
}

assert_rendered_output() {
    output=$1
    expected=$2
    python3 - "$output" "$expected" <<'PY'
import pathlib
import re
import sys

raw = pathlib.Path(sys.argv[1]).read_bytes()
plain = re.sub(rb"\x1b(?:\[[0-?]*[ -/]*[@-~]|\([A-Z0-9])", b"", raw)
expected = sys.argv[2].encode()
if plain != expected:
    raise SystemExit(
        "fcat integration: visible output mismatch\n"
        f"expected={expected!r}\nactual={plain!r}"
    )

path_line = expected.split(b"\n", 1)[0]
path_index = raw.find(path_line)
if path_index <= 0 or b"\x1b" not in raw[:path_index]:
    raise SystemExit("fcat integration: subtle path colour is missing")
if b"\x1b" not in raw[path_index + len(path_line):]:
    raise SystemExit("fcat integration: path colour reset is missing")
PY
}

home_output="$temp_dir/home.out"
run_fcat "$temp_dir" "$home_fixture" '' "$home_output"
assert_rendered_output "$home_output" '~/path with spaces/fixture.txt

HOME CONTENT
'

outside_output="$temp_dir/outside.out"
run_fcat "$temp_dir" "$outside_fixture" '' "$outside_output"
outside_canonical=$(realpath "$outside_fixture")
assert_rendered_output "$outside_output" "$outside_canonical

OUTSIDE CONTENT
"

cancel_output="$temp_dir/cancel.out"
run_fcat "$temp_dir" '' '' "$cancel_output"
test ! -s "$cancel_output"

producer_output="$temp_dir/producer.out"
producer_dir=$(dirname -- "$home_fixture")
mkdir -p "$producer_dir/.git"
printf 'fixture.txt\n' >"$producer_dir/.gitignore"
run_fcat "$producer_dir" '' 'fixture.txt' "$producer_output"
assert_rendered_output "$producer_output" '~/path with spaces/fixture.txt

HOME CONTENT
'
awk '
    previous == "--exclude" && $0 == ".git" { found = 1 }
    { previous = $0 }
    END { exit !found }
' "$fd_args"

git_internal_output="$temp_dir/git-internal.out"
printf 'MUST STAY EXCLUDED\n' >"$producer_dir/.git/should-not-appear"
run_fcat "$producer_dir" '' '.git/should-not-appear' "$git_internal_output"
test ! -s "$git_internal_output"

echo 'fcat integration: PASS'
