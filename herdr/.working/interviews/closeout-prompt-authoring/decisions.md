# Decision record: closeout-visible prompt authoring in Herdr

## Goal

Decide how Herdr should let Eddy author a follow-up agent prompt while the
agent's closeout stays visible.

## Exit criteria

Decision-only. Done when the trigger, the surface, the source of the closeout,
and the path back into the agent are all settled well enough to implement
without further product questions.

## Scope

In: one new Herdr binding (proposed `ctrl+shift+g`) and its script, alongside the
existing `prefix+b` / `prefix+shift+b`.

Out: changes to `prefix+b` behaviour, the nvim `@` completion work, agent-side
skill/closeout format changes.

## Evidence / Findings

- `prefix+b` -> `~/.dotfiles/herdr/prototype/ready_prompt.sh`;
  `prefix+shift+b` -> same with `--clear`.
- Extraction is delegated to `~/.dotfiles/tmux/scripts/ready_prompt.sh`
  (`--extract`), which scans up to 2000 lines of unwrapped pane history for the
  newest `**Ready-to-paste prompt:**` block and validates closeout structure
  (`Next move:` etc). It already parses the closeout — extracting the closeout
  block itself is an extension, not new machinery.
- Insertion is `herdr pane send-text` with a bracketed-paste wrapper; a
  fingerprint file prevents re-inserting the same handoff twice.
- `ctrl+shift+g` is unbound today. `prefix+g` is lazygit.
- Herdr already supports `type = "popup"` bindings with width/height.
- `$EDITOR` and `$VISUAL` are both `nvim`.
- `HERDR_PANE_ID=w4:p2` is present in the agent's own environment, so a child
  nvim inherits it and can call `herdr pane read` for its own pane.
- `AI_AGENT=claude-code_2-1-220_agent`, `CLAUDECODE=1` are also inherited.
- Verified live: opening a `/tmp` file makes the auto-root autocmd `lcd` the
  window to `/private/tmp`, even though `autochdir` is off. `@` completion's
  `M.root()` then resolves to `/private/tmp`.
- **SETTLED NEGATIVE (2026-08-01): `herdr pane read` cannot see the agent's
  scrollback from inside nvim.** Probe: pane `w4:p4`, marker line in scrollback,
  `nvim -u NONE` on the alt screen. Marker count before nvim: 2. During nvim:
  0 for every source — `visible`, `recent`, `recent-unwrapped`, `detection`,
  `--raw`, `--ansi`. After `:q!`: 2. The scrollback is intact throughout; herdr
  reports the alt screen while nvim holds it.
- Nvim's earliest hooks are already too late: capture from `--cmd` returned 0,
  from `VimEnter` 0. A capture run immediately before `exec nvim` returned 2.
  There is no in-nvim hook that precedes the alt-screen switch.
- Confirmed in the claude-code 2.1.220 bundle: the editor is resolved as
  `process.env.VISUAL || process.env.EDITOR`. Setting `VISUAL` alone is enough,
  which leaves `EDITOR` a bare `nvim` for tools that match on the editor name.
- `~/.config/nvim` has a **second** rooting autocmd the earlier survey missed:
  `change_to_cur_dir` at `lua/core/autocmds.lua:874`, on
  `BufWinEnter`/`FileChangedShellPost`. It defers its `lcd` with
  `vim.schedule`, so it lands *after* `VimEnter` and silently overrode the
  prompt window's cwd. Only found by an end-to-end launch; the unit spec passed
  while the real thing was broken.

## Decisions

1. **Surface: the agent's own ctrl+g, not a new Herdr binding.** nvim detects
   that it was opened as an agent prompt editor and opens the closeout beside
   it. The edited prompt returns to the agent through the path that already
   works; no `send-text` replay, no fingerprint guard, no Herdr config change.
2. **Layout: prompt left, closeout right.** Closeout is a read-only reference
   window; the prompt buffer is the file the agent handed us.
3. **Model is `git commit`:** rich editing with the record in view. Not a
   read-only popup, not a same-buffer comment block — the closeout must be
   independently scrollable, searchable and yankable while the prompt stays put.
4. **Scope moves to `~/.config/nvim`,** not the Herdr config.
5. **`prefix+b` and `prefix+shift+b` stay.** `prefix+shift+b` clears the session
   before pasting, which ctrl+g cannot do from inside the agent; plain
   `prefix+b` is the zero-friction accept-as-is path. ctrl+g is the editing
   gesture, not a replacement.
6. **The prompt window is `lcd`-ed to nvim's startup cwd** (the agent's cwd,
   inherited at launch), and agent prompt files are exempt from the auto-root
   autocmd at `lua/core/autocmds.lua:200-228`. Without this the window `lcd`s to
   `/private/tmp` and `@`, `:e`, `:grep` and fzf-lua all point at the wrong tree.
7. **Empty prompt buffer is pre-filled with the ready-to-paste block as a single
   undoable change.** `u` empties it for the write-from-scratch case. A buffer
   the agent handed over non-empty is left untouched. Ghost text rejected.
