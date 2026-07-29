#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=v0.7.4
asset=herdr-macos-aarch64
url="https://github.com/ogulcancelik/herdr/releases/download/$version/$asset"
expected_sha256=24992e1625dbdcb18354a59e299e4b263c312400b31396cdc07cd46ed57f24a7
install_bin=${HERDR_INSTALL_BIN:-"$HOME/.local/bin/herdr"}
config_dir=${HERDR_CONFIG_DIR:-"${XDG_CONFIG_HOME:-$HOME/.config}/herdr"}
config_link="$config_dir/config.toml"
config_target=${HERDR_CONFIG_TARGET:-"$root/herdr/config.toml"}
source_path=${HERDR_INSTALL_SOURCE:-}
activate=${HERDR_ACTIVATE:-1}

case "$activate" in
  0|1) ;;
  *) echo "HERDR_ACTIVATE must be 0 or 1" >&2; exit 64 ;;
esac

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-install.XXXXXX")
tmp_bin="$tmp_dir/herdr"
staged_install=
staged_link=
created_bin=0
created_link=0
cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  rm -rf -- "$tmp_dir"
  if [ "$status" -ne 0 ]; then
    [ -z "$staged_install" ] || rm -f -- "$staged_install"
    [ -z "$staged_link" ] || rm -f -- "$staged_link"
    [ "$created_link" -eq 0 ] || rm -f -- "$config_link"
    [ "$created_bin" -eq 0 ] || rm -f -- "$install_bin"
  fi
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

if [ -n "$source_path" ]; then
  cp "$source_path" "$tmp_bin"
else
  /bin/sh "$root/tools/fetch_verified.sh" "$url" "$expected_sha256" >"$tmp_bin"
fi

actual_sha256=$(shasum -a 256 "$tmp_bin" | awk '{print $1}')
if [ "$actual_sha256" != "$expected_sha256" ]; then
  echo "Herdr SHA-256 mismatch" >&2
  echo "expected: $expected_sha256" >&2
  echo "actual:   $actual_sha256" >&2
  exit 66
fi

# Resolve every refusal and validate the staged artifact before touching either
# live target.
if [ -L "$config_link" ]; then
  if [ "$(readlink "$config_link")" != "$config_target" ]; then
    echo "refusing to replace unrelated Herdr config link: $config_link" >&2
    exit 73
  fi
elif [ -e "$config_link" ]; then
  echo "refusing to replace existing Herdr config: $config_link" >&2
  exit 73
fi

HERDR_PROTOTYPE_DIR="$root/herdr/prototype" \
HERDR_BIN_PATH="$tmp_bin" \
HERDR_CONFIG_PATH="$config_target" \
  "$tmp_bin" config check >/dev/null

if [ -e "$install_bin" ] || [ -L "$install_bin" ]; then
  existing_sha256=$(shasum -a 256 "$install_bin" 2>/dev/null | awk '{print $1}')
  if [ "$existing_sha256" != "$expected_sha256" ]; then
    echo "refusing to replace unrelated Herdr binary: $install_bin" >&2
    exit 73
  fi
fi

mkdir -p "$(dirname -- "$install_bin")" "$config_dir"
if [ ! -e "$install_bin" ]; then
  staged_install=$(mktemp "$(dirname -- "$install_bin")/.herdr.XXXXXX")
  install -m 0755 "$tmp_bin" "$staged_install"
  mv "$staged_install" "$install_bin"
  staged_install=
  created_bin=1
fi
if [ ! -e "$config_link" ] && [ ! -L "$config_link" ]; then
  staged_link="$config_dir/.config.toml.$$"
  ln -s "$config_target" "$staged_link"
  mv "$staged_link" "$config_link"
  staged_link=
  created_link=1
fi

if [ "$activate" -eq 1 ]; then
  HERDR_CONFIG_DIR="$config_dir" "$root/herdr/set_default.sh" herdr >/dev/null
fi

printf 'installed %s at %s\n' "$($install_bin --version)" "$install_bin"
printf 'config: %s -> %s\n' "$config_link" "$config_target"
printf 'the first named-session attach provisions the tracked golden-focus plugin\n'
