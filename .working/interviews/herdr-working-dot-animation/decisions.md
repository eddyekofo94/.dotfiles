# Herdr working-dot animation

## Goal

Settle how the Working agent state animates in Herdr's sidebar/mobile agent
lists, after two reverted attempts (8d04e640 spinner glyph, 7302f8a8 tick),
so the next implementation lands once and animates in the real deployment
(headless server + attached clients).

## Exit Criteria

Decision-only. Enough to move on = glyph set, phase source, which loop owns the
tick, tick interval, visibility gating, and patch-series placement are settled,
with a validation step that would have caught the reverted failure.

## Scope / Non-goals

In: `state_dot` Working branch, redraw scheduling for it, patch-series shape
where it blocks placement. Out: other agent states, toast colours, upstream PR.

## Proposal

### What happens today (code)

- `src/ui/status.rs:200 state_dot` returns a static yellow `●` for
  `AgentState::Working`. Consumed by `ui/sidebar.rs:784,846` and
  `ui/mobile.rs:331,537,600`.
- Rendering is **server-side in every deployment**. The headless server renders
  virtual frames (`src/server/headless.rs:681`) and streams them per client;
  `src/server/render_stream.rs:14` shows clients are either semantic
  (skip-identical-frame) or terminal-ANSI (blit diff encoder). `src/client/mod.rs`
  blits frames — it has no widget layer and never re-renders the sidebar.
- Two scheduling loops exist and have drifted: `App::handle_scheduled_tasks`
  (`src/app/runtime.rs:280`, standalone) and the duplicate
  `handle_scheduled_tasks_headless` (`src/server/headless.rs:4318`). Both share
  the deadline list in `next_loop_deadline_with_resize_poll`
  (`src/app/runtime.rs:571`).

### Why the reverted attempt failed

7302f8a8 set `spinner_deadline` **only in `App::handle_scheduled_tasks`**. The
headless server never calls that function, so under `herdr` server+client the
deadline stayed `None`, the loop never woke at 80ms, and the glyph only advanced
on unrelated events. The wall-clock read was not the defect; the missing tick in
the loop that actually runs was.

### Premise correction

"Phase must be server-owned state pushed to clients" is not the constraint.
Clients cannot animate from state — they blit frames. Pushing a phase field
still requires the server to render and send a frame, so it buys nothing over
reading the clock at render time; it only adds a state field to sync and persist.
The real constraint is **which loop schedules the redraw**.

### Recommendation

