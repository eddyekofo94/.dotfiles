# Pi Meaningful Session Names — Implementation Brief

Status: Automated complete; awaiting Ghostty acceptance

## Source

- `.working/interviews/pi-meaningful-session-names/decisions.md`
- `.working/UNIFIED_INTAKE.md`

## Scope

- Add one deterministic session-name resolver owned by
  `pi/extensions/eddy-compat.ts` or a focused sibling core module.
- Route ordinary unnamed startup and durable unsubmitted handoffs through it.
- Preserve all explicit and persisted names, including resume and fork.
- Cover contextual precedence, normalization, collisions, and fallbacks.

## Non-goals

- Herdr/Codex changes, prompt inference, existing-session migration, commit,
  push, or automated physical acceptance.

## Acceptance Criteria

- A named goal worktree produces its goal slug.
- A non-default branch produces its normalized branch with `feature/` removed.
- A default-branch checkout produces its Git repository basename.
- A non-Git directory produces its basename.
- A contextual collision adds the shortest stable session-identity suffix required.
- Unavailable/invalid context uses the existing generated fallback.
- Startup and handoff use the same resolver; explicit/resumed/forked names do
  not change.

## Implementation Seams

- `pi/extensions/eddy-compat.ts`: creation lifecycle and shared resolver call.
- `pi/tests/`: deterministic resolver and session lifecycle coverage.
- Existing Pi validation harness for the full isolated gate.

## Stop Condition

Focused coverage and `./pi/verify.sh` pass; `git diff --check` is clean; fresh
Standards and Fidelity review report zero findings after any fixes; workflow
records identify Ghostty sidebar acceptance as the sole remaining manual gate.

## Validation

- Focused extension/session tests.
- `./pi/verify.sh`.
- `git diff --check`.
- Fresh Standards and Fidelity review against the decision record.
- Eddy's physical Ghostty/Herdr grouped-sidebar confirmation after handoff.
