# Auto-compact and tab rollover

Eddy, 2026-10-12: "I don't want to be sitting here and doing it": no manual
`/compact`, `/clear` or new tab to manage context. Last 7 days: 8 manual
`/compact`, 11 `/clear`.

Facts this plan rests on (Claude Code 2.1.296, read from the binary):

- `autoCompactWindow` (top-level setting) is an integer from 100000 to 1000000.
  Auto-compact fires about 33k below it: at the 200k default, recent
  auto-compacts ran at 166.8k-171.2k, and Eddy's manual ones at 153k-161k.
- A `PreCompact` hook's stdout (exit 0) is appended to the compaction
  instructions. Any non-empty output skips the precomputed summary
  (`miss_hook`), so that compaction takes a full pass (about 40-75s) instead of
  an instant swap.
- `SessionStart` fires with `source: "compact"` after every compaction; its
  `additionalContext` reaches the continuing session.
- BibleStandard's `WORKFLOW_LOOPS.md` §Shipping Fast rule 4 freezes `.claude/`
  and `tools/` until 2026-10-17, so step 1 lives in the dotfiles only. Its
  `tab_goal_resume.py` already injects on `compact` but words it as a clear
  ("not authorization"); the global hook corrects that, and the project fix
  waits for the freeze to lift.

## Step 1: compaction runs itself and keeps the goal

1. `agent-config/claude/settings.json`: `"autoCompactWindow": 185000`, which
   fires near 152k, where Eddy compacts by hand.
   Proof: in a test session, `/context` shows the new threshold.
2. `agent-config/claude/compact_handoff.py precompact`: a PreCompact hook that
   prints what the summary must keep: the record ID and file, the active
   `plan.md` path, its current step and proof, the branch and worktree, what
   is unlanded, Eddy's corrections verbatim, and the open question. Main
   sessions only.
   Proof: a forced `/compact` in a test session runs the hook (its
   `PreCompact [...] completed successfully` line shows on screen).
3. `compact_handoff.py resume` on `SessionStart` with matcher `compact`. It
   injects the goal (from `repo_lock.py resume --json` when the project has
   one) and the next unchecked `plan.md` step, says the session keeps its
   authorization and mode, and says to re-read the plan before acting.
   Proof: after the forced `/compact`, the test session can name the goal and
   plan step without being told.
4. `context_guard.py`: the 70% and 90% notices stop telling Eddy to `/compact`
   or open a tab. Auto-compact does that; the session only makes its resume
   file current.
   Proof: unit run of `message()`; no "/compact" in either band's text.
5. Unit tests: `agent-config/tests/compact_handoff_test.py`, covering
   precompact output, resume output, subagent skip and the no-goal silence.
   Proof: `python3 agent-config/tests/compact_handoff_test.py` passes.

Done 2026-10-12, uncommitted. Live proof, Sonnet test session on a scratch
repo: `/context` showed a 185k window with a 33k buffer (fires at 152k), and a
forced `/compact` ran the PreCompact hook and injected `COMPACTION HANDOFF`.
Asked with no tools, the session named FS-999, its plan.md and step S2.
8/8 unit tests pass.

Stop after step 1; Eddy reviews before step 2.

## Step 2: agent tabs continue by themselves

Changed in the build (Eddy, 2026-10-12: "these sessions should continue
building without me"): rather than open a new tab, `herdr-reap` continues the
same tab. The tab, checkout, label and lane stay; `/clear` gives the fresh
context a new tab would. Eddy's own tabs (no `▸`) keep step 1 only.

1. `herdr/reap_idle.py` `decide_continue`: a `▸` tab, unfocused, one pane,
   idle or done, quiet 3 minutes, whose last closeout reads `PARTIAL` with a
   fenced ready-to-paste prompt, gets that prompt back (as `/build <ID> ...` for
   a build tab). At 120k context or more it gets `/clear` first.
   Guards: never AWAITING, WAITING or Eddy-spoke-last; at most 8 a day per tab;
   a repeated Next move stops it; held while the five-hour allowance is 90%
   used or the seven-day 95% (`~/.cache/claude-allowance.json`, written by the
   statusline). The close rule also accepts Herdr's `done` state.
   Proof: `python3 herdr/tests/test_reap_continue.py`, 13 tests.
2. Live: a scratch `▸ grill-fs999` tab at PARTIAL; one `herdr-reap --only`
   pass sent `/clear` then its prompt, and the session ran it to DONE
   (`step-b` appended; state recorded). Done 2026-10-12.
3. Found live: Herdr reports a `/clear` as stalled (no state change), so the
   first version cleared fs200 at 23:18 and sent nothing. Fixed: `/clear` is
   sent without a wait and the prompt is retried once. fs200 was given its own
   prompt by hand and is building again.
