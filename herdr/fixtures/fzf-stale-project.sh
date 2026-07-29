#!/bin/sh
set -eu

target=${HERDR_FZF_STALE_TARGET:?stale target required}
selected=
while IFS= read -r line; do
  path=$(printf '%s\n' "$line" | awk -F "	" '{print $3}')
  [ "$path" = "$target" ] && selected=$line
done
[ -n "$selected" ] || exit 2
mv -- "$target" "$target.removed"
printf '%s\n' "$selected"
