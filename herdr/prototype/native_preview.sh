#!/bin/sh
set -eu

# PROTOTYPE ONLY: render one fzf selection through Herdr's pane-owned raster
# API. Unlike terminal Kitty passthrough, Herdr owns and clips this placement.

socket=${HERDR_SOCKET_PATH:?Herdr socket path is required}
pane=${HERDR_PANE_ID:?Herdr pane id is required}
log=${HERDR_GRAPHICS_LOG:-/tmp/herdr-prototype-graphics.log}
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

if [ "${1:-}" = "--clear" ]; then
  printf '{"id":"prototype-graphics-clear","method":"pane.graphics.clear","params":{"pane_id":"%s"}}\n' \
    "$pane" | request
  exit
fi

image=${1:?image path required}
if [ ! -f "$image" ]; then
  exit 1
fi

image_width=$(sips -g pixelWidth "$image" 2>/dev/null | awk '/pixelWidth:/ { print $2 }')
image_height=$(sips -g pixelHeight "$image" 2>/dev/null | awk '/pixelHeight:/ { print $2 }')
case "$image_width:$image_height" in
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

# fzf's right preview owns the final PREVIEW_COLUMNS cells. Leave one cell on
# each edge for its sharp border and place the raster relative to the pane.
viewport_col=$((pane_cols - preview_cols + 1))
viewport_row=1
grid_cols=$((preview_cols - 2))
grid_rows=$((preview_rows - 2))
if [ "$grid_cols" -lt 1 ] || [ "$grid_rows" -lt 1 ]; then
  exit 1
fi

{
  printf '{"id":"prototype-graphics-set","method":"pane.graphics.set","params":{"pane_id":"%s","format":"png","image_width":%s,"image_height":%s,"data_base64":"' \
    "$pane" "$image_width" "$image_height"
  base64 <"$image" | tr -d '\n'
  printf '","placement":{"viewport_col":%s,"viewport_row":%s,"grid_cols":%s,"grid_rows":%s}}}\n' \
    "$viewport_col" "$viewport_row" "$grid_cols" "$grid_rows"
} | request || exec "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/chafa_preview.sh" "$image"
