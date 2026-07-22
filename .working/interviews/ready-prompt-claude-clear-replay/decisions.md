# Codex And Claude Ready-Prompt Replay

## Goal

Make lowercase replay and uppercase clear-then-replay equally safe for Codex
and Claude in production tmux and the Herdr migration target.

## Settled Behavior

- `Prefix+b` finds the newest valid ready-to-paste handoff and inserts it into
  Codex or Claude without submitting it.
- `Prefix+B` sends `/clear` to Codex or Claude, waits for that agent's stable
  ready composer, then inserts the handoff without submitting it.
- Clear-and-replay remains unavailable for other recognized agents until their
  clear and ready contracts are independently proven.
- Extraction, consume-once, concurrency, copy-mode, malformed handoff, and
  unsupported-agent paths continue to fail closed.

## Diagnosis Evidence

- `./tmux/scripts/ready_prompt.sh --clear-support claude` failed in three of
  three pre-fix runs.
- `clear_supported_agent` allowed only `codex`, and the regression test asserted
  that Claude must fail.
- Both tmux and Herdr clear-ready loops matched only Codex's `›` composer even
  though the shared terminal parser already recognizes Claude's `❯` chrome.
- Claude Code 2.1.202 is installed and its official documentation defines
  `/clear` as clearing conversation history.

## Ranked Hypotheses

1. The explicit Codex-only allowlist is the immediate rejection cause. If
   Claude is added, the direct clear-support repro will pass.
2. Codex-only `›` readiness matching is a second independent cause. If matching
   becomes agent-aware, Claude `❯` fixtures will reach stable-ready insertion.
3. A fixed post-clear delay could race either agent. Existing stable-screen
   polling must remain the synchronization mechanism.

## Ready To Act

Ready. Expected behavior, scope, stop condition, and validation are settled by
the user's explicit selection on 2026-07-19.

## Implementation

- The shared tmux helper recognizes Codex and Claude clear contracts, derives
  the active agent from pane metadata and process evidence, and owns the shared
  empty-composer readiness and active-`/clear` predicates.
- tmux and Herdr use those shared predicates while retaining their own
  transport loops. Both insert with bracketed paste and never submit the
  recovered handoff.
- A pane-scoped atomic tmux lock rejects overlapping replays. Only the lock
  owner removes it, so rejected contenders cannot open a concurrency race.
- Herdr has deterministic Claude fixtures and an optional disposable live
  Claude validator that performs no model call.

## Verification Results

- `./tmux/scripts/verify.sh`: PASS, including 49 ready-prompt regressions.
- `./herdr/prototype/validate_ready_prompt.sh`: PASS.
- `./herdr/prototype/verify.sh`: PASS.
- Herdr skill validation: PASS.
- Live tmux Claude clear-ready-insert: PASS, ready composer preserved and
  `submitted=false`.
- `./herdr/prototype/validate_ready_prompt_live_claude.sh`: PASS, stable idle
  Claude composer preserved and `submitted=false`.
- `git diff --check`: PASS.
- Fresh Standards review: 0 findings after fix and re-review.
- Fresh Fidelity review: 0 findings after fix and re-review.

## Closure

Completed on 2026-07-19. The ready-prompt goal does not authorize Herdr
daily-driver promotion; that remains a separate human decision.
