#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/fzf-preview.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

bindings=$(fish --no-config -i -c '
    set --prepend fish_function_path "$argv[1]/functions"
    fish_user_key_bindings
    bind --mode default \ct
    bind --mode insert \ct
    bind --mode default \cp
    bind --mode insert \cp
    bind --mode default \cr
    bind --mode insert \cr
    bind --mode default \cg
    bind --mode insert \cg
    functions --query fzf-file-widget; and exit 70
    true
' "$package_dir" 2>"$tmp_dir/bindings.err")

for expected in \
    'bind ctrl-t _fzf_search_directory' \
    'bind -M insert ctrl-t _fzf_search_directory' \
    'bind ctrl-p _fzf_search_directory' \
    'bind -M insert ctrl-p _fzf_search_directory' \
    'bind ctrl-r _fzf_search_history' \
    'bind -M insert ctrl-r _fzf_search_history' \
    'bind ctrl-g _fzf_search_git_status' \
    'bind -M insert ctrl-g _fzf_search_git_status'
do
    printf '%s\n' "$bindings" | rg --fixed-strings --line-regexp --quiet "$expected"
done
if test -s "$tmp_dir/bindings.err"; then
    cat "$tmp_dir/bindings.err" >&2
    exit 1
fi

image="$tmp_dir/fixture.png"
printf '%s' \
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' \
    | base64 -D >"$image"
text_fixture="$tmp_dir/fixture.txt"
printf 'FZF_TEXT_PREVIEW_SENTINEL\n' >"$text_fixture"

opts=$(env -u FZF_DEFAULT_OPTS -u FZF_PREVIEW_COMMAND -u FZF_CTRL_T_OPTS \
    fish --no-config -c '
        set -p fish_function_path "$argv[1]/functions"
        source "$argv[1]/conf.d/_fzf_envs.fish"
        printf "%s\n%s\n%s\n%s\n" \
            "$FZF_PREVIEW_COMMAND" "$FZF_DEFAULT_OPTS" "$FZF_CTRL_T_OPTS" \
            "$fzf_preview_file_cmd"
    ' "$package_dir")

printf '%s\n' "$opts" | rg -q '^_fzf_preview \{\}$'
printf '%s\n' "$opts" | rg -q '^_fzf_preview$'
test "$(printf '%s\n' "$opts" | rg -c -- "--preview='_fzf_preview \{\}'")" -ge 1
test "$(printf '%s\n' "$opts" | rg -c -- "--preview '_fzf_preview \{\}'")" -ge 1
printf '%s\n' "$opts" | rg -q -- 'ctrl-f:preview-page-down,ctrl-b:preview-page-up'
if printf '%s\n' "$opts" | rg -q -- 'ctrl-u:'; then
    echo 'fzf preview integration: Ctrl-U must retain its native binding' >&2
    exit 1
fi

# fzf owns these variables inside preview subprocesses. Sourcing the Fish
# environment must preserve the live pane geometry it supplied.
geometry=$(env FZF_PREVIEW_COLUMNS=29 FZF_PREVIEW_LINES=17 \
    fish --no-config -c '
        source "$argv[1]/conf.d/_fzf_envs.fish"
        printf "%s,%s\n" "$FZF_PREVIEW_COLUMNS" "$FZF_PREVIEW_LINES"
    ' "$package_dir")
test "$geometry" = '29,17'
legacy_geometry=$(env FZF_PREVIEW_LINES=-200 fish --no-config -c '
    source "$argv[1]/conf.d/_fzf_envs.fish"
    if set -q FZF_PREVIEW_LINES
        printf "%s\n" "$FZF_PREVIEW_LINES"
    else
        printf "cleared\n"
    end
' "$package_dir")
test "$legacy_geometry" = cleared

picker_opts=$(fish --no-config -c '
    set -p fish_function_path "$argv[1]/functions"
    _fzf_file_picker_opts .
' "$package_dir")
for binding in \
    'ctrl-f:preview-page-down' \
    'ctrl-b:preview-page-up' \
    'ctrl-o:execute-silent' \
    'ctrl-y:execute-silent' \
    'alt-y:execute-silent' \
    'ctrl-g:become'
do
    printf '%s\n' "$picker_opts" | rg --fixed-strings --quiet "$binding"
done
if printf '%s\n' "$picker_opts" | rg --fixed-strings --quiet 'resize:refresh-preview'; then
    echo 'fzf preview integration: rollback must not refresh image previews on resize' >&2
    exit 1
fi

output="$tmp_dir/preview.out"
mock_bin="$tmp_dir/bin"
mock_args="$tmp_dir/kitten.args"
mkdir -p "$mock_bin"
printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "$@" >"$FZF_TEST_KITTEN_ARGS"' \
    'printf "\\033[m\\n"' >"$mock_bin/kitten"
chmod +x "$mock_bin/kitten"
env PATH="$mock_bin:$PATH" FZF_TEST_KITTEN_ARGS="$mock_args" \
    FZF_PREVIEW_COLUMNS=20 FZF_PREVIEW_LINES=8 \
    fish --no-config -c '
        set -p fish_function_path "$argv[1]/functions"
        _fzf_preview "$argv[2]"
    ' "$package_dir" "$image" >/dev/null
if ! rg --fixed-strings --line-regexp --quiet -- '--transfer-mode=memory' "$mock_args"; then
    echo 'fzf preview integration: images must use bounded shared-memory transfer' >&2
    exit 1
fi

# gss previews git status entries, so an image there must reach the same
# painter rather than bat/delta, placed below its own two-row status header.
gss_args="$tmp_dir/gss-kitten.args"
gss_output="$tmp_dir/gss-preview.out"
(
    cd "$tmp_dir"
    env PATH="$mock_bin:$PATH" FZF_TEST_KITTEN_ARGS="$gss_args" \
        FZF_PREVIEW_COLUMNS=20 FZF_PREVIEW_LINES=8 \
        fish --no-config -c '
            set -p fish_function_path "$argv[1]/functions"
            source "$argv[1]/functions/git/gss.fish"
            __gss_preview "?? fixture.png"
        ' "$package_dir" >"$gss_output"
)
if ! rg --fixed-strings --line-regexp --quiet -- '--place=20x6@0x2' "$gss_args"; then
    echo 'fzf preview integration: gss image preview lost its placement' >&2
    exit 1
fi
if LC_ALL=C rg -a -q 'Binary content|Binary files' "$gss_output"; then
    echo 'fzf preview integration: gss image reached a text renderer' >&2
    exit 1
fi
rg --fixed-strings --quiet 'fixture.png' "$gss_output"

env FZF_PREVIEW_COLUMNS=20 FZF_PREVIEW_LINES=8 FZF_PREVIEW_TEST_WINDOW_SIZE=1 \
    fish --no-config -c '
        set -p fish_function_path "$argv[1]/functions"
        source "$argv[1]/conf.d/_fzf_envs.fish"
        set -gx FZF_PREVIEW_COLUMNS 20
        set -gx FZF_PREVIEW_LINES 8
        _fzf_preview_file "$argv[2]"
    ' "$package_dir" "$image" >"$output"

test -s "$output"
test "$(wc -c <"$output" | tr -d ' ')" -lt 100000
test "$(LC_ALL=C tr -cd '\n' <"$output" | wc -c | tr -d ' ')" -ge 2
if LC_ALL=C rg -a -q 'Binary content from file' "$output"; then
    echo 'fzf preview integration: image reached bat instead of the canonical previewer' >&2
    exit 1
fi
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

text_output="$tmp_dir/text-preview.out"
fish --no-config -c '
    set -p fish_function_path "$argv[1]/functions"
    source "$argv[1]/conf.d/_fzf_envs.fish"
    _fzf_preview_file "$argv[2]"
' "$package_dir" "$text_fixture" >"$text_output"
rg -q 'FZF_TEXT_PREVIEW_SENTINEL' "$text_output"

directory_output="$tmp_dir/directory-preview.out"
fish --no-config -c '
    set -p fish_function_path "$argv[1]/functions"
    source "$argv[1]/conf.d/_fzf_envs.fish"
    _fzf_preview_file "$argv[2]"
' "$package_dir" "$tmp_dir" >"$directory_output"
rg -q 'fixture.png' "$directory_output"
rg -q 'fixture.txt' "$directory_output"

# A highlighted filename is untrusted argv, not Fish source code. This exact
# shape exploited fzf.fish's former eval-based adapter.
malicious_name="x'; touch PWNED; echo '"
printf 'FZF_QUOTED_FILENAME_SENTINEL\n' >"$tmp_dir/$malicious_name"
malicious_output="$tmp_dir/malicious-preview.out"
(
    cd "$tmp_dir"
    fish --no-config -c '
        set -p fish_function_path "$argv[1]/functions"
        source "$argv[1]/conf.d/_fzf_envs.fish"
        _fzf_preview_file "$argv[2]"
    ' "$package_dir" "$malicious_name" >"$malicious_output"
)
test ! -e "$tmp_dir/PWNED"
rg -q 'FZF_QUOTED_FILENAME_SENTINEL' "$malicious_output"

printf 'fzf preview integration: PASS\n'
