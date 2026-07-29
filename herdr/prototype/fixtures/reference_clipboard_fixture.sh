#!/bin/sh
set -eu

log=${HERDR_REFERENCE_CLIPBOARD_LOG:?}
value=$(cat)
printf '%s\n' "$value" >>"$log"
