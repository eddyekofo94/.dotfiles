# Cross-Session Agent Overview — Closure

Status: DONE on 2026-07-29.

## Outcome

Every ordinary Ghostty window remains attached to its own independent named
Herdr session. `Prefix+A` now opens an on-demand palette that discovers agents
across all running local Herdr sessions and shows session, agent, lifecycle
status, and cwd.

Read provides a bounded, read-only recent-output view. Focus targets the exact
agent pane inside its owning session without reattaching the current window or
raising another macOS window. Message provides an editable, Ghostty
`Cmd-V`-friendly composer and inserts exact single- or multiline text without
synthesizing Return, submitting it, or changing focus. Every action revalidates
the session-qualified stable identity and fails closed if the target changed.

Recovery, independent-window allocation, `pane_history = false`, and the tmux
fallback are preserved. No commit or push was performed.

## Verification

- `./herdr/prototype/validate_agent_overview.sh` — PASS
- `./herdr/verify.sh` — PASS
- `./fish/scripts/verify.sh` — PASS
  (`25.053 ms` median, `25.695 ms` p95)
- `git diff --check` — PASS
- Physical `Prefix+A` inventory across `window-7` and `window-9` — PASS
- Physical bounded Read and clean Escape return — PASS
- Physical multiline `Cmd-V` compose-and-insert without submission — PASS
- Physical exact owning-session Focus without attach or window raise — PASS
- Independent physical clients, cwd, typing, and navigation — PASS
- Fresh Standards review — 0 findings
- Fresh Fidelity review — 0 findings

## Review Fixes Encoded

- Unicode-aware composer backspace covers ASCII, accented, CJK, and emoji
  input.
- Hash-bound evidence includes the helper, composer, fixture, validator, and
  both production and prototype configs.
- The isolated `less` keymap consumes both bare Escape and Herdr's Kitty CSI-u
  Escape sequence, with deterministic PTY coverage for both.

## Deferred Scope

Remote-host aggregation, automatic submission, destructive agent/session
actions, continuous polling, and macOS window activation remain out of scope.
Unrelated intake remains unchanged.
