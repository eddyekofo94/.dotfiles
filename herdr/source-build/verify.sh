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
test "$HERDR_SOURCE_TAG" = v0.8.2
test "$HERDR_SOURCE_TAG_OBJECT" = 34ba52cc6ff3b723e6fc0130485ec24582dbe205
test "$HERDR_SOURCE_COMMIT" = 9eb521456ac0d19d3ab3d9d7cea3cca10baa8a4c
test "$HERDR_RUST_TOOLCHAIN" = 1.96.1
test "$HERDR_ZIG_VERSION" = 0.15.2
# The series is the unit that is pinned: HERDR_PATCH_SHA256 is the digest of the
# concatenation, and HERDR_TREE_DIFF_SHA256 pins the patched tree separately.
# Splitting the two is what lets a patch file own any set of paths; build.sh
# checks ownership against the modified tree instead of relying on apply order.
# Three patches retired at v0.8.2 — agent-panel-active-highlight,
# toast-triage-colours-status and working-spinner-tick are upstream code now, so
# the series carries only what upstream still does not do.
test "$HERDR_PATCH_SERIES" = \
  "copy-mode-vim-muscle-memory.patch toast-triage-colours-mobile.patch"
test "$(
  for patch_name in $HERDR_PATCH_SERIES; do
    cat "$source_build/$patch_name"
  done | shasum -a 256 | awk '{print $1}'
)" = "$HERDR_PATCH_SHA256"
# Pinned separately from the concatenation, so the two must not be assumed equal
# anywhere. No patch may claim a path another patch already claims.
test -n "$HERDR_TREE_DIFF_SHA256"
test "${#HERDR_TREE_DIFF_SHA256}" -eq 64
test -z "$(
  for patch_name in $HERDR_PATCH_SERIES; do
    awk '/^diff --git a\// { sub(/^diff --git a\//, ""); sub(/ b\/.*$/, ""); print }' \
      "$source_build/$patch_name"
  done | LC_ALL=C sort | uniq -d
)"
rg -q "^\\+            'a' \\| 'i' \\| 'q' => self\\.exit_copy_mode\\(terminal_runtimes, false\\),$" \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q "^\\+            'Y' => self\\.yank_copy_mode_lines\\(terminal_runtimes, count\\),$" \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q '^\+    async fn copy_mode_a_and_i_exit_without_copying\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q '^\+    async fn copy_mode_shift_y_copies_current_line_and_exits\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
# The pending-command buffer: a count repeats a motion, `zz` centres, and Esc
# discards a half-typed command. Named here so a re-pin cannot quietly drop them.
rg -q '^\+    async fn copy_mode_count_prefix_repeats_a_motion\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q '^\+    async fn copy_mode_multi_digit_count_accumulates_and_zero_stays_a_motion\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q '^\+    async fn copy_mode_escape_clears_pending_command_without_dropping_selection\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q '^\+    async fn copy_mode_zz_centers_the_cursor_line_in_the_viewport\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q '^\+    async fn copy_mode_counted_shift_y_copies_that_many_lines\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
rg -q '^\+    async fn copy_mode_counted_y_without_a_selection_copies_whole_lines\(\) \{$' \
  "$source_build/copy-mode-vim-muscle-memory.patch"
if rg -q 'pane_history|tmux_fallback|send-keys|send-text|input emulation' \
  "$source_build/copy-mode-vim-muscle-memory.patch"; then
  echo "copy-mode source patch crossed its approved seam" >&2
  exit 1
fi

# The mobile toast triage colours: red is blocked on a human, green is done,
# blue is informational. Named here so a re-pin cannot quietly revert them to
# the upstream mapping. The desktop half (ui/status.rs) was adopted upstream at
# v0.8.2 and its patch retired, so only the mobile renderer is ours to keep.
toast_mobile_patch="$source_build/toast-triage-colours-mobile.patch"
# Red is already upstream's mapping, so it appears as patch context rather than
# an addition; assert it survives instead of that we add it.
test "$(rg -c '^[ +]        ToastKind::NeedsAttention => p\.red,$' \
  "$toast_mobile_patch")" -eq 1
test "$(rg -c '^\+        ToastKind::Finished => p\.green,$' "$toast_mobile_patch")" -eq 1
test "$(rg -c '^\+        ToastKind::UpdateInstalled => p\.blue,$' \
  "$toast_mobile_patch")" -eq 1
# Mobile must speak the same colour language the desktop toast now ships with.
test "$(rg -c '^\+    let kind_color = match toast\.kind \{$' "$toast_mobile_patch")" -eq 1
# The toast file owns exactly its own renderer; anything else is a seam crossing.
test "$(rg -c '^diff --git ' "$toast_mobile_patch")" -eq 1
rg -q '^diff --git a/src/ui/mobile\.rs ' "$toast_mobile_patch"

# The built binary is a gitignored work product, so a fresh checkout cannot have
# it. Skip only the binary identity checks in that case; everything above is
# source-of-truth text that any checkout must still satisfy.
bin="$source_build/.work/bin/herdr"
if [ -x "$bin" ]; then
  test "$(shasum -a 256 "$bin" | awk '{print $1}')" = "$HERDR_BINARY_SHA256"
  test "$("$bin" --version)" = "herdr $HERDR_VERSION"
else
  echo "Herdr source-build verification: skipped binary identity (no local build at $bin)" >&2
fi
test "$(rg -c '^pane_history = false$' "$root/herdr/config.toml")" -eq 1
test -x "$root/herdr/tmux_fallback.sh"
tmux -V | rg -q '^tmux '

echo "Herdr source-build verification: PASS"
