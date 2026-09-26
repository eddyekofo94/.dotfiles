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
# v0.8.2 adopted parts of three private patches, and the three were re-decided
# one at a time rather than as a group. agent-panel-active-highlight became a
# config edit — upstream's `theme.custom.active_row_bg` expresses all of it, so
# it has no patch file and is asserted against herdr/config.toml at the bottom
# of this script. toast-triage-colours-status and working-spinner-tick were
# re-authored against v0.8.2 because upstream still does neither: the toast
# title is not triage-coloured and the Working dot does not breathe.
test "$HERDR_PATCH_SERIES" = \
  "copy-mode-vim-muscle-memory.patch toast-triage-colours-mobile.patch toast-triage-colours-status.patch working-spinner-tick.patch agent-focus-keeps-agent-in-view.patch"
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
# the upstream mapping. The desktop half lives in toast-triage-colours-status
# below; the two renderers must not drift apart.
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

# The desktop half of the same triage language, plus the breathing Working dot.
# Both live in ui/status.rs, so they are one patch file: build.sh gives a path to
# exactly one patch, and splitting them would need a second owner for that file.
toast_status_patch="$source_build/toast-triage-colours-status.patch"
# Red is already upstream's mapping here too, so it is context, not an addition.
test "$(rg -c '^[ +]        ToastKind::NeedsAttention => p\.red,$' \
  "$toast_status_patch")" -eq 1
test "$(rg -c '^\+        ToastKind::Finished => p\.green,$' "$toast_status_patch")" -eq 1
test "$(rg -c '^\+        ToastKind::UpdateInstalled => p\.blue,$' \
  "$toast_status_patch")" -eq 1
test "$(rg -c '^\+    let kind_color = match toast\.kind \{$' "$toast_status_patch")" -eq 1
# The reason the patch survives upstream's StatusIndicatorStyle work: the title
# carries the colour, so the signal is not a single cell.
test "$(rg -c '^\+            Style::default\(\)\.fg\(kind_color\)\.add_modifier\(Modifier::BOLD\),$' \
  "$toast_status_patch")" -eq 1
# The breath itself, pinned by its numbers: 1440ms per cycle, floor 0.34, cosine
# rather than a triangle wave, and a DIM toggle where the palette is not
# truecolour. Upstream owns the glyph — this only moves its colour.
test "$(rg -c '^\+const WORKING_PULSE_PERIOD_MS: u128 = 1_440;$' "$toast_status_patch")" -eq 1
test "$(rg -c '^\+const WORKING_PULSE_FLOOR: f32 = 0\.34;$' "$toast_status_patch")" -eq 1
rg -q '^\+    let wave = \(1\.0 - \(phase \* std::f32::consts::TAU\)\.cos\(\)\) / 2\.0;$' \
  "$toast_status_patch"
rg -q '^\+        AgentState::Working => working_pulse_style\(p, now_millis\(\)\),$' \
  "$toast_status_patch"
rg -q '^\+        None if intensity < 0\.6 => Style::default\(\)\.fg\(p\.yellow\)\.add_modifier\(Modifier::DIM\),$' \
  "$toast_status_patch"
rg -q '^\+    fn working_pulse_keeps_the_round_dot_and_only_moves_its_colour\(\) \{$' \
  "$toast_status_patch"
rg -q '^\+    fn working_pulse_never_fades_the_dot_into_the_background\(\) \{$' \
  "$toast_status_patch"
rg -q '^\+    fn working_pulse_repeats_every_period_and_is_symmetric\(\) \{$' \
  "$toast_status_patch"
rg -q '^\+    fn working_pulse_falls_back_to_dim_on_a_non_truecolour_palette\(\) \{$' \
  "$toast_status_patch"
test "$(rg -c '^diff --git ' "$toast_status_patch")" -eq 1
rg -q '^diff --git a/src/ui/status\.rs ' "$toast_status_patch"

# The redraw tick that makes the breath visible. A colour that is a function of
# wall-clock time moves only while something asks for frames, and the loop that
# actually runs day to day is the headless server's — arming the deadline in
# `App` alone is exactly how this feature shipped dead once and was reverted.
spinner_patch="$source_build/working-spinner-tick.patch"
rg -q '^\+pub\(crate\) const WORKING_SPINNER_TICK_INTERVAL: Duration = Duration::from_millis\(120\);$' \
  "$spinner_patch"
rg -q '^\+    pub\(crate\) spinner_deadline: Option<Instant>,$' "$spinner_patch"
# One helper, two callers, so the attached-terminal loop and the headless server
# cannot drift.
rg -q '^\+        changed \|= self\.sync_working_spinner_deadline\(now, dots_visible\);$' \
  "$spinner_patch"
rg -q '^\+        changed \|= self\.app\.sync_working_spinner_deadline\(now, dots_visible\);$' \
  "$spinner_patch"
# Wired into the same deadline set upstream's next_tab_bar_status_deadline() is
# in, so the tick competes for the next wake-up rather than adding a timer.
rg -q '^\+            self\.spinner_deadline,$' "$spinner_patch"
rg -q '^\+    fn working_spinner_tick_arms_in_the_headless_scheduled_tasks\(\) \{$' \
  "$spinner_patch"
rg -q '^\+    fn working_spinner_tick_stays_idle_without_an_attached_client\(\) \{$' \
  "$spinner_patch"
rg -q '^\+    fn working_spinner_tick_stays_idle_while_the_dot_surface_is_hidden\(\) \{$' \
  "$spinner_patch"
rg -q '^\+    fn working_spinner_tick_clears_when_the_last_agent_stops_working\(\) \{$' \
  "$spinner_patch"
test "$(rg -c '^diff --git ' "$spinner_patch")" -eq 3
# A regression test no filter selects is decoration, and build.sh's filters are
# the whole test run. The gate line is part of the patch's contract.
rg -q '^  cargo test --locked working_$' "$source_build/build.sh"

# `herdr agent focus` keeps the focused agent in view, as native next_agent does,
# so agent_cycle.py on Ctrl+Alt+j/k never focuses an agent past the panel's last
# row out of sight (BibleStandard FS-261).
agent_focus_patch="$source_build/agent-focus-keeps-agent-in-view.patch"
rg -q '^\+            self\.state\.ensure_agent_panel_entry_visible\(idx\);$' \
  "$agent_focus_patch"
rg -q '^\+    fn agent_focus_keeps_the_focused_agent_visible_in_agent_panel\(\) \{$' \
  "$agent_focus_patch"
test "$(rg -c '^diff --git ' "$agent_focus_patch")" -eq 2
rg -q '^  cargo test --locked agent_focus_$' "$source_build/build.sh"

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
# agent-panel-active-highlight, as config instead of a patch. v0.8.2's default
# active_row_bg (#1e1e2e) sits a few RGB steps from panel_bg, which is what the
# retired patch was written to fix; #45475a is Catppuccin Mocha's surface1, the
# colour that patch used. Asserted here because nothing else pins it now.
test "$(rg -c '^active_row_bg = "#45475a"$' "$root/herdr/config.toml")" -eq 1
test -x "$root/herdr/tmux_fallback.sh"
tmux -V | rg -q '^tmux '

echo "Herdr source-build verification: PASS"
