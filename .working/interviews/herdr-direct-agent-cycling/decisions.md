# Herdr Direct Agent Cycling

Status: Merged and installed locally — physical Ghostty acceptance remains;
full production verification is externally blocked by the pre-existing outdated
Pi integration.

## Intake

- Source: Eddy, 2026-09-12: "I want ctrl+alt+j/k to jump to the next agent,
  meaning the next agent on the list or previous. since ctrl+alt+h/l jumps to
  next tab I want to be able to jump to the next agent, use /herdr skill or
  whatever to achieve this".
- Goal: `Ctrl+Alt+j/k` moves directly to the next/previous agent in the native
  Herdr agent-list order, so Eddy can review active agents without stepping
  through non-agent tabs or opening a picker.
- User story: while monitoring several concurrent agents, Eddy can keep one
  hand on the home row and cycle through agent work in the same visible order
  as the sidebar.
- Current workaround: use `Ctrl+Alt+h/l` to cycle tabs, or `Prefix+f` /
  `Prefix+A` to locate and focus an agent explicitly.
- Current pain: direct tab cycling and agent cycling are not equivalent. A live
  2026-09-12 inspection returned 10 tabs but 9 agents because workspace `w3`'s
  tab had `agent_status: unknown` and no agent row; tab cycling can therefore
  stop on a surface that is absent from the agent list.

## Existing behavior and owner

- Partially ships: `herdr/config.toml` and `herdr/prototype/config.toml` already
  bind global `Ctrl+Alt+h/l` to native previous/next tab actions.
- `herdr agent list` already returns the current named session's ordered agent
  inventory, including stable terminal identity and the focused row.
- `herdr agent focus <target>` already focuses an exact agent; the completed
  `herdr/prototype/agent_overview.sh` uses that action with stale-target
  validation for explicit cross-session selection.
- Native list-order ownership belongs to Herdr v0.8.2's agent/sidebar state and
  `src/ui/sidebar.rs`; repository configuration should not invent a second
  ordering that can drift from what the sidebar displays.
- Existing seam: `herdr/config.toml`, `herdr/prototype/config.toml`, Herdr
  v0.8.2 agent focus/list behavior, and the pinned source-build patch seam under
  `herdr/source-build/`.

## Disposition

`finetune` the existing Herdr command/config seam with one thin wrapper that
consumes `agent list` and `tab list` in their emitted order, performs no sorting,
and delegates selection to `agent focus`. This preserves native list-order and
focus ownership without carrying a private Herdr source patch or creating a
second inventory.

## Scope

- `Ctrl+Alt+j` selects the next agent row; `Ctrl+Alt+k` selects the previous.
- Ordering matches the native current-session agent list visible in the
  sidebar.
- Both directions wrap at list boundaries.
- From a focused non-agent tab, `Ctrl+Alt+j` selects the next agent in sidebar
  order and `Ctrl+Alt+k` selects the previous agent, wrapping at boundaries.
- Non-agent tabs and panes are skipped.
- The chords are global Herdr actions, matching `Ctrl+Alt+h/l` ownership rather
  than being forwarded to Neovim or another foreground application.

## Out of scope

- Changing `Ctrl+Alt+h/l` tab cycling.
- Changing sidebar ordering, labels, grouping, filtering, or agent lifecycle
  state.
- Cycling agents in other named Herdr sessions; `Prefix+A` retains ownership of
  cross-session discovery and focus.
- Fixing current-row highlighting or viewport reveal.
- Adding a second agent inventory, selection state, or polling mechanism.

## Validation required

- Focused transport coverage for Kitty CSI-u `Ctrl+Alt+j/k` input.
- A fixture with at least three agent rows plus one non-agent tab, proving both
  directions follow displayed agent order, skip the non-agent tab, and wrap.
- Preserve `Ctrl+Alt+h/l`, pane navigation, application keymaps, `Prefix+f`,
  and `Prefix+A`.
- Run the focused Herdr gate, `herdr/prototype/verify.sh`, `herdr/verify.sh`,
  and `git diff --check` after implementation.
- Physical Ghostty acceptance must confirm both chords against a crowded native
  sidebar; automation cannot prove the perceived list-to-focus correspondence.

## Relationships

- `refines` the completed `herdr-alt-ctrl-tab-chords` home-row navigation
  contract by assigning the vertical pair to agent movement while preserving
  the horizontal pair for tabs.
- `shares implementation seam with`
  `.working/interviews/herdr-current-session-agent-highlight/decisions.md`
  because both depend on native active-agent/sidebar identity, but this feature
  is independently deliverable and does not include its rendering fix.
- `shares implementation seam with` the completed cross-session overview's
  exact `agent focus` action, while preserving that feature's `Prefix+A`
  cross-session boundary.

## Ready To Act

Ready 2026-09-12. Agent order, directional behavior from agent and non-agent
tabs, wrapping, skipped surfaces, thin-wrapper ownership, scope, and validation
are settled.
Activated 2026-09-12 after the shared checkout was cleaned and the prior
worktree claim was safely released. Brief:
`.working/interviews/herdr-direct-agent-cycling/implementation-brief.md`.

## Implementation Evidence

- `herdr/prototype/agent_cycle.py` consumes `agent list` and `tab list` without
  sorting, revalidates exact identity, and delegates to `agent focus`.
- Production and prototype configs bind Kitty CSI-u `Ctrl+Alt+j/k` globally.
- The focused four-tab fixture passes: three ordered agents, one non-agent tab,
  both directions, wraps, directional non-agent entry, and preserved
  `Ctrl+Alt+h/l` tab movement.
- Every config-hash-pinned validator was regenerated successfully. The popup
  validator was rerun after merge so its checkout-local evidence names `main`.
- `herdr/prototype/verify.sh`, `herdr/source-build/verify.sh`, ready-prompt
  parser tests, and `git diff --check` pass after the final change.
- Fresh review: Standards 0 findings; Fidelity 0 findings. Source: `review.md`.
- Implementation commit `f6d0ed83` is contained in local merge `8a18c3fc` on
  `main`; no push occurred.
- The reviewed Herdr v0.8.2 binary and merged config were installed. The live
  server accepted `reload-config`.
- Full build-local `herdr/verify.sh` ran through unit, source-build, and project
  picker gates, then stopped at the unchanged integration audit because the
  separately managed Pi integration reports `outdated (v5 < v8)`. Migrating
  Pi is outside this goal; no verifier weakening or integration overwrite was
  accepted.
- Physical Ghostty acceptance is not run.

## Open Questions

None.
