# Fish Prompt Return Latency

## Goal

Make Fish ready for input without perceptible post-command delay.

## Exit Criteria

- Real interactive Fish prompt-return p95 is at most 50 ms in this repository
  and `/Users/eddyekofo/Documents/Family_Business/RubyandRiver`.
- Full Fish verification passes.
- Fresh Standards and Fidelity reviews pass after the last change.
- Eddy accepts prompt return in physical Ghostty.

## Scope / Non-goals

- Preserve Starship Git status and eza `ll --git`.
- Repair RubyandRiver in place; preserve its exact path, worktree, refs, local
  commits, remotes, and ignored data.
- Preserve directory, Git branch, right-side command duration, Fish vi mode,
  and all other prompt appearance.
- Do not add async workers, persistent prompt caches, commits, or pushes.

## Decisions

- Quarantine only the proven stale zero-byte `.git/index.lock`; do not move the
  repository or broadly clean its Git metadata.
- Restore Starship Git status and retain `ll --git` after the index refresh.
- Use a 50 ms p95 regression boundary. The original 20 ms diagnostic boundary
  conflicts with retained Git presentation; 50 ms still fails the reproduced
  0.9-second regression by a wide margin.
- Measure Enter through Fish's OSC 133 prompt-ready marker in a real PTY.

## Evidence / Findings

- See `observations.md`.
- Clean RubyandRiver: prompt p95 959 ms; `git_status` 814 ms; Git index refresh
  912 ms; isolated simple prompt 0 ms.
- Insert, default, and normal keymaps all remain slow. Fish vi mode is not the
  cause.

## Tradeoffs / Risks

- iCloud/File Provider conflict copies and temporary Git objects remain. They
  may recreate stale locks; cleanup was not authorized by the in-place repair.
- Timing checks can be affected by severe host load; the exact regression is
  large enough to remain distinguishable.

## Validation Plan

- Run `fish/tests/measure_prompt_latency.exp` against this repository and
  RubyandRiver.
- Run `./fish/scripts/verify.sh`.
- Run fresh Standards and Fidelity review on the final diff.
- Confirm physical Ghostty prompt feel manually.

## Ready To Act

Implemented and closed DONE. User rejected removing Git tool by tool, selected
the in-place repair, and accepted physical Ghostty behavior on 2026-08-01.

## Open Questions

None that change implementation.
