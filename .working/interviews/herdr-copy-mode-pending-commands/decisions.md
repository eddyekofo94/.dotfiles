# Herdr Copy-Mode Pending Commands

Follow-up slice to `herdr-copy-mode-vim-muscle-memory`, which closed DONE on
2026-07-31 and explicitly deferred `zz`.

## Goal

Give Herdr copy mode Vim's pending-command buffer — counts and the `zz`
two-key sequence — and move the copy-mode entry chords to Alt+/ and Alt+b.

## Exit Criteria

- A typed count repeats the next motion (`2j`, `10l`, `3w`, `2n`).
- `2Y`, `2V`, and a selection-less `2y` are linewise over that many lines,
  matching Vim's `2yy`.
- `zz` scrolls the cursor's text line to the middle viewport row.
- Esc discards a half-typed count or `z` without leaving copy mode, clearing
  the selection, or clearing the search.
- Alt+/ enters copy mode alongside `Prefix+s`; Alt+b enters it with the
  backward-search prompt open; Alt+s splits down.
- Focused Rust tests, the copy-mode PTY gate, the Herdr gate, the Fish gate,
  and `git diff --check` pass.

## Scope / Non-goals

In scope:

- The pending-command buffer in the patched copy-mode dispatch, the `showcmd`
  echo in the copy-mode overlay, the reviewed rebuild and re-pin, and the
  production and prototype keybinding moves.

Non-goals:

- `5G` absolute line jumps, `zt`/`zb`/`zj`, operators other than `z`, and
  registers. `z` followed by anything other than `z` is a consumed no-op.
- Rectangle selection, marks, prompt jumps, selection-bounded search, and
  cursor-local URL opening, which stay `blocked by` absent primitives under
  `herdr-upstream-copy-mode-gaps`.
- Input emulation, `pane_history`, recovery changes, Herdr version upgrade,
  upstream publication, commit, or push.

## Decisions

- One `CopyModePending { count, operator }` on `CopyModeState` carries both
  features; there is no second mechanism for `zz`.
- Counts compose existing operations by repetition rather than by new motion
  math: `repeat_copy_mode` runs the existing operation `count` times and stops
  early if copy mode ends.
- Counted linewise yank composes the existing `select_copy_mode_line`, the
  existing downward motion, and the existing copy-and-exit, so `2Y` is exactly
  `V j y`.
- `y` keeps its plain copy-selection-and-exit meaning; it only becomes linewise
  when a count was typed and nothing is selected. A counted `y` with a live
  selection copies the selection and ignores the count.
- A leading `0` stays the line-start motion; `0` is a count digit only after a
  non-zero digit, as in Vim.
- Counts are capped at 9999 so a held digit key cannot become an unbounded
  motion loop.
- `zz` at the live bottom is a no-op rather than a forced scroll: there is no
  newer content to bring into view.
- Alt+d is unbound so it falls through to Neovim; Alt+s is the only split-down
  chord.
- Copy mode has no CLI entry point, so Alt+/ and Alt+b must be native
  bindings; Herdr claims both globally and Neovim's `<M-/>` and `<M-b>` no
  longer see them.

## Evidence / Findings

- `herdr/source-build/verify.sh` pinned the old `'Y' => {` patch shape, so the
  gate failed closed the moment the dispatch arm changed. Its assertions now
  name the new arm and each new test.
- `git diff --check` reads a `.patch` file's blank context lines as trailing
  whitespace. `.gitattributes` exempts `herdr/source-build/*.patch`.
- `herdr/prototype/validate_bindings.sh` fails with `pane_not_found` on the
  committed prototype config too; it is a pre-existing failure of a manual
  gate that nothing runs, not a regression from this work.

## Validation Plan

- Focused Rust tests for count repetition, multi-digit and leading-`0`
  handling, Esc discarding a count and a `z`, `zz` centring, `zz` at the live
  bottom, and counted `Y`/`y`/`V`.
- The disposable PTY copy-mode gate for real Alt+/ entry, `2Y` clipboard
  evidence, Esc discarding a count, Alt+b backward search, and viewport
  movement from `zz`.
- `build.sh --repin`, `./herdr/verify.sh`, `./fish/scripts/verify.sh`,
  `git diff --check`.
- Leave physical Alt+/, Alt+b, Alt+s, `2j`, `2Y`, and `zz` in a newly created
  session to Eddy.

## Ready To Act

Ready.

## Open Questions

None that change implementation.
