# Physical Two-Window QA

Date: 2026-07-29

## Exact interaction

1. Activated Ghostty and sent the native macOS `Command-N` shortcut.
2. Confirmed the new physical window attached to named session `window-2`
   while the existing physical window remained attached to `main`.
3. Typed `HERDR_WINDOW_TWO_QA_20260729` into the focused `window-2` Fish
   prompt and read it back only from that session.
4. Sent the configured Herdr `Control-A`, `c` navigation sequence to the new
   window.

## Result

- `window-2` gained a tab (`1 -> 2`).
- `main` retained its original tab and pane topology.
- The typed sentinel appeared in `window-2`; the existing `main` Codex surface
  remained unchanged.
- A fresh desktop capture showed two distinct physical Ghostty surfaces: the
  new independent Fish/Herdr window on the left and the retained Codex/Herdr
  window on the right.

Status: PASS. The two physical Ghostty windows can type and navigate
independently.

## CWD Acceptance Recheck

Eddy's 13:20 retest rejected the earlier closure because retained session
`window-3` had been created with its only Fish pane at filesystem root `/`.

After adding the root-cwd fallback:

1. Native `Command-N` created fresh independent session `window-4`.
2. Its root pane reported both `cwd` and `foreground_cwd` as
   `/Users/eddyekofo`.
3. The earlier idle `window-3` pane was moved non-destructively from `/` to
   `/Users/eddyekofo`; its visible prompt and Herdr chrome now show `~`.

CWD status: PASS for the then-settled root fallback. Eddy's later lifecycle
clarification supersedes inherited cwd for automatic New Window: automatic
launches start from `$HOME`, while restored panes retain their session cwd.

## Restore-or-Create Lifecycle Recheck

1. With `main` and `window-2` through `window-5` active, native `Command-N`
   created the never-before-allocated `window-6`.
2. `window-6` started at `/Users/eddyekofo`.
3. That check exercised a superseded in-shell exit callback. Fresh review found
   it was not reliable for a real terminal HUP, so it is not current closure
   evidence.
4. The corrected implementation uses an event-driven, HUP-resistant supervisor
   with deterministic PID-reuse, symlink, no-polling, preserved-client-stdin,
   and no-client restoration coverage.

Lifecycle status: physical active-client creation passes. Exact physical
close-all then reopen restoration remains the final user gate.

## Post-Fix Production Observation

At 2026-07-29 18:17 CEST:

- the original physical `main` client was still running from 12:41, so an exact
  all-clients-closed interval had not occurred;
- `window-7` was running through the finalized event-driven supervisor with a
  matching PID-plus-start-identity lease;
- automatic `window-8` had been allocated at 18:00, its client was no longer
  present, and the persistent restore pointer was `window-8`;
- the remaining `window-8` runtime lease referenced a dead supervisor PID and
  is therefore deterministic stale-state input that the allocator rejects by
  process-start identity on the next allocation.

This is current production evidence for finalized active-client allocation and
crash-safe pointer seeding. It is not evidence for the required no-client
restore because `main` and `window-7` were still attached during inspection.

## Final Close-All/Reopen Acceptance

At 2026-07-29 18:23 CEST, after every earlier physical Ghostty client was
closed:

1. The first newly opened physical Ghostty window restored retained automatic
   session `window-7`.
2. Its client and HUP-resistant supervisor were both fresh processes started
   at 18:21:31; none of the earlier 12:41 or 17:48 clients remained.
3. Opening a second physical Ghostty window while `window-7` was active created
   fresh monotonic session `window-9` at 18:21:46.
4. The allocator correctly skipped already-known `window-8` instead of
   recycling its name, and the durable last-session pointer advanced to
   `window-9`.
5. The two live runtime leases matched their respective new supervisor process
   identities.

Final lifecycle status: PASS. A no-client launch restores retained work; a
concurrent ordinary New Window creates a distinct monotonic session from
`$HOME`. The two physical windows remain independently navigable and writable.
