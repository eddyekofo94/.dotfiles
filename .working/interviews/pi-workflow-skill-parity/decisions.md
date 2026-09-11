# Pi Workflow Skill Parity

Status: Done — physically accepted 2026-09-12

## Goal

Make the core workflow available in Pi and make every Herdr-created workflow
tab retain the caller's agent family.

## Exit Criteria

- Pi exposes the reviewed core workflow set as `/skill:<name>`, `$<name>`, and
  plain `/<name>` commands.
- Unknown dollar-prefixed skills remain blocked.
- Claude opens Claude, Codex opens Codex, and Pi opens Pi from both
  `herdr-goals` and `herdr-goal-done`.
- Fresh tabs receive the selected `/todo`, `/grill-next`, or delivery prompt.
- Focused tests, `./pi/verify.sh`, diff checks, and fresh Standards/Fidelity
  review pass.

## Scope / Non-goals

- In scope: the eleven cross-project workflow skills used by the agentic loop,
  Pi's native/dollar/plain aliases, both Herdr launchers, tests, and docs.
- Non-goals: automatically load every personal or specialist skill, add
  project-only Claude skills to Pi, change model defaults, push, or overwrite
  shared-checkout work.

## Observation

- Eddy reported on 2026-09-11 that `/todo` and `/goals` are available in Codex
  and Claude Code but absent when typed in Pi.

## Reproduction

- From Bible Standard, Pi's live no-session Remote Procedure Call command
  inventory contains neither `todo` nor `goals`; the exact assertion exits 1.
- A disposable CLI-only probe that explicitly loads the canonical `todo` skill
  and Bible Standard's `goals` skill succeeds, but registers them as
  `skill:todo` and `skill:goals`, not plain `/todo` and `/goals`.
- Eddy's 2026-09-11 Herdr capture shows a `todo` tab running
  `claude --model fable --permission-mode plan "/todo"` after it was opened
  from another agent family; Claude then fails because subscription access is
  disabled.

## Diagnosis

- `pi/settings.json` intentionally allowlists seven reviewed skills and omits
  `/Users/eddyekofo/.agent-skills/todo`.
- Bible Standard owns `goals` only at `.claude/skills/goals/SKILL.md`. Pi
  discovers project `.agents/skills`, not `.claude/skills`, unless the latter
  is added explicitly.
- Pi's native syntax is `/skill:<name>`. The compatibility extension currently
  aliases only the two originally enabled workflow skills and does not provide
  plain `/todo` or `/goals` commands.
- A fresh RPC process reproduces the absence, so `/reload` or restarting an old
  Pi session cannot fix the configured inventory.

## Relationships

- `affects` cross-agent workflow parity.
- `shares implementation seam with` `pi/settings.json`,
  `pi/extensions/compat-core.mjs`, and Pi command-inventory verification.
- `refines` the intentional curated-skill policy in `pi-isolated-pilot`.
- `relates to` `agent-context-on-demand-loading`; capability parity and prompt
  catalog size must be settled together rather than loading every skill by
  accident.

## Scope To Settle

- Settled: expose the explicit cross-project core set: `bug`, `code-review`,
  `diagnosing-bugs`, `feature`, `feature-plan`, `grill-me`, `herdr`, `loop`,
  `skill-finish`, `spec-ticket`, and `todo`.
- Settled: preserve native `/skill:<name>` and add `$<name>` plus plain
  `/<name>` only for that workflow set. Specialist skills stay native-only.
- Settled: preserve the reviewed allowlist, isolation, and fail-closed unknown
  `$skill` policy; do not load the complete private skill tree.
- Settled: project-only Claude skills remain out of scope until they have a
  canonical cross-agent owner.
- Settled caller rule: Claude -> Claude, Codex -> Codex, Pi -> Pi.

## Validation Plan

- Unit-test every dollar alias and deterministic plain-alias skill expansion.
- Assert the complete native and plain command inventories in Pi's isolated
  Remote Procedure Call fixture.
- Exercise Claude, Codex, and Pi routing through both Herdr launchers, including
  fallback identity and automatic boot prompts.
- Run `./pi/verify.sh` and `git diff --check`.
- Run fresh Standards/Fidelity review and fix/re-review until both pass.

## Ready To Act

Ready. Eddy invoked `/feature-plan pi-workflow-skill-parity` on 2026-09-11 and
specified the exact caller rule and preservation constraints.

## Open Questions

None.

## Implementation Evidence

- `pi/settings.json` exposes the eleven settled workflow skills while retaining
  the existing specialist-only inventory.
- `compat-core.mjs` and `eddy-compat.ts` provide native `/skill:<name>`,
  `$<name>`, and plain `/<name>` parity; every other dollar token fails closed.
- `herdr/goals.sh` and `herdr/goal_done.sh` preserve Claude, Codex, and Pi for
  fresh, resumed, ranked-delivery, and `/todo` sessions.
- The focused alias/routing suite passes 21 tests. The isolated full
  `./pi/verify.sh` gate passes, including its SwiftUI fixture, fresh Pi/Herdr
  sessions, and runtime benchmark.
- Fresh review found two coverage/correctness gaps. Both were fixed; Standards
  and Fidelity re-review report PASS with no remaining findings.
- A supplementary `./herdr/verify.sh` run passed the 21 focused tests,
  source-build checks, and project-picker validation, then stopped at its
  intentional live-install assertion because shared-checkout integration links
  do not point into a review worktree. The requested Pi gate exercises its own
  isolated Herdr integration and passed.
- Follow-up 2026-09-12: Eddy's physical launch still reported the project as
  untrusted after `/trust`. `pi/pilot.sh` forced `--no-approve` on every run,
  overriding the saved parent-folder trust decision. The forced override is
  removed; `defaultProjectTrust: never` still denies unknown projects, and the
  launcher still rejects caller-supplied approval overrides.
- `project_trust_test.sh` proves a child project inherits an explicitly trusted
  parent and loads its `.agents/skills`, while an unrelated project containing
  the same fixture skill remains denied. The full Pi gate and post-fix
  Standards/Fidelity re-review pass.
- Eddy confirmed on 2026-09-12 that a fresh physical Pi session shows no trust
  warning and that the workflow skills load correctly. Local merges are
  `e4f70741` and `71d51e9b`; nothing was pushed.

## Stop Condition

- A selected Ready To Act goal must reproduce the exact missing commands,
  implement the settled discovery and alias policy, pass focused command
  inventory coverage plus `./pi/verify.sh`, receive fresh Standards/Fidelity
  review, and leave any physical slash-menu acceptance explicit. All automated
  requirements pass; physical slash-menu acceptance remains manual.
