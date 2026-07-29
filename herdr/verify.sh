#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
herdr_dir="$root/herdr"
prototype="$herdr_dir/prototype"
prepared_bin="$prototype/.runtime/bin/herdr"

for script in "$herdr_dir"/*.sh; do
  sh -n "$script"
done
fish --no-config -n "$prototype/herdr_login_attach.fish"
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
if [ -n "$verify_source" ]; then
  HERDR_INSTALL_SOURCE="$verify_source" \
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
  24992e1625dbdcb18354a59e299e4b263c312400b31396cdc07cd46ed57f24a7
test "$(readlink "$tmp/config/config.toml")" = "$herdr_dir/config.toml"
test "$(rg -c '^pane_history = false$' "$herdr_dir/config.toml")" -eq 1
for binding in \
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

"$herdr_dir/validate_project_picker.sh"
"$herdr_dir/verify_integrations.sh"
"$prototype/validate_login_attach.sh"
"$prototype/validate_utilities.sh"
"$prototype/validate_layout_menu.sh"
"$prototype/validate_picker_reference.sh"
"$prototype/verify.sh"
git -C "$root" diff --check -- herdr fish/config.fish
echo "Herdr production verification: PASS"
