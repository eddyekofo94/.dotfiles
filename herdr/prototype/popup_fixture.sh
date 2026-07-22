#!/bin/sh
set -eu

kind=${1:?popup fixture requires a kind}
case "$kind" in
  scratch|lazygit) ;;
  *) echo "popup fixture: unknown kind $kind" >&2; exit 2 ;;
esac

log=${HERDR_POPUP_LOG:?popup fixture requires HERDR_POPUP_LOG}
set -- $(stty size)
rows=$1
cols=$2

printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$$" "$rows" "$cols" "$PWD" >>"$log"
printf 'HERDR_POPUP_KIND=%s\r\n' "$kind"
printf 'HERDR_POPUP_SIZE=%sx%s\r\n' "$rows" "$cols"
printf 'HERDR_POPUP_READY\r\n'

# Enter dismisses the deterministic fixture by letting its process exit, just
# as exiting the scratch shell or lazygit returns to the tiled workspace.
IFS= read -r _ || true
