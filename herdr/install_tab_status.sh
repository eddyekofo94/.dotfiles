#!/bin/sh
# Install the tab-position stamper: a symlink onto PATH plus the launchd agent
# that keeps every live Herdr window's labels numbered from login onward.
#
# Split out of install.sh, not folded into it, because install.sh fetches and
# digest-checks a release binary — this part must stay runnable (and testable)
# from a clean checkout with no network. install.sh calls it last.
#
# Overrides, for tests and for machines that want a different layout:
#   HERDR_TAB_STATUS_BIN        symlink path (default ~/.local/bin/herdr-tab-status)
#   HERDR_LAUNCH_AGENT_DIR      plist directory (default ~/Library/LaunchAgents)
#   HERDR_TAB_STATUS_LOG        log path (default ~/Library/Logs/<label>.log)
#   HERDR_TAB_STATUS_INTERVAL   watch interval in seconds (default 3)
#   HERDR_TAB_STATUS_BOOTSTRAP  0 to render everything but not talk to launchd
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
label=com.eddyekofo.herdr-tab-status
script="$root/herdr/tab_status.sh"
template="$root/herdr/launchd/$label.plist.in"

link=${HERDR_TAB_STATUS_BIN:-"$HOME/.local/bin/herdr-tab-status"}
agent_dir=${HERDR_LAUNCH_AGENT_DIR:-"$HOME/Library/LaunchAgents"}
log=${HERDR_TAB_STATUS_LOG:-"$HOME/Library/Logs/$label.log"}
interval=${HERDR_TAB_STATUS_INTERVAL:-3}
bootstrap=${HERDR_TAB_STATUS_BOOTSTRAP:-1}
plist="$agent_dir/$label.plist"

[ -f "$script" ] || { echo "missing $script" >&2; exit 66; }
[ -f "$template" ] || { echo "missing $template" >&2; exit 66; }

case "$interval" in
  ''|*[!0-9.]*) echo "HERDR_TAB_STATUS_INTERVAL must be a number" >&2; exit 64 ;;
esac

# Same refusal shape as the config link in install.sh: adopt our own symlink,
# never clobber a real file or someone else's link.
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
  staged="$(dirname -- "$link")/.herdr-tab-status.$$"
  ln -s "$script" "$staged"
  mv "$staged" "$link"
fi

# Rendered through a temp file and moved into place, so a half-written plist is
# never visible to launchd.
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

printf 'tab status: %s -> %s\n' "$link" "$script"
printf 'launch agent: %s\n' "$plist"

if [ "$bootstrap" != 1 ] || ! command -v launchctl >/dev/null 2>&1; then
  printf 'not bootstrapped (launchctl skipped)\n'
  exit 0
fi

# bootout first so a re-run picks up a changed plist; it fails when the service
# was not loaded, which is fine.
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist"
printf 'bootstrapped %s (every %ss, log: %s)\n' "$label" "$interval" "$log"
