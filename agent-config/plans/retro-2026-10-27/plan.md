# Plan: retro 2026-10-27 top change (iOS report ios-2026-10-27.md)

Two guards, both in `~/.dotfiles/agent-config/` (the iOS record BS-IOS-TASK-671 sets the precedent for landing there).
Settings.json already carries unrelated uncommitted edits (cloudflare plugin); this plan edits only its PostToolUse list and commits nothing.

## A. Compaction stop in `claude/build_budget_guard.py`
- [x] A1 `scan` also counts `type: system, subtype: compact_boundary` rows (non-sidechain) after the build start. Proof: new test, 1 boundary allowed, 2 denied.
- [x] A2 `main` denies with "build past 2 compactions" at count >= 2; same allowed calls, extend file, `hold_ended`, fail-open. Proof: tests; parking calls (git log, plan.md edit) still pass at 2.
- [x] A3 Docstring rule list names the new rule. Proof: read.

## B. Bash output truncation hook `claude/bash_output_trim.py`
- [x] B1 PostToolUse on `Bash`: stdout+stderr over 8,000 chars becomes head 3,000 + marker + tail 3,000, full text written to `$TMPDIR/claude-bash-output/<session>-<tool_use_id>.log`; returns `hookSpecificOutput.updatedToolOutput` with the tool_response shape copied, only stdout/stderr replaced. Proof: tests (under 8k untouched, over 8k trimmed, log holds full text, shape keys kept).
- [x] B2 Fail open: any error or unknown response shape prints nothing, exit 0. Proof: test with bad stdin.
- [x] B3 Wire it in `claude/settings.json` PostToolUse (matcher `Bash`). Proof: JSON parses; hook runs from the command string.

## C. Run
- [x] `python3 agent-config/tests/build_budget_guard_test.py` and the new `bash_output_trim_test.py`, output read.
- Not provable here: that Claude 2.1.311 accepts the rewritten Bash shape in a live turn (needs a fresh session).
