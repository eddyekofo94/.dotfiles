#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/fif-real-fzf.XXXXXX")
socket_name="fif-real-fzf-$$"

cleanup() {
    tmux -L "$socket_name" kill-server 2>/dev/null || true
    rm -rf "$temp_dir"
}
trap cleanup EXIT HUP INT TERM

mkdir "$temp_dir/bin"
ln -s "$package_dir/tests/fixtures/bin/rg" "$temp_dir/bin/rg"
printf '%s\n' 'fixture' >"$temp_dir/fixture.txt"
printf '%s\n' 'default source' >"$temp_dir/default-source.txt"
mkdir "$temp_dir/FZF"

test_path="$temp_dir/bin:$PATH"
tmux -L "$socket_name" -f /dev/null new-session -d -x 120 -y 40 \
    "env PATH='$test_path' FIF_RG_LOG='$temp_dir/rg.log' TMPDIR='$temp_dir/' TERM=xterm-256color fish --no-config --interactive"

tmux -L "$socket_name" send-keys \
    "set -g fish_function_path '$package_dir/functions' \$fish_function_path; set -gx FZF_DEFAULT_COMMAND 'printf \"default-source.txt\\n\"'; set -gx FZF_DEFAULT_OPTS '--preview=\"printf GLOBAL_PREVIEW\" --height=96%'; cd '$temp_dir'" Enter
sleep 0.1
tmux -L "$socket_name" send-keys C-l
tmux -L "$socket_name" clear-history
tmux -L "$socket_name" send-keys "fif FZF" Enter

for attempt in 1 2 3 4 5 6 7 8 9 10; do
    tmux -L "$socket_name" capture-pane -p >"$temp_dir/pane.txt"
    if grep -q 'Match.*fixture.txt' "$temp_dir/pane.txt" \
            && grep -q '^Context' "$temp_dir/pane.txt"; then
        break
    fi
    sleep 0.1
done

grep -q '1\. ripgrep> FZF' "$temp_dir/pane.txt"
grep -q 'fixture.txt:1:1:ab match' "$temp_dir/pane.txt"
grep -q 'Match.*fixture.txt' "$temp_dir/pane.txt"
grep -q '^Context' "$temp_dir/pane.txt"
if grep -q 'default-source.txt\|GLOBAL_PREVIEW' "$temp_dir/pane.txt"; then
    echo 'fif real fzf: FAIL: global fzf input or preview leaked into fif' >&2
    cat "$temp_dir/pane.txt" >&2
    exit 1
fi

tmux -L "$socket_name" send-keys C-c
echo 'fif real fzf: PASS'
