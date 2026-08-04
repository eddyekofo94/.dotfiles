# Pi Pilot Manual Acceptance

Automated fixtures must not be used to mark this checklist complete.

## Provider comparison

- [x] Run `./pi/pilot.sh`, enter `/login`, and choose ChatGPT Plus/Pro (Codex)
  or another provider you intentionally want to evaluate.
- [x] Confirm the login is stored only in
  `~/.local/state/pi-pilot/config/auth.json`.
- [x] Run `./pi/benchmark_provider.py --run`.
- [x] Confirm `pi/evidence/provider-comparison.json` reports `PASS`.
- [x] Review both answers, elapsed times, token counts, and Pi's reported cost.
  Both scored 5/5. Pi used 6.273998 seconds, 806 reported tokens, and a
  $0.009055 API-equivalent estimated cost; native Codex used 15.990473 seconds
  and exposed token counts but no monetary cost.

## Physical Ghostty and Herdr

- [x] Open two physical Ghostty windows normally.
- [x] Confirm each window owns a different named Herdr session and can navigate,
  type, and change cwd without changing the other window.
- [x] Start the isolated Pi pilot in one window with `./pi/pilot.sh`.
- [x] Submit two distinct prompts in the persisted session. With the editor
  empty, confirm `Ctrl-P` and Up recall older prompts while `Ctrl-N` and Down
  move toward newer prompts and finally clear the editor.
- [x] Run `/reload`, then type `/re`. Confirm `/reload` is the first
  suggestion because it was the most recently submitted slash command.
- [x] Confirm the Catppuccin Mocha theme and accent-colored `❯` remain visible.
  In the prompt, confirm one stable-color hardware cursor blinks as a vertical
  bar with no reverse-video painted cursor underneath it. Open `/tree` or the
  model picker and confirm the cursor becomes a blinking block. Unfocus the
  Ghostty window and confirm Ghostty shows an outline cursor.
- [x] Confirm the same submitted prompts are still recalled in
  newest-to-oldest order after `/reload`.
- [x] Run `/fff-health`, then type `@` plus a non-contiguous or typo-tolerant
  path query. Confirm the FFF-backed list appears, Ctrl-P/Ctrl-N and arrows
  move through it, Escape cancels, and Enter inserts the selected path without
  submitting the prompt.
- [x] Open `/resume` and confirm `Ctrl-P`/`Ctrl-N` move through the session
  list. In the editor, confirm `Ctrl-Shift-M` opens the model picker, ordinary
  Enter still submits, and `Ctrl-P` no longer changes the active model. Resume
  the persisted test session, return to its editor, and confirm Ctrl-P/Ctrl-N
  still recall its submitted prompts.
- [x] With unsent editor text present, press `Ctrl-L`. Confirm the viewport
  clears and redraws, the `❯` editor and footer details remain visible, the
  editor text remains intact after another second, and the persisted
  conversation is still available through `/tree`.
- [x] Open `/tree`, move to an earlier branch, and return to the editor.
  Confirm Ctrl-P/Ctrl-N recall only the selected branch's submitted prompts,
  then return to the newest branch and confirm its newer prompts reappear.
- [x] With a completed labeled handoff visible, press `Prefix+b`. Confirm the
  exact multiline handoff appears in the current Pi editor and is not
  submitted.
- [x] Produce a different completed handoff, then press `Prefix+B`. Confirm a
  new named Pi session becomes active, the old session remains resumable, and
  the exact handoff appears without submission.
- [x] Press `Prefix+A`. Confirm the palette shows agents across both active
  Herdr sessions with session, agent, status, and cwd.
- [x] Exercise safe read and message actions. Exercise focus and confirm it
  targets the owning session without making the two Ghostty windows mirror.
- [x] Close both Ghostty windows, reopen normally, and confirm the last closed
  session recovers while an already-active session still causes a fresh
  independent window/session.
- [x] Confirm normal macOS `Cmd+V` paste still works.

## Agent prompt editor (Ctrl+G)

The offline gate in `pi/verify.sh` proves the pinned build still prefers
`$VISUAL`, writes its prompt under the temp dir, and that nothing pins
`externalEditor`. It cannot prove what the split actually looks like.

- [ ] With a completed closeout on screen, press `Ctrl+G`. Confirm Neovim opens
  with the prompt above and the whole closeout, ready-to-paste block included,
  in a read-only window below.
- [ ] Confirm `@` completes repository paths, not paths under the temp dir the
  prompt file lives in.
- [ ] Type nothing and press `u`. Confirm one undo empties the seeded prompt.
- [ ] Yank a line from the closeout window and confirm it pastes into the
  prompt.
- [ ] Run `:wq`. Confirm Neovim exits completely, with no leftover split, and
  the edited prompt appears in the Pi editor without submission.
- [ ] Press `Alt+h`/`Alt+j`/`Alt+k`/`Alt+l`. Confirm they move between the two
  Neovim windows and hand off to the neighboring Herdr pane at the edge.
- [ ] Press `Alt+s` to split the Herdr pane, then close that split. Confirm the
  closeout window returns to roughly the share of the frame it opened with.
- [ ] Open `Ctrl+G` from an ordinary shell in the same pane. Confirm no closeout
  split appears, since only an agent launch exports one.

## Rollback

- [x] Preview with `./pi/rollback.sh`.
- [ ] Do not apply rollback unless ending the pilot. If applied, confirm only
  marker-owned Pi pilot roots moved to Trash and Codex, Claude, Herdr, Fish,
  tmux, shared skills, and `~/.pi` remain unchanged.

## XcodeBuildMCP physical-device gates

- [ ] Connect an intended test device and explicitly authorize any required
  trust, signing, or Developer Mode changes.
- [ ] Run one pilot-owned device build/install/launch flow for a disposable or
  approved app; confirm no unapproved device or project is touched.
- [ ] Confirm physical interaction, tactile behavior, and performance on the
  device. Simulator screenshots and gestures do not satisfy this gate.
