#!/usr/bin/env python3
"""Stop hook: save the turn's closeout while it is still knowable.

Scraping the pane at ctrl+g time does not work. `herdr pane read` returns about
one viewport regardless of `--lines`, and by the moment the editor launches the
agent has redrawn the pane, so the closeout has usually scrolled out of reach.
The agent, however, knows exactly what it just printed -- so record it here, at
the end of the turn, and let the editor shim read a file instead of guessing.

Scoped to pane *and* session. Pane alone is not enough: pane ids are reused, so
a finished session leaves a file that the next agent in that pane reads as its
own. The session id makes the record unambiguous, the Stop hook drops the other
sessions' files for its pane, and SessionEnd removes its own on the way out.

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


PREFIX = "agent-prompt-turn-closeout"
# Scratch the ctrl+g shim writes beside the record, named per pane rather than
# per session. Cleared with the record so a dead session leaves nothing behind.
DERIVED = (
    "agent-prompt-seed.{}.txt",
    "agent-prompt-capture.{}.txt",
    "agent-prompt-closeout.{}.md",
    "agent-prompt-transcript.{}.md",
)


def slugify(value):
    return re.sub(r"[^A-Za-z0-9._-]", "_", value)


def temp_base():
    return Path(os.environ.get("TMPDIR") or tempfile.gettempdir())


def target_path(session):
    pane = os.environ.get("HERDR_PANE_ID")
    if not pane:
        return None
    session = slugify(session or "nosession")
    return temp_base() / f"{PREFIX}.{slugify(pane)}.{session}.md"


def prune(keep):
    """Drop every other record for this pane, and the pre-session filename.

    A pane hosts one live agent at a time, so any record here under another
    session id belongs to a session that has ended -- exactly the file that was
    being served to its successor.
    """
    pane = os.environ.get("HERDR_PANE_ID")
    if not pane:
        return
    base = temp_base()
    stale = list(base.glob(f"{PREFIX}.{slugify(pane)}.*.md"))
    stale.append(base / f"{PREFIX}.{slugify(pane)}.md")
    for path in stale:
        if path == keep:
            continue
        try:
            path.unlink()
        except OSError:
            pass


def cleanup(session):
    """SessionEnd: remove this session's record wherever it was written."""
    base = temp_base()
    paths = list(base.glob(f"{PREFIX}.*.{slugify(session)}.md")) if session else []
    pane = os.environ.get("HERDR_PANE_ID")
    if pane:
        paths.extend(base / name.format(slugify(pane)) for name in DERIVED)
    for path in paths:
        try:
            path.unlink()
        except OSError:
            pass
    return 0


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

    end = len(sys.argv) > 1 and sys.argv[1] == "--session-end"

    try:
        payload = json.load(sys.stdin)
    except ValueError:
        payload = {}

    session = payload.get("session_id") or os.environ.get("CLAUDE_CODE_SESSION_ID")

    if end:
        return cleanup(session)

    path = target_path(session)
    if not path:
        return 0

    # Even a turn that records nothing proves this pane now belongs to this
    # session, so the previous occupant's record goes either way.
    prune(path)

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
