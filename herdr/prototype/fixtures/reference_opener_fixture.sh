#!/bin/sh
set -eu

log=${HERDR_REFERENCE_OPEN_LOG:?}
printf '%s\n' "${1:?}" >>"$log"
