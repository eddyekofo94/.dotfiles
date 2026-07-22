#!/bin/sh
set -eu

log=${HERDR_LOGIN_ATTACH_LOG:?login attach fixture requires a log path}
jq -cn --args '$ARGS.positional' -- "$@" >>"$log"
