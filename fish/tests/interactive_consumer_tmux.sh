#!/bin/sh
set -eu

command -v tmux >/dev/null 2>&1 || {
    echo 'Fish interactive tmux: tmux is required' >&2
    exit 1
}

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/fish-interactive-tmux.XXXXXX")
socket_name="fish-interactive-tmux-$$"
window_columns=${FISH_TMUX_WINDOW_COLUMNS:-120}
window_rows=${FISH_TMUX_WINDOW_ROWS:-40}
expected_geometry=${FISH_TMUX_EXPECTED_GEOMETRY:-62,35}
trap 'TMUX_TMPDIR=/tmp tmux -L "$socket_name" kill-server >/dev/null 2>&1 || true; find "$tmp_dir" -depth -delete' EXIT HUP INT TERM

fixture_dir="$tmp_dir/repo"
fixture_home="$tmp_dir/home"
mkdir -p "$fixture_dir" "$fixture_home/.config"
ln -s "$package_dir" "$fixture_home/.config/fish"

if [ -n "${FISH_TMUX_IMAGE_FIXTURE:-}" ]; then
    cp "$FISH_TMUX_IMAGE_FIXTURE" "$fixture_dir/fixture.png"
else
    printf '%s' \
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' \
        | base64 -D >"$fixture_dir/fixture.png"
fi
printf 'FISH_TMUX_TEXT_SENTINEL\n' >"$fixture_dir/fixture.txt"
git -C "$fixture_dir" init -q

tmux_cmd() {
    TMUX_TMPDIR=/tmp tmux -L "$socket_name" "$@"
}

capture() {
    tmux_cmd capture-pane -p -e -t fish-pty:0.0 -S -100
}

wait_capture() {
    pattern=$1
    count=0
    while [ "$count" -lt 100 ]; do
        if capture | rg -q -- "$pattern"; then
            return 0
        fi
        sleep 0.05
        count=$((count + 1))
    done
    capture >&2
    echo "Fish interactive tmux: missing $pattern" >&2
    exit 1
}

TMUX_TMPDIR=/tmp tmux -L "$socket_name" \
    -f "$package_dir/tests/fixtures/tmux-graphics.conf" new-session -d \
    -s fish-pty -c "$fixture_dir" \
    "env HOME='$fixture_home' FZF_PREVIEW_TEST_WINDOW_SIZE=1 FZF_PREVIEW_TEST_REPORT_GEOMETRY=1 fish -i"
tmux_cmd resize-window -t fish-pty:0 -x "$window_columns" -y "$window_rows"
raw_output="$tmp_dir/pane-output.bin"
tmux_cmd pipe-pane -o -t fish-pty:0.0 "tee '$raw_output' >/dev/null"

setup="function __fish_tmux_report; printf '\\nFISH_TMUX_SELECTED:%s\\n' (commandline); commandline -r ''; commandline -f repaint; end; bind \\cx __fish_tmux_report; bind -M insert \\cx __fish_tmux_report; tmux set-option -p @fish_test_ready yes"
tmux_cmd send-keys -t fish-pty:0.0 -l -- "$setup"
tmux_cmd send-keys -t fish-pty:0.0 Enter

count=0
while [ "$count" -lt 100 ]; do
    if [ "$(tmux_cmd show-option -pv -t fish-pty:0.0 @fish_test_ready 2>/dev/null || true)" = yes ]; then
        break
    fi
    sleep 0.05
    count=$((count + 1))
done
if [ "$count" -eq 100 ]; then
    echo 'Fish interactive tmux: Fish did not become ready' >&2
    exit 1
fi

tmux_cmd send-keys -t fish-pty:0.0 -l -- fixture.png
tmux_cmd send-keys -t fish-pty:0.0 C-t
wait_capture 'Directory[^>]*>'
wait_capture "FZF_PREVIEW_GEOMETRY:$expected_geometry"
# The preview names its target on the first row, so the image is placed one row
# down and one row shorter than the reported pane geometry.
place_columns=${expected_geometry%,*}
place_rows=$((${expected_geometry#*,} - 1))
wait_capture "FZF_PREVIEW_IMAGE_PLACE:${place_columns}x${place_rows}@0x1"
if capture | rg -q 'Binary content from file'; then
    echo 'Fish interactive tmux: Ctrl-T sent an image to bat' >&2
    exit 1
fi

count=0
while [ "$count" -lt 100 ]; do
    if python3 -c '
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes() if Path(sys.argv[1]).exists() else b""
graphics = b"\x1b_G" in data or b"\x1b\x1b_G" in data
placeholder = chr(0x10EEEE).encode() in data
raise SystemExit(0 if graphics and placeholder else 1)
' "$raw_output"; then
        break
    fi
    sleep 0.05
    count=$((count + 1))
done
if [ "$count" -eq 100 ]; then
    echo 'Fish interactive tmux: exact image emitted no Kitty placeholder transport' >&2
    exit 1
fi

# Raw Kitty transport can be correct while fzf clips the Unicode-placeholder
# clusters that map the image onto cells. Compare Kitty's emitted column count
# with the widest placeholder row that remains in tmux's displayed pane.
if ! capture | python3 -c '
from pathlib import Path
import re
import sys

raw = Path(sys.argv[1]).read_bytes()
matches = re.findall(rb",c=(\d+),r=(\d+),", raw)
if not matches:
    raise SystemExit("Fish interactive tmux: Kitty image geometry metadata is missing")
expected_columns = int(matches[-1][0])
placeholder = chr(0x10EEEE)
displayed_columns = max((line.count(placeholder) for line in sys.stdin), default=0)
if displayed_columns < expected_columns:
    raise SystemExit(
        f"Fish interactive tmux: fzf retained {displayed_columns}/{expected_columns} image columns"
    )
' "$raw_output"; then
    exit 1
fi

tmux_cmd send-keys -t fish-pty:0.0 Enter
sleep 0.1
tmux_cmd send-keys -t fish-pty:0.0 C-x
wait_capture 'FISH_TMUX_SELECTED:fixture.png'

printf 'Fish interactive tmux: PASS\n'
