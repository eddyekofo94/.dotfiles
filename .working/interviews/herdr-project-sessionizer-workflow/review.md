# Herdr Project Sessionizer Review

## Baseline

- Fixed repository baseline:
  `9517357bae77a2cd538148a2761a7393eac2f1c9`.
- Review scope is the goal-specific files/hunks named in
  `.working/ACTIVE_GOAL.md`; unrelated pre-existing dirty work is excluded.
- Standards sources: global `AGENTS.md` instructions supplied for the session,
  the agentic loop standard, `tmux/WORKFLOW_LOOPS.md`,
  `fish/WORKFLOW_LOOPS.md`, and the shared code-review smell baseline.
- Fidelity sources:
  `.working/interviews/herdr-project-sessionizer-workflow/decisions.md`,
  `.working/ACTIVE_GOAL.md`, and
  `docs/migrations/tmux-to-herdr-parity-audit.md`.

## First Fresh Review

Result: Standards 4 findings; Fidelity 4 findings.

- P1: malformed workspace/pane/create responses were not fully validated and a
  malformed post-create response could leave a workspace behind.
- P1: `jq @tsv` escaped valid backslashes, defeating canonical cwd reuse.
- P2: concurrent check-then-create calls could create duplicate workspaces.
- P1: the validator claimed find fallback, mutation-failure, restart-metadata,
  and real fzf coverage that it did not exercise.

## Fixes

- Replaced TSV object parsing with validated compact JSON objects plus lossless
  field extraction; added a real backslash-path create/reuse regression.
- Added strict workspace/pane response shape checks, no-focus creation,
  metadata-before-focus, post-focus verification, focus restoration, and
  close-on-create/metadata/focus/malformed-result rollback.
- Added a session-scoped atomic mutation lock and a competing-picker regression
  with an intentionally delayed first create.
- Added explicit `auto|fd|find` scanner selection and exercised the portable
  find path against the same candidate set.
- Added injected malformed workspace/pane/create responses and create,
  metadata, and focus failures, asserting unchanged workspace count and focus.
- Removed the popup selection override and drove installed fzf through the real
  Herdr session-modal popup with typed query and Enter, twice, proving create
  then reuse.

## Post-fix Review

Result: Standards 5 findings; Fidelity 4 findings.

- P1: mutate-then-error create and adoption paths were not transactionally
  rolled back.
- P1: creation and post-focus response validation remained partial.
- P1: failure and restart evidence claimed more than the validator proved.
- P2: a dead picker process could strand the session mutation lock.
- P2: durable closure claims were ahead of the required zero-finding review.

## Second Fixes

- Added strict complete workspace-list and workspace-create response validation,
  plus strict post-focus list validation.
- Added before/after workspace rollback even when create mutates and exits
  nonzero; creation stays unfocused until metadata is recorded.
- Moved restored-pane identity adoption after verified focus and added rollback
  of focus and `project_cwd` for mutate-then-error metadata failures.
- Made mutation failures real in the API fixture and asserted unchanged
  workspace count, focus, and metadata after create, focus, metadata, malformed
  creation, and malformed post-focus responses.
- Proved restart token loss and restored-pane-cwd re-adoption explicitly.
- Added lock owner PIDs and atomic dead-owner recovery, with a stale-lock
  regression.

## Final Fresh Review

Result: Standards 4 findings; Fidelity 4 findings.

- P1: pane-cwd adoption could overwrite a different existing project identity.
- P1: pane envelopes, create state, and metadata postconditions remained
  insufficiently strict.
- P1: rollback could close unrelated concurrent workspaces and did not verify
  its close/focus postconditions.
- P2: lock ownership had a publication window before its owner PID was written.

## Third Fixes

- Limited pane-cwd restart adoption to tokenless workspaces and rejected
  ambiguous token and tokenless-cwd matches.
- Validated complete pane-list envelopes, focus results, selected create
  label/cwd/focus state, and metadata state by strict readback.
- Made rollback target-specific using the initial workspace snapshot plus pane
  cwd, preserved unrelated concurrent creations, and verified close and restored
  focus postconditions.
- Published the lock owner atomically as a PID symlink, verified exact ownership
  on cleanup, and retained safe legacy dead-directory recovery.
- Added regressions for malformed pane envelopes, wrong create state,
  status-zero metadata no-ops, unrelated concurrent creations, identity
  overwrite prevention, ambiguous tokenless matches, and atomic lock ownership.

## Zero-finding Review

Result: Standards 2 findings; Fidelity 2 findings.

- P1: an unusable create response plus unexpected live cwd could evade
  cwd-targeted rollback when it was the only snapshot delta.
- P1: create response validation was not followed by live workspace/pane
  label/cwd/focus readback, and the prior wrong-state fixture rewrote only JSON.

## Fourth Fixes

- Added unique snapshot-delta rollback fallback when exactly one workspace was
  created; multiple deltas still use target cwd so unrelated work is preserved.
- Added strict live workspace and pane readback for created label, focus, and
  canonical cwd before metadata or focus.
- Added a self-consistent lying response whose real workspace uses the wrong cwd
  and a malformed-response/unexpected-cwd case; both must roll back completely.

## Final Zero-finding Review

Result: Standards 1 finding; Fidelity 1 finding.

- P1: a structurally valid create response rewritten to a pre-existing
  workspace ID sent that old ID to rollback, so the real snapshot delta could
  survive.

## Fifth Fix

- Routed the pre-existing-ID branch through unknown-ID snapshot rollback and
  added a fixture that rewrites every returned workspace reference to an old ID
  after a real creation; workspace count and focus must remain unchanged.

## Closure Review

Result: Standards 0 findings; Fidelity 0 findings.

The fresh reviewer rechecked all prior failure classes, the final
rewritten-existing-ID rollback regression, current hash-bound evidence, and the
Herdr/privacy/tmux invariants. No actionable findings remain.
