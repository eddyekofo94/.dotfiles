# Herdr Home-Row Tab Aliases — Implementation Brief

Status: DONE 2026-09-10 — automated gates, fresh review, and physical Ghostty
acceptance pass.

## Scope

- Add global native `Ctrl+Alt+h` previous-tab and `Ctrl+Alt+l` next-tab aliases
  to the live and prototype Herdr configs.
- Extend the existing PTY driver and tab lifecycle gate with Kitty CSI-u
  transports `104;7u` and `108;7u` and prove two-tab wraparound.

## Non-goals

- Do not remove or change existing prefix, `n/p`, arrow, pane, workspace, Fish,
  Neovim, tmux, or Ghostty bindings.
- Do not introduce a shell-command binding or upgrade Herdr.
- Do not commit or push.

## Acceptance and validation

- Both configs parse and expose the aliases through the native tab arrays.
- The focused disposable PTY gate proves `h` selects previous and `l` selects
  next, including wraparound, while existing tab behavior remains green.
- `herdr/prototype/verify.sh` and `herdr/verify.sh` pass.
- Fresh Standards and Fidelity review reports zero findings after the last fix.
- Eddy physically confirms both chords in Ghostty; automation cannot close that
  final interaction gate.

## Sources

- `.working/interviews/herdr-alt-ctrl-tab-chords/decisions.md`
- `.working/UNIFIED_INTAKE.md`
