#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_TARGET_PANE_ID:-$("$prototype/focused_pane.sh")}
opener=${HERDR_URL_OPENER:-open}

visible=$($herdr pane read "$pane" --source visible --format text)
case "$visible" in
  \{*) content=$(printf '%s\n' "$visible" | jq -r '.result.text // .result.content // empty') ;;
  *) content=$visible ;;
esac
url=$(printf '%s\n' "$content" \
  | perl -nE 'while (m{https?://[^\s<>"'"'"'`]+}g) { push @u, $& } END { if (@u) { $u[-1] =~ s/[),.;:!?]+$//; say $u[-1] } }')

if [ -z "$url" ]; then
  printf 'open-visible-url: no HTTP(S) URL visible in focused pane %s\n' "$pane" >&2
  exit 4
fi

printf '%s\n' "$url"
exec "$opener" "$url"
