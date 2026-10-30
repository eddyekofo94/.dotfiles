# Compact window trial (Eddy, 2026-10-30)

`autoCompactWindow` went 120000 -> 160000 in `claude/settings.json` (commit cd258627).
Cause: compaction was the largest named cache-write cost on 2026-10-30
($21.29 of $224.84, 93 turns); /build tabs compacted at ~87k context.

## Check — on or after 2026-10-31
1. `date +%F` must be later than 2026-10-30; tabs open before the change keep the old window.
2. `python3 ~/.agent-skills/retro/scripts/token_audit.py --days 0 --match biblestandard --match BibleStandard`
   (its "Cache writes by cause" section is the split).
3. Compare with the baseline: $224.84 / 5058 turns = $0.0445 per turn; compaction $21.29, 93 turns.
4. Spend per turn rose -> set `autoCompactWindow` back to 120000, commit, push.
   Fell or flat -> keep it; delete this folder.
5. Report the comparison and stop.
