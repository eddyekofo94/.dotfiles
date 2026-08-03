# Independent Herdr Ghostty Windows — Closure

Status: DONE on 2026-07-29.

## Outcome

Ghostty's native `Command-N` now gives each ordinary top-level window an
independent named Herdr session instead of attaching every window to `main`.
When no automatic Herdr client is open, launch restores the last retained
automatic session. While any automatic session has an active client, New
Window allocates a never-before-used monotonic `window-N` session from
`$HOME`.

Closing a window leaves its Herdr server and work intact. Allocation is guarded
by private runtime state, a lock, and HUP-resistant leases tied to both PID and
process-start identity, so stale state and PID reuse cannot make two physical
windows mirror one session.

Explicit `HERDR_LOGIN_SESSION` selection, every existing nesting and opt-out
guard, and the tmux fallback are preserved. No commit or push was performed.

## Verification

- `./herdr/prototype/validate_login_attach.sh` — PASS
- `./herdr/prototype/verify.sh` — PASS
- `./herdr/verify.sh` — PASS
- `./fish/scripts/verify.sh` — PASS
  (`24.506 ms` median, `25.483 ms` p95)
- `git diff --check` — PASS
- Physical native `Command-N`, session-local typing, and independent tab
  navigation — PASS; see `physical-qa.md`
- Physical close-all/reopen: first fresh window restored `window-7`; a
  concurrent second window created `window-9` from `$HOME` — PASS
- Fresh Standards review — 0 findings
- Fresh Fidelity review — 0 findings

## Review Fixes Encoded

- Session-name validation covers the allocator's full `window-2` through
  `window-999` range, including a `window-10` regression.
- Runtime creation is cold-start concurrency-safe and rejects broad, symlinked,
  non-directory, wrongly owned, or non-private runtime state.
- Deterministic tests cover no-client restoration, active-client monotonic
  creation, stale leases, PID reuse, migration from the superseded allocator,
  and failed-HOME behavior.
- The prototype README documents independent session allocation and recovery.

## Deferred Scope

None for this goal. Herdr remains on the retained version, `pane_history`
remains disabled, and tmux remains available.
