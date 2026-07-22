#!/bin/sh
set -eu

if ! command -v brew >/dev/null 2>&1; then
    echo 'rustup bootstrap: Homebrew is required; install Homebrew first' >&2
    exit 69
fi

if ! brew list --formula rustup >/dev/null 2>&1; then
    brew install rustup >&2
fi

rustup_prefix=$(brew --prefix rustup)
rustup_bin=$rustup_prefix/bin/rustup

if ! "$rustup_bin" show active-toolchain >/dev/null 2>&1; then
    "$rustup_bin" default stable >&2
fi

printf '%s\n' "$rustup_prefix/bin"
