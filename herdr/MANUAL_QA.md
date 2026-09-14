# Herdr Manual QA

## Shared project catalog — physical Ghostty gate

This check requires Eddy in a real Ghostty window. Automated timing covers catalog output, not terminal first paint. Do not mark it passed from script output.

- [x] Press `Prefix+Shift+w`; candidates or an explicit `refreshing` state appears within 500 milliseconds by human-timed observation. Eddy reported it appeared “almost instantly” on 2026-09-14; no numeric timing was captured.
- [x] Keep typing while refresh is active; the picker remains interactive.
- [x] Type `BibleStandard`; one canonical CanonFidei checkout appears, with no separate symlink alias. Distinct registered worktrees may also appear.
- [x] Moving across project rows renders a bounded two-level directory-tree preview for the canonical path, without exposing the hidden TSV metadata fields. Eddy accepted the corrected preview on 2026-09-14.
- [x] Press `Enter`; Herdr creates or focuses the workspace for the selected canonical path.
- [x] Reopen `Prefix+Shift+w`; the workspace has an `[open]` annotation and its rank has not changed merely because it is open.
- [x] Press `Ctrl-r`; the existing list remains usable while refresh runs and reloads after successful completion.

Record the date, observed first-paint time, selected path, and any duplicate or interaction failure in the active decision record before closing the goal.
