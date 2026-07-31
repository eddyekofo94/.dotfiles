#!/bin/sh
set -eu

source_build=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$source_build/../.." && pwd)

# shellcheck source=/dev/null
. "$source_build/pins.env"

# Deliberately hardcoded rather than compared against pins.env: this is the
# independent cross-check that catches a tampered or half-finished re-pin, so it
# has to carry its own copy of the reviewed identity. upgrade.sh does not rewrite
# these — bump them by hand, from `git rev-parse`, as part of accepting a release.
test "$HERDR_SOURCE_TAG" = v0.7.5
test "$HERDR_SOURCE_TAG_OBJECT" = 99df3ac37be6bd7be2fd2023f0d88a7a0e7a7101
test "$HERDR_SOURCE_COMMIT" = ef4c23f5775bb8cfec05f05d0844226ff959a07a
test "$HERDR_RUST_TOOLCHAIN" = 1.96.1
test "$HERDR_ZIG_VERSION" = 0.15.2
test "$(shasum -a 256 "$source_build/copy-mode-vim-muscle-memory.patch" | awk '{print $1}')" = \
  "$HERDR_PATCH_SHA256"
rg -q "^\\+            'a' \\| 'i' \\| 'q' => self\\.exit_copy_mode\\(terminal_runtimes, false\\),$" \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q "^\\+            'Y' => \\{$" \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q '^\+    async fn copy_mode_a_and_i_exit_without_copying\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q '^\+    async fn copy_mode_shift_y_copies_current_line_and_exits\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
if rg -q 'pane_history|tmux_fallback|send-keys|send-text|input emulation' \
  "$source_build/copy-mode-vim-muscle-memory.patch"; then
  echo "copy-mode source patch crossed its approved seam" >&2
  exit 1
fi

bin="$source_build/.work/bin/herdr"
test -x "$bin"
test "$(shasum -a 256 "$bin" | awk '{print $1}')" = "$HERDR_BINARY_SHA256"
test "$("$bin" --version)" = "herdr $HERDR_VERSION"
test "$(rg -c '^pane_history = false$' "$root/herdr/config.toml")" -eq 1
test -x "$root/herdr/tmux_fallback.sh"
tmux -V | rg -q '^tmux '

echo "Herdr source-build verification: PASS"
