#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
prototype="$root/herdr/prototype"

test -x "$prototype/run.sh"
test -x "$prototype/live_ghostty.sh"
test -x "$prototype/launch_live_ghostty.sh"
test -x "$prototype/prepare_live_trial.sh"
test -x "$prototype/smart_nav.sh"
test -x "$prototype/chafa_preview.sh"
test -x "$prototype/native_preview.sh"
test -f "$prototype/herdr_nav.fish"
test -x "$prototype/golden-focus/golden_focus.sh"
test -f "$prototype/golden-focus/herdr-plugin.toml"
test -f "$prototype/config.toml"
test -f "$prototype/herdr_nav.lua"
test -f "$prototype/screenshots/expanded.png"
test -f "$prototype/screenshots/collapsed.png"
test -f "$prototype/screenshots/chafa-final.png"
test -f "$prototype/screenshots/native-preview-retry.png"
test -f "$prototype/screenshots/native-preview-acceptance.png"

grep -q '"method":"pane.graphics.set"' "$prototype/native_preview.sh"
grep -q 'viewport_col.*grid_cols' "$prototype/native_preview.sh"
grep -q 'chafa_preview.sh' "$prototype/native_preview.sh"

grep -q '^name = "catppuccin"$' "$prototype/config.toml"
grep -q '^prefix = "ctrl+a"$' "$prototype/config.toml"
grep -q '^sidebar_collapsed_mode = "hidden"$' "$prototype/config.toml"
grep -q '^pane_gaps = false$' "$prototype/config.toml"
grep -q '^hide_tab_bar_when_single_tab = true$' "$prototype/config.toml"
grep -q '^delivery = "off"$' "$prototype/config.toml"
grep -q '^enabled = false$' "$prototype/config.toml"

if [ -x "$prototype/.runtime/bin/herdr" ]; then
  "$prototype/run.sh" cli config check
  "$prototype/run.sh" --border boxed cli config check
  "$prototype/run.sh" --border focused cli config check
  "$prototype/run.sh" --border borderless cli config check

  grep -q '^pane_gaps = true$' "$prototype/.runtime/cb/herdr/config.toml"
  grep -q '^pane_gaps = true$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^overlay0 = "#1e1e2e"$' "$prototype/.runtime/cf/herdr/config.toml"
  test "$(grep -c '^type = "shell"$' "$prototype/.runtime/cf/herdr/config.toml")" -eq 0
  if grep -Eq '^key = "(alt|ctrl\+alt)\+(h|j|k|l)"$' \
    "$prototype/.runtime/cf/herdr/config.toml"; then
    echo "focused prototype must pass physical Alt through to pane applications" >&2
    exit 1
  fi
  grep -q 'bind --mode.*\\eh.*__herdr_nav h left' "$prototype/herdr_nav.fish"
  grep -q '^type = "plugin_action"$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^command = "prototype.golden-focus.toggle"$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^pane_borders = false$' "$prototype/.runtime/cl/herdr/config.toml"
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
