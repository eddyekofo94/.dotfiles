# Herdr Pane And Tab Utility Parity Closure Review

## Scope

Baseline: `9517357bae77a2cd538148a2761a7393eac2f1c9`.

Reviewed the settled `herdr-pane-tab-utility-parity` implementation against
`decisions.md`, the ranked migration audit, global loop requirements, current
goal-scoped source/evidence hashes, and the user's preservation/publication
exclusions.

## Verification

- `./herdr/prototype/validate_utilities.sh`: PASS.
- `./herdr/prototype/validate_layout_menu.sh`: PASS.
- `./herdr/prototype/verify.sh`: PASS.
- `./herdr/verify.sh`: PASS. This included project picker, integrations, Fish
  login attach, utility parity, layout menu, prototype aggregate, production
  config assertions, and diff checks.
- `./fish/scripts/verify.sh`: PASS. Final coordinator run: 30 startup runs,
  24.430 ms median, 24.820 ms p95.
- `sh -n` on changed Herdr shell helpers/fixtures: PASS.
- `git diff --check -- herdr/prototype`: PASS.
- Direct invariants: Herdr `0.7.4`; prototype and production
  `pane_history = false`; tmux `/opt/homebrew/bin/tmux`, version `3.7b`;
  unchanged HEAD.

## Regression Prevention

- Transfer evidence covers same- and cross-workspace send and receive, stale /
  self / cancel rejection, forced post-move rollback, and a sole-pane injected
  native move failure with temporary-guard cleanup.
- History evidence covers exact ordered lines 001 through 320, JSON-like text,
  trailing newline, mode 0600, refusal, confirmed overwrite, after-open path
  replacement, and before-open dangling-symlink replacement without referent
  creation.
- Layout evidence covers every compatible named preset and every single-pane
  no-op through the real popup binding, incompatible pre-mutation rejection,
  exact process/topology/focus survival, and a multi-update foreign-ratio race
  that fails closed without claiming or rolling back the foreign change.
- Aggregate verification binds source, fixture, validator, config, and
  production-scope hashes so stale evidence cannot pass.

## Review History

The first fresh review found 7 Standards and 6 Fidelity issues. Fix/re-review
loops addressed exact scrollback extraction, newline/JSON-like preservation,
private overwrite semantics, stale tab order, session-wide transfers,
cross-workspace ID semantics, all real preset bindings, live invariant
readback, production config assertions, concurrent ratio ownership, rollback,
and durable failure injection.

Final independent closure review:

- Standards: 0 findings.
- Fidelity: 0 findings.

## Closure

Status: DONE. No manual acceptance gate remains for this non-visual helper/API
slice. No commit, push, hosted mutation, Herdr upgrade, pane-history enablement,
default-multiplexer change, or tmux removal was performed. Unrelated dirty work
was preserved.
