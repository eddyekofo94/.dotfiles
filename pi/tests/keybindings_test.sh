#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
keybindings="$pi_dir/keybindings.json"
state_dir=${PI_PILOT_STATE_DIR:-"${XDG_STATE_HOME:-"$HOME/.local/state"}/pi-pilot"}

jq -e '
  ."tui.editor.cursorUp" == ["up", "ctrl+p"] and
  ."tui.editor.cursorDown" == ["down", "ctrl+n"] and
  ."tui.select.up" == ["up", "ctrl+p"] and
  ."tui.select.down" == ["down", "ctrl+n"] and
  ."app.model.cycleForward" == [] and
  ."app.model.cycleBackward" == [] and
  ."app.model.select" == ["ctrl+shift+m"] and
  ."app.tree.filter.labeledOnly" == [] and
  ."app.session.togglePath" == ["ctrl+shift+p"] and
  ."app.session.toggleNamedFilter" == ["ctrl+shift+n"] and
  ."app.models.toggleProvider" == ["ctrl+shift+p"]
' "$keybindings" >/dev/null

grep -F 'matchesKey(data, "ctrl+l")' \
  "$pi_dir/extensions/eddy-compat.ts" >/dev/null
if grep -F 'pi.registerShortcut("ctrl+l"' \
   "$pi_dir/extensions/eddy-compat.ts" >/dev/null; then
  echo "pi-pilot: Ctrl-L must be owned by the reloadable editor" >&2
  exit 1
fi

"$pi_dir/install.sh" >/dev/null

installed="$state_dir/config/keybindings.json"
[ -L "$installed" ]
[ "$(readlink "$installed")" = "$keybindings" ]
agents="$state_dir/config/AGENTS.md"
[ -L "$agents" ]
[ "$(readlink "$agents")" = "$pi_dir/AGENTS.md" ]

echo "Pi pilot keybindings: PASS"
