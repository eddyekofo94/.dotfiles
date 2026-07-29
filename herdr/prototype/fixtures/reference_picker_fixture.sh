#!/bin/sh
set -eu

mode=${HERDR_REFERENCE_FIXTURE_MODE:-copy}
case "$mode" in
  cancel) cat >/dev/null; exit 130 ;;
  fail) cat >/dev/null; exit 42 ;;
  copy|open) ;;
  *) echo "unknown reference picker fixture mode: $mode" >&2; exit 64 ;;
esac

kind=${HERDR_REFERENCE_FIXTURE_KIND:?}
reference=${HERDR_REFERENCE_FIXTURE_VALUE:?}
selection=$(awk -F '\t' -v kind="$kind" -v reference="$reference" \
  '$1 == kind && $2 == reference { print; found=1; exit }
   END { if (!found) exit 4 }')
if [ "$mode" = open ]; then
  printf 'ctrl-o\n%s\n' "$selection"
else
  printf '\n%s\n' "$selection"
fi
