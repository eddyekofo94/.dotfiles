# Herdr Recovery Safety Parity

## Trigger

Eddy paused final Herdr daily-driver acceptance and asked to implement the tmux
features that remain missing. Recovery is first because a full server restart
is the only audited gap that can lose active work rather than merely omit a
convenience.

## Goal

Give supported interactive agents a verified native conversation-resume path
after a Herdr server restart without persisting terminal screen contents or
damaging Eddy's existing agent hooks/plugins.

## Scope

In scope:

- official Herdr integrations for the exact supported agents Eddy approves;
- preservation-aware inspection and merging of existing agent configuration;
- the default-enabled Herdr native agent resume behavior;
- isolated restart/resume validation;
- deterministic verification and fresh Standards/Fidelity review.

Out of scope:

- arbitrary shell, server, test, or process resurrection;
- `pane_history = true`;
- a Herdr upgrade;
- sessionizer, copy-mode, picker, layout, clipboard-history, or pane-lock work;
- commit, push, tmux removal, or external publication.

## Current Evidence

- Herdr restores workspaces, tabs, panes, cwd, layout, and focus after a server
  restart, but the original processes are gone.
- Normal detach/reattach keeps original processes alive and remains the
  preferred persistence path.
- `herdr integration status` reports every official integration as not
  installed.
- Existing Codex, Claude, and OpenCode configuration surfaces are present, so
  installation must be treated as a merge and verified against their current
  behavior.
- Herdr's official session-restore support includes Claude Code, Codex, and
  OpenCode. The audited AGY and Gemini workflows do not have official Herdr
  native-session integrations.
- tmux currently sets `@resurrect-capture-pane-contents off`; Herdr already has
  `pane_history = false`. Keeping it off is the faithful and safer policy.

## Stop Condition

The selected official integrations report current/installed; pre-existing
agent configuration and behavior remain intact; an isolated Herdr session
proves native identity is recorded and a real supported agent conversation can
resume after a controlled server restart; `./herdr/verify.sh` and
`./fish/scripts/verify.sh` pass; fresh Standards/Fidelity review has no open
findings. Any live conversation-resume behavior that cannot be safely automated
remains an explicit user-confirmation gate.

## Validation Plan

1. Snapshot hashes and relevant semantic content of each selected agent's
   existing configuration before installation.
2. Install integrations one at a time with the official Herdr CLI and inspect
   every resulting change before continuing.
3. Run `herdr integration status` and integration-specific syntax/health
   checks.
4. Start a disposable named Herdr session, launch a selected supported agent,
   prove a native session reference is reported, stop/restart only that
   disposable server, and verify Herdr resumes the same conversation.
5. Confirm the production `main` session, tmux fallback, and unrelated agent
   configuration were not altered.
6. Run `./herdr/verify.sh` and `./fish/scripts/verify.sh`.
7. Run fresh Standards and Fidelity review, fix findings, and re-review.

## Settled Decisions

- Keep `pane_history = false`; terminal output may contain secrets and the tmux
  baseline also declines pane-content persistence.
- Do not claim arbitrary-process resurrection. Use live detach for process
  continuity and native agent restore only for supported conversations.
- Preserve the installed v0.7.4 during this slice. Evaluate v0.7.5 separately
  against the complete verified configuration and rollback matrix.
- On 2026-07-24, Eddy explicitly approved the official Claude Code, Codex, and
  OpenCode integrations. Preserve all existing hooks, plugins, notifications,
  permissions, and unrelated agent configuration while installing only these
  three current integrations.

## Open Questions

None that change implementation.

## Ready To Act

Ready. The exact integration targets and preservation boundary are approved.

## Closure

Implemented and verified on 2026-07-24. The official Claude Code, Codex, and
OpenCode integrations are current on the retained Herdr v0.7.4 binary;
pre-existing hooks/plugins remain active; `pane_history = false`; a real Codex
conversation resumed across an isolated full server stop and completed a new
turn; full Herdr and Fish verification passed; and fresh post-fix review closed
with Standards 0 / Fidelity 0. No Herdr upgrade, commit, push, tmux removal, or
external publication occurred.
