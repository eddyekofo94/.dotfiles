# Retro 2026-11-05: a tab lives for one record

Source: ~/.claude/retro/reports/ios-2026-11-05.md, "The one change that makes next week cheapest".

- [x] Test first (red): close_on_land_test.py — a `/build` prompt in a tab at 21 compactions or 601 turns is refused; 20 / 600 pass; a non-goal prompt passes. Proof: tests fail before the change.
- [x] close_on_land.py UserPromptSubmit: refuse `/build` past 20 compactions or 600 turns, open `/build <ID>` in a fresh tab (`herdr-goals --build <ID>`). Proof: new tests green.
- [x] close_on_land.py Stop: the first LANDED closes the tab (`herdr-goal-done`), no 2-record / 3-compaction floor. Proof: test_first_land_in_fresh_tab closes.
- [x] settings.json: wire close_on_land.py under UserPromptSubmit. Proof: hook entry present; settings parse.
- [x] Dotfiles tests: agent-config/tests + herdr/tests. Proof: all pass.
- [x] Commit path-limited (only my hunks of settings.json), push. Proof: `git log origin/main -1`.
