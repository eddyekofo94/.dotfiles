# Herdr Daily-Driver Promotion

## Goal

Decide whether and how to promote Herdr from its isolated prototype to Eddy's
main daily multiplexer without giving up a proven tmux fallback.

## Exit Criteria

Decision-only and implementation-ready: the rollout model, production surfaces,
fallback and rollback behavior, known accepted gaps, stop condition, and
validation plan are settled with no implementation-changing questions left.

## Scope / Non-goals

In scope: whether Herdr is ready for promotion, whether promotion is staged or
immediate, which production launcher/configuration surfaces may change, how tmux
remains available, and what must pass before and after the change.

Non-goals: implementing the promotion during this interview, deleting tmux,
reopening settled binding policy, emulating unsupported tmux features, polishing
the accepted image-preview gap, or changing unrelated Fish, Ghostty, Neovim,
agent, Zsh, or tmux behavior.

## Decisions

- Eddy wants Herdr to become the main driver. The remaining uncertainty is
  safety/readiness, not product preference.
- On 2026-07-23, Eddy selected promotion after accepting the live image,
  navigation, nested-Fish, and color behavior. Use the reversible staged route:
  Herdr becomes the default while tmux remains installed and immediately
  available as a non-nested fallback.
- Promotion must not imply deleting tmux or its configuration. A working tmux
  path remains the rollback baseline unless Eddy later authorizes its removal.
- The image replacement/focus lifecycle remains accepted deferred polish and is
  not a promotion blocker.
- Do not treat historical green evidence as sufficient while the current
  aggregate verifier is red; refresh only the stale proof needed to bind the
  current reviewed artifacts before promotion.
- Promotion is considered settled when the installed default, explicit tmux
  fallback, persistent rollback/default switch, aggregate verification, clean
  Ghostty launch, and fresh review pass. No waiting period is required, and
  tmux removal remains a separate future decision.

## Evidence / Findings

- The migration tracker reports all active required behavior and keybinding
  rows checked, with zero active behavior gaps and one remaining approval gate:
  explicit daily-driver authorization.
- Direct user acceptance already covers focused visual density, physical
  navigation, mouse behavior, golden-ratio focus, Ghostty key/color fidelity,
  and the application-owned Alt transport.
- Deterministic evidence covers detach/reattach, sessions/workspaces, panes,
  tabs, copy/search, picker behavior, URLs, ready-prompt replay, agent states,
  login attach safety, remote attach, and recovery.
- Recovery is intentionally Herdr-native: snapshot, pane history, and supported
  agent resume are proved; arbitrary process resurrection is not promised.
- Production tmux remains the documented baseline. The isolated login adapter
  is proved inert inside Herdr, inside tmux, for non-login/non-interactive
  shells, with opt-out, and for unsafe session names.
- On 2026-07-21, `./herdr/prototype/verify.sh` still exits 1. Trace evidence
  locates the failure in the hash-bound `binding-validation.jsonl` aggregate
  assertion after current Fish/prototype changes, not in configuration syntax:
  all four Herdr configuration checks report `config: ok`.
- The worktree already contains extensive user-owned Herdr, Fish, tmux, and
  workflow changes. A later implementation must use an explicit allowlist and
  preserve unrelated dirt.
