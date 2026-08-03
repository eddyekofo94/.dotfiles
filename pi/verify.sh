#!/bin/sh
set -eu

pi_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$pi_dir/.." && pwd)
mkdir -p "$pi_dir/.runtime"
runtime=$(mktemp -d "$pi_dir/.runtime/verify.XXXXXX")
cleanup() { rm -rf "$runtime"; }
trap cleanup EXIT HUP INT TERM

# Verification must never reinstall packages in the state used by a physical
# Pi session. Reuse the pinned binary, but build all mutable state separately.
export PI_PILOT_STATE_DIR="$runtime/pilot-state"
# shellcheck disable=SC1091
. "$pi_dir/pilot_paths.sh"
rpc_log="$runtime/rpc.jsonl"
export PI_PILOT_EVIDENCE_DIR="$runtime/evidence"
mkdir -p "$PI_PILOT_EVIDENCE_DIR"
[ "$pi_pilot_state_dir" = "$runtime/pilot-state" ] || {
  echo "pi-pilot: verification state is not isolated" >&2
  exit 1
}

git -C "$root" check-ignore -q pi/.runtime/generated-auth.json || {
  echo "pi-pilot: disposable runtime is not ignored" >&2
  exit 1
}

"$root/agent-config/tests/install_test.sh"
"$root/agent-config/verify.sh"

