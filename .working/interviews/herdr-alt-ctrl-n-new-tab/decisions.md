# Herdr Alt-Ctrl-n New Tab

Status: Awaiting physical Ghostty acceptance

## Settled contract

- Trigger: Eddy explicitly requested implementation on 2026-08-01.
- Add direct `Alt-Ctrl-n` as a Herdr new-tab shortcut.
- Preserve native `Prefix+c` new-tab behavior.
- Preserve `Alt-t`; it must not be rebound or intercepted.
- Create exactly one focused tab in the current workspace.
- Follow the focused pane's cwd, matching native new-tab behavior.
- Preserve tmux, Neovim, Fish, Ghostty, and unrelated Herdr bindings.
- Do not commit or push.

## Stop condition and validation

- Live and prototype configs validate.
- Focused transport coverage drives the Ghostty/Kitty CSI-u `Alt-Ctrl-n`
  sequence and proves exactly one focused cwd-following tab.
- Existing `Prefix+c` lifecycle coverage remains green.
- `Alt-t` remains absent from Herdr config and retains tmux/Neovim ownership.
- Full Herdr and Fish gates pass.
- Fresh Standards/Fidelity review reports zero actionable findings.
- Eddy physically presses `Alt-Ctrl-n` in Ghostty and confirms the result.

## Automated evidence

- Live and prototype `config check`: PASS.
- `validate_tabs.sh`: PASS. Exact Kitty CSI-u `110;7u` created one focused tab
  in the current workspace at the source cwd; `Prefix+c` remained native;
  Kitty CSI-u `Alt-t` created/focused no Herdr tab.
- `herdr/prototype/verify.sh`: PASS.
- `herdr/verify.sh`: PASS.
- `fish/scripts/verify.sh`: PASS.
- Fresh review: Standards 0 findings; Fidelity 0 findings.
- Live `window-13` config reloaded on reviewed Herdr 0.7.5.
- No commit or push.

## Open gate

- Physical Ghostty `Left Option+Control+n`, then current-workspace, cwd, focus,
  and exactly-one-tab confirmation.

## Closure

**DONE, 2026-08-03.** Eddy physically confirmed `Left Option+Control+n` in
Ghostty: the chord works. The open gate above is satisfied; implementation,
automated evidence, and the fresh Standards 0 / Fidelity 0 review were already
complete and are unchanged. Committed on this date under Eddy's explicit
"commit everything" authorization, which also lifted the "do not commit or
push" boundary recorded above.
