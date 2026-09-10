# Herdr Home-Row Tab Aliases — Implementation Brief

Status: DONE 2026-09-10

## Scope

- Add global native `Ctrl+Alt+h` previous-tab and `Ctrl+Alt+l` next-tab aliases
  to the live and prototype Herdr configs.
- Extend the PTY driver and tab lifecycle gate with Kitty CSI-u transports
  `104;7u` and `108;7u`, proving two-tab wraparound.

## Non-goals

- Do not alter existing prefix, `n/p`, arrow, pane, workspace, Fish, Neovim,
  tmux, or Ghostty bindings.
- Do not introduce a shell-command binding, upgrade Herdr, or push.

## Acceptance

- Both configs expose the aliases through the native tab arrays.
- Focused transport, full prototype, and full production gates pass.
- Fresh Standards and Fidelity review reports zero findings.
- Eddy physically confirms both chords and wrap directions in Ghostty.