for script in "$pi_dir"/*.sh "$pi_dir"/tests/*.sh; do
  sh -n "$script"
done
python3 -m py_compile \
  "$pi_dir/benchmark_runtime.py" \
  "$pi_dir/benchmark_provider.py" \
  "$pi_dir/tests/session_validation.py"
jq -e '
  .defaultProjectTrust == "never" and
  .enableInstallTelemetry == false and
  .enableAnalytics == false and
  .packages == ["npm:@ff-labs/pi-fff@0.10.1"] and
  (.skills | sort) == [
    "/Users/eddyekofo/.agent-skills/herdr",
    "/Users/eddyekofo/.agent-skills/skill-finish",
    "/Users/eddyekofo/.agent-skills/swift-concurrency-expert",
    "/Users/eddyekofo/.agent-skills/swiftui-liquid-glass",
    "/Users/eddyekofo/.agent-skills/swiftui-performance-audit",
    "/Users/eddyekofo/.agent-skills/swiftui-view-refactor",
    "/Users/eddyekofo/.dotfiles/pi/skills/xcodebuildmcp-cli"
  ] and
  (.extensions | length) == 1
' "$pi_dir/settings.json" >/dev/null

node "$pi_dir/tests/compat_core_test.mjs"
node "$pi_dir/tests/ui_core_test.mjs"
"$pi_dir/tests/keybindings_test.sh"
"$pi_dir/tests/theme_ui_test.sh"
"$pi_dir/tests/verify_isolation_test.sh"
"$pi_dir/tests/verification_concurrency_test.sh"

"$pi_dir/install.sh" >/dev/null
"$pi_dir/install.sh" >/dev/null
test -L "$pi_pilot_config_dir/AGENTS.md"
test "$(readlink "$pi_pilot_config_dir/AGENTS.md")" = "$pi_pilot_agents_source"

rm "$pi_pilot_config_dir/AGENTS.md"
if "$pi_dir/pilot.sh" --version >/dev/null 2>&1; then
  echo "pi-pilot: launcher accepted missing global instructions" >&2
  exit 1
fi
ln -s /tmp/unreviewed-pi-agents "$pi_pilot_config_dir/AGENTS.md"
if "$pi_dir/pilot.sh" --version >/dev/null 2>&1; then
  echo "pi-pilot: launcher accepted retargeted global instructions" >&2
  exit 1
fi
rm "$pi_pilot_config_dir/AGENTS.md"
cp "$pi_pilot_agents_source" "$pi_pilot_config_dir/AGENTS.md"
if "$pi_dir/pilot.sh" --version >/dev/null 2>&1; then
  echo "pi-pilot: launcher accepted regular global instructions" >&2
  exit 1
fi
rm "$pi_pilot_config_dir/AGENTS.md"
ln -s "$pi_pilot_agents_source" "$pi_pilot_config_dir/AGENTS.md"
test "$(PI_PILOT_REPO="$root" "$pi_dir/xcodebuildmcp" --version)" = 2.7.0
cmp -s "$pi_dir/skills/xcodebuildmcp-cli/SKILL.md" \
  "$pi_pilot_xcode_package/skills/xcodebuildmcp-cli/SKILL.md"
grep -Fq 'npm ci --ignore-scripts --no-bin-links --omit=dev' \
  "$pi_dir/install.sh"
for deferred_mode in \
  mcp init setup upgrade --socket=/tmp/outside --output-format=mcp-json
do
  if PI_PILOT_REPO="$root" "$pi_dir/xcodebuildmcp" \
      "$deferred_mode" >/dev/null 2>&1; then
    echo "pi-pilot: deferred XcodeBuildMCP mode was accepted: $deferred_mode" >&2
    exit 1
  fi
done
xcode_license_backup="$runtime/xcodebuildmcp-license"
cp "$pi_pilot_xcode_package/LICENSE" "$xcode_license_backup"
printf '\n' >>"$pi_pilot_xcode_package/LICENSE"
if PI_PILOT_REPO="$root" "$pi_dir/xcodebuildmcp" --version >/dev/null 2>&1; then
  echo "pi-pilot: wrapper accepted a modified XcodeBuildMCP tree" >&2
  exit 1
fi
cp "$xcode_license_backup" "$pi_pilot_xcode_package/LICENSE"
pi_pilot_verify_xcodebuildmcp
xcode_runtime_real="$runtime/xcode-runtime-real"
xcode_runtime_escape="$runtime/xcode-runtime-escape"
mv "$pi_pilot_xcode_runtime_dir" "$xcode_runtime_real"
mkdir "$xcode_runtime_escape"
ln -s "$xcode_runtime_escape" "$pi_pilot_xcode_runtime_dir"
if PI_PILOT_REPO="$root" "$pi_dir/xcodebuildmcp" --version >/dev/null 2>&1; then
  echo "pi-pilot: wrapper followed a symlinked XcodeBuildMCP runtime" >&2
  exit 1
fi
rm "$pi_pilot_xcode_runtime_dir"
mv "$xcode_runtime_real" "$pi_pilot_xcode_runtime_dir"
PI_PILOT_STATE_DIR="$pi_pilot_state_dir" \
  node "$pi_dir/tests/fff_reload_test.mjs"
test "$("$pi_dir/pilot.sh" --version)" = 0.82.1
test "$(LC_ALL=C "$pi_dir/pilot.sh" --version)" = 0.82.1
test "$(LC_ALL=en_US.UTF-8 "$pi_dir/pilot.sh" --version)" = 0.82.1
"$pi_dir/tests/context_load_test.sh" \
  "$pi_dir/pilot.sh" "$pi_pilot_config_dir/AGENTS.md"
printf 'Pi FFF locale-independent verification: PASS\n'
cmp -s "$pi_dir/packages/fff/package.json" \
  "$pi_pilot_config_dir/npm/package.json"
cmp -s "$pi_dir/packages/fff/package-lock.json" \
  "$pi_pilot_config_dir/npm/package-lock.json"
rg -q 'currentMode = "tools-and-ui";' \
  "$pi_pilot_config_dir/npm/node_modules/@ff-labs/pi-fff/src/index.ts"
rg -q "FFF mode is fixed to 'tools-and-ui'" \
  "$pi_pilot_config_dir/npm/node_modules/@ff-labs/pi-fff/src/index.ts"
for forbidden in \
  '--session-dir /tmp/outside' \
  '--session /tmp/outside.jsonl' \
  '--fork ../outside.jsonl' \
  '--extension /tmp/outside.ts' \
  '--skill /tmp/outside-skill' \
  '--prompt-template /tmp/outside.md' \
  '--fff-mode override' \
  '--fff-mode=tools-only' \
  '--fff-frecency-db /tmp/outside-frecency' \
  '--fff-frecency-db=/tmp/outside-frecency' \
  '--fff-history-db /tmp/outside-history' \
  '--fff-history-db=/tmp/outside-history' \
  '--fff-enable-root-scan' \
  '--fff-enable-root-scan=true' \
  '--approve'
do
  # Intentional word splitting supplies each option/value pair.
  # shellcheck disable=SC2086
  if "$pi_dir/pilot.sh" $forbidden --version >/dev/null 2>&1; then
    echo "pi-pilot: isolation bypass was accepted: $forbidden" >&2
    exit 1
  fi
done
for forbidden_command in \
  'install npm:unreviewed-package' \
  'remove npm:@ff-labs/pi-fff' \
  'config' \
  'update'
do
  # Intentional word splitting supplies the command arguments.
  # shellcheck disable=SC2086
  if "$pi_dir/pilot.sh" $forbidden_command >/dev/null 2>&1; then
    echo "pi-pilot: managed package mutation was accepted: $forbidden_command" >&2
    exit 1
  fi
done

printf '%s\n' '{"id":"commands","type":"get_commands"}' |
  "$pi_dir/pilot.sh" --mode rpc --no-session >"$rpc_log"
jq -e '
  select(.id == "commands") |
  .success == true and
  ([.data.commands[] | select(.name == "eddy-pilot")] | length == 1) and
  ([.data.commands[] | select(.name == "skill:herdr")] | length == 1) and
  ([.data.commands[] | select(.name == "skill:skill-finish")] | length == 1) and
  ([.data.commands[] | select(.name == "skill:xcodebuildmcp-cli")] | length == 1) and
  ([.data.commands[] | select(.name == "skill:swift-concurrency-expert")] | length == 1) and
  ([.data.commands[] | select(.name == "skill:swiftui-liquid-glass")] | length == 1) and
  ([.data.commands[] | select(.name == "skill:swiftui-performance-audit")] | length == 1) and
  ([.data.commands[] | select(.name == "skill:swiftui-view-refactor")] | length == 1) and
  ([.data.commands[] | select(.name == "fff-health")] | length == 1) and
  ([.data.commands[] | select(.name == "fff-mode")] | length == 1) and
  ([.data.commands[] | select(.name == "fff-rescan")] | length == 1) and
  ([.data.commands[] | select(.source == "skill")] | length == 7)
' "$rpc_log" >/dev/null

# The pinned tools-and-ui source registers the two reviewed FFF tools. The
# optional multi-grep tool is disabled by the launcher regardless of inherited
# environment, and the package tree hash makes this inventory tamper-evident.
rg -q 'find: "fffind"' \
  "$pi_pilot_config_dir/npm/node_modules/@ff-labs/pi-fff/src/index.ts"
rg -q 'grep: "ffgrep"' \
  "$pi_pilot_config_dir/npm/node_modules/@ff-labs/pi-fff/src/index.ts"
PI_FFF_MULTIGREP=1 "$pi_dir/pilot.sh" --version >/dev/null

# Existing unmarked roots and symlinked roots must never be adopted.
unmanaged_data="$runtime/unmanaged-data"
unmanaged_state="$runtime/unmanaged-state"
mkdir -p "$unmanaged_data" "$unmanaged_state"
if PI_PILOT_DATA_DIR="$unmanaged_data" \
   PI_PILOT_STATE_DIR="$unmanaged_state" \
   "$pi_dir/install.sh" >/dev/null 2>&1; then
  echo "pi-pilot: installer adopted an unmanaged root" >&2
  exit 1
fi
test ! -e "$unmanaged_data/.eddy-pi-pilot"
test ! -e "$unmanaged_state/.eddy-pi-pilot"

symlink_target="$runtime/symlink-target"
symlink_data="$runtime/symlink-data"
mkdir -p "$symlink_target"
: >"$symlink_target/.eddy-pi-pilot"
ln -s "$symlink_target" "$symlink_data"
if PI_PILOT_DATA_DIR="$symlink_data" \
   PI_PILOT_STATE_DIR="$runtime/missing-state" \
   "$pi_dir/rollback.sh" --apply >/dev/null 2>&1; then
  echo "pi-pilot: rollback followed a symlinked root" >&2
  exit 1
fi
test -L "$symlink_data"

derived_data="$runtime/derived-data"
derived_state="$runtime/derived-state"
derived_target="$runtime/derived-target"
mkdir -p "$derived_data" "$derived_state" "$derived_target"
: >"$derived_data/.eddy-pi-pilot"
: >"$derived_state/.eddy-pi-pilot"
ln -s "$derived_target" "$derived_state/config"
if PI_PILOT_DATA_DIR="$derived_data" \
   PI_PILOT_STATE_DIR="$derived_state" \
   "$pi_dir/install.sh" >/dev/null 2>&1; then
  echo "pi-pilot: installer followed a symlinked derived directory" >&2
  exit 1
fi
if PI_PILOT_DATA_DIR="$pi_pilot_data_dir" \
   PI_PILOT_STATE_DIR="$derived_state" \
   "$pi_dir/pilot.sh" --version >/dev/null 2>&1; then
  echo "pi-pilot: launcher followed a symlinked derived directory" >&2
  exit 1
fi
test -L "$derived_state/config"

fff_db_state="$runtime/fff-db-symlink-state"
fff_db_target="$runtime/fff-db-symlink-target"
mkdir -p "$fff_db_state/config/extensions" "$fff_db_state/sessions" \
  "$fff_db_state/control" "$fff_db_state/fff" "$fff_db_target"
: >"$fff_db_state/.eddy-pi-pilot"
ln -s "$pi_dir/settings.json" "$fff_db_state/config/settings.json"
ln -s "$pi_dir/keybindings.json" "$fff_db_state/config/keybindings.json"
cp "$pi_pilot_config_dir/extensions/herdr-agent-state.ts" \
  "$fff_db_state/config/extensions/herdr-agent-state.ts"
cp -R "$pi_pilot_config_dir/npm" "$fff_db_state/config/npm"
ln -s "$fff_db_target" "$fff_db_state/fff/frecency"
mkdir "$fff_db_state/fff/history"
if PI_PILOT_DATA_DIR="$pi_pilot_data_dir" \
   PI_PILOT_STATE_DIR="$fff_db_state" \
   "$pi_dir/pilot.sh" --version >/dev/null 2>&1; then
  echo "pi-pilot: launcher followed a symlinked FFF database directory" >&2
  exit 1
fi
test -L "$fff_db_state/fff/frecency"

extra_state="$runtime/extra-extension-state"
mkdir -p "$extra_state/config/extensions" "$extra_state/sessions" \
  "$extra_state/control"
: >"$extra_state/.eddy-pi-pilot"
ln -s "$pi_dir/settings.json" "$extra_state/config/settings.json"
cp "$pi_pilot_config_dir/extensions/herdr-agent-state.ts" \
  "$extra_state/config/extensions/herdr-agent-state.ts"
: >"$extra_state/config/extensions/unreviewed.ts"
if PI_PILOT_DATA_DIR="$pi_pilot_data_dir" \
   PI_PILOT_STATE_DIR="$extra_state" \
   "$pi_dir/pilot.sh" --version >/dev/null 2>&1; then
  echo "pi-pilot: launcher accepted an unreviewed global extension" >&2
  exit 1
fi

# The reviewed TypeScript wrapper is not sufficient: native FFF dependencies
# are executable code and must also be rejected after any content change.
fff_tamper_state="$runtime/fff-tamper-state"
mkdir -p "$fff_tamper_state/config/extensions" \
  "$fff_tamper_state/sessions" "$fff_tamper_state/control" \
  "$fff_tamper_state/fff"
: >"$fff_tamper_state/.eddy-pi-pilot"
ln -s "$pi_dir/settings.json" "$fff_tamper_state/config/settings.json"
ln -s "$pi_dir/keybindings.json" "$fff_tamper_state/config/keybindings.json"
cp "$pi_pilot_config_dir/extensions/herdr-agent-state.ts" \
  "$fff_tamper_state/config/extensions/herdr-agent-state.ts"
cp -R "$pi_pilot_config_dir/npm" "$fff_tamper_state/config/npm"
printf '\n' >>"$fff_tamper_state/config/npm/node_modules/@ff-labs/fff-bin-darwin-arm64/libfff_c.dylib"
if PI_PILOT_DATA_DIR="$pi_pilot_data_dir" \
   PI_PILOT_STATE_DIR="$fff_tamper_state" \
   "$pi_dir/pilot.sh" --version >/dev/null 2>&1; then
  echo "pi-pilot: launcher accepted a modified FFF native dependency" >&2
  exit 1
fi

fff_symlink_state="$runtime/fff-symlink-state"
cp -R "$fff_tamper_state" "$fff_symlink_state"
cp "$pi_pilot_config_dir/npm/node_modules/@ff-labs/fff-bin-darwin-arm64/libfff_c.dylib" \
  "$fff_symlink_state/config/npm/node_modules/@ff-labs/fff-bin-darwin-arm64/libfff_c.dylib"
ln -s "$runtime" \
  "$fff_symlink_state/config/npm/node_modules/unreviewed-module"
if PI_PILOT_DATA_DIR="$pi_pilot_data_dir" \
   PI_PILOT_STATE_DIR="$fff_symlink_state" \
   "$pi_dir/pilot.sh" --version >/dev/null 2>&1; then
  echo "pi-pilot: launcher accepted a symlink in the FFF dependency tree" >&2
  exit 1
fi
test -L "$fff_symlink_state/config/npm/node_modules/unreviewed-module"

# Rollback must preflight every destination before moving either root.
collision_data="$runtime/collision-data"
collision_state="$runtime/collision-state"
collision_trash="$runtime/collision-trash"
collision_stamp=20000101T000000Z
mkdir -p "$collision_data" "$collision_state" \
  "$collision_trash/pi-pilot-$collision_stamp-state"
: >"$collision_data/.eddy-pi-pilot"
: >"$collision_state/.eddy-pi-pilot"
if PI_PILOT_DATA_DIR="$collision_data" \
   PI_PILOT_STATE_DIR="$collision_state" \
   PI_PILOT_TRASH_DIR="$collision_trash" \
   PI_PILOT_ROLLBACK_STAMP="$collision_stamp" \
   "$pi_dir/rollback.sh" --apply >/dev/null 2>&1; then
  echo "pi-pilot: rollback ignored a destination collision" >&2
  exit 1
fi
test -d "$collision_data"
test -d "$collision_state"

# Prove rollback against disposable marker-owned roots. Nothing outside these
# paths may move.
rollback_data="$runtime/rollback-data"
rollback_state="$runtime/rollback-state"
rollback_trash="$runtime/rollback-trash"
mkdir -p "$rollback_data" "$rollback_state"
: >"$rollback_data/.eddy-pi-pilot"
: >"$rollback_state/.eddy-pi-pilot"
mkdir -p "$rollback_state/config/xcodebuildmcp"
: >"$rollback_state/config/xcodebuildmcp/fixture-marker"
PI_PILOT_DATA_DIR="$rollback_data" \
PI_PILOT_STATE_DIR="$rollback_state" \
PI_PILOT_TRASH_DIR="$rollback_trash" \
  "$pi_dir/rollback.sh" --apply >/dev/null
test ! -e "$rollback_data"
test ! -e "$rollback_state"
test "$(find "$rollback_trash" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" -eq 2
find "$rollback_trash" -mindepth 1 -maxdepth 1 -type d -exec \
  test -f '{}/.eddy-pi-pilot' ';'
test "$(find "$rollback_trash" -path '*/config/xcodebuildmcp/fixture-marker' | wc -l | tr -d ' ')" -eq 1

