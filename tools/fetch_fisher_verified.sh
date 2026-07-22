#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fisher_commit=a04308be92daa6cfecdbb0ca58b1e8508664cff2
fisher_sha256=0fb6c81ae3003e95b5671766fa6c25c3597066e29965b7772f6c1b007387356d
fisher_url="https://raw.githubusercontent.com/jorgebucaran/fisher/$fisher_commit/functions/fisher.fish"

exec /bin/sh "$repo_dir/tools/fetch_verified.sh" "$fisher_url" "$fisher_sha256"
