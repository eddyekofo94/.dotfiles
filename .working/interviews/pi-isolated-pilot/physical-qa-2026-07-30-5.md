# Pi physical QA — 2026-07-30, pass 5

## User-confirmed PASS

Eddy confirmed every physical Ghostty/Herdr item in `pi/MANUAL_QA.md` except
the two ready-prompt replay bindings:

- independent physical windows/sessions and recovery;
- interactive prompt history and branch-local recall;
- `/reload` stability and recent-command ordering;
- Catppuccin, `❯`, stable-color blinking bar/block cursor, and unfocused
  outline;
- FFF fuzzy mention picker and navigation;
- `/resume`, `/tree`, Ctrl-P/Ctrl-N, Ctrl-Shift-M, and ordinary Enter;
- delayed Ctrl-L redraw with unsent text, footer, and conversation preserved;
- cross-session agent overview/read/message/focus behavior;
- normal macOS paste.

## Replay result

- **PASS — `Prefix+b`:** the latest labeled multiline handoff was inserted into
  the current Pi editor without submission.
- **PASS — `Prefix+B`:** a distinct persisted Pi session was created, the prior
  session remained resumable, and the handoff was inserted without submission.

Eddy confirmed both replay paths work well. All applicable physical interaction
items are accepted.
