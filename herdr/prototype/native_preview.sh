#!/bin/sh
set -eu

# PROTOTYPE ONLY: render one fzf selection through Herdr's pane-owned raster
# API. Unlike terminal Kitty passthrough, Herdr owns and clips this placement.

socket=${HERDR_SOCKET_PATH:?Herdr socket path is required}
pane=${HERDR_PANE_ID:?Herdr pane id is required}
log=${HERDR_GRAPHICS_LOG:-/tmp/herdr-prototype-graphics.log}
prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state_root=${HERDR_GRAPHICS_STATE_DIR:-"$prototype/.runtime/graphics"}
pane_key=$(printf '%s' "$pane" | tr -c '[:alnum:]_.-' '_')
state_dir="$state_root/$pane_key"
token_file="$state_dir/latest"
lock_file="$state_dir/update.lock"
mkdir -p "$state_dir"
printf '%s start pane=%s args=%s preview=%sx%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pane" "$*" \
  "${FZF_PREVIEW_COLUMNS:-unset}" "${FZF_PREVIEW_LINES:-unset}" >>"$log"

request() {
  response=$(nc -U -w 2 "$socket" 2>&1) || {
    printf '%s\n' "$response" >>"$log"
    return 1
  }
  printf '%s\n' "$response" >>"$log"
  printf '%s' "$response" | grep -q '"result"'
}

is_latest() {
  [ -f "$token_file" ] && [ "$(sed -n '1p' "$token_file")" = "$token" ]
}

clear_layer() {
  printf '{"id":"prototype-graphics-clear","method":"pane.graphics.clear","params":{"pane_id":"%s"}}\n' \
    "$pane" | request
}

case "${1:-}" in
--worker-clear)
  token=${2:?update token required}
  is_latest || exit 0
  clear_layer
  exit
  ;;
--worker-set)
  token=${2:?update token required}
  image=${3:?image path required}
  is_latest || exit 0
  ;;
--clear)
  token="$(date +%s)-$$-clear"
  printf '%s\n' "$token" >"$token_file"
  lockf -t 3 "$lock_file" "$0" --worker-clear "$token"
  exit
  ;;
*)
  image=${1:?image path required}
  [ -f "$image" ] || exit 1
  token="$(date +%s)-$$-set"
  printf '%s\n' "$token" >"$token_file"
  lockf -t 3 "$lock_file" "$0" --worker-set "$token" "$image"
  exit
  ;;
esac

source_width=$(sips -g pixelWidth "$image" 2>/dev/null | awk '/pixelWidth:/ { print $2 }')
source_height=$(sips -g pixelHeight "$image" 2>/dev/null | awk '/pixelHeight:/ { print $2 }')
case "$source_width:$source_height" in
  *[!0-9:]*|:|*:|:*) exit 1 ;;
esac

tty_size=$(stty size </dev/tty)
set -- $tty_size
pane_rows=$1
pane_cols=$2
preview_cols=${FZF_PREVIEW_COLUMNS:-$pane_cols}
preview_rows=${FZF_PREVIEW_LINES:-$pane_rows}
case "$preview_cols" in ''|*[!0-9]*|0) preview_cols=$pane_cols ;; esac
case "$preview_rows" in ''|*[!0-9]*|0) preview_rows=$pane_rows ;; esac

# Herdr clips a PNG at its native pixels; grid dimensions do not scale it. Fit a
# disposable raster to the available cell box first, preserving aspect ratio.
# The defaults match the direct Ghostty trial and remain overridable for other
# font metrics without changing the prototype.
available_cols=$((preview_cols - 2))
available_rows=$((preview_rows - 2))
if [ "$available_cols" -lt 1 ] || [ "$available_rows" -lt 1 ]; then
  exit 1
fi
cell_pixel_width=${HERDR_CELL_PIXEL_WIDTH:-16}
cell_pixel_height=${HERDR_CELL_PIXEL_HEIGHT:-26}
target_width=$((available_cols * cell_pixel_width))
target_height=$((source_height * target_width / source_width))
max_height=$((available_rows * cell_pixel_height))
if [ "$target_height" -gt "$max_height" ]; then
  target_height=$max_height
  target_width=$((source_width * target_height / source_height))
fi
[ "$target_width" -gt 0 ] && [ "$target_height" -gt 0 ] || exit 1

grid_cols=$(((target_width + cell_pixel_width - 1) / cell_pixel_width))
grid_rows=$(((target_height + cell_pixel_height - 1) / cell_pixel_height))
viewport_col=$((pane_cols - preview_cols + 1 + (available_cols - grid_cols) / 2))
viewport_row=$((1 + (available_rows - grid_rows) / 2))

scaled="$state_dir/$token.png"
trap 'rm -f "$scaled"' EXIT HUP INT TERM
sips -s format png -z "$target_height" "$target_width" "$image" --out "$scaled" \
  >/dev/null 2>&1
image=$scaled
image_width=$target_width
image_height=$target_height

# A selection or resize can kill one fzf preview while the next starts. The
# per-pane lock prevents those requests from overtaking each other, and the
# latest-token check prevents a queued stale process from painting afterward.
# pane.graphics.set owns one layer per pane, so replace it directly; a separate
# clear here creates a visible compositor gap during rapid selection changes.
is_latest || exit 0

{
  printf '{"id":"prototype-graphics-set","method":"pane.graphics.set","params":{"pane_id":"%s","format":"png","image_width":%s,"image_height":%s,"data_base64":"' \
    "$pane" "$image_width" "$image_height"
  base64 <"$image" | tr -d '\n'
  printf '","placement":{"viewport_col":%s,"viewport_row":%s,"grid_cols":%s,"grid_rows":%s}}}\n' \
    "$viewport_col" "$viewport_row" "$grid_cols" "$grid_rows"
} | request || {
  is_latest || exit 0
  exec "$prototype/chafa_preview.sh" "$image"
}
