# Focused Terminal Cursor Blink Ownership

Status: DONE

## Observation

- Reported 2026-08-01: the Ghostty/Fish prompt cursor does not blink.
- Neovim also presents a steady cursor in normal, visual, operator, and replace
  modes.
- Eddy selected blinking in every Fish and Neovim mode, including insert mode,
  while preserving each mode's cursor shape.
- Clarified after multi-window testing: blink is a focus locator. Exactly the
  cursor in the focused Ghostty/Herdr surface should blink; background panes
  and windows should not. This focus contract supersedes app-requested blink as
  the authoritative ownership seam.

## Red-capable feedback loop

```sh
.working/interviews/fish-vi-cursor-not-blinking/probe_cursor_blink.exp
```

- Starts the real login Fish configuration in an isolated PTY.
- Handles terminal capability queries and observes Fish's DECSCUSR cursor
  sequence.
- Reports RED for steady cursor codes and PASS for blinking cursor codes.

## Evidence

- Effective Ghostty config: `cursor-style-blink = true`, block cursor.
- Ghostty shell integration uses `no-cursor`, so its integration does not own
  shell cursor changes.
- Every interactive Fish enables `fish_vi_key_bindings`.
- Login Fish retains its existing mode-specific cursor shapes. Herdr owns blink
  independently of whether the application requests a blinking variant.
- Installed Fish documentation states that `blink` must be appended after each
  shape to request blinking.
- Neovim's `guicursor` currently requests blinking only for command-line and
  insert modes; its normal, visual, operator, and replace entries omit blinking.
- Neovim documents the `a:` mode as applying blink timing to every mode without
  resetting mode-specific shapes.
- Herdr has no cursor-blink setting. Codex/Claude render their own TUI cursor,
  so their apparent blink is not a valid native-terminal control.

## Diagnosis

Fish and Neovim originally requested steady DECSCUSR variants. After both were
corrected, physical Ghostty still stayed steady because Herdr's active-agent
animation emits frames every 128 ms. Ghostty restarts its 500 ms native cursor
blink timer on PTY output, so the cursor never reaches its hidden phase.

The first renderer retest made Neovim blink but left ordinary Fish and a
focused Codex composer steady. Herdr's first client-owned phase handled only
apps that requested blinking DECSCUSR shapes and did not track Ghostty window
focus. That excluded steady/default/hidden TUI cursors and allowed background
clients to keep ticking.

## Goal

- Preserve application cursor position and shape.
- Herdr owns a 500 ms visibility phase for the focused surface, including
  steady/default cursors and hidden hardware cursors used by TUIs such as
  Codex.
- On Ghostty focus loss, stop the phase and restore the application's
  steady/hidden cursor state.
- Cover focused hidden/steady cursors and focus gain/loss in Herdr tests.
- Keep Ghostty configuration unchanged.
- Extend the reviewed Herdr source build with client-owned native-cursor blink
  visibility. Preserve application-requested shapes; do not disable agent
  animation.

## Exit Criteria

- Focused Fish, Neovim, and Codex surfaces blink while preserving their cursor
  position and shape.
- Background panes/windows do not blink.
- Herdr focus-state regression tests and repository gates pass.
- Fresh Standards and Fidelity reviews pass.
- Eddy physically accepts focused Fish, Neovim, and Codex blinking plus
  non-blinking background panes/windows in Ghostty.

## Ready To Act

Ready. No implementation-changing questions remain.

## Validation Evidence

- `./fish/scripts/verify.sh`: PASS, including insert/default/visual/replace-one
  blinking DECSCUSR sequences with preserved shapes.
- `/Users/eddyekofo/.config/nvim/tools/verify.sh`: PASS, including the
  all-mode `guicursor` regression.
- Neovim `make format-check` and `make lint`: PASS.
- Fresh review: Standards 0; Fidelity 0.
- Physical rejection: ordinary Fish and Neovim remained steady; the first
  automated model stopped at emitted DECSCUSR codes and missed renderer timing.
- Red-capable Herdr regression:
  `cargo test --locked host_cursor_blink_deadline_survives_frequent_agent_frames`
  failed before the renderer fix and passes afterward.
- Reviewed Herdr source build installed with digest
  `502dcdecfa5f4d74f1d8f2b3f5e18087b2b13ac16ce3d999b5be09237af360a0`.
- Final Herdr, Fish, Neovim, format, and lint gates pass. Sequential Fish prompt
  p95 is 29.989 ms; the earlier 61.791 ms result occurred while three heavy
  verification suites ran concurrently.
- Fresh post-renderer review: Standards 0; Fidelity 0.
- Physical renderer retest: Neovim blinks; ordinary Fish and focused Codex
  remain steady.
- Fresh review of the Fish-only follow-up found Standards 2 / Fidelity 2: the
  app-specific seam did not cover Codex or foreground/background focus.
- `cargo test --locked host_cursor_blink_`: PASS, 3 tests covering frequent
  frames, default/steady/hidden cursors, focus loss/gain, and background timer
  suppression.
- Reviewed focus-owned Herdr build installed with digest
  `1d844e9d354863878ee55b0190449db3585a76db3718651fda54801e4bcabf41`;
  installed and prototype binaries match the pin.
- `./herdr/verify.sh`: PASS. `./fish/scripts/verify.sh`: PASS; prompt p95
  28.182 ms and startup p95 25.278 ms after cleanup.
- Post-fix review found three Standards cleanup items and one Fidelity wording
  item; all fixed before final re-review.
- Fresh final re-review: Standards 0; Fidelity 0.
- Physical multi-window acceptance: PASS. Eddy confirmed the focus-owned blink
  behavior works perfectly across the tested Ghostty/Herdr surfaces on
  2026-08-01.
