#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
herdr_dir="$root/herdr"
prototype="$herdr_dir/prototype"
prepared_bin="$prototype/.runtime/bin/herdr"
source_build="$herdr_dir/source-build"

# shellcheck source=/dev/null
. "$source_build/pins.env"

clean_multiplexer_env() {
  env -u TMUX -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_SESSION \
    -u HERDR_SOCKET_PATH -u HERDR_WORKSPACE_ID -u HERDR_TAB_ID \
    -u HERDR_TARGET_PANE_ID -u HERDR_STARTUP_CWD "$@"
}

for script in "$herdr_dir"/*.sh; do
  sh -n "$script"
done
"$source_build/verify.sh"
test -x "$HOME/.local/bin/herdr"
test "$(shasum -a 256 "$HOME/.local/bin/herdr" | awk '{print $1}')" = \
  "$HERDR_BINARY_SHA256"
fish --no-config -n "$prototype/herdr_login_attach.fish"
test -x "$herdr_dir/window_session.sh"
rg -q 'window_session\.sh' "$prototype/herdr_login_attach.fish"
rg -q 'ensure_plugins\.sh.*\$session' "$prototype/herdr_login_attach.fish"
rg -q 'plugin_id=prototype\.golden-focus' "$herdr_dir/ensure_plugins.sh"

fallback_args=$(
  HERDR_GHOSTTY_OPEN=/bin/echo \
  HERDR_FALLBACK_FISH=/test/fish \
    "$herdr_dir/tmux_fallback.sh"
)
test "$fallback_args" = \
  '-na Ghostty --args -e /usr/bin/env -u TMUX -u HERDR_ENV -u HERDR_PANE_ID HERDR_NO_AUTO_ATTACH=1 /test/fish --login'

tmp=$(mktemp -d "${TMPDIR:-/tmp}/herdr-production-verify.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM
verify_source=${HERDR_VERIFY_SOURCE:-}
if [ -z "$verify_source" ] && [ -x "$prepared_bin" ]; then
  verify_source=$prepared_bin
fi
verify_sha=$HERDR_OFFICIAL_SHA256
if [ -n "$verify_source" ]; then
  source_sha=$(shasum -a 256 "$verify_source" | awk '{print $1}')
  case "$source_sha" in
    "$HERDR_BINARY_SHA256")
      verify_sha=$HERDR_BINARY_SHA256
      ;;
    "$verify_sha")
      ;;
    *)
      echo "Herdr verification source is neither the official nor reviewed source build" >&2
      exit 1
      ;;
  esac
  HERDR_INSTALL_SOURCE="$verify_source" \
  HERDR_INSTALL_EXPECTED_SHA256="$verify_sha" \
  HERDR_INSTALL_BIN="$tmp/bin/herdr" \
  HERDR_CONFIG_DIR="$tmp/config" \
  HERDR_ACTIVATE=0 \
    "$herdr_dir/install.sh" >/dev/null
else
  HERDR_INSTALL_BIN="$tmp/bin/herdr" \
  HERDR_CONFIG_DIR="$tmp/config" \
  HERDR_ACTIVATE=0 \
    "$herdr_dir/install.sh" >/dev/null
fi
bin="$tmp/bin/herdr"
test "$(shasum -a 256 "$tmp/bin/herdr" | awk '{print $1}')" = \
  "$verify_sha"
test "$(readlink "$tmp/config/config.toml")" = "$herdr_dir/config.toml"
test "$(rg -c '^pane_history = false$' "$herdr_dir/config.toml")" -eq 1
for binding in \
  'prefix+shift+a' \
  'prefix+shift+p' \
  'prefix+shift+u' \
  'prefix+^' \
  'prefix+$'
do
  test "$(rg -Fxc "key = \"$binding\"" "$herdr_dir/config.toml")" -eq 1
done
rg -q '^command = "exec \\"\$HERDR_PROTOTYPE_DIR/pane_transfer\.sh\\""$' \
  "$herdr_dir/config.toml"
rg -q '^command = "exec \\"\$HERDR_PROTOTYPE_DIR/export_history\.sh\\""$' \
  "$herdr_dir/config.toml"
rg -q '^command = "exec \\"\$HERDR_PROTOTYPE_DIR/tab_edge\.sh\\" first"$' \
  "$herdr_dir/config.toml"
rg -q '^command = "exec \\"\$HERDR_PROTOTYPE_DIR/tab_edge\.sh\\" last"$' \
  "$herdr_dir/config.toml"
rg -q '^command = "exec \\"\$HERDR_PROTOTYPE_DIR/agent_overview\.sh\\""$' \
  "$herdr_dir/config.toml"
rg -q '^height = 20$' "$herdr_dir/config.toml"
rg -Fqx 'last_pane = ["prefix+tab", "ctrl+^"]' "$herdr_dir/config.toml"

HERDR_BIN_PATH="$herdr_dir/fixtures/herdr-plugin-client.sh" \
HERDR_PLUGIN_FIXTURE_STATE="$tmp/plugin-fixture-state" \
  "$herdr_dir/ensure_plugins.sh" review-test
test "$(cat "$tmp/plugin-fixture-state")" = 2

# Refusal and config-validation failures must not alter either live target.
mkdir -p "$tmp/refusal/bin" "$tmp/refusal/config"
cp /usr/bin/false "$tmp/refusal/bin/herdr"
cp "$herdr_dir/fixtures/invalid-config.toml" "$tmp/refusal/config/config.toml"
refusal_hash=$(shasum -a 256 "$tmp/refusal/bin/herdr" | awk '{print $1}')
if HERDR_INSTALL_SOURCE="$bin" \
    HERDR_INSTALL_BIN="$tmp/refusal/bin/herdr" \
    HERDR_CONFIG_DIR="$tmp/refusal/config" \
    HERDR_ACTIVATE=0 "$herdr_dir/install.sh" >/dev/null 2>&1; then
  echo "installer unexpectedly replaced an unrelated config" >&2
  exit 1
fi
test "$(shasum -a 256 "$tmp/refusal/bin/herdr" | awk '{print $1}')" = "$refusal_hash"

mkdir -p "$tmp/binary-refusal/bin"
cp /usr/bin/false "$tmp/binary-refusal/bin/herdr"
binary_refusal_hash=$(shasum -a 256 "$tmp/binary-refusal/bin/herdr" | awk '{print $1}')
if HERDR_INSTALL_SOURCE="$bin" \
    HERDR_INSTALL_BIN="$tmp/binary-refusal/bin/herdr" \
    HERDR_CONFIG_DIR="$tmp/binary-refusal/config" \
    HERDR_ACTIVATE=0 "$herdr_dir/install.sh" >/dev/null 2>&1; then
  echo "installer unexpectedly replaced an unrelated binary" >&2
  exit 1
fi
test "$(shasum -a 256 "$tmp/binary-refusal/bin/herdr" | awk '{print $1}')" = "$binary_refusal_hash"
test ! -e "$tmp/binary-refusal/config/config.toml"

# A reviewed source build may atomically replace only the explicitly identified
# official binary; an incorrect predecessor hash still fails closed.
mkdir -p "$tmp/upgrade/bin"
/bin/sh "$root/tools/fetch_verified.sh" \
  "https://github.com/ogulcancelik/herdr/releases/download/v$HERDR_VERSION/$HERDR_OFFICIAL_ASSET" \
  "$HERDR_OFFICIAL_SHA256" \
  >"$tmp/upgrade/bin/herdr"
chmod 0755 "$tmp/upgrade/bin/herdr"
cp "$tmp/upgrade/bin/herdr" "$tmp/official-herdr"
HERDR_INSTALL_SOURCE="$source_build/.work/bin/herdr" \
HERDR_INSTALL_EXPECTED_SHA256="$HERDR_BINARY_SHA256" \
HERDR_INSTALL_REPLACE_SHA256="$HERDR_OFFICIAL_SHA256" \
HERDR_INSTALL_BIN="$tmp/upgrade/bin/herdr" \
HERDR_CONFIG_DIR="$tmp/upgrade/config" \
HERDR_ACTIVATE=0 \
  "$herdr_dir/install.sh" >/dev/null
test "$(shasum -a 256 "$tmp/upgrade/bin/herdr" | awk '{print $1}')" = \
  "$HERDR_BINARY_SHA256"

# A failure after the atomic replacement must restore the exact predecessor.
# Pre-create the accepted config link, then make its directory read-only so the
# activation step cannot stage the default-multiplexer file.
mkdir -p "$tmp/rollback/bin" "$tmp/rollback/config"
ln -s "$herdr_dir/config.toml" "$tmp/rollback/config/config.toml"
chmod 0500 "$tmp/rollback/config"
cp "$tmp/official-herdr" "$tmp/rollback/bin/herdr"
chmod 0755 "$tmp/rollback/bin/herdr"
rollback_status=0
HERDR_INSTALL_SOURCE="$source_build/.work/bin/herdr" \
    HERDR_INSTALL_EXPECTED_SHA256="$HERDR_BINARY_SHA256" \
    HERDR_INSTALL_REPLACE_SHA256="$HERDR_OFFICIAL_SHA256" \
    HERDR_INSTALL_BIN="$tmp/rollback/bin/herdr" \
    HERDR_CONFIG_DIR="$tmp/rollback/config" \
    HERDR_ACTIVATE=1 \
      "$herdr_dir/install.sh" >/dev/null 2>&1 || rollback_status=$?
chmod 0700 "$tmp/rollback/config"
if [ "$rollback_status" -eq 0 ]; then
  echo "installer unexpectedly survived a post-replacement activation failure" >&2
  exit 1
fi
test "$(shasum -a 256 "$tmp/rollback/bin/herdr" | awk '{print $1}')" = \
  "$HERDR_OFFICIAL_SHA256"

mkdir -p "$tmp/invalid/bin"
cp /usr/bin/false "$tmp/invalid/bin/herdr"
invalid_hash=$(shasum -a 256 "$tmp/invalid/bin/herdr" | awk '{print $1}')
if HERDR_INSTALL_SOURCE="$bin" \
    HERDR_INSTALL_BIN="$tmp/invalid/bin/herdr" \
    HERDR_CONFIG_DIR="$tmp/invalid/config" \
    HERDR_CONFIG_TARGET="$herdr_dir/fixtures/invalid-config.toml" \
    HERDR_ACTIVATE=0 "$herdr_dir/install.sh" >/dev/null 2>&1; then
  echo "installer unexpectedly accepted an invalid config" >&2
  exit 1
fi
test "$(shasum -a 256 "$tmp/invalid/bin/herdr" | awk '{print $1}')" = "$invalid_hash"
test ! -e "$tmp/invalid/config/config.toml"

HERDR_CONFIG_DIR="$tmp/config" "$herdr_dir/set_default.sh" tmux >/dev/null
test "$(cat "$tmp/config/default-multiplexer")" = tmux
HERDR_CONFIG_DIR="$tmp/config" "$herdr_dir/set_default.sh" herdr >/dev/null
test "$(cat "$tmp/config/default-multiplexer")" = herdr

clean_multiplexer_env "$herdr_dir/validate_project_picker.sh"
"$herdr_dir/verify_integrations.sh"

# The tmux-to-Herdr parity audit. Its evidence files are dated records of what
# was validated on a specific Herdr release, so it asserts that release's version
# throughout and is deliberately NOT part of the everyday health check — an
# upgrade is supposed to move the binary, not invalidate a past investigation.
# Run it when the migration itself is the question:
#
#   HERDR_VERIFY_AUDIT=1 sh herdr/verify.sh
#
# Re-pointing it at a newer release means re-running the validators so the
# evidence is regenerated honestly, not editing the recorded version strings.
if [ "${HERDR_VERIFY_AUDIT:-0}" = 1 ]; then
  "$prototype/validate_login_attach.sh"
  clean_multiplexer_env "$prototype/validate_utilities.sh"
  clean_multiplexer_env "$prototype/validate_layout_menu.sh"
  clean_multiplexer_env "$prototype/validate_picker_reference.sh"
  clean_multiplexer_env "$prototype/validate_agent_overview.sh"
  "$prototype/verify.sh"
fi

# Stored unified diffs legitimately contain one-space blank context markers;
# source-build verification separately checks that the patch applies exactly.
git -C "$root" diff --check -- herdr fish/config.fish \
  ':(exclude)herdr/source-build/*.patch'
echo "Herdr production verification: PASS"
