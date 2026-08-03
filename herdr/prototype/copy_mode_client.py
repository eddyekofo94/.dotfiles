#!/usr/bin/env python3
"""Copy-mode-specific actions layered onto the shared disposable PTY client."""

from __future__ import annotations

import os

import picker_client


for inherited_multiplexer_marker in (
    "TMUX",
    "HERDR_ENV",
    "HERDR_PANE_ID",
    "HERDR_SESSION",
    "HERDR_SOCKET_PATH",
    "HERDR_WORKSPACE_ID",
    "HERDR_TAB_ID",
    "HERDR_TARGET_PANE_ID",
    "HERDR_STARTUP_CWD",
):
    os.environ.pop(inherited_multiplexer_marker, None)


picker_client.KEYS.update(
    {
        "copy-up": b"k",
        "copy-select": b"v",
        "copy-exit-a": b"a",
        "copy-exit-i": b"i",
        "copy-line-yank": b"Y",
        # Alt chords arrive as ESC + the character, which is how Ghostty sends
        # them and how Herdr's native bindings see them.
        "copy-mode-alt": b"\x1b/",
        "copy-search-alt": b"\x1bb",
        "copy-count-2": b"2",
        "copy-esc": b"\x1b",
        "copy-center": b"zz",
    }
)


if __name__ == "__main__":
    raise SystemExit(picker_client.main())
