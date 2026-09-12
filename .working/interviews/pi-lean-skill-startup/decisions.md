# Pi Lean Skill Startup

Status: Implemented — locally verified, not pushed

## Source

Eddy, 2026-09-12:

> my starting token count is now 11.8k, can we examine my previous usage of
> skills and remove the ones I don't use from loading?

## Goal

Reduce fresh Pi context spent advertising unused shared skills without making
any valid canonical skill unavailable.

## Usage Evidence

Pi's durable active-skill entries record four `feature-plan` activations, two
`feature` activations, and one `skill-finish` activation. Its slash-command
usage log independently records two `feature` calls. Eddy's immediately prior
acceptance work explicitly depends on `bug`, `todo`, and `goals` remaining core
workflows even though failed or newly enabled attempts are not represented by
the historical activation counter.

## Decisions

- Load only `bug`, `feature`, `feature-plan`, `goals`, `skill-finish`, and
  `todo` through native startup skill discovery.
- Keep every validated top-level skill in `~/.agent-skills` available on demand
  through `$name`, `/name`, and `/skill:name`.
- Register `/skill:name` as an extension command for non-startup skills so the
  shared inline parser has one target command shape without loading those skill
  descriptions into the initial prompt.
- Continue discovering the canonical inventory dynamically. Hidden, archived,
  nested, symlinked, malformed, mismatched, and unknown skills remain excluded
  or fail closed.
- Do not delete, move, or modify canonical skills based on usage frequency.

## Validation Contract

- Core tests prove the startup catalog is exact and the full canonical catalog
  remains enabled for explicit invocation.
- Runtime command inventory proves startup skills are native, every canonical
  skill has a plain alias, and every non-startup skill has an on-demand
  `/skill:name` command.
- A fresh-session pseudoterminal test invokes both a startup skill and the
  non-startup `doctor` skill.
- Compare the fresh Pi startup token estimate with Eddy's reported 11.8k
  baseline.
- Run `./pi/verify.sh`, `git diff --check`, committed-subset verification, and
  fresh Standards/Fidelity review with automatic fix and re-review loops.

## Out Of Scope

- Removing shared skills from `~/.agent-skills`.
- Changing Codex or Claude skill discovery.
- Changing user-owned `agent-config/codex/config.toml` or `pi/settings.json`.

## Implementation Evidence

- The fresh Bible Standard fixture estimate fell from Eddy's reported ~11.8k
  baseline to ~5.4k before any prompt. The repository-only verification fixture
  starts at ~2.5k and now fails when its one-decimal display reaches 3.5k.
- `./pi/verify.sh` passes end to end with isolated agent configuration,
  including fresh-session, Herdr, XcodeBuildMCP, and runtime benchmark gates.
- The committed-subset footer fixture accepts Git's explicit `detached` branch
  label so the same full gate can run from a clean detached worktree.
- Fresh Standards and Fidelity reviews pass after correcting both README
  descriptions and tightening the rounded token-budget assertion.
- Canonical skills were not deleted or modified. User-owned
  `agent-config/codex/config.toml` and `pi/settings.json` remain untouched.
