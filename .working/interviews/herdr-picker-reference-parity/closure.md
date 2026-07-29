# Herdr Picker And Visible-Reference Parity Closure

## Loop Boundary

- Trigger: the ranked `herdr-picker-reference-parity` goal was explicitly
  selected for implementation and closure.
- Scope: confirmed/stale-safe pane/tab/workspace deletion plus recent pane-read
  URI/path/hash discovery outside copy mode.
- Stop condition: focused validation, full Herdr/Fish verification, and fresh
  post-fix Standards/Fidelity review pass while the preservation constraints
  remain true.
- Human handoff: none for this bounded engineering slice. Final Herdr
  daily-driver acceptance remains a separate migration decision.

## Implementation

- `Prefix+Shift+f` opens a searchable one-target destructive object manager.
- Pane fingerprints bind pane, terminal, tab, and workspace identity.
- Tab/workspace fingerprints bind descendant pane/terminal ownership and reject
  concurrent identity or topology changes.
- Inventories reject duplicate IDs, duplicate terminals, and inconsistent
  workspace/tab/pane ownership before displaying destructive candidates.
- Every close requires `y`/`yes`; cancel, picker failure, malformed inventory,
  missing target, or changed target is inert.
- `Prefix+Shift+r` extracts newest-first unique URI/path/hash references from up
  to 1,000 recent unwrapped focused-pane lines.
- Enter copies; Ctrl-O opens URI/path references, resolves relative and `~/`
  paths, and rejects hashes.
- Pane-derived labels and reference text strip terminal control characters
  before fzf display.
- Native `Prefix+f` remains goto; no copy-mode input or primitive is emulated.

## Verification

- `./herdr/prototype/validate_picker_reference.sh` — PASS after the final fixes.
  Fixture and real PTY evidence is recorded in
  `herdr/prototype/evidence/picker-reference-validation.jsonl`.
- All hash-bound Herdr evidence producers were refreshed against the
  two-binding config change — PASS.
- `./herdr/prototype/verify.sh` — PASS.
- `./herdr/verify.sh` — PASS.
- `./fish/scripts/verify.sh` — PASS. Final benchmark: 30 runs, median
  25.234 ms, p95 26.830 ms.
- `git diff --check` — PASS.
- Shell syntax and Python compilation for the affected helpers/fixtures —
  PASS.
- Herdr version readback — `herdr 0.7.4`.
- Production config assertion — `pane_history = false`.
- tmux executable and tracked tmux/Fish/Ghostty/Neovim hashes remained
  available/unchanged during the focused gate.

## Fresh Review

Fixed point: `9517357bae77a2cd538148a2761a7393eac2f1c9`, with the
active-goal file set and relevant untracked files reviewed separately from
unrelated dirty work.

Standards sources: supplied global `AGENTS.md`, the agentic loop standard,
`tmux/WORKFLOW_LOOPS.md`, `fish/WORKFLOW_LOOPS.md`, and the code-review smell
baseline.

Fidelity sources:
`.working/interviews/herdr-picker-reference-parity/decisions.md` and
`docs/migrations/tmux-to-herdr-parity-audit.md`.

First review findings fixed:

1. `~/` path opening produced `$HOME/~/...`; corrected and regression-tested.
2. Pane-derived text could retain terminal control bytes; sanitized and
   regression-tested.
3. Tab/workspace stale fingerprints omitted descendant terminal identities;
   fingerprints and replacement-identity fixtures were strengthened.

### Standards

Findings: 0 after fixes.

No hard project-rule violations or actionable smell-baseline findings remain.
The implementation stays within the active goal, uses structured Herdr APIs,
fails closed around destructive state, preserves unrelated dirty work, and
adds deterministic prevention for each review finding.

### Fidelity

Findings: 0 after fixes.

The final behavior matches the settled bindings, confirmation, stale-state,
reference-type/action, preservation, and non-goal requirements. The evidence
does not claim cursor-local, selection-bounded, or other copy-mode parity.

### Summary

Standards findings: 0. Fidelity findings: 0. Worst issue in each axis: none
remaining after the automatic fix/re-review loop.

## Preserved Boundaries

- Herdr remains v0.7.4.
- `pane_history = false` remains active.
- tmux remains installed and available.
- No commit, push, Herdr upgrade, external publication, or copy-mode emulation
  occurred.
- Existing unrelated dirty and untracked work remains present.

## Status

Verified closed on 2026-07-29.
