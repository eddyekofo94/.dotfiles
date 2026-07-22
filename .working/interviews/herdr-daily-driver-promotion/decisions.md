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
- Promotion must not imply deleting tmux or its configuration. A working tmux
  path remains the rollback baseline unless Eddy later authorizes its removal.
- The image replacement/focus lifecycle remains accepted deferred polish and is
  not a promotion blocker.
- Do not treat historical green evidence as sufficient while the current
  aggregate verifier is red; refresh only the stale proof needed to bind the
  current reviewed artifacts before promotion.

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

## Tradeoffs / Risks

- A reversible staged promotion captures the real benefit—Herdr opens by
  default—while keeping tmux immediately available if an untested daily-work
  edge appears.
- An immediate destructive replacement adds no useful validation signal and
  makes recovery harder. It is unnecessary for making Herdr the main driver.
- Prototype automation is extensive, but only ordinary daily work exposes
  timing, long-session, and subjective workflow friction. The rollout should
  therefore distinguish "default" from "tmux removed."
- The aggregate verifier's stale hash evidence is a promotion blocker until
  refreshed and green, even though it does not currently indicate a behavioral
  failure.

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

Not yet. The promotion method is awaiting Eddy's decision. No production
configuration change is authorized by this interview alone.

## Open Questions

1. Should Herdr become the default through a reversible staged promotion, with
   tmux kept intact as an explicit fallback, or should promotion wait?
2. What amount of normal daily use is enough before the staged promotion can be
   considered settled rather than a trial?

