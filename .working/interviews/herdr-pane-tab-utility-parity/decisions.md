# Herdr Pane And Tab Utility Parity

## Goal

Close the next ranked tmux-to-Herdr utility slice with process-preserving pane
transfer, explicit scrollback export, first/last tab helpers, and only layout
presets that Herdr v0.7.4 can apply without replacing pane terminals.

## Exit Criteria

- A focused pane can be sent to another pane or a selected pane can be received
  beside the focus through one stale-safe interactive picker.
- Focused-pane scrollback can be exported to an explicitly entered path; a
  pre-existing path is never replaced without an explicit confirmation.
- First/last tab helpers use current workspace API order without changing the
  approved `Prefix+Tab` last-pane behavior.
- Tiled/equalize and topology-compatible even/main presets update ratios only.
  Incompatible named presets reject before mutation.
- Same-workspace transfers retain pane IDs. Cross-workspace transfers may
  receive Herdr's destination-workspace pane ID, while terminal ID, sentinel
  PID, cwd, and focus survive. Every layout path retains pane IDs too.
- Focused validation, `./herdr/verify.sh`, `./fish/scripts/verify.sh`, and fresh
  Standards/Fidelity review all pass after the final fix.

## Scope / Non-goals

- Add one pane-transfer popup, one history-export popup, two tab-edge helpers,
  and the bounded process-safe layout palette.
- Keep Herdr v0.7.4, `pane_history = false`, and tmux installed and available.
- Preserve all unrelated dirty work, integrations, hooks, plugins, and
  migration behavior.
- Do not use `layout.apply`, replace or restart pane processes, enable pane
  history, upgrade Herdr, remove tmux, change the default multiplexer, commit,
  push, or publish.
- Rich destructive picker operations, visible-reference search, clipboard
  history, pane input locking, outer-title work, and upstream copy-mode gaps
  remain separate intake.

## Decisions

- `Prefix+Shift+p` opens one pane-transfer popup. Its fzf choices cover both
  “send focused pane beside destination” and “receive selected pane beside
  focus”; no pane ID must be typed manually.
- Transfer candidates carry source and destination pane IDs but are re-read
  after selection. Self, missing, malformed, or stale endpoints fail before
  `pane move`.
- Transfers use Herdr's native pane-move API and preserve the moved terminal
  identity. The destination split is below the selected target, matching the
  old vertical `join-pane` behavior. Candidates span the session. Herdr v0.7.4
  remaps a pane ID into the destination workspace namespace on a cross-workspace
  move, so postconditions follow the stable terminal ID and report both IDs.
- `Prefix+Shift+u` opens history export. The helper reads focused-pane recent
  text through the Herdr API, asks for an explicit path, creates a new file
  without clobbering, and asks `y/N` before replacing an existing path.
- `Prefix+^` focuses the first tab and `Prefix+$` focuses the last tab in API
  list order. `Prefix+Tab` and `Ctrl+^` remain last-pane navigation.