# A marker and matching --version output are insufficient: every launch must
# reject a modified binary.
tamper_data="$runtime/tamper-data"
tamper_state="$runtime/tamper-state"
mkdir -p "$tamper_data/versions/0.82.1" "$tamper_state"
: >"$tamper_data/.eddy-pi-pilot"
: >"$tamper_state/.eddy-pi-pilot"
: >"$tamper_data/versions/0.82.1/.eddy-pi-pilot"
cp "$pi_pilot_binary" "$tamper_data/versions/0.82.1/pi"
printf '\n' >>"$tamper_data/versions/0.82.1/pi"
chmod +x "$tamper_data/versions/0.82.1/pi"
if PI_PILOT_DATA_DIR="$tamper_data" PI_PILOT_STATE_DIR="$tamper_state" \
   "$pi_dir/pilot.sh" --version >/dev/null 2>&1; then
  echo "pi-pilot: launcher accepted a modified binary" >&2
  exit 1
fi

cmp -s "$pi_dir/integrations/herdr-agent-state.ts" \
  "$pi_pilot_config_dir/extensions/herdr-agent-state.ts"
grep -q 'HERDR_INTEGRATION_VERSION=5' \
  "$pi_pilot_config_dir/extensions/herdr-agent-state.ts"

PI_PILOT_REPO="$root" "$pi_dir/tests/xcodebuildmcp_fixture.sh"

