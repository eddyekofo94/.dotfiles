# Agent Prompt Session-Scoped Capture

## Goal

`ctrl+g` in an agent pane opens Neovim with *that* pane's own last closeout,
regardless of how many Herdr sessions (independent Ghostty windows) are open.

## Exit Criteria

- Two agents in different Herdr sessions at the same pane id (`w1:p2` in
  `window-43` and `window-44`) each keep and read their own record.
- A Stop hook in one session never deletes another session's record.
- SessionEnd removes only its own session's files.
- `agent-config/verify.sh`, `make -C ~/.config/nvim test-agent-prompt`,
  `~/.config/nvim/tools/verify.sh`, `herdr/verify.sh` green.
- Fresh Standards/Fidelity review 0/0.
- Eddy: live `ctrl+g` in two Ghostty windows each opens its own closeout.
- `~/.codex/config.toml` and `~/.claude/keybindings.json` are tracked through
  installer-owned, fail-closed symlinks so the external-editor bindings cannot
  silently drift outside the repository.

## Scope / Non-goals

- In: `agent-config/claude/closeout_capture.py`, the agent-config installer,
  Codex config and Claude keybinding ownership,
  `~/.config/nvim/tools/agent_prompt_editor.sh`, their two test suites, intake.
- Out: Herdr patch, `herdr pane read` semantics, the parser, Neovim Lua
  (`agent-prompt.lua` reads only `AGENT_CLOSEOUT_FILE`/`AGENT_PROMPT_REASON`).
- Out: Codex/Pi equivalents of the Stop hook (none exist; transcript fallback
  is Claude-only by design).

## Decisions

- **Scope key** = `slugify(HERDR_SESSION) + "." + slugify(HERDR_PANE_ID)`
  (e.g. `window-43.w1_p5`). Without `HERDR_SESSION` it degrades to the pane
  slug alone, so hook and shim agree in every environment and the existing
  pane-only tests keep their meaning.
- Record name: `agent-prompt-turn-closeout.<scope>.<claude-session>.md`.
  Derived scratch (`seed`, `capture`, `closeout`, `transcript`) uses `<scope>`.
- `prune()` drops other records under the same `<scope>`, plus the legacy
  pane-only shapes (`<prefix>.<pane>.*.md`, `<prefix>.<pane>.md`) — no Herdr
  pane writes those any more, so under a Herdr session they are always stale.
- `cleanup()` keys on the Claude session id (unchanged) plus `<scope>`-named
  derived files.
- Shim debug log tag becomes `[<HERDR_SESSION>/<HERDR_PANE_ID>]` so misses are
  attributable per window.
- The shim test strips `HERDR_SESSION` from the host env (as it already does
  for `HERDR_PANE_ID`) and sets it explicitly per case.
- Herdr session identity comes from the env Herdr already exports
  (`HERDR_SESSION`, `HERDR_SOCKET_PATH`); `herdr pane read` needs no flag.
