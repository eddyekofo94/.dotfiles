# Agent-Facing Zsh Startup Hardening

## Goal

Make Zsh a quiet, low-side-effect compatibility shell for agents and
automation. Interactive Zsh is not the user's daily-driver shell.

## Exit Criteria

- Missing optional local files never emit startup errors.
- A readable `~/.local.env` is still sourced without exposing its contents.
- Agent and noninteractive login shells skip installation, network, plugin,
  completion, and other interactive bootstrap work.
- Inherited terminal and XDG values are preserved; required Zsh paths have
  safe defaults.
- One deterministic verifier prevents these regressions from recurring.
- Fresh Standards and Fidelity review reports zero findings.

## Scope / Non-goals

In scope: `zsh/.zshenv`, the agent/noninteractive fast paths in `zsh/.zprofile`
and `zsh/.zshrc`, and one Zsh startup verifier.

Non-goals: making interactive Zsh a polished daily driver, changing plugins or
keybindings, creating `~/.local.env`, reading or printing secrets, changing
Fish/tmux/Herdr behavior, commit, push, or external publication.

## Decisions

- Prefer quiet defaults and inherited environment values over terminal or XDG
  overrides in `.zshenv`.
- Keep `.zshenv` safe for every Zsh process: guard optional files, avoid
  duplicate setup, and fail softly when cache preparation is unavailable.
- Return from `.zprofile` before bootstrap work for any noninteractive or
  explicitly agent/CI shell.
- Keep `.zshrc`'s existing agent fast path, but run it before optional
  interactive environment loading.
- Preserve normal interactive behavior outside those guards.

## Evidence / Findings

- `/Users/eddyekofo/.config/zsh/.zshenv` is a live symlink to the repository.
- Line 98 unconditionally sources missing `~/.local.env`, producing the warning
  on every agent command.
- `.zshenv` overwrites inherited `TERM` twice, leaves a core Zsh path dependent
  on later startup files, evaluates duplicate Homebrew setup, and loads history
  in noninteractive shells.
- A noninteractive login probe reached `.zprofile`'s terminfo download path,
  proving agent login shells do not currently bypass interactive bootstrap.
- `.zshrc` already has an agent/noninteractive fast path, but currently loads
  `envs.zsh` before it.

## Tradeoffs / Risks

- Interactive Zsh bootstrap remains legacy and intentionally out of scope; the
  hardening prevents agents from entering it.
- A user-authored readable `.local.env` remains trusted code by design.

## Validation Plan

- `./zsh/scripts/verify.sh`
- `zsh -n zsh/.zshenv zsh/.zprofile zsh/.zshrc`
- Isolated HOME fixture with no `.local.env`: exact quiet startup and preserved
  inherited `TERM`, `COLORTERM`, and XDG values.
- Isolated HOME fixture with a readable `.local.env`: sentinel variable is
  available without printing file contents.
- Noninteractive login fixture: no Znap, terminfo, installer, or other profile
  bootstrap artifacts are created.
- `git diff --check`
- Fresh Standards and Fidelity review after the last fix.

## Ready To Act

Ready. The user selected broad conservative agent-facing Zsh hardening on
2026-07-21 and does not require interactive Zsh feature work.

## Open Questions

None.

## Implementation

- `.zshenv` now preserves inherited terminal, XDG, editor, visual, and path
  ownership while providing safe defaults only when values are absent.
- Optional `~/.local.env` loading is readable-file guarded; no placeholder or
  secret file is created.
- Duplicate Homebrew and history initialization was removed from the universal
  startup path, cache creation fails softly, and Homebrew fallback stops only
  after a working executable returns environment data.
- `.zprofile` returns before installation, network, plugin, completion, and
  terminfo bootstrap for noninteractive and explicit agent/CI shells.
- `.zshrc` applies its agent fast path before optional interactive environment
  loading and guards the final optional local environment source.
- `zsh/scripts/verify.sh` provides the repository's deterministic regression
  gate for these behaviors.

## Verification Evidence

- `./zsh/scripts/verify.sh`: PASS. It covers missing and readable
  `.local.env`, inherited terminal/XDG/editor values, soft cache failure,
  noninteractive login, and isolated interactive PTYs for `AI_AGENT`,
  `CLAUDECODE`, and `CI`; no Znap, terminfo, or compdump artifacts were created.
- `zsh -n zsh/.zshenv zsh/.zprofile zsh/.zshrc`: PASS.
- Ordinary and login Zsh command probes: PASS without the prior warning.
- Live `AI_AGENT=1` interactive login PTY: PASS.
- `./tools/audit_transport_security.sh`: PASS.
- `git diff --check`: PASS.

## Fresh Review

- Initial review: Standards 0; Fidelity 1 for missing durable interactive-agent
  PTY coverage.
- After adding PTY fixtures for all explicit agent/CI markers, fresh re-review:
  Standards 0; Fidelity 0.

## Closure

Done on 2026-07-21. The active-goal pointer is cleared. Interactive Zsh plugin
and keybinding modernization remains out of scope. No commit or push was
performed.
