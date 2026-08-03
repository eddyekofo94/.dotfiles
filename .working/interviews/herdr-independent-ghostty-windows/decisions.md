# Independent Herdr Ghostty Windows

## Goal

Make every ordinary top-level Ghostty window an independent simultaneous Herdr
work surface instead of attaching multiple clients to the same shared `main`
session view, while restoring the most recently used automatic session when no
Herdr client is open.

## Exit Criteria

With no Herdr client open, the first ordinary Ghostty window restores the most
recently used automatic named session. While any Herdr session is open, each
additional Ghostty window creates a new named session from `$HOME`. Two windows
can navigate and type independently, retained sessions preserve their work, and
the existing guarded tmux fallback and explicit named-session override remain.

## Scope / Non-goals

In scope:

- restore the persisted most recently used automatic session when no Herdr
  client is active;
- while any Herdr client is active, create a never-before-allocated automatic
  session (`main`, then monotonically increasing `window-N`);
- start every newly allocated automatic session from `$HOME`;
- preserve the explicit `HERDR_LOGIN_SESSION` override;
- add deterministic concurrency, stale-lease, compatibility, and fail-closed
  validation;
- run physical two-window QA.

Non-goals:

- per-client independent navigation inside one Herdr session, which Herdr
  v0.7.4 does not support;
- one named session per project;
- stopping or deleting a session when its window closes;
- changing Herdr version, tmux configuration, or Ghostty's native New Window
  binding;
- commit, push, or external publication.

## Decisions

- If no automatic history exists, the first ordinary top-level login uses
  `main`. Each automatic allocation seeds a most-recent-session pointer, and
  the automatic client refreshes it on exit so the final window to close wins.
- When no Herdr client or live allocation lease exists, the next ordinary
  top-level login restores that most-recent automatic session. On migration,
  the highest existing automatic `window-N` is the deterministic latest
  fallback when no pointer exists.
- When any Herdr client or live allocation lease exists, the next ordinary
  top-level login creates a never-before-allocated session: `main` if it has
  never existed, otherwise the next monotonically increasing `window-N`.
- Automatic login changes to `$HOME` before allocation. Retained Herdr session
  panes keep their own persisted cwd when restored; new session roots start
  from home.
- Each lease binds the automatic client supervisor PID to its process start
  identity. The event-driven supervisor waits for its Herdr client instead of
  polling, survives terminal HUP, refreshes the most-recent pointer when that
  exact client exits, removes only its matching lease, and explicitly preserves
  the terminal stdin descriptor for the supervised Herdr client.
- Allocation belongs in the existing guarded Fish-to-Herdr login seam. Ghostty
  1.3.1 exposes a native `new_window` action but no stable per-window
  environment identity, and its configured command is shared by every new
  terminal surface.
- A small tracked allocator owns atomic slot selection. The initial lease
  reserves the slot against the top-level Fish PID, then transfers under the
  same lock to the event-driven supervisor before Herdr starts. Stale leases
  are recoverable, and the live process list protects pre-existing or
  explicitly launched clients that have no lease.
- `HERDR_LOGIN_SESSION=<safe-name>` remains an explicit override and bypasses
  automatic allocation. This preserves intentional attach/recovery workflows,
  including deliberate shared viewing.
- Allocation failure must fail closed through the already retained tmux
  fallback rather than attach to an occupied Herdr session.
- Existing Herdr-inside-Herdr, Herdr-inside-tmux, non-login,
  non-interactive, unsafe-name, and opt-out guards remain unchanged.

## Evidence / Findings

- Eddy's 2026-07-29 screenshot shows two Ghostty windows rendering and editing
  the same live Codex pane.
- The live process table showed two clients with identical
  `herdr --session main` arguments and one `main` server.
- `herdr/prototype/herdr_login_attach.fish` currently selects `main` for every
  ordinary top-level login.
- Herdr v0.7.4 documents multi-client attachment as one shared session view,
  without tmux-style per-client independent navigation.
- Named sessions have distinct sockets, workspaces, tabs, panes, and persisted
  state and are the already approved isolation boundary.
- Ghostty 1.3.1's default `super+n=new_window` launches the same configured
  command for the new terminal surface. The live environment contains no
  stable window or surface identifier suitable as a recovery identity.
- The existing project picker intentionally creates workspaces inside the
  current named session; it does not solve independent macOS windows.

## Tradeoffs / Risks

- Monotonic session names preserve dormant session identity and prevent a new
  simultaneous window from unexpectedly reopening old work. Automatic session
  count grows until the configured safety cap; old sessions are not deleted.
- Local process and lease evidence covers ordinary Ghostty clients. A future
  unsupported attach path that hides its client process could still share a
  slot; explicit named attaches remain intentionally allowed to share.
- Existing mirrored clients cannot be retroactively separated. Newly opened
  windows use the new allocator; physical QA must create fresh windows.
- Runtime leases are advisory and may remain after a crash. PID plus process
  start identity and deterministic stale cleanup prevent PID reuse from falsely
  making the allocator think a session is open. Unsafe symlink leases fail
  closed.
- The persistent most-recent pointer records the last automatic session whose
  client exits; allocation-time recording is the crash fallback. macOS focus
  changes between simultaneously open windows are not separately tracked.

## Validation Plan

- Extend the isolated login-attach validator to prove a cold first login gets
  `main`, simultaneous logins create `window-2` and `window-3`, no-active-client
  launch restores the persisted latest session, an active client forces a new
  monotonic session instead of an inactive restore, migration bootstraps from
  the highest existing automatic session, stale leases recover, and explicit
  safe overrides still work.
- Retain every existing login guard and production-preservation assertion.
- Run `./herdr/verify.sh`.
- Run `./fish/scripts/verify.sh`.
- Run `git diff --check`.
- Run fresh Standards and Fidelity review against this record, the active
  brief, the complete diff, and verification evidence; fix and re-review until
  both axes have zero findings.
- Physically open two fresh Ghostty windows, confirm their Herdr session
  identities differ, type distinct sentinels, change workspace/tab focus in
  one, and confirm the other remains unchanged.

## Ready To Act

Ready as of 2026-07-29. Eddy selected the lifecycle rule directly: restore the
last automatic session when none is open; if any session is open, create a new
named session from home. Recovery and tmux fallback remain required. Local
implementation, validation, review, fixes, and durable closure are authorized;
commit and push are not.

## Open Questions

None that change implementation.

## Implementation Brief

- Make the atomic allocator persist automatic-session history and distinguish
  no-client restoration from active-client monotonic creation.
- Route only unoverridden ordinary top-level Herdr login through the allocator.
- Keep explicit named-session selection and every existing nesting/default
  guard intact.
- Extend the existing login fixture and validator with concurrent client
  lifetimes, persisted latest-session restoration, monotonic creation,
  migration bootstrap, and stale-state coverage.
- Integrate the allocator syntax and focused validator into `herdr/verify.sh`.
- Stop only when focused and aggregate verification pass, fresh Standards and
  Fidelity review report zero findings, and physical Ghostty QA proves both
  active-client creation from home and no-client restoration.