- On 2026-08-12, two audit-gate defects were found while confirming the
  production gate against the `semantic_agent_state.py --session` fix. Both are
  about how the gate is invoked and cleaned up, not about parity coverage.
  1. **Fixed.** `HERDR_VERIFY_AUDIT=1` is owned by `herdr/verify.sh`, but
     `herdr/prototype/verify.sh` silently ignored it, so
     `HERDR_VERIFY_AUDIT=1 sh herdr/prototype/verify.sh` printed PASS having run
     no audit at all — fail-open, and the invocation `.working/ACTIVE_GOAL.md`
     itself documented. The prototype gate now exits 2 and names the owning
     gate; `herdr/verify.sh` clears the flag when it delegates downward.
  2. **Fixed 2026-08-12.** A failed audit validator left its
     `herdr/prototype/.runtime/bin/herdr server` running. The next audit run
     then collides with the orphan and fails somewhere else entirely — observed
     as `layout-menu validation timed out: single-pane popup dismissed`, then as
     a silent exit 4 after login-attach, while `validate_layout_menu.sh` passed
     standalone. Killing the two orphaned servers made the full gate green
     (exit 0) with no new leak. So a single red audit run poisons every
     subsequent run with a *different, misleading* failure, and the recorded
     cause of a red audit gate could not be trusted until the orphans were
     cleared. Traps were the wrong fix: `kill -9` runs no trap, and 8 of the 14
     validators never killed the server at all, relying on `session stop`
     succeeding. `herdr/prototype/server_lifecycle.sh` instead moves teardown
     off the dying shell onto a watchdog subshell that outlives it, with a
     startup sweep as the backstop for a watchdog that was itself killed; all
     16 validators source it. It **keys on the socket, not a server pid**, so
     the guard can be armed *before* the server launches — a pid-keyed guard
     could only be armed on the line after `server_pid=$!`, and a SIGKILL
     landing in that window leaked the server anyway (observed). It **detaches
     stdin** as well as stdout/stderr, because these validators drive a PTY
     client that reads the script's stdin; a background subshell holding that
     descriptor starves the client and the gate times out on "initial pane"
     (observed, then isolated by disabling only the guard). Both helpers signal
     only processes whose command line matches the `/.runtime/bin/herdr …
     server` runtime path, so neither can touch production
     `~/.local/bin/herdr`. Verified: `HERDR_VERIFY_AUDIT=1 sh herdr/verify.sh`
     exits 0.

## Tradeoffs / Risks

- A reversible staged promotion captures the real benefit—Herdr opens by
  default—while keeping tmux immediately available if an untested daily-work
  edge appears.
- An immediate destructive replacement adds no useful validation signal and
  makes recovery harder. It is unnecessary for making Herdr the main driver.
- Prototype automation is extensive, but only ordinary daily work exposes
  timing, long-session, and subjective workflow friction. The rollout should
  therefore distinguish "default" from "tmux removed."
- **Resolved 2026-08-12.** The aggregate verifier's stale hash evidence was a
  promotion blocker until refreshed and green, even though it never indicated a
  behavioral failure. It is now refreshed: `verify.sh` recomputes the
  `config.toml` / `herdr_nav.fish` / `shell_action.sh` / `validate_bindings.sh`
  hashes live and asserts them against `binding-validation.jsonl`, all four
  match the current artifacts, and the same run asserts the production
  tmux/Fish/Ghostty/Neovim hashes unchanged before and after. Verified:
  `HERDR_VERIFY_AUDIT=1 sh herdr/verify.sh` exits 0 with prototype and
  production verification PASS. This blocker no longer gates promotion; the
  remaining gate is the live Ghostty daily-work trial plus explicit
  authorization.

## Validation Plan

- Refresh only the stale hash-bound Herdr evidence required by the current
  reviewed artifacts; then require `./herdr/prototype/verify.sh` to pass.
- Run the repository's relevant Fish verification and syntax checks after the
  narrowly scoped launcher change.
- Prove a fresh top-level interactive Fish login attaches to Herdr's approved
  main session, while non-login, non-interactive, nested Herdr, nested tmux,
  opt-out, and unsafe-session paths remain inert.
- Prove the explicit tmux fallback opens a working tmux session without nesting
  or launcher loops.
- Prove rollback restores tmux as the default without deleting or corrupting
  Herdr sessions or tmux configuration.
- Perform a live Ghostty trial using ordinary Neovim, Fish/fzf, Codex/Claude,
  detach/reattach, copy/search, pane/tab lifecycle, and ready-prompt replay.
- Require a fresh Standards/Fidelity review after deterministic and live
  validation; fix and re-review findings before closure.

## Ready To Act

Ready as of 2026-07-23. Eddy selected the reversible staged promotion. Local
implementation, validation, review, and durable closure are authorized; commit,
push, tmux removal, and external publication are not authorized.

## Open Questions

None that change implementation.

## Implementation Brief

- Promote the reviewed focused Herdr configuration to a tracked production
  config while retaining the validated prototype helpers during the staged
  period.
