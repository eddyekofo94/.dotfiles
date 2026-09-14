# Pi Weekly Usage Live Refresh — Implementation Brief

## Status

Rebased onto clean main `01b4a36c`. Post-fix focused/full verification and independent Standards/Fidelity re-review pass. Ready for authorized local commit/merge and installation. Stop at `/reload` readiness; physical Ghostty confirmation remains outstanding.

## Sources

- `.working/interviews/pi-weekly-usage-live-refresh/decisions.md`
- `.working/UNIFIED_INTAKE.md`
- `.working/ACTIVE_GOAL.md`

## Scope

- Replace the launch-only footer snapshot with extension-owned weekly state.
- Refresh that state after completed Codex provider activity.
- Preserve the last valid value when a refresh fails.
- Render weekly allowance neutral above 20%, amber from 11–20%, and maroon at 0–10%.
- Update focused automated coverage, documentation, and manual QA fixtures.

## Non-goals

- No timer-based idle polling.
- No footer layout changes.
- No changes to non-Codex provider behavior.
- No unrelated dirty-file changes.
- No push or remote publication. Eddy authorized local commit, merge, and installation with `ship`.
- Preserve the parked `pi-reasoning-level-footer` worktree unchanged.

## Validation

- Focused weekly reader/state and footer tests.
- `./pi/verify.sh`.
- Fresh Standards review against repository instructions and the actual diff.
- Fresh Fidelity review against the decisions record.
- Physical Ghostty refresh and colour inspection remains user confirmation.
