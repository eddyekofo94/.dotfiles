# Focused Terminal Cursor Blink Closure

Status: DONE

- Ghostty's existing `cursor-style-blink = true` remains enabled.
- Herdr owns the 500 ms blink phase for the focused surface, including
  default, steady, and hidden hardware cursors used by TUIs such as Codex.
- Focus loss restores the application's steady/hidden state; background
  panes/windows do not keep blinking.
- Application cursor position and visual shape remain intact.
- Superseded Fish-specific blink configuration and coverage were removed.
- Focused Rust tests: PASS, 3 tests.
- Full Herdr and Fish verification: PASS.
- Fresh final review: Standards 0 / Fidelity 0.
- Installed and prototype binary digest:
  `1d844e9d354863878ee55b0190449db3585a76db3718651fda54801e4bcabf41`.
- Physical multi-window Ghostty acceptance: PASS, confirmed by Eddy on
  2026-08-01.
- Commit authorized after acceptance; push not authorized.
