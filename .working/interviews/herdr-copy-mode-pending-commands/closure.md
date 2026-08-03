# Closure — Herdr Copy-Mode Pending Commands

Status: **AWAITING USER CONFIRMATION** (physical acceptance only).

## What shipped

- `CopyModePending { count, operator }` on `CopyModeState`. A typed count
  repeats the next motion; `z` opens a two-key sequence whose only member is
  `zz`; Esc discards a half-typed command without touching the selection or
  the search.
- Counted linewise yank: `2Y`, `2V`, and a selection-less `2y` cover that many
  lines by composing the existing single-line selector, the existing downward
  motion, and the existing copy-and-exit.
- `zz` centres the cursor's text line by moving the pane scroll offset, using
  the same primitives as the existing page scroll. At the live bottom it is a
  no-op.
- The copy-mode overlay echoes the pending keys the way Vim's `showcmd` does.
- Keybindings: `copy_mode = ["prefix+s", "alt+/"]`, `copy_mode_search =
  "alt+b"` (moved off Alt+s), and Alt+s took over split-down while Alt+d was
  unbound.

## Artifacts

- `herdr/source-build/copy-mode-vim-muscle-memory.patch` — regenerated.
- `herdr/source-build/pins.env` — patch, patched-source, and binary digests
  re-pinned. Binary `7949b02c…`.
- `herdr/source-build/verify.sh` — assertions follow the new dispatch arm and
  name each new test.
- `herdr/source-build/README.md` — documents the pending-command buffer.
- `herdr/config.toml`, `herdr/prototype/config.toml` — keybindings.
- `herdr/prototype/copy_mode_client.py`,
  `herdr/prototype/validate_copy_mode.sh`,
  `herdr/prototype/evidence/copy-mode-validation.jsonl` — PTY gate coverage.
- `herdr/reload.sh`, `herdr/update.sh` — Alt+b in the inert-binding warning.
- `.gitattributes` — exempts the reviewed patch from whitespace checking.

## Verification

- Focused Rust: 51 `copy_mode_*` tests pass, 8 of them new.
- Full patched-source suite: 2775 pass. Two unrelated parallel-execution
  flakes (`AddrInUse`, an idle-stream timeout) pass serially.
- `cargo fmt --check`, `cargo clippy --all-targets --locked -D warnings`,
  `cargo build --release --locked` pass through `build.sh --repin`.
- `validate_copy_mode.sh` PASS with real clipboard and viewport evidence:
  Alt+/ then `2Y` yielded `COPY_LINE_119…\nCOPY_LINE_120…`; a count discarded
  by Esc yielded one line; Alt+b backward search reached line 118; `zz` moved
  the window from 44–82 to 64–102.
- `./herdr/verify.sh` PASS, `./fish/scripts/verify.sh` PASS,
  `git diff --check` clean.
- Reviewed binary installed at `~/.local/bin/herdr`.

## Not run

- Fresh Standards/Fidelity multi-agent review.
- `herdr/prototype/validate_bindings.sh` — pre-existing `pane_not_found`
  failure, reproduced against the committed config; nothing runs it.

## Awaiting Eddy

Physical acceptance in a **newly created** Herdr session (running servers keep
the old executable image): Alt+/, Alt+b, Alt+s, `2j`, `2Y`, `2` then Esc, and
`zz`.

## Not done by design

No commit, no push, no upstream publication.
