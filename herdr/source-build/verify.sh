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
test "$HERDR_SOURCE_TAG" = v0.8.0
test "$HERDR_SOURCE_TAG_OBJECT" = 857196dee1ce98df53efdd3f437aa2ac8a75b608
test "$HERDR_SOURCE_COMMIT" = 346411fa21afd297f5ed3b3fa56f9e3fbf7654b7
test "$HERDR_RUST_TOOLCHAIN" = 1.96.1
test "$HERDR_ZIG_VERSION" = 0.15.2
# The series is the unit that is pinned: HERDR_PATCH_SHA256 is the digest of the
# concatenation, and HERDR_TREE_DIFF_SHA256 pins the patched tree separately.
# Splitting the two is what lets a patch file own any set of paths; build.sh
# checks ownership against the modified tree instead of relying on apply order.
# The toast-triage split around agent-panel-active-highlight.patch predates the
# split and is kept because those three patches are genuinely separate changes.
test "$HERDR_PATCH_SERIES" = \
  "copy-mode-vim-muscle-memory.patch toast-triage-colours-mobile.patch agent-panel-active-highlight.patch toast-triage-colours-status.patch working-spinner-tick.patch"
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

# The toast triage colours: red is blocked on a human, green is done, blue is
# informational, and the title carries the colour so the signal is not one cell.
# Named here so a re-pin cannot quietly revert them to the upstream mapping.
# Split across two files (mobile.rs, status.rs) so agent-panel-active-highlight
# .patch can sit between them in path-sorted apply order; check both together.
toast_mobile_patch="$source_build/toast-triage-colours-mobile.patch"
toast_status_patch="$source_build/toast-triage-colours-status.patch"
# Red is already upstream's mapping, so it appears as patch context rather than
# an addition; assert it survives in both renderers instead of that we add it.
test "$(cat "$toast_mobile_patch" "$toast_status_patch" |
  rg -c '^[ +]        ToastKind::NeedsAttention => p\.red,$')" -eq 2
test "$(cat "$toast_mobile_patch" "$toast_status_patch" |
  rg -c '^\+        ToastKind::Finished => p\.green,$')" -eq 2
test "$(cat "$toast_mobile_patch" "$toast_status_patch" |
  rg -c '^\+        ToastKind::UpdateInstalled => p\.blue,$')" -eq 2
rg -q '^\+            Style::default\(\)\.fg\(kind_color\)\.add_modifier\(Modifier::BOLD\),$' \
  "$toast_status_patch"
# Desktop and mobile toasts must not drift apart into two colour languages.
test "$(cat "$toast_mobile_patch" "$toast_status_patch" |
  rg -c '^\+    let kind_color = match toast\.kind \{$')" -eq 2
# Each toast file owns exactly its own renderer; anything else is a seam crossing.
test "$(rg -c '^diff --git ' "$toast_mobile_patch")" -eq 1
test "$(rg -c '^diff --git ' "$toast_status_patch")" -eq 1
rg -q '^diff --git a/src/ui/mobile\.rs ' "$toast_mobile_patch"
rg -q '^diff --git a/src/ui/status\.rs ' "$toast_status_patch"

# The Working-state spinner. Two halves that must stay together: the glyph, in
# the status renderer, and the redraw tick that lets it advance. The tick is the
# half that was missing when this shipped and was reverted — the glyph was a
# function of wall-clock time, and the headless server, which is what actually
# runs, never scheduled a redraw for it. Named here so a re-pin cannot drop the
# tick and leave a spinner frozen on whichever frame the last event painted.
spinner_patch="$source_build/working-spinner-tick.patch"
test "$(rg -c '^diff --git ' "$spinner_patch")" -eq 3
rg -q '^diff --git a/src/app/mod\.rs ' "$spinner_patch"
rg -q '^diff --git a/src/app/runtime\.rs ' "$spinner_patch"
rg -q '^diff --git a/src/server/headless\.rs ' "$spinner_patch"
# One helper, called by both scheduling loops. Two copies is the failure mode.
test "$(rg -c '^\+    pub\(crate\) fn sync_working_spinner_deadline\($' "$spinner_patch")" -eq 1
test "$(rg -c '^\+        changed \|= self\.sync_working_spinner_deadline\(now, dots_visible\);$' \
  "$spinner_patch")" -eq 1
test "$(rg -c '^\+        changed \|= self\.app\.sync_working_spinner_deadline\(now, dots_visible\);$' \
  "$spinner_patch")" -eq 1
# The deadline has to reach the loop's wakeup list or nothing ever fires.
rg -q '^\+            self\.spinner_deadline,$' "$spinner_patch"
# The headless regression test is the gate; build.sh selects it by this prefix.
rg -q '^\+    fn working_spinner_tick_arms_in_the_headless_scheduled_tasks\(\) \{$' \
  "$spinner_patch"
rg -q '^  cargo test --locked working_spinner_$' "$source_build/build.sh"
# The glyph lives with the other status colours, in the patch that owns that file.
rg -q '^\+const WORKING_SPINNER_FRAME_MS: u128 = 120;$' "$toast_status_patch"
rg -q '^\+pub\(crate\) const WORKING_SPINNER_TICK_INTERVAL: Duration = Duration::from_millis\(120\);$' \
  "$spinner_patch"

# Agent panel active-row highlight: the current tab/pane used to render with the
# same unconditional overlay0 + DIM text as every idle row, so nothing in the
# sidebar said "this is where you are." Named here so a re-pin cannot quietly
# revert the active row back to indistinguishable-from-idle.
highlight_patch="$source_build/agent-panel-active-highlight.patch"
test "$(rg -c '^diff --git ' "$highlight_patch")" -eq 1
rg -q '^diff --git a/src/ui/sidebar\.rs ' "$highlight_patch"
rg -q '^-        let agent_style = Style::default\(\)\.fg\(p\.overlay0\)\.add_modifier\(Modifier::DIM\);$' \
  "$highlight_patch"
test "$(rg -c '^\+            Style::default\(\)\.fg\(p\.accent\)\.add_modifier\(Modifier::BOLD\)$' \
  "$highlight_patch")" -eq 2
rg -q '^\+            Style::default\(\)\.bg\(p\.surface1\)$' "$highlight_patch"

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
