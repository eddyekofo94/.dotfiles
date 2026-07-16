#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/fzf-preview.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

image="$tmp_dir/fixture.png"
printf '%s' \
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' \
    | base64 -D >"$image"

opts=$(env -u FZF_DEFAULT_OPTS -u FZF_PREVIEW_COMMAND -u FZF_CTRL_T_OPTS \
    fish --no-config -c '
        set -p fish_function_path "$argv[1]/functions"
        source "$argv[1]/conf.d/_fzf_envs.fish"
        printf "%s\n%s\n%s\n" \
            "$FZF_PREVIEW_COMMAND" "$FZF_DEFAULT_OPTS" "$FZF_CTRL_T_OPTS"
    ' "$package_dir")

printf '%s\n' "$opts" | rg -q '^_fzf_preview \{\}$'
test "$(printf '%s\n' "$opts" | rg -c -- "--preview='_fzf_preview \{\}'")" -ge 1
test "$(printf '%s\n' "$opts" | rg -c -- "--preview '_fzf_preview \{\}'")" -ge 1
printf '%s\n' "$opts" | rg -q -- 'ctrl-f:preview-page-down,ctrl-b:preview-page-up'
if printf '%s\n' "$opts" | rg -q -- 'ctrl-u:'; then
    echo 'fzf preview integration: Ctrl-U must retain its native binding' >&2
    exit 1
fi

output="$tmp_dir/preview.out"
env FZF_PREVIEW_COLUMNS=20 FZF_PREVIEW_LINES=8 FZF_PREVIEW_TEST_WINDOW_SIZE=1 \
    fish --no-config -c '
        set -p fish_function_path "$argv[1]/functions"
        _fzf_preview "$argv[2]"
    ' "$package_dir" "$image" >"$output"

test -s "$output"
test "$(wc -c <"$output" | tr -d ' ')" -lt 100000
test "$(LC_ALL=C tr -cd '\n' <"$output" | wc -c | tr -d ' ')" -ge 2
if LC_ALL=C rg -a -q '033\[m' "$output"; then
    echo 'fzf preview integration: ANSI reset was emitted as visible text' >&2
    exit 1
fi
python3 -c '
import pathlib
import sys

data = pathlib.Path(sys.argv[1]).read_bytes()
if b"\x1b[m" not in data:
    raise SystemExit("fzf preview integration: ANSI reset is missing")
' "$output"

printf 'fzf preview integration: PASS\n'
