# Pi Workflow Skill Parity

Status: Investigating

## Observation

- Eddy reported on 2026-09-11 that `/todo` and `/goals` are available in Codex
  and Claude Code but absent when typed in Pi.

## Reproduction

- From Bible Standard, Pi's live no-session Remote Procedure Call command
  inventory contains neither `todo` nor `goals`; the exact assertion exits 1.
- A disposable CLI-only probe that explicitly loads the canonical `todo` skill
  and Bible Standard's `goals` skill succeeds, but registers them as
  `skill:todo` and `skill:goals`, not plain `/todo` and `/goals`.

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

- Decide whether Pi should expose only `/todo` and `/goals`, the complete
  cross-project core workflow set, or another explicit allowlist.
- Decide whether project-specific Claude skills should be shared through a
  canonical `.agents/skills` owner or added to Pi settings per repository.
- Preserve Pi's reviewed allowlist, isolation, and fail-closed `$skill` policy.

## Stop Condition

- A selected Ready To Act goal must reproduce the exact missing commands,
  implement the settled discovery and alias policy, pass focused command
  inventory coverage plus `./pi/verify.sh`, receive fresh Standards/Fidelity
  review, and leave any physical slash-menu acceptance explicit.
