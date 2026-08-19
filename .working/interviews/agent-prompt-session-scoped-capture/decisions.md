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

## Scope / Non-goals

- In: `agent-config/claude/closeout_capture.py`,
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
