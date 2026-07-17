# Herdr Searchable Picker Policy

## Goal

Settle one implementation-ready policy for searchable Herdr runtime navigation: replace the tmux session/window/pane `choose-tree` and custom fzf window picker with a defined Herdr policy covering bindings, searchable runtime objects, selection behavior, and deterministic failure/return paths.

## Exit Criteria

Decision-only and implementation-ready: one picker policy is selected; every in-scope binding and searchable object has one owner; selection, cancellation, empty-result, stale-target, and cross-session behavior are explicit; and a deterministic validation plan is recorded.

## Scope / Non-goals

In scope: Herdr v0.7.4's workspace/tab/pane navigator, the boundary between its current named session and other named sessions, migration of tmux `prefix+w`, `prefix+f`, and `Alt-Ctrl-f`, runtime-object search fields and agent-state filters, selection semantics, and failure/return behavior.

Non-goals: the Fish `fe` command or any filesystem picker; production tmux, Fish, Ghostty, or Neovim edits; changing already approved Herdr bindings; filesystem preview/image parity; session auto-attach; agent-state model fixes; migration authorization; and implementing the picker during this interview.

## Decisions

- The Fish `fe` command is unrelated to this policy and must not be modified, rebound, validated, or treated as a Herdr/tmux migration surface.
- Respect Herdr's runtime model rather than reproducing tmux's global tree: the searchable navigator is scoped to workspaces, tabs, and panes inside the currently attached named Herdr session.
- Named-session discovery and attachment remain explicit Herdr lifecycle operations outside the picker. Do not build a custom cross-session aggregator or make the navigator attach to another named session.
- Preserve Herdr's two native navigation surfaces: `prefix+w` opens ordinary workspace/sidebar navigation through `workspace_picker`, while `prefix+f` opens the searchable workspace/tab/pane navigator through `goto`.
- Preserve the approved `prefix+g` lazygit popup; moving searchable `goto` to `prefix+f` resolves the existing default-key displacement without reopening lazygit's chord.
- Preserve the approved `prefix+Enter` scratch-shell popup unchanged. Picker work may verify that it does not collide, but popup behavior and sizing are outside this policy.
- Keep searchable runtime navigation prefix-only: `prefix+f` opens `goto`; retire the old direct `Alt-Ctrl-f` alias rather than registering a global Herdr shortcut that could intercept pane applications.
- On navigator open, retain Herdr's native initial state: clear prior query/filter state, expand all workspaces, and select the current pane (or the first available row if no current row exists).
- Retain Herdr's native search controls and object fields. `/` enters text search; case-insensitive whitespace-separated terms match with AND semantics against visible workspace label/activity, tab label/pane-count/activity, and pane title/agent/state text. `b/w/i/d` apply blocked/working/idle/done filters; `a` or filter-mode backspace clears the state filter.
- Retain Herdr's native selection behavior. `Enter` on a workspace focuses that workspace, on a tab focuses that workspace/tab, and on a pane focuses that exact workspace/tab/pane; every successful selection returns to terminal mode.
- Retain Herdr's native failure and return paths. `Esc` from search returns to the navigator without changing the active target; outer `Esc` cancels to the previously active pane; an empty result or a target that disappeared before acceptance is a no-op; the picker never creates, closes, or terminates runtime objects.
- Herdr navigator search is runtime-scoped, not filesystem-scoped. It searches the attached Herdr session's workspaces, tabs, and panes using visible workspace labels/activity, tab labels/pane counts/activity, and pane titles/agent labels/state text. It also supports blocked/working/idle/done state filters.

## Evidence / Findings

- `docs/migrations/tmux-to-herdr.md` marks searchable session/window/pane picking as a required unresolved gate, with old bindings `prefix+w`, `prefix+f`, and `Alt-Ctrl-f` awaiting a Herdr policy.
- `herdr/prototype/config.toml` preserves approved `Ctrl-a` prefix navigation and already owns `prefix+g` with the approved prototype lazygit popup; `prefix+w` and `prefix+f` are currently free in the isolated Herdr key table.
- `fish/functions/fe.fish` confirms that `fe` is only a Fish filesystem/editor command. Its appearance in the migration trial does not make it part of the Herdr runtime picker policy.
- The checked Herdr binary is stable v0.7.4. Its config surface provides `workspace_picker` (default `prefix+w`) and `goto` (default `prefix+g`). Source inspection shows `workspace_picker` enters the ordinary sidebar/navigation mode, while `goto` opens the searchable workspace/tab/pane navigator overlay.
- Herdr v0.7.4 navigator opens with all workspaces expanded and the current pane selected. `/` focuses text search; whitespace-separated terms use case-insensitive AND substring matching. `b/w/i/d` filter blocked/working/idle/done; `a` or backspace clears a state filter.
- `Enter` on a workspace, tab, or pane focuses that target and returns to terminal mode. `Esc` from text search returns to the navigator with the query intact; `Esc` from the navigator cancels and returns to the pre-existing active pane without changing focus. Empty or stale selections are safe no-ops because acceptance returns false unless the target still exists.
- Official Herdr concepts define a session as a separate persistent server namespace and recommend workspaces as the project-level container. The navigator operates on the current session state; session switching is exposed separately by CLI attach commands.
- The existing approved binding record reserves `prefix+b/B`, uses `prefix+S`, `prefix+s`, `prefix+g`, and the other settled chords, and requires unrelated picker work not to reopen them.

## Tradeoffs / Risks

- Keeping separate `prefix+w` and `prefix+f` actions adds one concept to remember, but preserves Herdr's deliberate distinction between ordinary workspace navigation and the searchable navigator.
- Navigator text search does not include arbitrary pane scrollback or filesystem content; pane titles and labels must be meaningful for reliable lookup.
- Stable v0.7.4 cannot natively aggregate multiple named sessions into one overlay. Treating that as part of this picker would expand scope into a custom launcher and attach lifecycle.
- The user explicitly approved the Herdr-native boundary: the migration does not have to mimic tmux, and the policy should respect Herdr's approach.

## Validation Plan

1. Static config validation: generate the isolated prototype config with `workspace_picker = "prefix+w"` and `goto = "prefix+f"`; run the prototype's config check and collision audit; prove `Alt-Ctrl-f` is absent and all previously approved bindings, including `prefix+Enter` and `prefix+g`, remain unchanged.
2. Fixture topology: create two labeled workspaces, at least two tabs in one workspace, and distinct shell/agent pane titles with blocked, working, idle, and done states in one isolated named session.
3. Search assertions: drive real prefix input to open the navigator; verify the current pane is initially selected; verify multi-term case-insensitive search resolves workspace, tab, and pane labels; verify each state filter returns only the intended rows and clear restores the full tree.
4. Selection assertions: select one workspace, one tab, and one pane; after each `Enter`, read back focused workspace/tab/pane IDs and verify terminal mode resumes.
5. Return/failure assertions: verify search `Esc` returns to the navigator without changing focus; outer `Esc` returns to the original pane; no-match `Enter` is a no-op; deleting a target before acceptance is a no-op; no pane process is terminated.
6. Session-boundary assertion: run two isolated named sessions, prove the navigator in session A lists only session A objects, and prove explicit `session attach` is required to reach session B.
7. Final scope audit: `git diff --name-only` must show only picker-policy/prototype validation artifacts; production tmux, Fish, Ghostty, and Neovim paths must be absent.

## Ready To Act

The picker policy is implementation-ready. Next, implement only an isolated prototype navigator validation gate from this record, update the migration checkmark only after the full validation plan passes, and leave production migration/configuration untouched.

## Open Questions

None for the scoped picker policy.
