#!/bin/sh
set -eu

log=${HERDR_RECOVERY_AGENT_LOG:?recovery agent fixture requires a log}
printf '%s\n' "$@" >"$log"
printf 'RECOVERY_AGENT_RESUMED\n'
exec sleep 300
