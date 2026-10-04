#!/bin/sh
# Install herdr-reap: a symlink onto PATH plus the launchd agent that runs one
# pass every two minutes (Eddy, 2026-10-04: "I don't want to clog space with
# idle sessions"). Shaped like install_tab_status.sh, which it mirrors.
#
# Overrides, for tests and for machines that want a different layout:
#   HERDR_REAP_BIN         symlink path (default ~/.local/bin/herdr-reap)
#   HERDR_LAUNCH_AGENT_DIR plist directory (default ~/Library/LaunchAgents)
#   HERDR_REAP_LOG         log path (default ~/Library/Logs/<label>.log)
#   HERDR_REAP_INTERVAL    seconds between passes (default 120)
#   HERDR_REAP_BOOTSTRAP   0 to render everything but not talk to launchd
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
label=com.eddyekofo.herdr-reap
script="$root/herdr/reap_idle.py"
template="$root/herdr/launchd/$label.plist.in"

link=${HERDR_REAP_BIN:-"$HOME/.local/bin/herdr-reap"}
agent_dir=${HERDR_LAUNCH_AGENT_DIR:-"$HOME/Library/LaunchAgents"}
log=${HERDR_REAP_LOG:-"$HOME/Library/Logs/$label.log"}
interval=${HERDR_REAP_INTERVAL:-120}
bootstrap=${HERDR_REAP_BOOTSTRAP:-1}
plist="$agent_dir/$label.plist"

[ -f "$script" ] || { echo "missing $script" >&2; exit 66; }
[ -f "$template" ] || { echo "missing $template" >&2; exit 66; }
case "$interval" in
  ''|*[!0-9]*) echo "HERDR_REAP_INTERVAL must be whole seconds" >&2; exit 64 ;;
esac

# Adopt our own symlink; never clobber a real file or someone else's link.
if [ -L "$link" ]; then
  if [ "$(readlink "$link")" != "$script" ]; then
    echo "refusing to replace unrelated link: $link" >&2
    exit 73
  fi
elif [ -e "$link" ]; then
  echo "refusing to replace existing file: $link" >&2
  exit 73
fi

chmod 0755 "$script"
mkdir -p "$(dirname -- "$link")" "$agent_dir" "$(dirname -- "$log")"
if [ ! -L "$link" ]; then
  staged="$(dirname -- "$link")/.herdr-reap.$$"
  ln -s "$script" "$staged"
  mv "$staged" "$link"
fi

staged_plist="$agent_dir/.$label.plist.$$"
sed -e "s|@LABEL@|$label|g" \
    -e "s|@SCRIPT@|$script|g" \
    -e "s|@INTERVAL@|$interval|g" \
    -e "s|@BIN_DIR@|$(dirname -- "$link")|g" \
    -e "s|@LOG@|$log|g" \
    "$template" >"$staged_plist"
if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$staged_plist" >/dev/null || {
    rm -f -- "$staged_plist"
    echo "rendered plist failed plutil -lint" >&2
    exit 65
  }
fi
mv "$staged_plist" "$plist"

printf 'herdr-reap: %s -> %s\n' "$link" "$script"
printf 'launch agent: %s\n' "$plist"

if [ "$bootstrap" != 1 ] || ! command -v launchctl >/dev/null 2>&1; then
  printf 'not bootstrapped (launchctl skipped)\n'
  exit 0
fi

launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist"
printf 'bootstrapped %s (every %ss, log: %s)\n' "$label" "$interval" "$log"
