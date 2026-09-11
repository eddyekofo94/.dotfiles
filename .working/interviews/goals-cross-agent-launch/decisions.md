# Goals Cross-Agent Launch

## Status

DONE 2026-09-10.

## Trigger

`$goals` invoked from Codex opened Claude because `herdr/goals.sh` hardcoded
the `claude` executable.

## Decisions

- The source Herdr pane owns caller identity.
- Claude callers open Claude sessions with the existing Fable/Opus and
  permission-mode behavior unchanged.
- Codex callers open Codex sessions and Pi callers open Pi sessions, inheriting
  each agent's existing configuration without adding model, approval, or
  sandbox overrides. This supersedes the original 2026-09-10 Pi-to-Codex
  routing decision after Eddy's 2026-09-11 physical `/todo` failure.
- `HERDR_GOALS_AGENT` is a diagnostic override. Agent environment variables are
  fallback evidence when Herdr pane metadata is unavailable.
- Unknown explicit agent identities fail closed. A direct shell invocation with
  no identity preserves the historical Claude default.

## Stop Condition

- Deterministic tests prove Claude -> Claude, Codex -> Codex, and Pi -> Pi.
- Existing named-worktree behavior remains green.
- Full Herdr verification and fresh Standards/Fidelity review pass.
- Eddy physically confirms one Codex invocation opens a Codex session without
  submitting an unintended prompt.

## Verification

- Focused routing and lifecycle suite: 17/17 pass.
- Bash syntax and `git diff --check`: pass.
- Fresh Standards review: 0 findings after adding ranked, resume, precedence,
  fallback, conflict, and unknown-agent rejection coverage.
- Fresh Fidelity review: 0 findings after removing automatic boot prompts from
  Codex and Pi routes.
- Full `herdr/verify.sh` reaches project-picker PASS from the isolated worktree,
  then stops on checkout-specific live integration paths. It must be rerun from
  the shared checkout after merge.
- Physical Codex launch acceptance: PASS 2026-09-10. Tab `goals-routing-qa`
  opened Codex with an empty composer and submitted no prompt.
- Post-merge `./herdr/verify.sh`: PASS, including all 17 focused tests,
  source-build, project-picker, installed integration, and production checks.

## 2026-09-11 Amendment

- The current caller owns every fresh workflow tab, including `/todo` and
  automatically ranked `/deliver` tabs.
- Fresh Codex and Pi tabs receive their assigned boot prompt; dropping it left
  a correctly branded but idle session instead of continuing the workflow.
- `herdr-goal-done` now follows the same caller-identity contract as
  `herdr-goals`; its unconditional Claude launch was the screenshot-confirmed
  regression.