"$pi_dir/validate_sessions.sh"
echo "Pi pilot verification: session gate complete; starting Herdr gate"
"$pi_dir/validate_herdr.sh"
echo "Pi pilot verification: Herdr gate complete; starting benchmarks"
"$pi_dir/benchmark_runtime.py"
cp "$pi_dir/evidence/provider-comparison.json" \
  "$PI_PILOT_EVIDENCE_DIR/provider-comparison.json"
"$pi_dir/benchmark_provider.py"
mkdir -p "$pi_dir/evidence"
for evidence_name in \
  session-validation.json herdr-validation.json runtime-benchmark.json
do
  evidence_source="$PI_PILOT_EVIDENCE_DIR/$evidence_name"
  evidence_stage="$pi_dir/evidence/.$evidence_name.$$"
  cp "$evidence_source" "$evidence_stage"
  mv "$evidence_stage" "$pi_dir/evidence/$evidence_name"
done
jq -e '
  if .status == "PASS" then
    .pi.score.passed == .pi.score.possible and
    .codex.score.passed == .codex.score.possible
  else
    .status == "AWAITING_USER_AUTH" and
    .pi_run == false and
    .codex_run == false
  end
' "$PI_PILOT_EVIDENCE_DIR/provider-comparison.json" >/dev/null

git -C "$root" diff --check -- pi herdr tmux
echo "Pi pilot verification: PASS"
