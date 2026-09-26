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

The transcript is written asynchronously, so the newest closeout on disk at
Stop time can still be the *previous* turn's -- and ctrl+g then opens with the
turn before the one that just finished. Every record carries the transcript
timestamp of the message it holds, and the hook waits for a closeout newer than
that stamp before it writes. Bounded: a turn that genuinely carries no closeout
gives up after the wait and leaves the last real record in place, which is what
a closeout-less turn does anyway.

`/clear` is the one end that hands over. It wipes the screen prefix+b reads,
but not the pane's work, so SessionEnd moves the record to a `cleared` slot that
prefix+b falls back to until the next session writes a closeout of its own.

Silent on anything unparseable: a broken transcript must not wedge a session.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from closeout_length import split_at_closeout  # noqa: E402


PREFIX = "agent-prompt-turn-closeout"
# Sidecar holding the transcript timestamp of the message the record came from.
# Deliberately not `.md`: the shim picks the newest `PREFIX.<place>.*.md` when
# nobody can name the session, and a stamp must never be a candidate closeout.
STAMP = ".stamp"
# The slot a record moves to when `/clear` ends its session. The successor's
# session id is unknown until its first turn, so the record cannot be renamed
# to it; prefix+b reads this slot instead (`--pane-record`).
CARRY = "cleared"
# How long Stop waits for the turn's own message to reach the transcript. Kept
# well under the hook's 10s timeout: guessing wrong costs one stale ctrl+g,
# hanging costs every turn. Overridable so the test does not sleep for real.
CAPTURE_WAIT = 3.0
POLL = 0.05
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


# One file per running Claude Code process naming the session it hosts now. The
# ctrl+g shim is a descendant of that same process, so it finds its agent by
# walking its own ancestry -- no pane id, tab, window or Herdr session involved.
# Those name where the agent *was* launched; a resumed, moved or handed-off
# agent keeps its process and loses its place.
AGENT = "agent-prompt-agent"


def agent_pid():
    """The Claude Code process this hook runs under, or None outside one."""
    pid = os.getppid()
    for _ in range(12):
        if pid <= 1:
            return None
        try:
            out = subprocess.run(
                ["ps", "-o", "ppid=,comm=", "-p", str(pid)],
                capture_output=True,
                text=True,
                timeout=2,
            ).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            return None
        if not out:
            return None
        ppid, _, comm = out.partition(" ")
        if os.path.basename(comm.strip()) == "claude":
            return pid
        try:
            pid = int(ppid)
        except ValueError:
            return None
    return None


def agent_path(pid=None):
    pid = pid or agent_pid()
    return temp_base() / f"{AGENT}.{pid}" if pid else None


def claim_agent(session):
    """Point this Claude process at `session`, the one that just ran a turn."""
    path = agent_path()
    if not path or not session:
        return
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(session + "\n")
    except OSError:
        pass


def target_path(session):
    scope = place()
    if not scope:
        return None
    session = slugify(session or "nosession")
    return temp_base() / f"{PREFIX}.{scope}.{session}.md"


def carry_path():
    """Where `/clear` leaves this place's last closeout for its successor."""
    scope = place()
    return temp_base() / f"{PREFIX}.{scope}.{CARRY}.md" if scope else None


def stamp_path(record):
    """The sidecar beside a record, holding the timestamp it was taken from."""
    return record.with_suffix(STAMP) if record else None


