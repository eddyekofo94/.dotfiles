#!/bin/sh
set -eu

# PROTOTYPE ONLY: retain the established equalize entry point while routing it
# through the guarded process-preserving preset implementation.

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$prototype/layout_preset.sh" tiled
