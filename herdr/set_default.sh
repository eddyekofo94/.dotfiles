#!/bin/sh
set -eu

choice=${1:?usage: set_default.sh herdr|tmux}
case "$choice" in
  herdr|tmux) ;;
  *)
    echo "default multiplexer must be herdr or tmux" >&2
    exit 64
    ;;
esac

config_dir=${HERDR_CONFIG_DIR:-"${XDG_CONFIG_HOME:-$HOME/.config}/herdr"}
mkdir -p "$config_dir"
tmp=$(mktemp "$config_dir/.default-multiplexer.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT HUP INT TERM
printf '%s\n' "$choice" >"$tmp"
chmod 0600 "$tmp"
mv "$tmp" "$config_dir/default-multiplexer"
trap - EXIT HUP INT TERM
printf 'default multiplexer: %s\n' "$choice"
