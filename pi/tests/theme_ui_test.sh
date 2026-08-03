#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
theme="$pi_dir/themes/catppuccin-mocha.json"
ghostty_config="$pi_dir/../ghostty/config"

jq -e '
  .theme == "catppuccin-mocha" and
  .themes == ["/Users/eddyekofo/.dotfiles/pi/themes/catppuccin-mocha.json"] and
  .packages == ["npm:@ff-labs/pi-fff@0.10.1"] and
  .showHardwareCursor == true
' "$pi_dir/settings.json" >/dev/null

jq -e '
  .name == "catppuccin-mocha" and
  (.colors | keys | length) >= 51 and
  .colors.accent == "mauve" and
  .colors.text == "text"
' "$theme" >/dev/null

grep -F 'class EddyPromptEditor extends CustomEditor' \
  "$pi_dir/extensions/eddy-compat.ts" >/dev/null
grep -Fx 'cursor-style = block' "$ghostty_config" >/dev/null
grep -Fx 'cursor-style-blink = true' "$ghostty_config" >/dev/null
grep -Fx 'shell-integration-features = no-cursor' \
  "$ghostty_config" >/dev/null

echo "Pi theme and editor tests: PASS"