- Install the pinned, hash-verified Herdr v0.7.4 binary in `~/.local/bin` and
  link only `~/.config/herdr/config.toml`; preserve existing Herdr session and
  log state.
- Make top-level interactive Fish login attach to the named `main` Herdr
  session only when the fail-closed default state is `herdr`; retain every
  existing nested, tmux, opt-out, non-login, and non-interactive guard.
- Provide a persistent `herdr|tmux` default switch and a fresh-Ghostty tmux
  fallback that never nests tmux inside Herdr.
- Sanitize the Codex-only `NO_COLOR` leak in the isolated live-trial launcher,
  not in normal user shells.
- Stop only when production config/install checks, the login/fallback/rollback
  matrix, `herdr/prototype/verify.sh`, `fish/scripts/verify.sh`, a clean Ghostty
  default launch, and fresh Standards/Fidelity review pass. Final physical
  daily-driver acceptance remains a manual gate.

## Implementation Status

**DONE 2026-08-12** — Eddy accepted Herdr as the daily driver after the live
Ghostty trial (see below). Prior state, retained for history:

Awaiting User Approval as of 2026-07-23. The local staged default is active and
the named `main` session is running. `herdr/verify.sh` and
`fish/scripts/verify.sh` pass; the real Ghostty fallback/rollback matrix and
preservation hashes are recorded in `promotion-validation.md`. Fresh
Standards/Fidelity review findings were fixed through the automatic
fix/re-review loops, affected checks rerun, and both final re-reviews report
zero findings. The open production Herdr window needs only Eddy's final
physical daily-driver acceptance.

### Live Ghostty trial — 2026-08-12

Launched via `sh herdr/prototype/launch_live_ghostty.sh`. Automated state at
launch: `sh herdr/prototype/verify.sh` exits 0 (PASS, all four `config: ok`) on
the pre-trial worktree; the trial session `trial-focused` came up with the
expected three panes (`w1:p1` nvim focused, `w1:p2` fzf preview, `w1:p3` QA
notes) on a fresh session directory, and only the prototype runtime server was
started — production `~/.local/bin/herdr` was untouched.

One prep defect observed, not fixed: `prepare_live_trial.sh`'s scripted
`vsplit` (line 66) did not land. The script had already exited and the trial
Neovim still reported one window; issuing the same `--remote-expr` afterwards
produced two. So the `sleep 1.5` after the socket answers races Neovim's config
load, and the trial can start without the second Neovim window that the
Alt-h/l application-boundary check depends on. Recovered by hand for this run.

**Closed 2026-08-12.** Eddy ended the trial with "close this trial I am happy
with herdr now" — the final physical daily-driver acceptance this goal was
waiting on, given as a whole-experience judgement rather than a per-check
report, so no individual hand check is recorded as separately proved. The trial
window and its `trial-focused` prototype server were stopped; production
`~/.local/bin/herdr` kept running throughout. The staged promotion stands as
installed: Herdr is the default, tmux remains the untouched fallback, and its
removal is still a separate future decision. The Acceptance Pause below is
resolved by this acceptance — the parity sequence it named is no longer an
acceptance gate, and any remaining parity items are ordinary backlog.

Hand checks handed over at launch, offered but not individually reported: Neovim
Alt-h/j/k/l across the Neovim/Herdr boundary, fzf preview navigation and image
redraw on resize, Alt-v / Alt-n / Alt-z / Alt-q / Alt-X pane and tab lifecycle,
`prefix+shift+g` golden focus, copy mode and search, detach/reattach, a real
Codex/Claude pane with ready-prompt replay, and ordinary daily work long enough
to expose timing and long-session friction.

## Acceptance Pause

On 2026-07-24, Eddy paused final daily-driver acceptance after requesting a
feature-by-feature audit of the complete tmux configuration. The reversible
promotion remains installed, verified, and available; it is not rolled back.
Final acceptance is now `blocked by` the ranked parity sequence recorded in
[`../../../docs/migrations/tmux-to-herdr-parity-audit.md`](../../../docs/migrations/tmux-to-herdr-parity-audit.md).
The first bounded goal is `herdr-recovery-safety-parity`. This pause does not
authorize an upgrade, integration install, commit, push, tmux removal, or
external publication.
