#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$pi_dir/pilot_paths.sh"

apply=0
if [ "${1:-}" = "--apply" ]; then
  apply=1
  shift
fi
[ "$#" -eq 0 ] || {
  echo "usage: rollback.sh [--apply]" >&2
  exit 2
}

for managed_root in "$pi_pilot_data_dir" "$pi_pilot_state_dir"; do
  if [ -e "$managed_root" ] || [ -L "$managed_root" ]; then
    if [ -L "$managed_root" ] || [ ! -d "$managed_root" ] || \
        [ ! -f "$managed_root/$pi_pilot_marker" ]; then
      echo "pi-pilot: refusing unmanaged rollback target: $managed_root" >&2
      exit 1
    fi
  fi
done

if [ "$apply" -eq 0 ]; then
  printf 'Pi pilot rollback would move these managed roots to Trash:\n'
  printf '  %s\n  %s\n' "$pi_pilot_data_dir" "$pi_pilot_state_dir"
  exit 0
fi

trash_root=${PI_PILOT_TRASH_DIR:-"$HOME/.Trash"}
mkdir -p "$trash_root"
stamp=${PI_PILOT_ROLLBACK_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}
case "$stamp" in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
  *) echo "pi-pilot: invalid rollback stamp" >&2; exit 2 ;;
esac
data_destination="$trash_root/pi-pilot-$stamp-data"
state_destination="$trash_root/pi-pilot-$stamp-state"

if [ -e "$pi_pilot_data_dir" ] && [ -e "$data_destination" ]; then
  echo "pi-pilot: rollback destination already exists: $data_destination" >&2
  exit 1
fi
if [ -e "$pi_pilot_state_dir" ] && [ -e "$state_destination" ]; then
  echo "pi-pilot: rollback destination already exists: $state_destination" >&2
  exit 1
fi

if [ -e "$pi_pilot_data_dir" ]; then
  mv "$pi_pilot_data_dir" "$data_destination"
  printf 'Moved %s to %s\n' "$pi_pilot_data_dir" "$data_destination"
fi
if [ -e "$pi_pilot_state_dir" ]; then
  mv "$pi_pilot_state_dir" "$state_destination"
  printf 'Moved %s to %s\n' "$pi_pilot_state_dir" "$state_destination"
fi
