#!/bin/sh
set -eu

tab=${1:?layout concurrency fixture requires a tab}
sequence=${2:?layout concurrency fixture requires a sequence}
[ "$sequence" -eq 2 ] || exit 0
socket=${HERDR_SOCKET_PATH:?layout concurrency fixture requires the Herdr socket}
request_id="layout-concurrent-$$"
jq -cn --arg id "$request_id" --arg tab "$tab" '{
  id:$id,method:"layout.set_split_ratio",
  params:{tab_id:$tab,path:[],ratio:0.41}
}' | nc -U -w 2 "$socket" |
  jq -e --arg id "$request_id" '
    select(.id == $id and has("result") and (has("error") | not))
  ' >/dev/null
