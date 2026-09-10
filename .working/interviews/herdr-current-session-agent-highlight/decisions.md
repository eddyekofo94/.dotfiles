# Herdr Current Session Agent Highlight

Status: Spec Needed

## Intake

- Source: Eddy, 2026-09-10, with a live Herdr screenshot: "when I select the
  last session, the list of herdr agents left on the left as displaye, should
  always highlight the current session but how as you can see based on the
  sidebar, it doesn't highlight it, the current session should always be
  displayed on the list".
- Goal: after any Herdr tab/session selection, keep the corresponding current
  agent row inside the sidebar viewport and visibly highlight that row.
- User story: when moving among several simultaneous agent tabs, Eddy can tell
  which sidebar agent owns the focused content without matching tab numbers or
  reading pane contents.
- Current pain: the screenshot shows tab `6 .dotfiles` selected while none of
  the six agent rows has the expected active-row background. The row exists,
  but the sidebar does not communicate that it is current.
- Current workaround: match the selected top-bar tab number and label to the
  numbered agent rows manually.

## Existing behavior and owner

- Partially ships: `herdr/config.toml` sets
  `[theme.custom].active_row_bg = "#45475a"` specifically to distinguish the
  active agent row from the panel background.
- Rendering owner: Herdr v0.8.2
  `src/ui/sidebar.rs::render_agent_detail` and
  `src/ui/sidebar.rs::render_sidebar_collapsed` derive row highlighting from
  `AppState::is_active_pane`.
- Visibility owner: Herdr v0.8.2 `src/ui/sidebar.rs` builds the agent-panel
  entries and viewport; existing focused-row tests cover styling but do not
  reproduce a real tab switch with six visible agents.
- Configuration contract: `herdr/source-build/verify.sh` pins the active-row
  color, but a config assertion cannot prove selection synchronization or
  viewport reveal.
- Historical relationship: this `refines` the shipped
  `agent-panel-active-highlight` behavior from commit `fcae6d95`; that work
  made an already-active row visually distinct but did not establish this
  reported tab-switch contract.

## Disposition

`finetune` the authoritative Herdr sidebar selection/rendering seam. Do not add
a parallel sidebar, selection store, watcher, or shell-driven synchronization
path. The exact source change remains unresolved until the divergence between
the active tab/pane and `is_active_pane` is reproduced.

## Scope

- Keep the current agent row visible when tab selection changes, including
  when the list exceeds the available sidebar height.
- Apply the configured active-row background across the full current agent
  card/row.
- Cover mouse, native tab-key, numbered-tab, and API-driven focus paths if they
  share the reproduced state transition.
- Preserve lifecycle dots, agent text hierarchy, sidebar scrolling, workspace
  selection, collapsed mode, and unrelated focus behavior.

## Out of scope

- Renaming tabs, agents, sessions, or workspaces.
- Changing the Catppuccin palette or choosing a new highlight color.
- Replacing Herdr's native sidebar or active-pane state.
- Expanding the active `herdr-alt-ctrl-tab-chords` implementation goal.

## Validation required

- A focused Herdr source test that switches from an earlier tab to the last of
  at least six agent tabs and proves the selected agent card is both inside the
  viewport and painted with `active_row_bg` across its full width.
- Coverage for a current agent outside the pre-switch viewport.
- Focused source-build verification and the full Herdr verification command.
- Physical Ghostty acceptance using the same crowded-sidebar interaction from
  Eddy's screenshot; automation cannot confirm visual salience.

## Relationships and constraints

- `refines` the shipped `agent-panel-active-highlight` contract because the
  configured highlight already owns this outcome when active-pane identity is
  correct.
- `shares implementation seam with` sidebar rendering and active-pane focus in
  the pinned Herdr v0.8.2 source tree.
- The former `blocked by herdr-alt-ctrl-tab-chords` relationship is resolved;
  that goal closed without expanding this intake. This item remains unselected
  and `Spec Needed`.
- Possible relationship to the tab-switch paths being changed by that goal;
  confirm only if the same failure reproduces with an unchanged existing tab
  binding or mouse selection.

## Open question

- Does the missing highlight reproduce when selecting tab 6 by mouse or an
  existing `Prefix+n`/top-bar action, or only through the new
  `Ctrl+Alt+h/l` chord currently under implementation?

Nothing is implemented or activated by this intake.
