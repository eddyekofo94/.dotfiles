# Goals Cross-Agent Launch

## Status

Ready To Act. Selected by Eddy on 2026-09-10.

## Trigger

`$goals` invoked from Codex opened Claude because `herdr/goals.sh` hardcoded
the `claude` executable.

## Decisions

- The source Herdr pane owns caller identity.
- Claude callers open Claude sessions with the existing Fable/Opus and
  permission-mode behavior unchanged.
- Codex and Pi callers open plain Codex sessions, inheriting the user's existing
  Codex configuration without adding approval or sandbox overrides.
- `HERDR_GOALS_AGENT` is a diagnostic override. Agent environment variables are
  fallback evidence when Herdr pane metadata is unavailable.
- Unknown explicit agent identities fail closed. A direct shell invocation with
  no identity preserves the historical Claude default.

## Stop Condition

- Deterministic tests prove Claude -> Claude, Codex -> Codex, and Pi -> Codex.
- Existing named-worktree behavior remains green.
- Full Herdr verification and fresh Standards/Fidelity review pass.
- Eddy physically confirms one Codex invocation opens a Codex session without
  submitting an unintended prompt.
