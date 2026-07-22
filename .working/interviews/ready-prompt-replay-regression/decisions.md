# Ready-Prompt Replay Regression

## Observation

On 2026-07-21 the user reported that `Prefix+B` no longer works in Codex as it
used to and that both `Prefix+b` and `Prefix+B` now feel broken.

## Relationship

Verified regression of `ready-prompt-claude-clear-replay`. The stricter shared
empty-composer predicate introduced for safe Codex/Claude support does not
represent the current Codex empty-composer presentation.

## Tight Reproduction

A disposable real Codex 0.144.6 tmux run prints a canonical handoff, launches
Codex without making a model request, invokes the production helper, and
asserts that the sentinel is left in the composer without submission.

- Lowercase: PASS (`code=0`, both handoff lines present).
- Uppercase: FAIL (`code=1`, neither handoff line present).
- Trace: `/clear` is submitted, but the post-clear loop repeatedly sees a
  prompt such as `› Explain this codebase` and times out.
- Styled capture proves the suggestion is dim terminal placeholder text:
  `ESC[1m›ESC[0m ESC[2mSummarize recent commits`; genuinely typed text lacks
  the dim style and moves the cursor past the input.
- Existing deterministic suite: PASS 49/49, proving it does not model the
  current Codex placeholder state.

## Why Both Feel Broken

The current Codex pane has a valid handoff whose fingerprint matches its
pane-local consume-once state. Lowercase therefore correctly directs the user
to uppercase. Uppercase is the intended clear-and-replay escape path, but its
post-clear readiness check rejects Codex's semantically empty placeholder and
never pastes. Lowercase works in a fresh disposable pane; the combined workflow
is what is currently trapped.

## Ranked Hypotheses And Results

1. **Confirmed:** the glyph-only ready predicate rejects Codex's dim rotating
   empty placeholder. Prediction: an idle five-second-old Codex pane still
   fails uppercase while showing a styled suggestion; observed.
2. **Contributing but not sufficient:** invoking during startup or active work
   leaves `/clear` disabled. Prediction: waiting for startup removes that
   message but not the timeout; observed.
3. **Rejected:** bindings are missing or stale. Both live prefix bindings point
   at the expected production helper.
4. **Rejected for the current pane:** handoff extraction is the primary cause.
   The current pane's latest canonical handoff extracts successfully and its
   consume fingerprint is valid.

## Recommended Bounded Goal

Restore semantic Codex empty-composer detection for tmux without weakening the
Claude typed-composer guard. Audit the Herdr adapter only where it consumes the
same readiness contract; do not widen into unrelated Herdr migration work.

## Expected Behavior

- `Prefix+b` continues consume-once safe insertion without submission.
- `Prefix+B` recognizes a current Codex dim placeholder as empty after
  `/clear`, then pastes without submission.
- Real typed Codex or Claude composer text, active `/clear`, queued input,
  loading, and working-state paths continue to fail closed.

## Stop Condition

The real disposable Codex reproduction passes for lowercase and uppercase;
deterministic fixtures distinguish bare empty, dim placeholder, and typed text;
the full tmux and affected Herdr verification chains pass; live Claude behavior
remains safe; and fresh Standards/Fidelity reviews have zero findings.

## Scope / Non-goals

- Change the shared readiness predicate and its directly impacted deterministic
  coverage.
- Preserve consume-once insertion, `/clear` submission, queued/loading guards,
  agent recognition, bindings, and all unrelated tmux and Herdr behavior.
- Do not authorize Herdr daily-driver promotion, commit, push, or external
  lifecycle changes.

## Validation Plan

- `./tmux/tests/ready_prompt_test.sh`
- `./tmux/scripts/verify.sh`
- disposable live Codex tmux lowercase and uppercase replay without submission
- `./herdr/prototype/validate_ready_prompt.sh`
- `./herdr/prototype/validate_ready_prompt_live_claude.sh`
- `git diff --check`
- fresh Standards and Fidelity review after the last implementation change

## Ready To Act

Ready. The user selected this bounded goal with `feature-plan` on 2026-07-21.
No implementation-changing questions remain.

## Open Questions

None.

## Implementation

- tmux captures one ANSI-preserving readiness snapshot and derives the plain
  view from that same snapshot, removing the typed-input race between reads.
- Codex readiness accepts a bare composer or content wholly rendered with dim
  styling, including wrapped placeholders. Inline, partially styled, and
  multiline typed content remains non-empty.
- Queued input, model loading, and `Working (... esc to interrupt)` remain
  explicit fail-closed states.
- The Herdr adapter reads its visible pane in ANSI format, derives the paired
  plain view, and applies the same readiness contract without changing other
  prototype behavior.

## Verification Evidence

- `./tmux/tests/ready_prompt_test.sh`: PASS, 61/61.
- `./tmux/scripts/verify.sh`: PASS.
- Disposable Codex 0.145.0 tmux replay: lowercase PASS and uppercase PASS;
  both sentinel lines remained in the composer with `submitted=false`.
- `./herdr/prototype/validate_ready_prompt.sh`: PASS, including the dim Codex
  placeholder through the production adapter.
- `./herdr/prototype/validate_ready_prompt_live_claude.sh`: PASS,
  `submitted=false`.
- `git diff --check`: PASS.
- Broad diagnostic `./herdr/prototype/verify.sh`: FAIL at the unrelated
  pre-existing `binding-validation.jsonl` artifact-hash assertion. The focused
  replay verifier and its generated evidence pass; unrelated binding evidence
  was intentionally not regenerated or changed.

## Fresh Review

- Standards: 0 findings.
- Fidelity: 0 findings.
- Review ran after the final atomic-capture, multiline-input, working-state,
  and Herdr ANSI fixes.

## Closure

Done on 2026-07-21. The active-goal pointer is cleared. No commit or push was
performed.