- The layout palette retains equalize, zoom, adaptive split, fixed right split,
  and cancel. It adds tmux-menu-compatible symbols for tiled (`+`),
  main-horizontal (`_`), main-vertical (`|`), even-horizontal (`\`), and
  even-vertical (`-`).
- Tiled/equalize changes only split ratios and keeps the existing topology.
  Even-horizontal requires an all-right split tree; even-vertical requires an
  all-down split tree. Main-horizontal requires a top main leaf over an
  all-right remainder; main-vertical requires a left main leaf beside an
  all-down remainder. A single-pane tab is a safe no-op for every preset.
- Main presets use a 62% main-pane ratio. Every other compatible subtree is
  leaf-weight equalized. Focus is not changed by a preset.

## Evidence / Findings

- The ranked parity audit explicitly names pane transfer, history export, tab
  edges, and process-preserving layout presets as sequence item three.
- Herdr v0.7.4 exposes `pane move`, `pane read`, ordered `tab list/focus`,
  `layout.export`, and `layout.set_split_ratio`.
- A disposable v0.7.4 probe showed that rebuilding a layout with
  `layout.apply`, even when the request reused existing pane IDs, made the old
  panes unavailable. That method is excluded from this goal.
- Existing equalize validation already proves split-ratio updates preserve the
  exact BSP topology and sentinel processes.
- Existing bindings reserve uppercase pane-navigation chords for swaps,
  `Prefix+Shift+s` for the sidebar, and `Prefix+Tab`/`Ctrl+^` for last pane.
  The selected utility chords do not disturb those ownership rules.

## Tradeoffs / Risks

- Ratio-only named presets are intentionally conditional. They do not pretend
  Herdr can safely rebuild arbitrary topology like tmux's preset engine.
- A pane may naturally exit between process readback and a transfer/layout
  operation. Validation proves the helpers do not themselves replace live
  processes; it cannot keep an independently exiting command alive.
- Terminal text export is byte-preserving at the decoded-text boundary, not a
  raw terminal-state archive. ANSI styling and pane-history persistence remain
  outside the approved privacy boundary.
- Popup helpers depend on `fzf`, `jq`, and the current Herdr socket/API. Missing
  dependencies fail closed.

## Validation Plan

- Add a focused isolated utility validator covering same- and cross-workspace
  send/receive transfer, stale/self/cancel rejection, moved terminal/PID/cwd
  identity, 320-line exact-text history contents, no-clobber and confirmed
  overwrite, tab-edge focus, all supported
  layout shapes, incompatible-layout no-op behavior, exact focus retention,
  and production-scope hashes.
- Drive both new popup bindings through a real fixed-size Herdr PTY client and
  prove cancel leaves panes and files unchanged.
- Extend aggregate evidence assertions so stale evidence cannot pass.
- Run `./herdr/verify.sh`.
- Run `./fish/scripts/verify.sh`.
- Confirm `herdr --version` remains `herdr 0.7.4`,
  `pane_history = false`, and `command -v tmux` still succeeds.
- Run a fresh two-axis review against this record, the active brief, the
  goal-specific diff, global/project standards, and current evidence; fix and
  re-review until Standards and Fidelity both have zero findings.

## Ready To Act

Ready. The user selected this ranked goal and explicitly settled the four
utilities, process-preservation boundary, privacy/fallback constraints, and
publication exclusions.

## Implementation Brief

- Source: this decision record and
  `docs/migrations/tmux-to-herdr-parity-audit.md`.
- Seams: `herdr/prototype/` helpers and validators, prototype and production
  Herdr configs, aggregate verification/evidence, migration docs, and `.working`
  goal/intake state.
- Stop condition: every exit criterion above is verified, fresh review is
  zero-finding after the last change, closure evidence is durable, and the
  active pointer is cleared.
- Manual gate: none for this non-visual API/helper slice unless live validation
  exposes behavior automation cannot prove.
- Dependencies: installed pinned Herdr v0.7.4, `jq`, `fzf`, `nc`, Fish, and
  tmux fallback. No hosted tickets or publication steps are needed.

## Open Questions

None that change implementation.

## Closed

Closed on 2026-07-28.

- Focused utility and layout validators pass with hash-bound evidence.
- `./herdr/verify.sh` passes, including production verification.
- `./fish/scripts/verify.sh` passes; the coordinator's final 30-run startup
  benchmark was 24.430 ms median and 24.820 ms p95.
- Fresh closure review is Standards 0 / Fidelity 0 after all fixes.
- Herdr remains v0.7.4, both configs retain `pane_history = false`, and tmux
  3.7b remains available.
- HEAD remains `9517357bae77a2cd538148a2761a7393eac2f1c9`; no commit, push,
  Herdr upgrade, default-multiplexer change, or tmux removal occurred.
- Detailed verification and review history:
  `.working/interviews/herdr-pane-tab-utility-parity/review.md`.
