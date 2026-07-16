#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
prototype="$root/herdr/prototype"
runtime="$prototype/.runtime"
bin="$runtime/bin/herdr"
config_home="$runtime/c"
session=trial
asset=herdr-macos-aarch64
version=v0.7.4
expected_size=15866512

mkdir -p "$runtime/bin" "$config_home/herdr"

if [ ! -x "$bin" ]; then
  tmp="$bin.download"
  rm -f "$tmp"
  curl -fL "https://github.com/ogulcancelik/herdr/releases/download/$version/$asset" -o "$tmp"
  actual_size=$(wc -c <"$tmp" | tr -d ' ')
  if [ "$actual_size" != "$expected_size" ]; then
    rm -f "$tmp"
    echo "Herdr download size mismatch: expected $expected_size, got $actual_size" >&2
    exit 1
  fi
  chmod 0755 "$tmp"
  mv "$tmp" "$bin"
fi

cp "$prototype/config.toml" "$config_home/herdr/config.toml"

export XDG_CONFIG_HOME="$config_home"
export PATH="$runtime/bin:$PATH"
export HERDR_BIN_PATH="$bin"
export HERDR_SESSION="$session"

if [ "${1:-}" = "cli" ]; then
  shift
  exec "$bin" --session "$session" "$@"
fi

exec "$bin" --session "$session"
