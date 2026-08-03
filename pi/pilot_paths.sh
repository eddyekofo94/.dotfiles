#!/bin/sh

# Shared path resolution for the isolated Pi pilot.

if [ -n "${PI_PILOT_REPO:-}" ]; then
  pi_pilot_repo=$PI_PILOT_REPO
else
  pi_pilot_repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fi
pi_pilot_version_file="$pi_pilot_repo/pi/version.env"

[ -r "$pi_pilot_version_file" ] || {
  echo "pi-pilot: missing version metadata" >&2
  exit 2
}

# shellcheck disable=SC1090
. "$pi_pilot_version_file"

pi_pilot_data_dir=${PI_PILOT_DATA_DIR:-"${XDG_DATA_HOME:-"$HOME/.local/share"}/pi-pilot"}
pi_pilot_state_dir=${PI_PILOT_STATE_DIR:-"${XDG_STATE_HOME:-"$HOME/.local/state"}/pi-pilot"}
pi_pilot_version_dir="$pi_pilot_data_dir/versions/$PI_PILOT_VERSION"
pi_pilot_binary="$pi_pilot_version_dir/pi"
pi_pilot_config_dir="$pi_pilot_state_dir/config"
pi_pilot_session_dir="$pi_pilot_state_dir/sessions"
pi_pilot_control_dir="$pi_pilot_state_dir/control"
pi_pilot_marker=.eddy-pi-pilot
pi_pilot_agents_source="$pi_pilot_repo/pi/AGENTS.md"
pi_pilot_herdr_integration_source="$pi_pilot_repo/pi/integrations/herdr-agent-state.ts"
pi_pilot_fff_manifest_dir="$pi_pilot_repo/pi/packages/fff"
pi_pilot_xcode_manifest_dir="$pi_pilot_repo/pi/packages/xcodebuildmcp"
pi_pilot_xcode_install_dir="$pi_pilot_config_dir/xcodebuildmcp"
pi_pilot_xcode_modules="$pi_pilot_xcode_install_dir/node_modules"
pi_pilot_xcode_package="$pi_pilot_xcode_modules/xcodebuildmcp"
pi_pilot_xcode_cli="$pi_pilot_xcode_package/build/cli.js"
pi_pilot_xcode_doctor="$pi_pilot_xcode_package/build/doctor-cli.js"
pi_pilot_xcode_runtime_dir="$pi_pilot_state_dir/xcodebuildmcp"

pi_pilot_verify_fff() {
  fff_root="$pi_pilot_config_dir/npm/node_modules/@ff-labs/pi-fff"
  fff_modules="$pi_pilot_config_dir/npm/node_modules"
  fff_manifest="$pi_pilot_config_dir/npm/package.json"
  fff_lock="$pi_pilot_config_dir/npm/package-lock.json"
  [ ! -L "$pi_pilot_config_dir/npm" ] && \
    [ -d "$pi_pilot_config_dir/npm" ] && \
    [ ! -L "$fff_modules" ] && [ -d "$fff_modules" ] && \
    [ ! -L "$fff_root" ] && [ -d "$fff_root" ] && \
    [ ! -L "$fff_manifest" ] && [ -f "$fff_manifest" ] && \
    [ ! -L "$fff_lock" ] && [ -f "$fff_lock" ] || return 1
  if find "$fff_modules" -type l | grep -q .; then
    return 1
  fi
  cmp -s "$pi_pilot_fff_manifest_dir/package.json" \
    "$fff_manifest" || return 1
  cmp -s "$pi_pilot_fff_manifest_dir/package-lock.json" \
    "$fff_lock" || return 1
  [ "$(find "$fff_root" -type f | wc -l | tr -d ' ')" -eq 6 ] || return 1
  jq -e \
    --arg version "$PI_PILOT_FFF_VERSION" \
    --arg integrity "$PI_PILOT_FFF_INTEGRITY" '
      .packages["node_modules/@ff-labs/pi-fff"].version == $version and
      .packages["node_modules/@ff-labs/pi-fff"].integrity == $integrity
    ' "$fff_lock" >/dev/null || return 1
  [ "$(jq -r '.version' "$fff_root/package.json")" = \
    "$PI_PILOT_FFF_VERSION" ] || return 1
  fff_source_sha=$(
    cd "$fff_root"
    find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 |
      shasum -a 256 |
      awk '{print $1}'
  )
  [ "$fff_source_sha" = "$PI_PILOT_FFF_SOURCE_SHA256" ] || return 1
  [ "$(find "$fff_modules" -type f | wc -l | tr -d ' ')" -eq \
    "$PI_PILOT_FFF_TREE_FILES" ] || return 1
  fff_tree_sha=$(
    cd "$fff_modules"
    find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 |
      shasum -a 256 |
      awk '{print $1}'
  )
  [ "$fff_tree_sha" = "$PI_PILOT_FFF_TREE_SHA256" ]
}