8. **Must work for claude-code, codex and pi** — pi adoption is planned within
   weeks, so detection cannot be claude-specific.
9. **Capture happens in a pre-exec `$VISUAL` shim, not inside nvim** (added
   2026-08-01, forced by the negative finding above).
   `~/.config/nvim/tools/agent_prompt_editor.sh` gates on `HERDR_PANE_ID` +
   `AI_AGENT`, runs `ready_prompt.sh --extract-closeout` against a fresh
   `herdr pane read`, exports `AGENT_CLOSEOUT_FILE` (and optional
   `AGENT_PROMPT_SEED_FILE`), then `exec`s nvim. Every failure falls through to
   plain nvim, which is also what `git commit` gets when it reaches the shim.
   This is not the rejected Herdr-side alternative: no `send-text` replay, no
   fingerprint guard, no Herdr config change — one line of shell env.
10. **Detection keys on `AGENT_CLOSEOUT_FILE`**, replacing "a closeout
    extractable from that pane". Strictly more reliable: the variable exists
    only because extraction already succeeded. `AI_AGENT`/`CLAUDECODE` are
    still not used for detection — every child of an agent shell inherits them.

## Tradeoffs / Risks

- Rejected: Herdr `ctrl+shift+g` running its own editor + `send-text` replay.
  Strongest form: works for panes whose agent has no editor hook, and reuses the
  proven `ready_prompt.sh` insertion path. Lost because it duplicates replay
  machinery and the already-consumed fingerprint guard for a problem the agent
  already solves — and it would sit *next to* ctrl+g rather than fixing it.
- Rejected: same-buffer git-commit-style comment block. Simpler, but the closeout
  is long; scrolling it would move the prompt out of view, which is the failure
  being fixed.
- ~~Risk: nvim opened by ctrl+g occupies the pane's alternate screen. Reading
  the pane's own scrollback from inside it is unproven.~~ Tested; it fails.
  Resolved by decision 9.
- Cost of decision 9: `$VISUAL` now points at a script rather than `nvim`, and
  every editor launch in an agent pane pays one `herdr pane read`. Tools that
  match on the editor's *name* read `$EDITOR`, which is untouched.
- Risk: detection must not fire for every nvim launched from an agent shell.
  `AI_AGENT` / `CLAUDECODE` are inherited by any child process.
- Rejected: Copilot-style ghost text for the seeded prompt. Strongest form: you
  never end up sending boilerplate you did not consciously accept. Lost to
  pre-fill-as-one-undoable-change, which gives the same escape hatch with `u`
  and lets the common case (tweak two lines) be edited immediately with every
  motion, instead of requiring an accept keystroke first. NOT YET CONFIRMED.

## Open Questions

None blocking. Remaining items are implementation choices, settled as follows:

- **Right window shows the whole closeout**, ready-to-paste block included —
  Eddy wants to yank from it. Scratch buffer, `nomodifiable`, `nobuflisted`.
- **Detection**: `AGENT_CLOSEOUT_FILE` set and readable, plus exactly one file
  argument resolving under `$TMPDIR` (both sides realpath-resolved — on macOS
  `$TMPDIR` is a symlinked `/var/folders` path). If any check fails, open
  normally with no split — the fallback is always plain nvim.
- **Extraction**: extend `~/.dotfiles/tmux/scripts/ready_prompt.sh` with an
  `--extract-closeout` mode reusing its existing closeout parsing, so the
  ctrl+g path and `prefix+b` share one parser rather than drifting apart.

## Validation Plan

- `bash ~/.config/nvim/tools/verify.sh` must stay green.
- New spec in `~/.config/nvim/tests/` covering: detection predicate accepts an
  agent prompt file and rejects an ordinary `/tmp` file; the prompt window's cwd
  is the startup cwd, not `/private/tmp`; `M.root()` from that window resolves
  to the repo so `@` completion targets the right tree; pre-fill lands as one
  change that a single `u` reverses; a non-empty handed-over buffer is untouched.
- Parser: a fixture asserting `--extract-closeout` returns the whole closeout
  including the ready-to-paste block, and exits non-zero when none is found.
- Manual QA (needs Eddy, still unconfirmed): open a new shell so `VISUAL` is
  re-exported, then ctrl+g inside claude-code shows prompt left / closeout
  right; `:wq` returns the edited prompt to the agent; `@` completes repo files;
  `u` on a seeded prompt empties it in one step. Repeat for codex, and again
  once pi is in use — both are assumed to prefer `$VISUAL` over `$EDITOR`, which
  is confirmed only for claude-code.

## Ready To Act

Implemented 2026-08-01/02. The riskiest unknown was settled negative and the
design absorbed it as decision 9.

Shipped:

- `~/.dotfiles/herdr/prototype/ready_prompt_parser.sh` — `--extract-closeout`,
  sharing one `mode`-parameterised state machine with `--extract` so the two
  cannot drift. Relocated out of `tmux/scripts/ready_prompt.sh` on 2026-08-02
  (see "Parser relocation" below).
