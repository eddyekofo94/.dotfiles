#!/bin/sh
set -eu

# The every-couple-of-weeks update for this setup.
#
# `herdr update` downloads the official release straight over ~/.local/bin/herdr.
# That silently discards the reviewed source build, and with it the copy-mode
# patch — alt+s keeps being accepted as a binding and stops doing anything, with
# nothing to explain why. This runs the equivalent update through the reviewed
# path instead: find the newest upstream release, rebase the patch onto it, run
# the gates, re-pin, install, then verify the result.
#
# usage:
#   update.sh            check for a newer release, change nothing
#   update.sh --apply    migrate, build, install, and verify

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
herdr_dir="$root/herdr"
source_build="$herdr_dir/source-build"

apply=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    *)
      echo "usage: update.sh [--apply]" >&2
      exit 64
      ;;
  esac
  shift
done

if [ "$apply" -eq 0 ]; then
  "$source_build/upgrade.sh"
  exit 0
fi

"$source_build/upgrade.sh" --apply --install

# A newer Herdr usually ships newer agent-integration plugins. The old ones keep
# running and quietly report stale agent state, and `integration status` is the
# only place it shows. Refreshing here is safe: only integrations already
# installed are reinstalled, so this never adds an integration you did not have.
herdr_bin=${HERDR_BIN_PATH:-"$HOME/.local/bin/herdr"}
outdated=$(
  "$herdr_bin" integration status 2>/dev/null |
    awk -F: '$2 ~ /outdated/ {print $1}' || true
)
if [ -n "$outdated" ]; then
  echo
  echo "refreshing outdated agent integrations ..."
  for integration in $outdated; do
    echo "  $integration"
    "$herdr_bin" integration install "$integration" >/dev/null
  done
fi

echo
echo "verifying the installed setup ..."
"$herdr_dir/verify.sh"

echo
echo "Herdr update: DONE"
echo "Running servers keep their current executable image. Start a new named"
echo "session to pick up the new binary, or reload config with: sh herdr/reload.sh"
