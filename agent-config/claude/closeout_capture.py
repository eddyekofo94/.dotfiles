#!/usr/bin/env python3
"""Stop hook: save the turn's closeout while it is still knowable.

Scraping the pane at ctrl+g time does not work. `herdr pane read` returns about
one viewport regardless of `--lines`, and by the moment the editor launches the
agent has redrawn the pane, so the closeout has usually scrolled out of reach.
The agent, however, knows exactly what it just printed -- so record it here, at
the end of the turn, and let the editor shim read a file instead of guessing.

Pane-scoped, because two agents in two panes must never show each other's work.
Silent on anything unparseable: a broken transcript must not wedge a session.
"""

import json
import os
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from closeout_length import last_assistant_text, split_at_closeout  # noqa: E402


def target_path():
    pane = os.environ.get("HERDR_PANE_ID")
    if not pane:
        return None
    slug = re.sub(r"[^A-Za-z0-9._-]", "_", pane)
    base = Path(os.environ.get("TMPDIR") or tempfile.gettempdir())
    return base / f"agent-prompt-turn-closeout.{slug}.md"


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0

    path = target_path()
    if not path:
        return 0

    transcript = payload.get("transcript_path")
    if not transcript:
        return 0

    try:
        text = last_assistant_text(transcript)
    except OSError:
        return 0
    if not text:
        return 0

    _, closeout = split_at_closeout(text)
    if not closeout:
        # A turn with no closeout leaves the previous one in place rather than
        # replacing it with nothing: the last real closeout is still the one
        # the next prompt answers.
        return 0

    try:
        # The closeout is verbatim agent output; keep it readable by its author.
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write("\n".join(closeout).rstrip() + "\n")
    except OSError:
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
