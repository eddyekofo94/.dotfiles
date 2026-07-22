#!/bin/sh
set -eu
printf '%s\n' "${1:?URL required}" >>"${HERDR_URL_OPEN_LOG:?URL open log required}"