- `~/.config/nvim/tools/agent_prompt_editor.sh` — the pre-exec `$VISUAL` shim.
- `~/.config/nvim/lua/plugin/agent-prompt.lua` — detection and layout.
- Exemptions in **both** rooting autocmds in `lua/core/autocmds.lua`
  (`auto_cwd` and `change_to_cur_dir`, the latter re-checked inside its
  `vim.schedule` body).
- `~/.config/fish/user_variables.fish` — `VISUAL` points at the shim;
  `EDITOR`/`SUDO_EDITOR` stay `nvim`.

Automated validation is green (68 parser tests, 19 nvim specs, 10 shim tests,
`tools/verify.sh`).

## Manual QA confirmed for claude-code (2026-08-04)

Eddy confirmed live: ctrl+g shows prompt above / closeout below, `:wq` returns
to the agent, `@` completes repo files, Alt+h/j/k/l moves inside Neovim and
hands off to the neighbouring Herdr pane at the edge.

Two defects the live run exposed, both fixed:

- `:wq` closed the prompt window and left the closeout holding the pane, so
  returning to the agent took a second close. The closeout's lifetime is now
  tied to the prompt window's, quitting outright when it is the last window.
- A Herdr split (Alt+s) squeezed the pane past what `winfixheight` could
  absorb; Neovim shrank the closeout and never gave the rows back. The window
  now records its share of the frame and restores it on `VimResized`.

The nvim spec suite was reporting 16 of 17 passes: a closeout autocmd outliving
its test fired during teardown and quit the run, skipping the rest silently.
Fixed in `after_each`.

## Pi confirmed from the pinned build (2026-08-04)

Read out of the pinned Pi 0.82.1 binary, not its documentation:

- `externalEditorCommand || process.env.VISUAL || process.env.EDITOR || "nano"`
  — `$VISUAL` wins, so the shim is reached. `pi/settings.json` pins no
  `externalEditor`, which would otherwise take precedence over both.
- `mkdtempSync(join(tmpdir(), "pi-editor-"))` then `prompt.md` — the prompt
  lands under `$TMPDIR`, which is what detection requires.
- `spawn(editor, [...editorArgs, filePath], { stdio: "inherit", shell: false })`
  — exactly one file argument, which is the other half of detection.
- `pilot.sh` exports `PI_CODING_AGENT_DIR` and `PI_PILOT_CONTROL_DIR`, both
  matched by the shim's marker prefixes.
- The parser recognises the pilot by basename `pi`, and the pilot binary is
  `…/versions/0.82.1/pi`.

One behavioural difference from claude-code: Pi discards the edited prompt
unless the editor exits 0. `:wq` and the last-window `quitall!` both do; `:cq`
deliberately does not.

Pi uses the pane-scrollback capture, not the transcript reader — the latter is
claude-specific.

Gated offline in `pi/verify.sh`; the visual half is `pi/MANUAL_QA.md`.
Codex remains unconfirmed.

## Parser relocation (2026-08-02)

Eddy chose to retire tmux rather than keep a compatibility shim: "move fully to
herdr now, tmux on my path will confuse things."

The old file was two programs in one — a transport-free parser and a tmux
replay driver. Only the parser was shared, so the split fell along that seam:

- **New:** `herdr/prototype/ready_prompt_parser.sh` — PARSER_AWK, the extract
  modes, agent recognition, and the ready/clear screen predicates. Owns no
  terminal and spawns no multiplexer, which is what keeps `prefix+b` and
  `ctrl+g` on one parser rather than two drifting copies.
- **Deleted:** `tmux/scripts/ready_prompt.sh`, `tmux/tests/ready_prompt_test.sh`,
  and the `prefix+b` / `prefix+B` binds at `tmux/tmux.conf:219-220`.
- **Repointed:** `herdr/prototype/ready_prompt.sh`, `validate_ready_prompt.sh`,
  `validate_ready_prompt_live_claude.sh`, and both nvim shim files.
- **Tests:** ported to `herdr/prototype/tests/ready_prompt_parser_test.sh`,
  49 of the original 68. The 19 dropped cases covered the deleted tmux replay
  and the deleted tmux.conf binding; the Herdr replay they mirror stays covered
  by the `mock_replay` check in the ready-prompt gate. The suite now runs in
  everyday `herdr/verify.sh` — it needs no server and no prototype binary.
- **Evidence:** `ready-prompt-validation.jsonl` regenerated (not hand-edited);
  `.[1].evidence.source` is now the new path and `checks` is 49.
  `herdr/prototype/verify.sh:942` follows it.

Note for future readers: the `production_hashes_before/after` fields in these
gates are compared to *each other* within a run, not to pinned literals, so
editing `tmux/tmux.conf` does not invalidate the other gates. Only
`artifact_hashes`, which verify.sh recomputes live against the recorded jsonl,
is stale-sensitive.
