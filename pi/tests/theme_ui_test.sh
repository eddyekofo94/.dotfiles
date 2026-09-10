#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
theme="$pi_dir/themes/catppuccin-mocha.json"
ghostty_config="$pi_dir/../ghostty/config"

jq -e '
  .quietStartup == true and
  .theme == "catppuccin-mocha" and
  .themes == ["/Users/eddyekofo/.dotfiles/pi/themes/catppuccin-mocha.json"] and
  .packages == ["npm:@ff-labs/pi-fff@0.10.1"] and
  .showHardwareCursor == true
' "$pi_dir/settings.json" >/dev/null

jq -e '
  .name == "catppuccin-mocha" and
  (.colors | keys | length) >= 51 and
  .colors.accent == "mauve" and
  .colors.text == "text" and
  .colors.thinkingXhigh == "pink" and
  .colors.thinkingMax == "maroon"
' "$theme" >/dev/null

grep -F 'class EddyPromptEditor extends CustomEditor' \
  "$pi_dir/extensions/eddy-compat.ts" >/dev/null
grep -F 'ctx.ui.setFooter(' \
  "$pi_dir/extensions/eddy-compat.ts" >/dev/null
grep -F '.extensions = [$extension]' \
  "$pi_dir/validate_sessions.sh" >/dev/null
for scenario in context-69 context-70 context-84 context-85 weekly-10 normal; do
  grep -F "$scenario" "$pi_dir/physical_qa.sh" >/dev/null
done
grep -F '"$pi_dir/install.sh"' "$pi_dir/physical_qa.sh" >/dev/null
for traffic_color in success warning error; do
  grep -F "color: \"$traffic_color\"" \
    "$pi_dir/extensions/eddy-compat.ts" >/dev/null
done
grep -Fx 'cursor-style = block' "$ghostty_config" >/dev/null
grep -Fx 'cursor-style-blink = true' "$ghostty_config" >/dev/null
grep -Fx 'shell-integration-features = no-cursor' \
  "$ghostty_config" >/dev/null

echo "Pi theme and editor tests: PASS"
