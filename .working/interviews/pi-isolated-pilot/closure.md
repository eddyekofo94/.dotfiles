# Isolated Pi Pilot — Closure

Status: DONE on 2026-07-30.

## Outcome

The pinned, reversible Pi 0.82.1 pilot is complete and remains opt-in. It
provides the selected Catppuccin Mocha presentation, `❯` editor prompt,
branch-local prompt history, Ctrl-P/Ctrl-N navigation, Ctrl-Shift-M model
selection, resilient Ctrl-L clear/redraw, mode-aware terminal cursor,
recent/frequent slash suggestions, pinned FFF `@` completion, and Herdr
handoff/session integration.

Codex and Claude remain available. No normal Pi installation, default agent,
MCP/iOS package set, or Xcode installation was changed. No commit or push was
performed.

## Verification

- `./pi/verify.sh` — PASS
- `./fish/scripts/verify.sh` — PASS
- `./herdr/prototype/validate_ready_prompt.sh` — PASS
- Focused Herdr-hosted Pi launch, `/reload`, Ctrl-L redraw, FFF integrity, and
  locale-ordering regressions — PASS
- Fresh final Standards review — 0 findings
- Fresh final Fidelity review — 0 findings
- `pi/MANUAL_QA.md` applicable physical interaction checks — PASS
- Physical `Prefix+b` same-session insertion — PASS
- Physical `Prefix+B` fresh persisted session plus insertion — PASS

## Deferred Scope

Pi promotion to a default agent, MCP/iOS packages, Xcode 27 beta, and
project-scoped lazy MCP activation remain separate future goals. The manual
rollback steps stay intentionally unapplied because the accepted opt-in pilot
is being retained; automated rollback verification passed.
