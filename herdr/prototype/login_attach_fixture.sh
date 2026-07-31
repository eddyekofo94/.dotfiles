#!/bin/sh
set -eu

log=${HERDR_LOGIN_ATTACH_LOG:?login attach fixture requires a log path}
jq -cn --args '$ARGS.positional' -- "$@" >>"$log"

if [ -n "${HERDR_LOGIN_ATTACH_CWD_LOG:-}" ]; then
  pwd -P >"$HERDR_LOGIN_ATTACH_CWD_LOG"
fi

if [ -n "${HERDR_LOGIN_ATTACH_STDIN_LOG:-}" ]; then
  IFS= read -r stdin_line || stdin_line=
  printf '%s\n' "$stdin_line" >"$HERDR_LOGIN_ATTACH_STDIN_LOG"
fi

if [ -n "${HERDR_LOGIN_ATTACH_HOLD_DIR:-}" ]; then
  mkdir -p "$HERDR_LOGIN_ATTACH_HOLD_DIR"
  : >"$HERDR_LOGIN_ATTACH_HOLD_DIR/ready.$$"
  while [ ! -e "$HERDR_LOGIN_ATTACH_HOLD_DIR/release" ]; do
    sleep 0.02
  done
fi