def read_stamp(path):
    """The timestamp of the message already recorded, or empty when unknown.

    Empty means "nothing to be stale against" -- a first turn, a record from
    before stamping, or a transcript whose entries carry no timestamp -- and the
    hook then writes whatever it reads, exactly as it did before.
    """
    if not path:
        return ""
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def prune(keep):
    """Drop every other record for this place, and the pre-scoping filenames.

    A pane hosts one live agent at a time, so any record here under another
    session id belongs to a session that has ended -- exactly the file that was
    being served to its successor. The pane-only names predate Herdr-session
    scoping; no Herdr pane writes them any more, so under a Herdr session they
    are always stale. A stamp outlives its record for nobody, so it goes too.
    Callers keep the `/clear` carry; it goes once the session has its own record.
    """
    scope = place()
    if not scope:
        return
    base = temp_base()
    pane = pane_slug()
    stale = []
    for suffix in ("md", STAMP.lstrip(".")):
        stale.extend(base.glob(f"{PREFIX}.{scope}.*.{suffix}"))
        if scope != pane:
            stale.extend(base.glob(f"{PREFIX}.{pane}.*.{suffix}"))
    stale.append(base / f"{PREFIX}.{pane}.md")
    keep = {path for path in keep if path}
    for path in stale:
        if path in keep:
            continue
        try:
            path.unlink()
        except OSError:
            pass


def cleanup(session, reason=None):
    """SessionEnd: remove this session's record wherever it was written.

    `/clear` moves this place's record to the carry slot instead, so prefix+b
    can still replay it. A second `/clear` with no record of its own keeps the
    carry. Any other end drops the carry too: the pane's next occupant must
    never inherit it.
    """
    base = temp_base()
    carry = carry_path()
    if reason == "clear" and session and carry:
        record = target_path(session)
        if record.exists():
            try:
                record.replace(carry)
            except OSError:
                pass
    paths = []
    if session:
        for suffix in ("md", STAMP.lstrip(".")):
            paths.extend(base.glob(f"{PREFIX}.*.{slugify(session)}.{suffix}"))
    scope = place()
    if scope:
        paths.extend(base / name.format(scope) for name in DERIVED)
    if carry and reason != "clear":
        paths.append(carry)
    if reason != "clear":
        # The process is exiting; `/clear` keeps it, and its next turn re-points.
        pointer = agent_path()
        if pointer:
            paths.append(pointer)
    for path in paths:
        try:
            path.unlink()
        except OSError:
            pass
    return 0


def modified(path):
    try:
        return path.stat().st_mtime
    except OSError:
        return 0


