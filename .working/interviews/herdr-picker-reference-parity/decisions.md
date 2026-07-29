# Herdr Picker And Visible-Reference Parity

## Goal

Add bounded Herdr-native replacements for the destructive part of the tmux
window picker and broad URI/path/hash discovery without implying copy-mode
parity.

## Exit Criteria

- A searchable popup can select one pane, tab, or workspace for deletion.
- Every delete requires an explicit confirmation and rejects a stale or changed
  target before mutation.
- A separate searchable popup lists URI, path, and hexadecimal-hash references
  from recent focused-pane readback.
- Enter copies the selected reference; Ctrl-O opens URI/path references and
  refuses hashes.
- Real prefix bindings, focused validators, full Herdr/Fish verification, and
  fresh Standards/Fidelity review pass.
- Durable tracking closes the goal without claiming unsupported copy-mode
  behavior.

## Scope / Non-goals

In scope:

- `Prefix+Shift+f`: one-target pane/tab/workspace destructive picker.
- `Prefix+Shift+r`: recent pane-read URI/path/hash picker.
- Searchable labels and a metadata preview for destructive targets.
- Exact reference type/value/context visibility.
- Stale-target and cancellation/error regression coverage.

Non-goals:

- Replacing native `Prefix+f` navigation.
- Multi-target or session deletion.
- Rectangle selection, marks, prompt jumps, selection-bounded search,
  cursor-local URL opening, or any other unsupported copy-mode primitive.
- Input emulation, pane-history persistence, Herdr upgrades, tmux removal, or
  publication.

## Decisions

- Native goto remains the default navigation path at `Prefix+f`.
- Destructive management is isolated at `Prefix+Shift+f`.
- One target is deleted per invocation so confirmation and stale-state
  ownership remain unambiguous.
- The confirmation prompt names the exact type, ID, and label. Only `y` or
  `yes` proceeds.
- Pane identity includes terminal, tab, and workspace ownership. Tab and
  workspace identity includes their current descendants, so concurrent
  topology changes invalidate the selection.
- Visible-reference search is an outside-copy-mode replacement at
  `Prefix+Shift+r`; it reads bounded recent unwrapped pane output without
  enabling `pane_history`.
- Enter copies every reference. Ctrl-O opens URI/path references and rejects
  hashes.
- Relative paths resolve from the focused pane's reported foreground cwd, then
  cwd.
- Herdr stays at v0.7.4, `pane_history = false` stays enforced, and tmux remains
  available.

## Evidence / Findings

- `docs/migrations/tmux-to-herdr-parity-audit.md` ranks this goal fourth and
  explicitly separates it from upstream-limited copy-mode gaps.
- The tmux fzf window picker supports searchable destructive window removal,
  while Herdr's native navigator already supplies the non-destructive
  workspace/tab/pane navigation path.
- Herdr v0.7.4 exposes structured pane/tab/workspace list and close commands and
  bounded `pane read` sources.
- Existing Herdr helpers already establish jq validation, fzf popup, exact
  confirmation, preservation, and stale-target conventions.

## Tradeoffs / Risks

- Recent pane readback is broader than the currently painted viewport and does
  not preserve cursor locality or selection bounds.
- Reference extraction is intentionally heuristic; the popup exposes type and
  context so the user can verify a match before acting.
- Closing an object is irreversible at the terminal-process layer; explicit
  confirmation and fresh topology fingerprints reduce accidental or stale
  deletion but do not create undo.

## Validation Plan

- Focused parser/fixture coverage for URI/path/hash extraction, deduplication,
  punctuation trimming, ordering, relative-path resolution, copy/open
  dispatch, hash-open refusal, cancellation, picker failure, confirmation, and
  stale pane/tab/workspace rejection.
- Real disposable Herdr PTY coverage for both prefix popup bindings and a
  confirmed non-current target deletion.
- Assert native `Prefix+f`, Herdr v0.7.4, `pane_history = false`, tmux config,
  and unrelated production hashes remain preserved.
- Run `./herdr/prototype/validate_picker_reference.sh`,
  `./herdr/verify.sh`, and `./fish/scripts/verify.sh`.
- Run fresh Standards and Fidelity review against this record, the parity
  audit, the final diff, and validation evidence; fix and re-review.

## Ready To Act

Ready.

## Open Questions

None that change implementation.
