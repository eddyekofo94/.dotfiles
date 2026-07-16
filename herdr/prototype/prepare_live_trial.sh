#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
runner="$prototype/run.sh"
user_config_home=${HERDR_PROTOTYPE_USER_CONFIG_HOME:-"$HOME/.config"}

attempt=0
while [ "$attempt" -lt 50 ]; do
  if panes=$($runner --border focused cli pane list 2>/dev/null); then
    initial_pane=$(printf '%s' "$panes" | jq -r '.result.panes[0].pane_id // empty')
    if [ -n "$initial_pane" ]; then
      break
    fi
  fi
  attempt=$((attempt + 1))
  sleep 0.1
done

if [ -z "${initial_pane:-}" ]; then
  echo "Herdr focused trial did not become ready" >&2
  exit 1
fi

pane_count=$(printf '%s' "$panes" | jq '.result.panes | length')
if [ "$pane_count" -ne 1 ]; then
  echo "Herdr focused trial expected one fresh pane, found $pane_count" >&2
  exit 1
fi

$runner --border focused cli plugin unlink prototype.golden-focus \
  >/dev/null 2>&1 || true
$runner --border focused cli plugin link "$prototype/golden-focus" >/dev/null

right=$($runner --border focused cli pane split "$initial_pane" \
  --direction right --ratio 0.5 --env "XDG_CONFIG_HOME=$user_config_home" --focus)
right_pane=$(printf '%s' "$right" | jq -r '.result.pane.pane_id')

lower=$($runner --border focused cli pane split "$right_pane" \
  --direction down --ratio 0.5 --env "XDG_CONFIG_HOME=$user_config_home" --focus)
lower_pane=$(printf '%s' "$lower" | jq -r '.result.pane.pane_id')

$runner --border focused cli pane send-text "$initial_pane" \
  "env XDG_CONFIG_HOME=$user_config_home nvim --listen /tmp/herdr-focused-nvim.sock -c 'luafile $prototype/herdr_nav.lua'"
$runner --border focused cli pane send-keys "$initial_pane" return

attempt=0
while [ "$attempt" -lt 50 ]; do
  if env XDG_CONFIG_HOME="$user_config_home" \
    nvim --server /tmp/herdr-focused-nvim.sock --remote-expr '1' \
    >/dev/null 2>&1; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 0.1
done

if [ "$attempt" -ge 50 ]; then
  echo "Neovim focused trial did not become ready" >&2
  exit 1
fi

sleep 1.5
env XDG_CONFIG_HOME="$user_config_home" \
  nvim --server /tmp/herdr-focused-nvim.sock --remote-expr 'execute("vsplit")' \
  >/dev/null

$runner --border focused cli pane send-text "$right_pane" \
  "env XDG_CONFIG_HOME=$user_config_home fish --no-config -c 'source $root/fish/conf.d/_fzf_envs.fish; cd $prototype/screenshots; fd -e png . | fzf --query=png --preview \"$prototype/chafa_preview.sh {}\" --preview-window=right,55%,border-sharp,nocycle'"
$runner --border focused cli pane send-keys "$right_pane" return

$runner --border focused cli pane send-text "$lower_pane" \
  "printf '\\nFINAL HERDR NAV QA\\nPhysical Alt-h/j/k/l uses an isolated Ghostty remap, then moves through Neovim and Herdr.\\nFocused panes grow to 62%%; Ctrl-a Shift-g restores/toggles golden focus.\\nHigh-quality images are blocked in Herdr v0.7.4; chafa remains only as a safe diagnostic.\\n'"
$runner --border focused cli pane send-keys "$lower_pane" return

$runner --border focused cli pane focus --direction left --current >/dev/null
