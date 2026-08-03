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


def project_dir(cwd=None):
    """Claude's per-project transcript directory for a working directory.

    The slug is the absolute path with every non-alphanumeric run replaced by a
    dash, e.g. /Users/x/.dotfiles -> -Users-x--dotfiles.
    """
    path = Path(cwd or os.getcwd()).resolve()
    slug = re.sub(r"[^A-Za-z0-9]", "-", str(path))
    return Path.home() / ".claude" / "projects" / slug


def find_transcript(session_id, cwd=None):
    """Locate the transcript to read the closeout from.

    Prefers the exact session. Falls back to the project's most recently
    written transcript, because the editor is not always launched from a
    process that inherited the agent's environment -- ctrl+g can land in a
    pane with no CLAUDE_CODE_SESSION_ID at all, and keying only on the id
    makes the feature silently unavailable there.
    """
    root = Path.home() / ".claude" / "projects"
    if session_id:
        for candidate in root.glob(f"*/{session_id}.jsonl"):
            return candidate

    directory = project_dir(cwd)
    transcripts = sorted(
        directory.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True
    )
    return transcripts[0] if transcripts else None


def last_closeout(path):
    """The newest assistant message that actually carries a closeout.

    Not simply the newest message: the shim runs while the turn that triggered
    it is still being written, and tool-only turns carry no closeout either.
    Either would otherwise read as "nothing to show".
    """
    found = None
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if entry.get("type") != "assistant":
                continue
            content = entry.get("message", {}).get("content")
            if not isinstance(content, list):
                continue
            text = "".join(
                block.get("text", "")
                for block in content
                if isinstance(block, dict) and block.get("type") == "text"
            ).strip()
            if not text:
                continue
            _, closeout = split_at_closeout(text)
            if closeout:
                found = closeout
    return found


def print_closeout(session_id, cwd=None):
    path = find_transcript(session_id, cwd)
    if not path:
        sys.stderr.write(f"no transcript under {project_dir(cwd)}\n")
        return 1
    try:
        closeout = last_closeout(path)
    except OSError:
        return 1
    if not closeout:
        return 1
    sys.stdout.write("\n".join(closeout).rstrip() + "\n")
    return 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--print":
        session = sys.argv[2] if len(sys.argv) > 2 else os.environ.get(
            "CLAUDE_CODE_SESSION_ID"
        )
        cwd = sys.argv[3] if len(sys.argv) > 3 else None
        return print_closeout(session or None, cwd)

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