def record_bases():
    """Every temp dir a pane's Stop hook may have written its record to.

    The hook writes under the pane's own $TMPDIR, but prefix+b runs in the Herdr
    client, whose $TMPDIR can differ. On 2026-09-15 window-81's panes had none
    (so /tmp) while its client had /var/folders/.../T/, and the fallback looked
    in the wrong place. Search this process's dir, /tmp, and macOS's per-user
    temp dir.
    """
    bases = [temp_base(), Path("/tmp")]
    try:
        darwin = subprocess.run(
            ["getconf", "DARWIN_USER_TEMP_DIR"],
            capture_output=True,
            text=True,
            timeout=2,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        darwin = ""
    if darwin:
        bases.append(Path(darwin))
    unique = []
    for base in bases:
        try:
            resolved = base.resolve()
        except OSError:
            continue
        if resolved not in unique:
            unique.append(resolved)
    return unique


def pane_record(session):
    """prefix+b's fallback when the screen holds no handoff.

    The live session's own record first, then what `/clear` carried over from
    the session before it, each looked for in every temp dir the pane may use.
    Unnamed, the newest record for this place, as the ctrl+g shim does.
    """
    scope = place()
    if not scope:
        return None
    bases = record_bases()
    pane = pane_slug()
    if session:
        name = slugify(session)
        candidates = [base / f"{PREFIX}.{scope}.{name}.md" for base in bases]
        # A session id is unique, so its record is its own under any Herdr
        # session; the keybinding environment may not name one.
        candidates += sorted(
            {path for base in bases for path in base.glob(f"{PREFIX}.*.{pane}.{name}.md")}
        )
        candidates += [base / f"{PREFIX}.{scope}.{CARRY}.md" for base in bases]
        if not os.environ.get("HERDR_SESSION"):
            # Every window has a w1:p2, so a carry found without the Herdr
            # session is this pane's only when it is the only one.
            carries = {
                path for base in bases for path in base.glob(f"{PREFIX}.*.{pane}.{CARRY}.md")
            }
            if len(carries) == 1:
                candidates += list(carries)
    else:
        candidates = sorted(
            (path for base in bases for path in base.glob(f"{PREFIX}.{scope}.*.md")),
            key=modified,
            reverse=True,
        )
    for path in candidates:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if text.strip():
            return text
    return None


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


def last_closeout(path):
    """The newest assistant message carrying a closeout, whole, and its stamp.

    Not simply the newest message: the shim runs while the turn that triggered
    it is still being written, and tool-only turns carry no closeout either.
    Either would otherwise read as "nothing to show". The closeout decides
    *which* message this is; the text returned is all of it.

    The stamp is the entry's transcript timestamp -- Claude Code writes ISO-8601
    UTC (`2026-08-20T09:14:02.117Z`), which orders correctly as a plain string.
    Empty when the entry carries none, meaning "cannot tell how old this is".
    """
    found = None
    stamp = ""
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
                stamp = entry.get("timestamp") or ""
    return stamp, found


def last_turn(path):
    """Just the text. The ctrl+g `--print` path has no stamp to compare."""
    return last_closeout(path)[1]


def wait_seconds():
    try:
        value = float(os.environ.get("CLOSEOUT_CAPTURE_WAIT") or CAPTURE_WAIT)
    except ValueError:
        return CAPTURE_WAIT
    return max(0.0, value)


def await_closeout(transcript, previous):
    """A closeout newer than the one already recorded, or nothing.

    Reading once is what made ctrl+g one turn stale: Stop fires before the
    turn's own message has necessarily reached the transcript, so the newest
    closeout on disk is still the previous turn's, and the record is rewritten
    with the same text it already held. Poll instead, until a closeout with a
    later timestamp appears or the wait runs out.

    Giving up returns nothing, which leaves the last real record in place --
    the same outcome as a turn that carries no closeout at all, and the right
    one: an older closeout is never a better answer than the previous turn's.
    """
    deadline = time.monotonic() + wait_seconds()
    while True:
        try:
            stamp, text = last_closeout(transcript)
        except OSError:
            return "", None
        # No stamp on either side means nothing to compare: take the read, as
        # the hook did before stamps existed.
        if text and (not previous or not stamp or stamp > previous):
            return stamp, text
        if time.monotonic() >= deadline:
            return "", None
        time.sleep(POLL)


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

    if len(sys.argv) > 1 and sys.argv[1] == "--pane-record":
        text = pane_record(sys.argv[2] if len(sys.argv) > 2 else None)
        if not text:
            return 1
        sys.stdout.write(text.rstrip() + "\n")
        return 0

    end = len(sys.argv) > 1 and sys.argv[1] == "--session-end"

    try:
        payload = json.load(sys.stdin)
    except ValueError:
        payload = {}

    session = payload.get("session_id") or os.environ.get("CLAUDE_CODE_SESSION_ID")

    if end:
        reason = payload.get("reason") if isinstance(payload, dict) else None
        return cleanup(session, reason)

    claim_agent(session)

    path = target_path(session)
    if not path:
        return 0
    stamp_file = stamp_path(path)

    # Even a turn that records nothing proves this pane now belongs to this
    # session, so the previous occupant's record goes either way.
    prune((path, stamp_file, carry_path()))

    transcript = payload.get("transcript_path")
    if not transcript:
        return 0

    # A turn with no closeout of its own -- and a wait that ends before this
    # turn's message lands -- leaves the previous record alone rather than
    # replacing it with nothing or with itself: the last real closeout is still
    # the one the next prompt answers.
    stamp, text = await_closeout(transcript, read_stamp(stamp_file))
    if not text:
        return 0

    try:
        # Verbatim agent output; keep it readable by its author.
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text.rstrip() + "\n")
        # Written after the record, and always -- an empty stamp says "unknown",
        # which is the honest state for a transcript that carries no timestamps.
        # A stamp left over from an older record would block every later turn.
        fd = os.open(stamp_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(stamp + "\n")
    except OSError:
        return 0

    # This session has a closeout of its own now; the carried one is answered.
    try:
        carry_path().unlink()
    except OSError:
        pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
