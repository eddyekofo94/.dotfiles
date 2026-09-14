#!/bin/sh
set -eu
bind=0
header=0
preview=0
single=0
for argument in "$@"; do
  case "$argument" in
    --bind=ctrl-r:reload:*) bind=1 ;;
    --header=*) header=1 ;;
    --preview=*'{3}'*) preview=1 ;;
    --no-multi) single=1 ;;
  esac
done
[ "$bind" -eq 1 ]
[ "$header" -eq 1 ]
[ "$preview" -eq 1 ]
[ "$single" -eq 1 ]
input=$(mktemp "${TMPDIR:-/tmp}/herdr-fzf-open.XXXXXX")
trap 'rm -f -- "$input"' EXIT HUP INT TERM
cat >"$input"
line=$(awk -F "\t" -v expected="$HERDR_FZF_EXPECTED_OPEN" \
  '$3 == expected && $2 ~ / \[open\]/ { print; exit }' "$input")
[ -n "$line" ]
printf '%s\n' "$line"
