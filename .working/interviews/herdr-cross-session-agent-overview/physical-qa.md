# Cross-Session Agent Overview — Physical QA

Date: 2026-07-29

## Result

PASS.

The system privacy dialog was dismissed with **Don't Allow**; no additional
macOS permission was granted. Both live Herdr servers then accepted
`server reload-config` with no diagnostics so the retained physical windows
could exercise the new binding.

## Physical Evidence

- `Prefix+A` in `window-9` displayed both live agents with the required fields:
  `window-7` / Claude / idle / BibleStandard cwd and
  `window-9` / Codex / working / dotfiles cwd.
- Ctrl-R opened a bounded recent-output view. Physical QA exposed that Herdr
  encodes Escape as Kitty CSI-u (`ESC[27;5;27~`) in this path, which the
  original bare-Escape lesskey mapping did not consume. The reader now maps
  both encodings to quit, deterministic PTY coverage includes both, and the
  physical retest returned cleanly to the two-row palette without leaking
  bytes into the query.
- Ctrl-E opened the composer. Physical `Cmd-V` pasted the exact two-line
  sentinel, and confirmation inserted both lines into the selected Codex input
  without Return, submission, command execution, or a focus change. The
  sentinel was then cleared and live readback confirmed it was absent. The
  original clipboard was restored.
- Focus selected the exact Claude terminal in `window-7`. `window-7` changed
  its own pane focus while `window-9` remained attached to and focused inside
  its independent session; the current Ghostty window was not reattached and
  the owning macOS window was not raised.
- The physical clients remained distinct: `window-7` client PID 73725 and
  `window-9` client PID 73842. Their panes retained different cwd and accepted
  independent interaction. The previously completed independent-window gate
  already proved native `Cmd-N`/`Cmd-W`; this pass physically proved
  Ghostty-owned `Cmd-V`, while the config leaves `Cmd-C`, `Cmd-A`, and `Cmd-F`
  unbound by Herdr.

## Final State

- Both named sessions and both physical clients remain running independently.
- `window-7` retains the BibleStandard cwd; `window-9` retains the dotfiles
  cwd.
- No test text remains in either agent input.
- No permission was granted, no message was submitted, and no session was
  stopped or merged.

Status: PASS. The physical Command-key and two-window interaction gate is
complete.
