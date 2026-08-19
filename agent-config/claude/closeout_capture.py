#!/usr/bin/env python3
"""Stop hook: save the turn's final message while it is still knowable.

Records the *whole* message, not only the closeout. The closeout names the
artifacts but not the questions the prompt has to answer -- the two device
checks, the file and line a QA row refers to, the option being chosen between
-- all of which sit in the body above `Status:`. Writing from ctrl+g with only
the closeout on screen meant re-reading the pane, which is exactly what this
record exists to avoid. A closeout is still what marks a turn as answerable,
so it remains the gate; it is no longer the cut.

Scraping the pane at ctrl+g time does not work. `herdr pane read` returns about
one viewport regardless of `--lines`, and by the moment the editor launches the
agent has redrawn the pane, so the closeout has usually scrolled out of reach.
The agent, however, knows exactly what it just printed -- so record it here, at
the end of the turn, and let the editor shim read a file instead of guessing.

Scoped to Herdr session, pane, *and* agent session. Pane alone is not enough
twice over: pane ids are reused, so a finished session leaves a file that the
next agent in that pane reads as its own; and pane ids are only unique within
one Herdr session, so two Ghostty windows both hold a `w1:p2` and share one
$TMPDIR. The Herdr session plus pane makes the place unambiguous, the agent
session id makes the record unambiguous, the Stop hook drops the other agents'
files for its place, and SessionEnd removes its own on the way out.

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
# Scratch the ctrl+g shim writes beside the record, named per place rather than
# per session. Cleared with the record so a dead session leaves nothing behind.
DERIVED = (
    "agent-prompt-seed.{}.txt",
    "agent-prompt-capture.{}.txt",
    "agent-prompt-closeout.{}.md",
    "agent-prompt-transcript.{}.md",
)


def slugify(value):
    # ASCII on purpose, matching `tr -c '[:alnum:]._-' '_'` in the shim; Herdr
    # sessions (`window-43`, `main`) and pane ids (`w1:p2`) never leave ASCII.
    return re.sub(r"[^A-Za-z0-9._-]", "_", value)


def pane_slug():
    pane = os.environ.get("HERDR_PANE_ID")
    return slugify(pane) if pane else None


def temp_base():
    return Path(os.environ.get("TMPDIR") or tempfile.gettempdir())


def place():
    """The pane's identity across every Herdr session on this machine.

    `HERDR_PANE_ID` (`w1:p2`) is only unique inside one Herdr session, and each
    independent Ghostty window is its own session (`window-43`, `window-44`...)
    while all of them share one $TMPDIR. Prefix the Herdr session so two windows
    at the same pane id never read or prune each other's record. Without a
    Herdr session the pane slug stands alone, so the shim -- which derives the
    same name from the same environment -- always agrees.
    """
    pane = pane_slug()
    if not pane:
        return None
    session = os.environ.get("HERDR_SESSION")
    if session:
        return f"{slugify(session)}.{pane}"
    return pane


def target_path(session):
    scope = place()
    if not scope:
        return None
    session = slugify(session or "nosession")
    return temp_base() / f"{PREFIX}.{scope}.{session}.md"


def prune(keep):
    """Drop every other record for this place, and the pre-scoping filenames.

    A pane hosts one live agent at a time, so any record here under another
    session id belongs to a session that has ended -- exactly the file that was
    being served to its successor. The pane-only names predate Herdr-session
    scoping; no Herdr pane writes them any more, so under a Herdr session they
    are always stale.
    """
    scope = place()
    if not scope:
        return
    base = temp_base()
    pane = pane_slug()
    stale = list(base.glob(f"{PREFIX}.{scope}.*.md"))
    if scope != pane:
        stale.extend(base.glob(f"{PREFIX}.{pane}.*.md"))
    stale.append(base / f"{PREFIX}.{pane}.md")
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
    scope = place()
    if scope:
        paths.extend(base / name.format(scope) for name in DERIVED)
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

    A named session is that session's transcript or nothing: a fresh session
    with no transcript yet must read as "no closeout", not as whichever Claude
    pane last wrote in this project -- which is exactly what the shim showed
    before it asked Herdr for the pane's session. The project-newest fallback
    survives only for the caller that cannot name the session at all.
    """
    root = Path.home() / ".claude" / "projects"
    if session_id:
        for candidate in root.glob(f"*/{session_id}.jsonl"):
            return candidate
        return None

    directory = project_dir(cwd)
    transcripts = sorted(
        directory.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True
    )
    return transcripts[0] if transcripts else None


def last_turn(path):
    """The newest assistant message that actually carries a closeout, whole.

    Not simply the newest message: the shim runs while the turn that triggered
    it is still being written, and tool-only turns carry no closeout either.
    Either would otherwise read as "nothing to show". The closeout decides
    *which* message this is; the text returned is all of it.
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
                found = text
    return found


def print_turn(session_id, cwd=None):
    path = find_transcript(session_id, cwd)
    if not path:
        if session_id:
            sys.stderr.write(f"no transcript for session {session_id}\n")
        else:
            sys.stderr.write(f"no transcript under {project_dir(cwd)}\n")
        return 1
    try:
        turn = last_turn(path)
    except OSError:
        return 1
    if not turn:
        return 1
    sys.stdout.write(turn.rstrip() + "\n")
    return 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--print":
        session = sys.argv[2] if len(sys.argv) > 2 else os.environ.get(
            "CLAUDE_CODE_SESSION_ID"
        )
        cwd = sys.argv[3] if len(sys.argv) > 3 else None
        return print_turn(session or None, cwd)

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
        # Verbatim agent output; keep it readable by its author.
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text.rstrip() + "\n")
    except OSError:
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
