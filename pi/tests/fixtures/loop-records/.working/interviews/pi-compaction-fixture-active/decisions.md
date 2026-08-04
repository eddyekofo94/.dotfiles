# pi-compaction-fixture-active

Fixture decisions record. Every sentinel `pi/tests/session_validation.py`
asserts on originates in one of the sections below, so the test proves that
compaction carries a settled record forward rather than proving what this
repository happens to be working on today.

## Goal

Prove that this record survives manual, repeated, and threshold compaction with
its obligations intact. Marker: `pi-compaction-fixture-decisions-record`. The
marker appears only here, so a summary that contains it can only have loaded
this file.

## Exit Criteria

- Manual and threshold compaction both keep this record.
- A second compaction keeps the active skill and this validation plan.
- `pi/verify.sh` passes, followed by a fresh Standards/Fidelity review.

## Scope / Non-goals

In scope: compaction continuity for the isolated Pi pilot.

Non-goals: physical-device QA, provider quality, commit, or push.

## Decisions

- Preserve fixture digest
  `41fb04ce914c46d715fc257091c024f753678f69b19ec480c5ec35a560746580` exactly.
- Keep one canonical repository source; live files are adapters or symlinks.
- Keep the Codex and Claude fallbacks available.
- Keep pilot verification concurrency-safe with a private runtime per run.

## Validation Plan

- `pi/verify.sh` as the single verification command.
- Manual, repeated, and threshold compaction sentinel checks.
- Physical two-window Ghostty QA stays a human gate.

## Open Questions

None.