1. Keep the phase a pure function of wall-clock read in `state_dot`
   (8d04e640's `working_spinner_frame`) — no new state.
2. Add the tick to **one shared helper on `App`** called by both
   `handle_scheduled_tasks` and `handle_scheduled_tasks_headless`, so the two
   loops cannot diverge again.
3. Gate the tick on: at least one agent Working **and** an attached client
   **and** the surface that shows dots is visible (`state.sidebar_collapsed`,
   config here is `sidebar_collapsed_mode = "hidden"`).
4. Interval 80ms only if a full render at 12.5 Hz is acceptable; otherwise 120ms.

### Flagged forks

- F1 tick interval vs render cost (scheduled tasks force `needs_full_render`).
- F2 patch-series placement — build.sh requires the concatenation to equal one
  `git diff`, which forbids a standalone spinner patch file.
- F3 client-side local animation as the only design that avoids server ticks.

## Decisions

- D1: phase = wall-clock at render time in `state_dot`, no new state field. The
  premise "push phase from the server as state" is rejected: clients blit frames
  and have no widget layer, so a phase field still requires a server render.
- D2: the tick lives in one shared helper on `App`, called by both
  `App::handle_scheduled_tasks` and `handle_scheduled_tasks_headless`. The two
  loops having drifted is the whole cause of the reverted failure.
- D3: interval 120ms (8 Hz), not 80ms, and armed only behind a visibility gate.
  Rejected 80ms: a 10-frame braille cycle is indistinguishable at 8 Hz, and the
  tick forces a full render per attached client for as long as any agent works,
  which is most of the day.
- D3a: the gate is `any agent Working && an app client is attached && the dot
  surface is visible to some render target`. It cannot be `!sidebar_collapsed`:
  `render_sidebar_collapsed` (`ui/sidebar.rs:752`) still draws dots, and only
  `sidebar_collapsed_mode = Hidden` yields width 0 (`ui.rs:230`). Mobile is a
  width-derived view of the same state (`ui.rs:222 is_mobile_width`), not a
  separate client, and per-client geometry differs — so the predicate follows
  the existing `pty_sources_visible_to_any_render_target` shape.
- D4: split the build digests before the spinner patch lands. `build.sh:160`
  currently compares the whole-tree `git diff` against `HERDR_PATCH_SHA256`, the
  concatenation digest, which forces every patch file to own a sorted-contiguous
  path range. Add `HERDR_TREE_DIFF_SHA256` for the tree compare and keep the
  concatenation digest for tamper detection. Rejected folding into
  `copy-mode-vim-muscle-memory.patch` again: it survives review only by
  misnaming the change, and it makes copy-mode undroppable without also dropping
  the spinner at the next upstream tag. Contiguity buys no safety — the patched
  tree is already pinned twice.
- D5: no client-side animation. Rejected after argument: it is the only design
  where the server never ticks, so it is the one that scales to a slow remote
  link, and the phase would be perfectly smooth regardless of server load. It
  loses because the server owns a per-client `BlitEncoder` baseline
  (`server/render_stream.rs`); a client painting cells the encoder does not know
  about desyncs that baseline and produces artifacts until a repaint. It would
  also need a new protocol message carrying cell coordinates, invalidated by
  every layout change, in a transport layer the private series does not touch
  today. At 8 Hz the wire cost it avoids is one diff-encoded cell.

## Evidence / Findings

- `build.sh:160-167` compares `git diff --binary` of the whole tree against
  `HERDR_PATCH_SHA256`, the digest of the concatenated patch files. Patch files
  must therefore own path ranges that are contiguous in sorted order.
- Current ownership: copy-mode patch spans `src/app/api/panes.rs` …
  `src/ui/menus.rs`; then mobile, sidebar, status. `src/app/mod.rs`,
  `src/app/runtime.rs`, `src/server/headless.rs` all fall *inside* the copy-mode
  span, which is why 7302f8a8 folded them into a copy-mode-named patch.
- `HERDR_PATCHED_SOURCE_SHA256` already pins the patched tree independently.

## Tradeoffs / Risks

- A scheduled-task wake sets `needs_full_render` in both loops: a full widget
  render every tick for every attached client while any agent works.
- Remote/mobile clients get the same cadence over the wire (diff-encoded, small).
- Folding non-copy-mode code into `copy-mode-vim-muscle-memory.patch` makes the
  series' "one file per reviewed change" claim false.

## Validation Plan

- The regression test that would have caught the revert: drive
  `handle_scheduled_tasks_headless` across a tick boundary with an agent
  Working and assert the deadline arms and re-arms. A test against `App`'s loop
  alone is what passed while the feature was dead.
- Gate test: no deadline armed when no client is attached, or when no render
  target can see the dot surface.
- `herdr/source-build/build.sh --repin` must re-pin cleanly, and a second run
  without `--repin` must pass — proof the split digests agree.
- `herdr/verify.sh` and `herdr/verify_integrations.sh`.
- Manual: attach a client, start an agent, watch a quiet terminal for 5s with no
  keystrokes and no agent output; then collapse the sidebar and confirm the tick
  stops (`render_prof`).

## Ready To Act

Seams: `src/ui/status.rs` (glyph + phase), `src/app/mod.rs` and
`src/app/runtime.rs` (shared tick helper, deadline list),
`src/server/headless.rs` (headless scheduled tasks calling the shared helper),
`herdr/source-build/build.sh` and `pins.env` (D4 digest split), plus a new
patch file for the runtime/server paths.

Order: D4 build.sh split and re-pin first, standalone, verified green. Then the
spinner as its own patch file.

Stop condition: with an agent Working and a client attached, the dot animates on
an otherwise idle terminal; the tick is absent when no client is attached or the
dot surface is hidden; all three digests re-pin and re-verify; the headless-path
test fails if the tick is removed from the headless loop.

## Implementation Notes

- D4 landed first and was verified green on its own: `build.sh` passed with no
  re-pin, confirming the digest split is a no-op for the existing tree.
- New guard found during implementation: `build.sh` only runs the test filters it
  names, so `cargo test --locked working_spinner_` was added. Without it the
  regression test would have been decoration — the same class of mistake as the
  original revert.
- `working_dots_visible` reads the last rendered geometry
  (`view.sidebar_rect.width`, `view.mobile_header_rect.height`) rather than
  `sidebar_collapsed`, per D3a.
- Negative control run: deleting the headless call makes
  `working_spinner_tick_arms_in_the_headless_scheduled_tasks` fail. Restored.

## Open Questions

None. F1, F2, F3 resolved as D3, D4, D5.
