#!/bin/sh
set -eu

target=${1:?history path-swap fixture requires a target}
mv -- "$target" "$target.confirmed"
umask 077
case "${HERDR_HISTORY_SWAP_MODE:-replacement}" in
  replacement)
    printf 'UTILITY-UNCONFIRMED-REPLACEMENT\n' >"$target"
    ;;
  dangling)
    ln -s "$target.referent" "$target"
    ;;
  *)
    echo "history path-swap fixture: unknown mode" >&2
    exit 64
    ;;
esac
