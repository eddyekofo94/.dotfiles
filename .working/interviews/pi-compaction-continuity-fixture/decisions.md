# pi-compaction-continuity-fixture

Selected 2026-08-03. `pi/verify.sh` was red and blocked every other Pi item, so
the compaction continuity gate was taken first.

## Goal

Make `pi/verify.sh` green by fixing the two real defects behind the red
compaction gate: a test that asserted against this repository's mutable
planning prose, and goal-record selection that took the first backticked slug
in `.working/ACTIVE_GOAL.md` regardless of whether that goal still owned a
decisions record.

## Exit Criteria

- `pi/verify.sh` passes end to end.
- The compaction gate asserts against a fixed fixture tree, not live prose.
- Selection reaches the record it claims to load, and the summary names it.
- Fresh Standards/Fidelity review at 0 / 0.

## Scope / Non-goals

In scope: compaction goal-record selection, the loop-records fixture, and the
standalone-run diagnostic in `pi/tests/session_validation.py`.

Non-goals: commit, push, provider quality, and physical-device QA.

## Decisions

- `selectGoalRecordSlug` (`pi/extensions/compaction-core.mjs`) takes the first
  slug that owns a *usable* decisions record — one that yields the sections
  compaction carries — not the first slug outright.
- The winner can still be a closed goal when the open goal owns no record, so
  `buildLoopCompaction` names the record it loaded under a `Source:` line.
  Unlabelled decisions can read as current when they are not.
- When no slug owns a record, the summary names every slug that was tried
  instead of degrading to an empty section.
- `pi/tests/session_validation.py` runs with `cwd=pi/tests/fixtures/loop-records`.
  Its sentinels live only in that fixture's decisions record; the seed prompt
  was stripped of them so the conversation tail cannot satisfy the assertion.
- The fixture lists a record-less slug first, so the integration gate fails if
  selection regresses to first-slug-wins.
- Every compaction site in the validator reports the standalone-run cause:
  production `keepRecentTokens` is 20000, so a fixture-sized session cannot
  compact at all outside `pi/validate_sessions.sh`.

## Validation Plan

- `pi/verify.sh` as the single verification command.
- `pi/tests/compat_core_test.mjs` covers slug selection and summary rendering
  directly.
- Manual, repeated, and threshold compaction sentinel checks in the session
  gate.
- Fresh Standards/Fidelity review of the diff.
- Physical two-window Ghostty QA stays a human gate.

## Open Questions

- Whether the fixture tree should be committed before the rest of the Pi work
  ships; `session_validation.py` fails on a fresh clone while it is untracked.
