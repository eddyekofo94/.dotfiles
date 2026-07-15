# Tmux Ready-Prompt Replay

## Goal

Define an implementation-ready tmux shortcut that extracts the most recent
agent-provided ready-to-paste next-session prompt and places it into the current
agent input without copy mode, manual selection, or clipboard round-trips.

## Exit Criteria

The interview is complete when the shortcut, extraction boundary, submission
safety, fallback behavior, supported prompt shapes, and validation cases are
settled well enough to implement without further product decisions.

## Scope / Non-goals

Scope: one tmux prefix binding for the current pane, prompt discovery and
extraction, safe insertion behavior, failure feedback, and package-local
verification/manual QA.

Non-goals: agent-status indicators, general clipboard or copy-mode changes,
rewriting agent skills, and automatically starting a new agent session.

## Decisions

- Use `prefix+b`; the key is free in the repository config and live prefix table.
- Preserve the existing `prefix+u` one-shot interaction style as the design
  precedent.
- `prefix+b` inserts the extracted prompt into the current pane without
  submitting it. The user reviews it and presses Enter explicitly.
- Discovery searches recent bounded scrollback rather than only the visible
  pane. The initial implementation cap should be validated against long agent
  handoffs instead of scanning the full 65,536-line history.
- Recognize both a fenced block and a single-line backtick prompt when they are
  attached to a `Ready-to-paste prompt` label. Ignore unlabeled code blocks.
- The newest labeled prompt in the bounded history is the only automatic
  candidate.
- `prefix+b` consumes each discovered prompt once per pane. A repeated attempt
  reports that it was already inserted; `prefix+B` deliberately replays the
  newest prompt.
- Missing or malformed newest extraction fails closed, inserts nothing, and
  displays a specific tmux message. It never falls back to an older prompt.
- Failure messages distinguish no prompt, malformed latest prompt, and an
  already-consumed prompt that can be replayed with `prefix+B`.
- Both bindings operate only when the current pane's foreground program is a
  recognized Codex, Claude, OpenCode, Gemini, or `agy` agent. Other panes fail
  closed with `prefix+b: current pane is not a supported agent`.

## Producer Protocol And Compatibility

New Codex and Claude skill closeouts use one readable canonical protocol from
the shared `skill-finish` skill:

````text
**Ready-to-paste prompt:**
```text
<prompt>
```
````

The label is the machine-readable anchor and the fenced block is the boundary.
Rendered terminal output that strips Markdown fences remains supported as a
labeled plain paragraph. V1 markers remain accepted for older handoffs only.

The parser accepts these forms in priority order:

1. Labeled fenced blocks: canonical for all new Codex and Claude handoffs.
2. V1 begin/end markers: legacy compatibility.
3. Labeled inline backticks: legacy single-line form.
4. A labeled plain paragraph: rendered terminal form after Markdown fences are
   stripped.
5. `Next move:` followed by a standalone paragraph: older unlabeled skill
   closeout form.
6. An inline `Next move:` action: last legacy fallback when the following lines
   are Codex terminal chrome.

Unlabeled code blocks, unterminated markers/backticks/fences, worked-for
dividers, input rows, model-status rows, and older candidates behind a malformed
newest candidate fail closed or are ignored.

## Evidence / Findings

- `tmux/tmux.conf:214` implements `prefix+u` by scanning the current visible pane,
  opening the last URL, and showing a tmux message when none exists.
- `rg` found no `prefix+b` binding in the tracked tmux configuration.
- `tmux list-keys -T prefix` found no live `prefix+b` binding.
- `prefix+B` is also free in the repository config and live prefix table.
- Captured agent history contains both fenced multi-line ready-to-paste prompts
  and older inline backtick prompt forms; extraction cannot assume one shape
  without an explicit compatibility decision.
- The current `skill-finish` contract standardizes the heading
  `Ready-to-paste prompt`, giving new handoffs a durable marker to target.
- Existing unrelated worktree state must remain untouched: one modified Fish
  helper and untracked `.opencode/`, `CONTEXT.md`, `ripgrep/.ripgreprc`, and
  `tmux/tmux.conf.dreamsofcode`.

## Tradeoffs / Risks

- Automatic submission saves one more keystroke but can execute a stale or
  incorrectly extracted prompt before review.
- Accepted: insertion-only costs one Enter keystroke in exchange for review and
  protection against accidental execution.
- Accepted: consume-once state adds a small per-pane runtime record but prevents
  accidental duplicate insertion; uppercase replay is the explicit escape hatch.
- Visible-screen-only extraction matches `prefix+u` but may miss a handoff that
  has just scrolled out of view.
- Scrollback extraction is more forgiving but increases the chance of selecting
  an older prompt from a prior turn.
- Accepted: bounded scrollback is worth the stale-match risk, provided a separate
  freshness rule prevents replaying an old handoff unintentionally.
- Accepted: fail-closed parsing may require manual copy mode for a malformed
  handoff, but avoids silently inserting stale content.
- Accepted: an agent-only guard excludes generic shell/editor reuse in exchange
  for preventing multi-line instructions from being pasted into the wrong kind
  of pane.

## Validation Plan

- Parse the changed tmux configuration in an isolated server.
- Run `bash -n` on the helper script.
- Run deterministic extraction fixtures covering fenced multi-line, inline,
  missing, malformed, multiple-prompt, bounded-history, consume-once, and forced
  replay cases.
- Run `git diff --check`.
- Manually verify in a fresh tmux session that insertion preserves newlines and
  does not submit, lowercase refuses a consumed prompt, uppercase replays it,
  non-agent panes fail closed, and each failure message is clear.
- Exercise foreground-process recognition for Codex, Claude, OpenCode, Gemini,
  and `agy`; any unavailable CLI remains explicitly unverified rather than
  assumed supported.

## Ready To Act

Prototype the parser and bindings as a bounded tmux package change:

1. Add `tmux/scripts/ready_prompt.sh` with a default 2,000-line capture bound,
   labeled-format parsing, per-pane consumed fingerprint, and force-replay mode.
2. Bind `prefix+b` to normal insertion and `prefix+B` to forced replay in
   `tmux/tmux.conf`.
3. Add deterministic parser fixtures/tests beside the tmux package.
4. Run the validation plan and leave interactive behavior awaiting user visual
   and workflow confirmation.

## Open Questions

None. The current scope is implementation-ready.
