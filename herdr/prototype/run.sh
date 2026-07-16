#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
prototype="$root/herdr/prototype"
runtime="$prototype/.runtime"
bin="$runtime/bin/herdr"
border_style=compact

if [ "${1:-}" = "--border" ]; then
  if [ "$#" -lt 2 ]; then
    echo "--border requires compact, boxed, focused, or borderless" >&2
    exit 2
  fi
  border_style=$2
  shift 2
fi

case "$border_style" in
  compact)
    config_home="$runtime/c"
    session=trial
    ;;
  boxed)
    config_home="$runtime/cb"
    session=trial-boxed
    ;;
  focused)
    config_home="$runtime/cf"
    session=trial-focused
    ;;
  borderless)
    config_home="$runtime/cl"
    session=trial-borderless
    ;;
  *)
    echo "unknown border style: $border_style (expected compact, boxed, focused, or borderless)" >&2
    exit 2
    ;;
esac

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

case "$border_style" in
  compact)
    cp "$prototype/config.toml" "$config_home/herdr/config.toml"
    ;;
  boxed)
    sed 's/^pane_gaps = false$/pane_gaps = true/' \
      "$prototype/config.toml" >"$config_home/herdr/config.toml"
    ;;
  focused)
    sed 's/^pane_gaps = false$/pane_gaps = true/' \
      "$prototype/config.toml" >"$config_home/herdr/config.toml"
    printf '\n[theme.custom]\noverlay0 = "#1e1e2e"\n' \
      >>"$config_home/herdr/config.toml"
    while read -r key direction; do
      printf '\n[[keys.command]]\nkey = "alt+%s"\ntype = "shell"\ncommand = "%s/smart_nav.sh %s %s"\ndescription = "prototype smart Neovim or Herdr navigation"\n' \
        "$key" "$prototype" "$key" "$direction" >>"$config_home/herdr/config.toml"
    done <<'EOF'
h left
j down
k up
l right
EOF
    ;;
  borderless)
    sed 's/^pane_borders = true$/pane_borders = false/' \
      "$prototype/config.toml" >"$config_home/herdr/config.toml"
    ;;
esac

export XDG_CONFIG_HOME="$config_home"
export PATH="$runtime/bin:$PATH"
export HERDR_BIN_PATH="$bin"
export HERDR_SESSION="$session"

if [ "${1:-}" = "cli" ]; then
  shift
  exec "$bin" --session "$session" "$@"
fi

exec "$bin" --session "$session"
