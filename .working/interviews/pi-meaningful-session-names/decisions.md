# Pi Meaningful Session Names

Status: Automated complete; awaiting Ghostty acceptance

## Goal

Give every automatically named Pi session a short, durable identity derived
from its work context so Herdr's grouped agents sidebar remains readable.

## Exit Criteria

- Explicit and previously persisted names remain unchanged.
- New unnamed sessions use one shared resolver for ordinary startup and durable
  unsubmitted handoffs.
- The resolver prefers a named-worktree slug, then a non-default branch, Git
  repository basename, current-directory basename, and generated fallback.
- Resume and fork names remain stable.
- Focused tests, `./pi/verify.sh`, `git diff --check`, and fresh Standards and
  Fidelity review pass.
- Ghostty sidebar acceptance remains explicitly awaiting Eddy.

## Scope / Non-goals

In scope: the Pi compatibility extension, focused deterministic coverage,
session-creation fixtures, and durable local workflow records.

Out of scope: Herdr rendering changes, Codex integration changes, prompt-text
inference, rewriting existing sessions, commit, push, and automated claims of
physical visual acceptance.

## Decisions

- Assign an automatic name only when Pi has no explicit or persisted name.
- Derive the name once when its durable session is created; do not continuously
  rename when cwd or branch changes.
- Use this precedence: repository-managed named-worktree slug; normalized
  non-default Git branch with `feature/` stripped; Git repository basename;
  current-directory basename; existing timestamp-based fallback.
- Apply the same resolver to startup and durable handoff replacement sessions.
- Preserve resume and fork identity even when reopened from another cwd.
- Do not derive names from prompts.
- Keep labels lower-case and filename-safe. When a generated contextual label
  collides, append the shortest stable session-identity suffix needed to
  distinguish it instead of exposing the former timestamp/process identifier.

## Evidence / Findings

- Eddy's 2026-09-11 screenshot shows Codex as `.dotfiles` and Pi as the opaque
  `pi-20260911105049283...` in Herdr's native grouped agent sidebar.
- `pi/extensions/eddy-compat.ts` currently creates
  `pi-<UTC timestamp>-<process id>` on unnamed `session_start`.
- Its handoff path independently creates
  `pi-<UTC timestamp>-<handoff token prefix>`.
- `pi/integrations/herdr-agent-state.ts` reports Pi's session file to Herdr;
  Herdr displays the persisted Pi name rather than inventing the timestamp.
- `pi/pilot.sh` already passes Pi's native `--name` through unchanged.
- Named goal worktrees already use stable lower-case kebab-case slugs and
  `feature/<slug>` branches.

## Tradeoffs / Risks

- Deriving once favors durable identity over tracking later branch changes.
- Parallel sessions from the same shared checkout need a short suffix to stay
  distinguishable.
- Git discovery must be bounded and failure-tolerant so Pi startup remains
  reliable outside repositories.
- Existing persisted sessions intentionally keep their old generated names.

## Validation Plan

- Cover explicit, persisted, named-worktree, feature branch, other branch,
  repository, non-Git cwd, normalization, collision, resume, fork, startup, and
  handoff cases.
- Run the focused extension/session tests and `./pi/verify.sh`.
- Run `git diff --check` and fresh Standards/Fidelity review against this file.
- Ask Eddy to confirm the final labels in a physical Ghostty/Herdr sidebar.

## Ready To Act

Ready. Eddy invoked `$feature-plan` on 2026-09-11 and authorized the bounded
local implementation and verification loop without commit or push.

## Open Questions

None.

## Verification Result

- Focused resolver, Remote Procedure Call session, and Herdr handoff coverage
  pass.
- The isolated full `./pi/verify.sh` gate passes through the short worktree
  alias required by macOS Unix-socket path limits.
- `git diff --check` passes.
- Final fresh review reports Standards 0 findings and Fidelity 0 findings.
- The three meaningful-label checks in `pi/MANUAL_QA.md` remain unchecked and
  require Eddy's physical Ghostty/Herdr observations.