- **Agent session from Herdr** (added after Eddy's live check, 2026-08-19):
  Claude Code does not pass `CLAUDE_CODE_SESSION_ID` to its `$EDITOR`, so the
  shim asks `herdr pane get <pane>` for `agent_session.value` (reported by the
  agent-state integration on SessionStart) when the env is silent; a
  non-Claude answer is ignored. With a named session the turn record is the
  exact one and the transcript reader opens that session's transcript or
  nothing — `find_transcript()` no longer falls back to the project's newest
  transcript for a named session. Project-newest survives only when nobody can
  name the session.

## Evidence / Findings

- `~/.config/herdr/sessions/` holds `window-2 … window-44`; each has its own
  `w1:p1…` ids. `$TMPDIR` is per-user, shared across all of them.
- `closeout_capture.py:70-83` `prune()` deleted every other session's record for
  the same pane slug — the other window's live closeout.
- `agent_prompt_editor.sh:84-121` slugged on pane only; the no-session-id path
  took the newest `<pane>.*` record, possibly another window's.
- `/tmp/agent-prompt-debug.log` tags `[w1:p3]` with no session.
- Live check 1 (screenshot, 14:49): `w1:p5` (this pane) got its own closeout;
  a brand-new Claude pane `w1:p9` in the same tab had no Stop record and no
  `CLAUDE_CODE_SESSION_ID`, so the shim fell to the project-newest transcript
  and showed the Spinner pane's (`w1:p6`) closeout. Log:
  `14:49:40 [window-43/w1:p9] using the agent's transcript`. `herdr pane get`
  names each pane's Claude session correctly (p5/p9/p6 all distinct).
- Prior goal `ready-prompt-parser-relocation` and nvim commit `98119ee0`
  ("restore the pane- and session-aware ctrl+g closeout") scoped on *Claude*
  session + pane, never on Herdr session.

## Tradeoffs / Risks

- Records written before this change under pane-only names become unreadable
  by the new shim; they are pruned on the next Stop. One turn of "no closeout"
  possible in panes with agents started before the hook was reinstalled (the
  hook is a symlink, so the next Stop already uses the new code).
- `HERDR_SESSION` absent (non-Herdr terminal): behaviour unchanged from today.

## Validation Plan

- `python3 agent-config/tests/closeout_capture_test.py` — add two-sessions,
  same-pane case for Stop prune and SessionEnd.
- `bash ~/.config/nvim/tools/test_agent_prompt_editor.sh` — add two-sessions,
  same-pane case with no `CLAUDE_CODE_SESSION_ID` (the observed failure mode)
  and a log-tag assertion.
- `sh agent-config/verify.sh`, `make -C ~/.config/nvim test-agent-prompt`,
  `~/.config/nvim/tools/verify.sh`, `sh herdr/verify.sh`.
- Manual: two Ghostty windows, one Claude pane each, `ctrl+g` in both.

## Ready To Act

Ready — 2026-08-19. Authorized by `/feature-plan` invocation.

## Open Questions

None implementation-changing.

## Closure

Status: **AWAITING USER CONFIRMATION** (physical two-window `ctrl+g` only).

Round 2 (after live check 1 failed in a fresh pane): shim resolves the agent
session via Herdr; reader never serves project-newest for a named session.
Shim suite 39 checks, hook suite extended (`--print` unknown session → none).
Both red on the prior shim/reader, green now.

Implemented 2026-08-19:
- `agent-config/claude/closeout_capture.py`: `place()` = `HERDR_SESSION.pane`
  slug (pane alone without a Herdr session); `target_path`, `prune`, `cleanup`
  use it; legacy pane-only shapes pruned.
- `~/.config/nvim/tools/agent_prompt_editor.sh`: `pane_place()` mirror; all
  scratch and turn-record names scoped; log tag `[session/pane]`.
- Tests: hook suite gains two-Herdr-sessions-same-pane Stop/SessionEnd case;
  shim suite gains two-window no-session-id case with log-tag and place
  assertions (35 checks). Both proven red on the old code, green on the new.

Verification: `agent-config/verify.sh` PASS, `make -C ~/.config/nvim
test-agent-prompt` PASS, `~/.config/nvim/tools/verify.sh` PASS,
`herdr/verify.sh` PASS. Fresh Standards/Fidelity review 0/0 blocking; nits
applied; re-review 0/0 blocking.

Not done by design: no commit, no push (no `ship`). Neovim config repo
(`~/.config/nvim`) and dotfiles both carry uncommitted changes.

Awaiting Eddy: two Ghostty windows, one Claude pane each, finish a turn in
both, `ctrl+g` in each — each opens its own closeout; `/tmp/agent-prompt-
debug.log` shows `[window-N/w1:pM]` tags.

Manual migration check, 2026-09-09: Pi `ctrl+g` PASS; Codex FAIL. Pi's live
`window-70/w1:p13` pane shows the expected prompt and read-only closeout.
Whether the Codex failure was editor launch, companion split, empty content,
or wrong content is not yet known, so there is not yet a red-capable
reproduction or justified fix.

Automated discriminator, 2026-09-09: Codex 0.153.4 was launched in a PTY with
the real `$VISUAL` shim and only `AGENT_PROMPT_NVIM=/usr/bin/true`. Sending
`Ctrl+G` invoked the shim, scraped a closeout for `window-70/w1:p11`, returned
to the composer, and exited cleanly. The Codex keymap and `$VISUAL` handoff are
therefore green; the unresolved manual failure is downstream in the real
Neovim display or its captured content.

Markerless Codex fix, 2026-09-10: the live shim debug log identified the real
editor launch as `[window-70/w1:p11] no agent marker in env`; the earlier
`CODEX_THREAD_ID` test fixture was not representative. Codex passes exactly
one prompt at `~/.codex/editor/.tmpXXXXXX.md`, not under `$TMPDIR`. The shell
shim now treats only that exact Codex-owned directory and six-alphanumeric-
character Markdown filename as a markerless Codex launch, and forwards the
editor argument into the capture function. Neovim mirrors that directory and
filename check before creating the prompt layout. Regression coverage proves
the markerless route in both suites: `bash ~/.config/nvim/tools/
test_agent_prompt_editor.sh` (42/42) and `make -C ~/.config/nvim
test-agent-prompt` (21/21). Manual Codex `ctrl+g` acceptance remains required.

Manual acceptance, 2026-09-10: Eddy confirmed that Codex `ctrl+g` now opens
the expected prompt-editor flow. Pi and Claude were already working. Fresh
review after the live-path correction found one Fidelity mismatch: Neovim
accepted a generated filename in a nested directory below the Codex editor
root while the shim requires the exact directory. Neovim now requires the
exact root too; the new nested-path rejection spec passes. Fresh review after
that fix: Standards 0, Fidelity 0. Focused validation remains green: shim
42/42 and Neovim specs 22/22. The remaining manual gate is one two-Ghostty-
window check that same-named Herdr pane ids each retain their own closeout.

Closure, 2026-09-10: Eddy confirmed the two-Herdr-window isolation check is
working properly. The goal is **DONE**; no commit or publication was
authorized, and the dotfiles worktree remains uncommitted.

Ownership extension, 2026-09-09: `agent-config/codex/config.toml` and
`agent-config/claude/keybindings.json` now own the two live files through the
existing reviewed-predecessor installer. Exact pre-migration copies are under
`.backups/agent-config/`. Installer fixtures cover regular-file migration,
backup creation, idempotency, and fail-closed preflight.

## Amendment: /clear hands over (Eddy, 2026-09-15)

Reverses "a record under another session id must never be shown" for `/clear`
only. `/clear` wipes the screen `prefix+b` reads, so the last closeout was lost.

- SessionEnd with `reason == "clear"` moves this place's record to
  `agent-prompt-turn-closeout.<scope>.cleared.md`. Any other end deletes it.
- The Stop hook's prune keeps that carry until the session writes its own record.
- `closeout_capture.py --pane-record <session>` prints the session's own record,
  else the carry. `herdr/prototype/ready_prompt.sh` uses it for Claude panes
  when the screen holds no handoff.
- `--pane-record` searches its own `$TMPDIR`, `/tmp`, and
  `getconf DARWIN_USER_TEMP_DIR`. prefix+b runs in the Herdr client, whose
  `$TMPDIR` differed from the pane's in the first live check (window-81).
- Out: the ctrl+g shim in `~/.config/nvim` still reads only the live session's
  own record.
- Tests: `agent-config/tests/closeout_capture_test.py`,
  `herdr/prototype/tests/ready_prompt_saved_closeout_test.sh`.
