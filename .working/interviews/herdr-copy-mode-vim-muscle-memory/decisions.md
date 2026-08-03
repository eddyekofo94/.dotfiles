# Herdr Copy-Mode Vim Muscle Memory

## Goal

Make the retained Herdr 0.7.4 copy mode honor Eddy's highest-frequency Vim exit
and line-yank muscle memory through a reviewed, reproducible source build.

## Exit Criteria

- After `Prefix+s`, `a` and `i` immediately exit copy mode without copying.
- After `Prefix+s`, `Y` selects the whole current line, copies it, and exits.
- The implementation aliases or composes the existing `q`, `V`, and `y`
  operations and uses no injected-input emulation.
- The exact annotated v0.7.4 tag object and commit, patch, patched source,
  Rust/Zig toolchains, and built binary are pinned and verified.
- Focused source tests, the Herdr gate, the Fish gate, and fresh
  Standards/Fidelity review pass.
- Only physical `Prefix+s` then `a`, `i`, and `Y` acceptance remains for Eddy.

## Scope / Non-goals

In scope:

- Copy-mode command dispatch and focused adjacent Rust tests.
- A local source patch, source/toolchain/binary pins, reproducible builder,
  atomic installer support, and verification integration.
- Installing the reviewed binary for newly created Herdr sessions without
  stopping any running retained session.

Non-goals:

- `zz` cursor centering; exact v0.7.4 source has no `z`/`zz` command.
  Superseded on 2026-08-01 by `herdr-copy-mode-pending-commands`, which adds a
  pending-command buffer and implements `zz` on top of it.
- Rectangle selection, marks, prompt jumps, selection-bounded search,
  cursor-local URL opening, or multi-entry clipboard history.
- `pane_history = true`, recovery changes, tmux removal, input injection,
  Herdr version upgrade, upstream publication, commit, or push.

## Decisions

- `a` and `i` share the exact exit-without-copy dispatch arm with `q`.
- `Y` calls the existing whole-line selector and then the existing
  copy-and-exit operation, matching the approved `V` then `y` behavior.
- Keep `herdr --version` at `0.7.4`; provenance is enforced by exact source,
  toolchain, patch, patched-source, and binary hashes rather than a misleading
  new upstream version.
- Use the upstream-pinned Rust 1.96.1 and release-workflow Zig 0.15.2 with
  `Cargo.lock`, `ReleaseFast`, and SIMD enabled.
- Install atomically, accept replacement only from an explicitly identified
  current hash, and do not restart active sessions.
- Preserve `pane_history = false`, native agent recovery, and
  `herdr/tmux_fallback.sh`.

## Evidence / Findings

- Exact annotated tag `v0.7.4` is tag object
  `54208dc16efe15ea92d7f131439d43cbd84b489e`, peeling to commit
  `50aaa2ec046ee26ff407c20f49de496f522512a8`.
- Tagged `src/app/input/copy_mode.rs` dispatches `q` to
  `exit_copy_mode(..., false)`, `y` to `exit_copy_mode(..., true)`, and `V` to
  `select_copy_mode_line(...)`.
- `copy_mode_command_char` does not implement multi-key sequences and the
  dispatch has no `z`, so `zz` is currently two no-ops rather than centering.
- The upstream config exposes entry into copy mode, not its internal command
  table. A source patch is the faithful ownership seam.
- Upstream is AGPL-3.0-or-later; the corresponding pinned public source and
  local patch remain available beside the build route.

## Tradeoffs / Risks

- Running servers retain the old executable image until they naturally close;
  physical acceptance must use a newly created named session.
- The local binary is a private fork of 0.7.4. Every future retained-version
  change must re-review or remove the patch rather than silently carrying it.
- A binary hash is architecture/toolchain-specific by design; unexpected build
  drift fails closed for review.

## Validation Plan

- Run the two new Rust tests and the existing copy-mode Rust test family from
  the exact patched source.
- Build `--release --locked`, verify all source/toolchain/patch/binary pins,
  and exercise safe installer success/refusal paths.
- Extend the disposable PTY copy-mode gate for actual `a`, `i`, and shifted
  `Y` input plus clipboard evidence.
- Run `./herdr/verify.sh`, `./fish/scripts/verify.sh`, `git diff --check`, and
  fresh Standards/Fidelity review after the final fix.
- Leave physical `Prefix+s` then `a`, `i`, and `Y` in a new session to Eddy.

## Ready To Act

Ready.

## Open Questions

None that change implementation.
