# Herdr Copy-Mode Vim Muscle Memory Closure

## Status

DONE — verified closure on 2026-07-31.

## Delivered

- Copy-mode `a` and `i` share the existing `q` exit-without-copy operation.
- Copy-mode `Y` composes the existing whole-line selector and copy-and-exit
  operation.
- The reviewed Herdr 0.7.4 source-build route pins the annotated tag object,
  peeled commit, Rust and Zig versions, patch, patched source, and arm64 macOS
  binary.
- Installation and replacement are atomic, predecessor-bound, and
  rollback-tested.
- No injected-input emulation was introduced.
- `pane_history = false`, recovery behavior, and the tmux fallback remain
  intact.

## Automated Verification

- `./herdr/source-build/build.sh --install`: PASS, including formatting,
  Clippy with warnings denied, 41 copy-mode tests, locked release build, binary
  hash, and installation.
- `./herdr/prototype/validate_copy_mode.sh`: PASS three consecutive focused
  runs after the final isolation fix.
- `./herdr/verify.sh`: PASS after all implementation and review fixes.
- `./fish/scripts/verify.sh`: PASS after all implementation and review fixes.
- Fresh review: Standards 0 / Fidelity 0 after fixes.
- Closure preflight on 2026-07-31: source-build verification, live binary
  digest, `pane_history = false`, executable tmux fallback, focused evidence,
  and `git diff --check` all PASS.
- `shellcheck` was not available and was not run; shell syntax checks passed.

## Human Acceptance

On 2026-07-31, Eddy explicitly accepted the requested physical acceptance:

- `Prefix+s`, selection, then `a` exits without changing the clipboard.
- `Prefix+s`, selection, then `i` exits without changing the clipboard.
- `Prefix+s` then `Y` copies the entire current line and exits.

The human-only stop condition is satisfied.

## Deferred Scope

- `zz` cursor centering remains absent in Herdr 0.7.4 and was not part of this
  goal.
- Rectangle selection, marks, prompt jumps, selection-bounded search,
  cursor-local URL opening, and multi-entry clipboard history remain separate
  intake or upstream-limited work.
- No commit or push was performed.

## Workflow Result

The active-goal pointer is cleared. Re-rank unified intake before activating
the next bounded implementation goal.
