#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
prototype="$root/herdr/prototype"
runtime="$prototype/.runtime"
bin="$runtime/bin/herdr"
border_style=compact
user_config_home=${HERDR_PROTOTYPE_USER_CONFIG_HOME:-"$HOME/.config"}

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

source_build="$root/herdr/source-build"

# pins.env is the single source of truth for which Herdr this machine runs.
# Reading it here (rather than hardcoding a version) keeps the download
# fallback on the same release as the reviewed source build: a stale constant
# here would silently hand a prototype trial the wrong binary whenever the
# cached one is missing, which invalidates any version-specific evidence.
# shellcheck source=/dev/null
. "$source_build/pins.env"
asset=$HERDR_OFFICIAL_ASSET
version=$HERDR_SOURCE_TAG

mkdir -p "$runtime/bin" "$config_home/herdr"

if [ ! -x "$bin" ]; then
  reviewed_bin="$source_build/.work/bin/herdr"
  if [ -x "$reviewed_bin" ]; then
    reviewed_sha=$(shasum -a 256 "$reviewed_bin" | awk '{print $1}')
    if [ "$reviewed_sha" != "$HERDR_BINARY_SHA256" ]; then
      echo "reviewed Herdr source-build binary hash mismatch" >&2
      exit 1
    fi
    tmp="$bin.reviewed"
    install -m 0755 "$reviewed_bin" "$tmp"
  else
    tmp="$bin.download"
    curl -fL "https://github.com/ogulcancelik/herdr/releases/download/$version/$asset" -o "$tmp"
    actual_sha=$(shasum -a 256 "$tmp" | awk '{print $1}')
    if [ "$actual_sha" != "$HERDR_OFFICIAL_SHA256" ]; then
      rm -f "$tmp"
      echo "Herdr download hash mismatch: expected $HERDR_OFFICIAL_SHA256, got $actual_sha" >&2
      exit 1
    fi
    chmod 0755 "$tmp"
  fi
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
    # Leave Alt unbound here so Ghostty can pass the physical chord through to
    # Neovim or Fish. Both Herdr-level interception attempts broke this path.
    printf '\n[[keys.command]]\nkey = "prefix+shift+g"\ntype = "plugin_action"\ncommand = "prototype.golden-focus.toggle"\ndescription = "toggle prototype 62 percent golden focus"\n' \
      >>"$config_home/herdr/config.toml"
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
export HERDR_NAV_LOG="$runtime/nav-events.log"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_PROTOTYPE_USER_CONFIG_HOME="$user_config_home"

if [ "${1:-}" = "cli" ]; then
  shift
  exec "$bin" --session "$session" "$@"
fi

exec "$bin" --session "$session"
