#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$pi_dir/pilot_paths.sh"
fixture_mode=${PI_PILOT_FIXTURE:-0}

[ -x "$pi_pilot_binary" ] || {
  echo "pi-pilot: not installed; run $pi_dir/install.sh" >&2
  exit 2
}
[ ! -L "$pi_pilot_data_dir" ] && [ ! -L "$pi_pilot_state_dir" ] && \
  [ ! -L "$pi_pilot_version_dir" ] && \
  [ -f "$pi_pilot_version_dir/$pi_pilot_marker" ] && \
  [ -f "$pi_pilot_state_dir/$pi_pilot_marker" ] || {
  echo "pi-pilot: refusing unmanaged pilot paths" >&2
  exit 1
}
command -v shasum >/dev/null 2>&1 || {
  echo "pi-pilot: shasum is required to verify the pinned binary" >&2
  exit 2
}
[ "$(shasum -a 256 "$pi_pilot_binary" | awk '{print $1}')" = \
    "$PI_PILOT_BINARY_SHA256" ] || {
  echo "pi-pilot: binary checksum no longer matches the pin" >&2
  exit 1
}

for managed_directory in \
  "$pi_pilot_config_dir" \
  "$pi_pilot_config_dir/extensions" \
  "$pi_pilot_xcode_install_dir" \
  "$pi_pilot_xcode_modules" \
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
settings_target="$pi_pilot_config_dir/settings.json"
if [ "$fixture_mode" != 1 ]; then
  [ -L "$settings_target" ] && \
    [ "$(readlink "$settings_target")" = "$pi_dir/settings.json" ] || {
    echo "pi-pilot: isolated settings link is invalid" >&2
    exit 1
  }
fi
keybindings_target="$pi_pilot_config_dir/keybindings.json"
if [ "$fixture_mode" != 1 ]; then
  [ -L "$keybindings_target" ] && \
    [ "$(readlink "$keybindings_target")" = "$pi_dir/keybindings.json" ] || {
    echo "pi-pilot: isolated keybindings link is invalid" >&2
    exit 1
  }
fi
agents_target="$pi_pilot_config_dir/AGENTS.md"
if [ "$fixture_mode" != 1 ]; then
  [ -L "$agents_target" ] && \
    [ "$(readlink "$agents_target")" = "$pi_pilot_agents_source" ] || {
    echo "pi-pilot: global instructions link is invalid" >&2
    exit 1
  }
fi
for regular_path in \
  "$pi_pilot_config_dir/auth.json" \
  "$pi_pilot_config_dir/models.json" \
  "$pi_pilot_config_dir/models-store.json" \
  "$pi_pilot_config_dir/extensions/herdr-agent-state.ts"
do
  if [ -e "$regular_path" ] || [ -L "$regular_path" ]; then
    [ ! -L "$regular_path" ] && [ -f "$regular_path" ] || {
      echo "pi-pilot: refusing invalid isolated file: $regular_path" >&2
      exit 1
    }
  fi
done
if find "$pi_pilot_config_dir/extensions" -mindepth 1 -maxdepth 1 \
    ! -name 'herdr-agent-state.ts' | grep -q .; then
  echo "pi-pilot: refusing unreviewed global extension inventory" >&2
  exit 1
fi
managed_integration="$pi_pilot_config_dir/extensions/herdr-agent-state.ts"
[ -f "$managed_integration" ] && \
  [ "$(shasum -a 256 "$managed_integration" | awk '{print $1}')" = \
      "$PI_PILOT_HERDR_INTEGRATION_SHA256" ] || {
  echo "pi-pilot: managed Herdr integration checksum is invalid" >&2
  exit 1
}

mkdir -p "$pi_pilot_config_dir" "$pi_pilot_session_dir" \
  "$pi_pilot_control_dir" "$pi_pilot_state_dir/fff/frecency" \
  "$pi_pilot_state_dir/fff/history"
chmod 700 "$pi_pilot_state_dir" "$pi_pilot_config_dir" \
  "$pi_pilot_session_dir" "$pi_pilot_control_dir" \
  "$pi_pilot_state_dir/fff" "$pi_pilot_state_dir/fff/frecency" \
  "$pi_pilot_state_dir/fff/history"

export PI_CODING_AGENT_DIR="$pi_pilot_config_dir"
export PI_CODING_AGENT_SESSION_DIR="$pi_pilot_session_dir"
export PI_PILOT_CONTROL_DIR="$pi_pilot_control_dir"
export PI_FFF_MODE=tools-and-ui
export FFF_FRECENCY_DB="$pi_pilot_state_dir/fff/frecency"
export FFF_HISTORY_DB="$pi_pilot_state_dir/fff/history"
export FFF_ENABLE_ROOT_SCAN=0
unset PI_FFF_MULTIGREP
export PI_TELEMETRY=0
export PI_SKIP_VERSION_CHECK=1

package_command=
case "${1:-}" in
  list)
    package_command=list
    ;;
  install|remove|uninstall|config|update)
    echo "pi-pilot: package mutations are managed by pi/install.sh and repository settings" >&2
    exit 2
    ;;
esac

expect_isolated_locator=0
for argument in "$@"; do
  if [ "$expect_isolated_locator" -eq 1 ]; then
    if [ "$fixture_mode" != 1 ]; then
      case "$argument" in
        ''|*[!A-Za-z0-9._-]*)
          echo "pi-pilot: session and fork locators must be isolated IDs" >&2
          exit 2
          ;;
      esac
    fi
    expect_isolated_locator=0
    continue
  fi
  case "$argument" in
    --session|--session-id|--fork)
      expect_isolated_locator=1
      ;;
    --session=*|--session-id=*|--fork=*)
      locator=${argument#*=}
      if [ "$fixture_mode" != 1 ]; then
        case "$locator" in
          ''|*[!A-Za-z0-9._-]*)
            echo "pi-pilot: session and fork locators must be isolated IDs" >&2
            exit 2
            ;;
        esac
      fi
      ;;
    --session-dir|--session-dir=*|--extension|--extension=*|-e|\
    --skill|--skill=*|--prompt-template|--prompt-template=*|\
    --fff-mode|--fff-mode=*|--fff-frecency-db|--fff-frecency-db=*|\
    --fff-history-db|--fff-history-db=*|\
    --fff-enable-root-scan|--fff-enable-root-scan=*|\
    --approve|-a|--no-approve|-na)
      if [ "$fixture_mode" != 1 ]; then
        echo "pi-pilot: isolation-bypassing option rejected: $argument" >&2
        exit 2
      fi
      ;;
  esac
done
[ "$expect_isolated_locator" -eq 0 ] || {
  echo "pi-pilot: missing session or fork locator" >&2
  exit 2
}

jq -e --arg source "$PI_PILOT_FFF_SOURCE" '
  .packages == [$source]
' "$settings_target" >/dev/null || {
  echo "pi-pilot: package inventory differs from the reviewed pin" >&2
  exit 1
}
pi_pilot_verify_fff || {
  echo "pi-pilot: pinned FFF package verification failed" >&2
  exit 1
}
pi_pilot_verify_xcodebuildmcp || {
  echo "pi-pilot: pinned XcodeBuildMCP package verification failed" >&2
  exit 1
}

export PATH="$pi_dir:$PATH"

if [ -n "$package_command" ]; then
  exec "$pi_pilot_binary" "$@"
fi
exec "$pi_pilot_binary" --no-approve "$@"
