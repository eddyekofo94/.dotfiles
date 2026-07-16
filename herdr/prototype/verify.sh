#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
prototype="$root/herdr/prototype"

test -x "$prototype/run.sh"
test -f "$prototype/config.toml"
test -f "$prototype/herdr_nav.lua"
test -f "$prototype/screenshots/expanded.png"
test -f "$prototype/screenshots/collapsed.png"

grep -q '^name = "catppuccin"$' "$prototype/config.toml"
grep -q '^prefix = "ctrl+a"$' "$prototype/config.toml"
grep -q '^sidebar_collapsed_mode = "hidden"$' "$prototype/config.toml"
grep -q '^pane_gaps = false$' "$prototype/config.toml"
grep -q '^hide_tab_bar_when_single_tab = true$' "$prototype/config.toml"
grep -q '^delivery = "off"$' "$prototype/config.toml"
grep -q '^enabled = false$' "$prototype/config.toml"

if [ -x "$prototype/.runtime/bin/herdr" ]; then
  "$prototype/run.sh" cli config check
fi

nvim_config=${XDG_CONFIG_HOME:-"$HOME/.config"}/nvim/lua/plugin/tmux.lua
if [ ! -f "$nvim_config" ]; then
  echo "production Neovim tmux adapter not found: $nvim_config" >&2
  exit 1
fi

if grep -q 'HERDR_PANE_ID\|herdr pane' "$nvim_config"; then
  echo "production Neovim tmux adapter contains Herdr prototype code" >&2
  exit 1
fi

echo "Herdr prototype verification: PASS"
