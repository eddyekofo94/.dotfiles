#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$pi_dir/pilot_paths.sh"

[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || {
  echo "pi-pilot: the pinned standalone artifact supports only arm64 macOS" >&2
  exit 2
}

for required in curl jq shasum tar npm patch; do
  command -v "$required" >/dev/null 2>&1 || {
    echo "pi-pilot: required command is unavailable: $required" >&2
    exit 2
  }
done

for managed_root in "$pi_pilot_data_dir" "$pi_pilot_state_dir"; do
  if [ -e "$managed_root" ] || [ -L "$managed_root" ]; then
    [ ! -L "$managed_root" ] && [ -d "$managed_root" ] && \
      [ -f "$managed_root/$pi_pilot_marker" ] || {
        echo "pi-pilot: refusing unmanaged existing root: $managed_root" >&2
        exit 1
      }
  fi
done

mkdir -p "$pi_pilot_data_dir" "$pi_pilot_state_dir"
chmod 700 "$pi_pilot_data_dir" "$pi_pilot_state_dir"
: >"$pi_pilot_state_dir/$pi_pilot_marker"
: >"$pi_pilot_data_dir/$pi_pilot_marker"

install_parent=$(dirname -- "$pi_pilot_version_dir")
for managed_directory in \
  "$install_parent" \
  "$pi_pilot_config_dir" \
  "$pi_pilot_config_dir/extensions" \
  "$pi_pilot_config_dir/npm" \
  "$pi_pilot_xcode_install_dir" \
  "$pi_pilot_session_dir" \
  "$pi_pilot_control_dir" \
  "$pi_pilot_xcode_runtime_dir" \
  "$pi_pilot_xcode_runtime_dir/home" \
  "$pi_pilot_xcode_runtime_dir/tmp" \
  "$pi_pilot_xcode_runtime_dir/run" \
  "$pi_pilot_state_dir/fff" \
  "$pi_pilot_state_dir/fff/frecency" \
  "$pi_pilot_state_dir/fff/history"
do
  if [ -e "$managed_directory" ] || [ -L "$managed_directory" ]; then
    [ ! -L "$managed_directory" ] && [ -d "$managed_directory" ] || {
      echo "pi-pilot: refusing invalid managed directory: $managed_directory" >&2
      exit 1
    }
  fi
done
mkdir -p "$install_parent" "$pi_pilot_config_dir/extensions" \
  "$pi_pilot_config_dir/npm" "$pi_pilot_xcode_install_dir" \
  "$pi_pilot_session_dir" \
  "$pi_pilot_control_dir" "$pi_pilot_state_dir/fff/frecency" \
  "$pi_pilot_state_dir/fff/history" "$pi_pilot_xcode_runtime_dir/home" \
  "$pi_pilot_xcode_runtime_dir/tmp" "$pi_pilot_xcode_runtime_dir/run"
chmod 700 "$pi_pilot_config_dir" "$pi_pilot_config_dir/extensions" \
  "$pi_pilot_config_dir/npm" "$pi_pilot_xcode_install_dir" \
  "$pi_pilot_session_dir" \
  "$pi_pilot_control_dir" "$pi_pilot_state_dir/fff" \
  "$pi_pilot_state_dir/fff/frecency" "$pi_pilot_state_dir/fff/history" \
  "$pi_pilot_xcode_runtime_dir" "$pi_pilot_xcode_runtime_dir/home" \
  "$pi_pilot_xcode_runtime_dir/tmp" "$pi_pilot_xcode_runtime_dir/run"

if [ -e "$pi_pilot_version_dir" ] || [ -L "$pi_pilot_version_dir" ]; then
  [ ! -L "$pi_pilot_version_dir" ] && [ -d "$pi_pilot_version_dir" ] || {
    echo "pi-pilot: refusing invalid existing version path" >&2
    exit 1
  }
  [ -f "$pi_pilot_version_dir/$pi_pilot_marker" ] || {
    echo "pi-pilot: refusing unmanaged existing version directory" >&2
    exit 1
  }
  [ -x "$pi_pilot_binary" ] || {
    echo "pi-pilot: managed version directory is incomplete" >&2
    exit 1
  }
  [ "$("$pi_pilot_binary" --version)" = "$PI_PILOT_VERSION" ] || {
    echo "pi-pilot: installed binary version does not match the pin" >&2
    exit 1
  }
  [ "$(shasum -a 256 "$pi_pilot_binary" | awk '{print $1}')" = \
      "$PI_PILOT_BINARY_SHA256" ] || {
    echo "pi-pilot: installed binary checksum does not match the pin" >&2
    exit 1
  }
else
  download_dir=$(mktemp -d "${TMPDIR:-/tmp}/pi-pilot-install.XXXXXX")
  cleanup() {
    rm -rf "$download_dir"
  }
  trap cleanup EXIT HUP INT TERM

  curl -fsSL -o "$download_dir/$PI_PILOT_ARCHIVE" \
    "$PI_PILOT_RELEASE_URL/$PI_PILOT_ARCHIVE"
  actual_sha=$(shasum -a 256 "$download_dir/$PI_PILOT_ARCHIVE" | awk '{print $1}')
  [ "$actual_sha" = "$PI_PILOT_SHA256" ] || {
    echo "pi-pilot: release checksum mismatch" >&2
    exit 1
  }

  tar -xzf "$download_dir/$PI_PILOT_ARCHIVE" -C "$download_dir"
  [ -x "$download_dir/pi/pi" ] || {
    echo "pi-pilot: release archive did not contain the expected binary" >&2
    exit 1
  }
  [ "$("$download_dir/pi/pi" --version)" = "$PI_PILOT_VERSION" ] || {
    echo "pi-pilot: release binary version does not match the pin" >&2
    exit 1
  }
  [ "$(shasum -a 256 "$download_dir/pi/pi" | awk '{print $1}')" = \
      "$PI_PILOT_BINARY_SHA256" ] || {
    echo "pi-pilot: extracted binary checksum does not match the pin" >&2
    exit 1
  }

  mv "$download_dir/pi" "$pi_pilot_version_dir"
  : >"$pi_pilot_version_dir/$pi_pilot_marker"
fi

settings_target="$pi_pilot_config_dir/settings.json"
if [ -e "$settings_target" ] || [ -L "$settings_target" ]; then
  if [ ! -L "$settings_target" ] || \
      [ "$(readlink "$settings_target")" != "$pi_dir/settings.json" ]; then
    echo "pi-pilot: refusing to replace existing pilot settings" >&2
    exit 1
  fi
else
  ln -s "$pi_dir/settings.json" "$settings_target"
fi

keybindings_target="$pi_pilot_config_dir/keybindings.json"
if [ -e "$keybindings_target" ] || [ -L "$keybindings_target" ]; then
  if [ ! -L "$keybindings_target" ] || \
      [ "$(readlink "$keybindings_target")" != "$pi_dir/keybindings.json" ]; then
    echo "pi-pilot: refusing to replace existing pilot keybindings" >&2
    exit 1
  fi
else
  ln -s "$pi_dir/keybindings.json" "$keybindings_target"
fi

agents_target="$pi_pilot_config_dir/AGENTS.md"
if [ -e "$agents_target" ] || [ -L "$agents_target" ]; then
  if [ ! -L "$agents_target" ] || \
      [ "$(readlink "$agents_target")" != "$pi_pilot_agents_source" ]; then
    echo "pi-pilot: refusing to replace existing global instructions" >&2
    exit 1
  fi
else
  ln -s "$pi_pilot_agents_source" "$agents_target"
fi

managed_integration="$pi_pilot_config_dir/extensions/herdr-agent-state.ts"
if find "$pi_pilot_config_dir/extensions" -mindepth 1 -maxdepth 1 \
    ! -name 'herdr-agent-state.ts' | grep -q .; then
  echo "pi-pilot: refusing unreviewed global extension inventory" >&2
  exit 1
fi
if [ -L "$managed_integration" ] || \
   { [ -e "$managed_integration" ] && [ ! -f "$managed_integration" ]; }; then
  echo "pi-pilot: refusing invalid managed Herdr integration path" >&2
  exit 1
fi

[ "$(shasum -a 256 "$pi_pilot_herdr_integration_source" | awk '{print $1}')" = \
    "$PI_PILOT_HERDR_INTEGRATION_SHA256" ] || {
  echo "pi-pilot: repository Herdr integration checksum is not pinned" >&2
  exit 1
}
cp "$pi_pilot_herdr_integration_source" "$managed_integration"

[ -s "$managed_integration" ] || {
  echo "pi-pilot: repository Herdr integration is empty" >&2
  exit 1
}
[ "$(shasum -a 256 "$managed_integration" | awk '{print $1}')" = \
    "$PI_PILOT_HERDR_INTEGRATION_SHA256" ] || {
  echo "pi-pilot: managed Herdr integration checksum is not pinned" >&2
  exit 1
}

for npm_path in \
  "$pi_pilot_config_dir/npm/package.json" \
  "$pi_pilot_config_dir/npm/package-lock.json" \
  "$pi_pilot_config_dir/npm/node_modules"
do
  if [ -e "$npm_path" ] || [ -L "$npm_path" ]; then
    [ ! -L "$npm_path" ] || {
      echo "pi-pilot: refusing symlinked FFF package state: $npm_path" >&2
      exit 1
    }
  fi
done
cp "$pi_pilot_fff_manifest_dir/package.json" \
  "$pi_pilot_config_dir/npm/package.json"
cp "$pi_pilot_fff_manifest_dir/package-lock.json" \
  "$pi_pilot_config_dir/npm/package-lock.json"
(
  cd "$pi_pilot_config_dir/npm"
  npm ci --ignore-scripts --legacy-peer-deps >/dev/null
)
patch -s -V none -d "$pi_pilot_config_dir/npm/node_modules/@ff-labs/pi-fff" -p1 \
  <"$pi_pilot_fff_manifest_dir/fixed-tools-and-ui.patch"
pi_pilot_verify_fff || {
  echo "pi-pilot: pinned FFF package verification failed" >&2
  exit 1
}

for xcode_path in \
  "$pi_pilot_xcode_install_dir/package.json" \
  "$pi_pilot_xcode_install_dir/package-lock.json" \
  "$pi_pilot_xcode_modules"
do
  if [ -e "$xcode_path" ] || [ -L "$xcode_path" ]; then
    [ ! -L "$xcode_path" ] || {
      echo "pi-pilot: refusing symlinked XcodeBuildMCP package state: $xcode_path" >&2
      exit 1
    }
  fi
done
cp "$pi_pilot_xcode_manifest_dir/package.json" \
  "$pi_pilot_xcode_install_dir/package.json"
cp "$pi_pilot_xcode_manifest_dir/package-lock.json" \
  "$pi_pilot_xcode_install_dir/package-lock.json"
(
  cd "$pi_pilot_xcode_install_dir"
  npm ci --ignore-scripts --no-bin-links --omit=dev >/dev/null
)
pi_pilot_verify_xcodebuildmcp || {
  echo "pi-pilot: pinned XcodeBuildMCP package verification failed" >&2
  exit 1
}

printf 'Pi pilot %s installed.\n' "$PI_PILOT_VERSION"
printf 'Binary: %s\n' "$pi_pilot_binary"
printf 'Config: %s\n' "$pi_pilot_config_dir"
printf 'Sessions: %s\n' "$pi_pilot_session_dir"
printf 'XcodeBuildMCP: %s\n' "$pi_pilot_xcode_cli"
