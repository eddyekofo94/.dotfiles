# Herdr Direct Agent Cycling — Implementation Brief

Status: Merged, installed, and reloaded locally — automated feature gates and
fresh review pass; physical Ghostty acceptance remains, and full production
verification is externally blocked by the pre-existing outdated Pi integration.

## Source

- `.working/interviews/herdr-direct-agent-cycling/decisions.md`

## Scope

Bind global `Ctrl+Alt+j/k` to next/previous current-session agent movement in
Herdr's emitted sidebar order. Wrap, skip non-agent tabs, and choose the nearest
directional agent from a focused non-agent tab.

## Seams

- `herdr/config.toml` and `herdr/prototype/config.toml`
- `herdr/prototype/agent_cycle.py`
- focused Kitty CSI-u transport validation and aggregate Herdr gates

## Non-goals

No cross-session cycling, sidebar-order changes, highlight fixes, source-build
patches, application keymap changes, commit, or push.

## Acceptance and stop condition

- Both chords work globally and wrap in a three-agent/one-non-agent fixture.
- Agent and non-agent starting surfaces follow the settled direction contract.
- `Ctrl+Alt+h/l`, `Prefix+f`, `Prefix+A`, and application bindings remain intact.
- Focused validation, prototype/full Herdr verification, diff checks, and fresh
  Standards/Fidelity review pass after the final change.
- Physical Ghostty confirmation remains a manual acceptance gate.