pi_pilot_verify_xcodebuildmcp() {
  [ ! -L "$pi_pilot_xcode_install_dir" ] && \
    [ -d "$pi_pilot_xcode_install_dir" ] && \
    [ ! -L "$pi_pilot_xcode_modules" ] && \
    [ -d "$pi_pilot_xcode_modules" ] && \
    [ ! -L "$pi_pilot_xcode_package" ] && \
    [ -d "$pi_pilot_xcode_package" ] && \
    [ ! -L "$pi_pilot_xcode_install_dir/package.json" ] && \
    [ -f "$pi_pilot_xcode_install_dir/package.json" ] && \
    [ ! -L "$pi_pilot_xcode_install_dir/package-lock.json" ] && \
    [ -f "$pi_pilot_xcode_install_dir/package-lock.json" ] && \
    [ ! -L "$pi_pilot_xcode_cli" ] && [ -f "$pi_pilot_xcode_cli" ] && \
    [ ! -L "$pi_pilot_xcode_doctor" ] && [ -f "$pi_pilot_xcode_doctor" ] || return 1
  if find "$pi_pilot_xcode_modules" -type l | grep -q .; then
    return 1
  fi
  cmp -s "$pi_pilot_xcode_manifest_dir/package.json" \
    "$pi_pilot_xcode_install_dir/package.json" || return 1
  cmp -s "$pi_pilot_xcode_manifest_dir/package-lock.json" \
    "$pi_pilot_xcode_install_dir/package-lock.json" || return 1
  jq -e \
    --arg version "$PI_PILOT_XCODEBUILDMCP_VERSION" \
    --arg integrity "$PI_PILOT_XCODEBUILDMCP_INTEGRITY" '
      .packages["node_modules/xcodebuildmcp"].version == $version and
      .packages["node_modules/xcodebuildmcp"].integrity == $integrity
    ' "$pi_pilot_xcode_install_dir/package-lock.json" >/dev/null || return 1
  [ "$(jq -r '.version' "$pi_pilot_xcode_package/package.json")" = \
    "$PI_PILOT_XCODEBUILDMCP_VERSION" ] || return 1
  [ "$(find "$pi_pilot_xcode_package" -type f | wc -l | tr -d ' ')" -eq \
    "$PI_PILOT_XCODEBUILDMCP_SOURCE_FILES" ] || return 1
  pi_pilot_xcode_source_sha=$(
    cd "$pi_pilot_xcode_package"
    find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 |
      shasum -a 256 |
      awk '{print $1}'
  )
  [ "$pi_pilot_xcode_source_sha" = \
    "$PI_PILOT_XCODEBUILDMCP_SOURCE_SHA256" ] || return 1
  [ "$(find "$pi_pilot_xcode_modules" -type f | wc -l | tr -d ' ')" -eq \
    "$PI_PILOT_XCODEBUILDMCP_TREE_FILES" ] || return 1
  pi_pilot_xcode_tree_sha=$(
    cd "$pi_pilot_xcode_modules"
    find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 |
      shasum -a 256 |
      awk '{print $1}'
  )
  [ "$pi_pilot_xcode_tree_sha" = \
    "$PI_PILOT_XCODEBUILDMCP_TREE_SHA256" ] || return 1
  [ "$(shasum -a 256 \
      "$pi_pilot_xcode_package/skills/xcodebuildmcp-cli/SKILL.md" |
      awk '{print $1}')" = "$PI_PILOT_XCODEBUILDMCP_SKILL_SHA256" ] || return 1
  cmp -s "$pi_pilot_repo/pi/skills/xcodebuildmcp-cli/SKILL.md" \
    "$pi_pilot_xcode_package/skills/xcodebuildmcp-cli/SKILL.md" || return 1
  [ "$(shasum -a 256 "$pi_pilot_xcode_package/LICENSE" | awk '{print $1}')" = \
    "$PI_PILOT_XCODEBUILDMCP_LICENSE_SHA256" ]
}
