# Named Parallel Dotfiles Worktrees

## Goal

Let Eddy work on multiple independent dotfiles fixes and refinements at once:
each goal has a stable name, a `feature/<slug>` branch, a dedicated worktree,
and a Herdr tab whose label identifies that goal.

## Exit Criteria

- `open <goal>` creates or reuses exactly one worktree at
  `../.dotfiles-sessions/<slug>` from local `main` on `feature/<slug>`.
- The resulting Herdr tab is labelled `<slug>` and opens in that worktree.
- A second independent goal can coexist without sharing a branch, worktree,
  or declared owned path.
- A duplicate goal name reuses the existing worktree; malformed names, a
  dirty shared checkout, and a branch/worktree mismatch fail without creating
  a tab or mutating a worktree.
- `close <goal>` refuses a dirty or unmerged worktree, then removes only the
  finished goal's worktree after its branch is contained in `main`.
- A shared external repository, including `~/.config/nvim`, is never silently
  edited from a dotfiles goal. It requires its own named goal and worktree.

## Scope / Non-goals

- In: generic dotfiles goal names, branch/worktree lifecycle, Herdr tab
  creation, path-collision ownership, status, tests, and manual QA.
- Out: modifying the existing Bible Standard `tools/session_worktree.py`,
  changing agent model routing, automatically creating worktrees in external
  repositories, commits, pushes, or publication.

## Decisions

- Existing owner: `herdr/goals.sh` creates labelled goal tabs and delegates
  worktree creation only when a repository supplies `tools/session_worktree.py`.
- Existing owner: `herdr/goal_done.sh` safely retires a merged, clean goal
  worktree only when that same project-local manager exists.
- Disposition: finetune these generic launch/retirement seams with a
  dotfiles-owned manager; do not add a parallel launcher.
- Naming: lower-case kebab-case `<slug>`; branch `feature/<slug>`; worktree
  `../.dotfiles-sessions/<slug>`; Herdr label `<slug>`.
- Base: every new goal branches from local `main`; existing named worktrees
  are reused rather than recreated.
- External boundary: a goal declares its repository root. Dotfiles worktrees
  may edit only paths within that root. `~/.config/nvim` is a distinct root.
- Collision rule: a second active goal whose declared tracked path overlaps an
  existing goal is rejected. It may continue only after the first goal closes
  or an explicit `transfer` moves that path claim to the second goal.

## Evidence / Findings

- `herdr/goals.sh` already resolves a fresh build goal to a named worktree,
  but falls back to the shared checkout when `tools/session_worktree.py` is
  absent; dotfiles has no such manager.
- `herdr/tab_status.sh` displays deliberate tab labels and derives a worktree
  basename when no label is supplied.
- The completed `agent-prompt-session-scoped-capture` goal crossed into
  `~/.config/nvim`, proving that a dotfiles worktree alone cannot isolate all
  configuration changes.

## Tradeoffs / Risks

- Parallel branches protect Git history but not simultaneous edits to the same
  path; collision policy must be explicit.
- Every implementation goal must declare the tracked paths it owns before its
  worktree can open. This adds brief setup but makes collision rejection
  deterministic and auditable.
- A per-repository worktree model avoids hidden cross-repository mutation but
  means a multi-repository fix needs linked named goals.

## Validation Plan

- Deterministic command tests: create, reuse, malformed-name rejection,
  duplicate-branch rejection, dirty-shared rejection, clean/merged close,
  dirty/unmerged close refusal, and no-tab-on-failure.
- Collision tests: two independent path sets pass; an overlapping path set
  follows the settled policy; claims release on successful close.
- Herdr integration test: each successful open reports its exact worktree and
  creates one correctly labelled tab; failed opens create none.
- Manual QA: open two named goals concurrently, verify their branches, cwd,
  tab labels, and isolated edits; verify an external Neovim goal is rejected
  from the dotfiles manager and opened only through that repository's manager.

## Ready To Act

Ready. Implementation is intentionally deferred from this planning run.

## Implementation Evidence — 2026-09-10

- `tools/session_worktree.py` now owns dotfiles-local create/reuse, tracked-path
  claims, explicit transfer, clean/merged close, and compatibility aliases for
  Herdr's `create`/`open`, `close`/`remove`, and `shared-status` calls.
- `herdr/goals.sh` accepts comma-separated declared paths in the fifth SPEC
  field and resolves the worktree before creating a tab.
- `tools/tests/session_worktree_test.py` and `tools/tests/goal_done_test.py`
  have sixteen hermetic cases covering claim serialization, canonical and
  hierarchical collision rejection, repository-specific singular/plural path
  interfaces, automatic-next-goal fallback, and the original lifecycle and
  Herdr integration paths.
- The original lifecycle coverage includes
  create/reuse, dirty shared refusal, malformed names, mismatched worktrees,
  clean/merged close, dirty/unmerged close refusal, collision/transfer, claim
  release, exact Herdr tab cwd/label, and no tab after a failed open.
- Focused verification passed: `python3 -m unittest -v
  tools.tests.session_worktree_test tools.tests.goal_done_test`, `bash -n
  herdr/goals.sh herdr/goal_done.sh herdr/verify.sh`, and `git diff --check`.
- Review fixes serialize claim transactions, normalize path claims, reject
  ancestor/descendant overlaps, preserve declared paths from linked worktrees,
  adapt to each repository manager's declared path flag, and route a failed
  automatic goal open to Fable `/todo` instead of shared-checkout delivery.
- Full `./herdr/verify.sh` passes, including the focused worktree and automatic
  goal-close regressions.
- Manual Herdr/Ghostty QA was not run. The exact `herdr tab create --cwd` and
  failure-without-tab contracts are covered through a deterministic fake Herdr
  executable.
- Final fresh review: Standards 0 findings; Fidelity 0 findings.

## Open Questions

None.
