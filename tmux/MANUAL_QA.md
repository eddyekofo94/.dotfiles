# Tmux Manual QA

## Agent status tabs

- [ ] Start each normal command without a wrapper: `codex`, `claude`,
      `opencode`, `agy`, and `gemini`.
- [ ] Confirm the launch-directory basename remains stable in its label.
- [ ] Submit a prompt and confirm a blue spinner appears within one second.
- [ ] Finish normally and confirm a bold green `` remains while the CLI stays open.
- [ ] Ask a direct final question and confirm a bold orange ``.
- [ ] Trigger a native permission request and confirm a bold red ``.
- [ ] Trigger or simulate an error and confirm a bold red `` survives process exit.
- [ ] Put two agents in one window and confirm both entries remain readable.
- [ ] Confirm project titles longer than 16 characters use a middle ellipsis.
- [ ] Confirm selecting or leaving a window does not clear its state.
- [ ] Confirm a window with no supported agent keeps its normal Catppuccin name.
- [ ] Confirm hooks silently no-op when the same CLIs run outside tmux.

## Agent spinner lifecycle

- [ ] Submit a prompt and confirm the blue Braille spinner reads as continuous
      motion rather than one glyph change per second.
- [ ] Re-source `tmux/tmux.conf` while the spinner is active and confirm its
      motion continues without speeding up or spawning a second animator.
- [ ] Let the turn finish or request attention and confirm the spinner changes
      immediately to the terminal-state glyph.
- [ ] Confirm `tmux show-options -gqv @agent_status_animator_pid` is empty when
      no supported agent pane is running.

Codex hooks require one-time trust through `/hooks` before live QA.

## 2026-07-15 startup evidence

- All five unchanged commands were launched without submitting a model prompt
  in disposable tmux servers.
- Claude's `SessionStart` hook wrote `claude`, `.dotfiles`, and `ready` pane
  state.
- Codex and AGY opened normally. Gemini opened its existing authentication and
  migration screen; its authenticated turn hooks could not be exercised.
- OpenCode initially crashed because its plugin file exported a test helper as
  a second plugin entrypoint. The helper was moved to a support module, a
  one-entrypoint regression assertion was added, and OpenCode then remained
  open normally.
- Live tmux readback confirmed left-positioned window numbers, the shared
  renderer for current and inactive windows. This pass predated the cached
  spinner animator.
- Exact glyph visibility and semantic color appearance remain user-confirmation
  items above.

## 2026-07-15 spinner evidence

- A fresh attached client displayed `codex:SpinnerQA` and the complete Braille
  frame sequence at approximately twelve frames per second.
- Re-sourcing `tmux/tmux.conf` retained the same animator PID and frame changes
  continued.
- A question event replaced the spinner with the orange `` immediately.
- The server-scoped animator PID option cleared and the process exited after the
  question event.
- Subjective smoothness in the user's normal terminal remains awaiting user
  confirmation.

## 2026-07-15 glanceability follow-up

- User screenshot feedback confirmed the former red permission circle rendered
  too small to identify at a glance.
- Permission now uses a bold warning triangle, and all terminal-state glyphs
  use bold styling so they occupy comparable visual weight.
- The running indicator now uses dense Braille frames at twelve frames per
  second; a fresh attached client showed the full sequence and immediate
  permission transition.
- Six-window active CPU settled near 3.4%; the animator still exits completely
  when no supported agent pane is running.
- Final size and motion preference remain awaiting user confirmation in the
  normal terminal.

## Ready-prompt replay

- [ ] In the normal terminal, leave a completed agent handoff visible and press
      `prefix+b`; confirm the prompt appears in the input without submission.
- [ ] Repeat while viewing scrollback in tmux copy mode; confirm copy mode closes
      and the prompt is inserted.
- [ ] Press `prefix+b` again; confirm consume-once blocks the duplicate.
- [ ] Trigger replay with no complete handoff visible; confirm tmux shows one
      concise message and does not print a quoted command followed by
      `returned 1` into the pane.

### 2026-07-15 regression evidence

- A disposable attached tmux client reproduced the failure: the pane was in
  copy mode, so the helper refused the shortcut before extraction.
- The binding now preserves its invoking pane for the background job, and the
  helper exits copy mode before capture.
- An attached-client test confirmed `prefix+b` inserted the newest handoff into
  a real Codex input, left it unsubmitted, and recorded consume-once state.
- Live `prefix+B` tracing confirmed `/clear` was submitted and Codex returned to
  an idle prompt; replay had timed out only because the old handoff remained
  visible. Readiness now ignores old output while still rejecting an unsubmitted
  `/clear`, queued follow-ups, and model loading.
- User screenshot feedback confirmed an inline-only `Next move:` fallback had
  captured Codex's `─ Worked for …` divider. The extractor now prefers the
  inline action and rejects worked-for dividers, input rows, and model-status
  rows as terminal chrome; readback from the original Bible Standard pane
  returned the intended issue-closure question exactly.

## Project names in tabs

- [ ] Reload tmux, open an ordinary shell in a project, and confirm its tab uses
      the active pane's project directory name instead of the shell command.
- [ ] Start a supported coding agent and confirm the tab changes to an agent
      status label while retaining the same project name.

## Agent status in `prefix+w`

- [ ] Reload tmux and press `prefix+w`; confirm every session and window remains
      selectable and pane rows can still be expanded with `+`.
- [ ] With an agent working, confirm its window row shows a smooth blue spinner.
- [ ] Let the agent finish, ask a question, require approval, and fail; confirm
      the chooser uses the same green, orange, and red state indicators as the
      status tab.
- [x] Confirm each top status-tab icon is fully round and matches the chooser
      icon's visual size; the closing rounded tab cap must not clip its edge.
