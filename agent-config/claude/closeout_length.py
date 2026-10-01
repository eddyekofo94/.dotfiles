#!/usr/bin/env python3
"""Stop hook: reject a turn that breaks the closeout shape or runs away.

Eddy's response contract ends every turn with the closeout, and the fenced
ready-to-paste prompt last on screen -- `prefix+b` pastes that block, so a turn
without it breaks the workflow. Instructions alone did not hold, so the shape
is enforced here. Length is judged by the Response Style rules, not a tight
cap; only a runaway body past the backstop is rejected.

Blocks at most once per turn (`stop_hook_active` guards the loop), never twice
for the same message, and stays silent on anything it cannot parse -- a broken
transcript must never wedge a session.
"""

import json
import re
from datetime import datetime, timezone
import sys
import time

BODY_MAX = 60  # runaway backstop, not a budget; Eddy's number
WIDTH = 100  # terminal columns; a paragraph costs what it costs to read
MAX_BLOCKS = 4  # consecutive rejections per turn before the hook gives up
REREAD_SECONDS = 1.0  # how long to wait for a reply not yet in the transcript
REREAD_STEP = 0.1


CONTRACT = """
## Enforced Closeout (mechanical, not advice)

Length follows the Response Style rules: precise, plain, only what the reader
needs. A Stop hook rejects a turn when:
- the closeout below is missing, or the fenced prompt is not the last thing
- the body (everything before `**Status**`) exceeds {body} screen lines, a
  runaway backstop -- not a target ({width} columns per line, blanks free)

Write the closeout from this skeleton: Picked / gave up / why in 2-3 lines,
every other label one line, no sub-bullets:

**Status:** DONE | PARTIAL | BLOCKED | AWAITING USER APPROVAL
Picked / gave up / why: 2-3 lines
Not run: each check that did not run, or "nothing"
**Next move:** one action

**Ready-to-paste prompt:**
```
3-4 lines: the task, then the stop condition
```

A turn that ends while its own background job (a Bash `run_in_background`
command or a background agent) still runs is not a handoff: the job's exit
re-invokes the session. It ends with one line and no prompt block:

**Status:** WAITING — <the job>; resumes when it exits, nothing to paste

The hook rejects WAITING when this session has no background job pending, and
rejects a prompt block under it.

A rejected turn is already on the user's screen; the hook cannot unprint it.
Getting it right on the first send is the only thing that works.
"""


def contract():
    """The budget, rendered from the same constants the check enforces.

    Injected every turn by `closeout.sh context`. Kept here, not in the prose
    contract, so the numbers the model is told can never drift from the numbers
    it is measured against.
    """
    return CONTRACT.format(body=BODY_MAX, width=WIDTH)


def blocks_of(entry, kind):
    content = entry.get("message", {}).get("content")
    if not isinstance(content, list):
        return []
    return [
        block
        for block in content
        if isinstance(block, dict) and block.get("type") == kind
    ]


def last_assistant_entry(path):
    """The final reply in the transcript, and the entry's uuid.

    Only text after the last tool call counts. Progress text written partway
    through a turn ("running the tests now") precedes a tool call and is not the
    reply the closeout belongs to; measuring it rejected turns that ended fine.
    A tool call or tool result therefore clears whatever text came before it,
    and a turn whose reply has not reached the transcript yet reads as no text.

    The uuid is what makes a stale read detectable. The transcript is written
    asynchronously, so at Stop time this can still return the *previous* turn's
    message; without an identity to compare, that read is indistinguishable from
    a re-send that ignored the budget.
    """
    uuid = ""
    text = None
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if not isinstance(entry, dict):
                continue
            if blocks_of(entry, "tool_use") or blocks_of(entry, "tool_result"):
                uuid, text = "", None
                continue
            if entry.get("type") != "assistant":
                continue
            content = entry.get("message", {}).get("content")
            if not isinstance(content, list):
                continue
            parts = [
                block.get("text", "")
                for block in content
                if isinstance(block, dict) and block.get("type") == "text"
            ]
            joined = "".join(parts).strip()
            if joined:
                uuid = entry.get("uuid") or ""
                text = joined
    return uuid, text


def settled_reply(path):
    """The final reply, re-read briefly when it has not reached the transcript.

    Headless sessions run Stop before the reply is written, so the first read
    finds only the tool result and the turn passed unmeasured. Waiting is
    bounded well inside the hook timeout; a reply that never lands still passes.
    """
    uuid, text = last_assistant_entry(path)
    deadline = time.monotonic() + REREAD_SECONDS
    while not text and time.monotonic() < deadline:
        time.sleep(REREAD_STEP)
        uuid, text = last_assistant_entry(path)
    return uuid, text


def split_at_closeout(text):
    """Body is everything before the last Status line; the rest is the closeout.

    The last, not the first: a body may quote a Status line (skill-finish shows
    `**Status:** WAITING …` as an example), and the closeout is what ends the
    message.
    """
    lines = text.splitlines()
    for index in range(len(lines) - 1, -1, -1):
        if lines[index].lstrip().startswith(("**Status:**", "**Status**", "Status:")):
            return lines[:index], lines[index:]
    return lines, []


WAITING_RE = re.compile(r"^\s*\*\*Status:?\*\*:?\s*WAITING\b(.*)$")

# Claude Code's own wording for a job it will report back on. A launch is the
# *result* of a Bash or Agent call, and the wording opens that result: a
# background Bash command answers "Command running in background with ID: <id>"
# (or "... moved to the background (ID: <id>)" when its foreground timeout ran
# out); an async agent answers "Async agent launched successfully ... agentId:
# <id>". Anchoring on a line start of a Bash or Agent result (Claude Code may
# put a "Shell cwd was reset" line first) keeps a `cat` or `grep` that merely
# quotes those words, mid-line in a Read or a file dump, from counting as a job. The end arrives in several
# entry shapes (a queue operation, a queued-command attachment, a user turn), so
# it is matched on the raw line: a `<task-notification>` naming `<task-id>` and
# a final `<status>`, or the agent's hand-back message.
LAUNCHED_RE = re.compile(
    r"^Command running in background with ID: (\w+)"
    r"|^Command did not complete[^\n]*moved to the background \(ID: (\w+)\)"
    r"|^Async agent launched successfully\.[\s\S]{0,400}?agentId: (\w+)",
    re.M,
)
FINISHED_RE = re.compile(
    r"<task-id>(\w+)</task-id>.{0,2000}?<status>(?!running)\w+</status>"
    r"|agent-message from=\\*\"(\w+)"
)
JOB_TOOLS = ("Bash", "Agent", "Task")
CLEAR_MARK = "<command-name>/clear</command-name>"
#: The longest a background Bash job may run (Claude Code's `timeout` cap).
JOB_LIFETIME_SECONDS = 2 * 60 * 60


def recent_clear(line):
    """A user `/clear` entry from within one job lifetime of now."""
    try:
        entry = json.loads(line)
        content = entry.get("message", {}).get("content")
        if not (isinstance(content, str) and content.lstrip().startswith(CLEAR_MARK)):
            return False
        stamp = datetime.fromisoformat(entry["timestamp"].replace("Z", "+00:00"))
    except (ValueError, KeyError, TypeError, AttributeError):
        return False
    return (datetime.now(timezone.utc) - stamp).total_seconds() < JOB_LIFETIME_SECONDS


def result_text(block):
    """A tool result's text, whether its content is a string or text blocks."""
    content = block.get("content", "")
    if isinstance(content, list):
        content = "".join(
            part.get("text", "") for part in content if isinstance(part, dict)
        )
    return content if isinstance(content, str) else ""


def waiting_status(closeout):
    """The text after `WAITING` on the Status line, or None for any other status."""
    match = WAITING_RE.match(closeout[0]) if closeout else None
    return match.group(1) if match else None


def pending_jobs(path):
    """IDs of the background jobs this transcript launched and never heard end.

    A WAITING turn is only honest while one of these runs: its exit is what
    re-invokes the session. None when it cannot tell -- an unreadable
    transcript, or a `/clear` since which earlier jobs may still run -- and the
    caller lets that through.
    """
    calls, launched, finished, cleared = set(), [], set(), False
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                # Jobs outlive `/clear` and report into the new session, which
                # never saw them launch: for as long as one of them could still
                # run, an empty list proves nothing.
                if '"type":"user"' in line and CLEAR_MARK in line:
                    cleared = cleared or recent_clear(line)
                for match in FINISHED_RE.finditer(line):
                    finished.add(next(g for g in match.groups() if g))
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(entry, dict):
                    continue
                for block in blocks_of(entry, "tool_use"):
                    if block.get("name") in JOB_TOOLS:
                        calls.add(block.get("id"))
                for block in blocks_of(entry, "tool_result"):
                    if block.get("tool_use_id") not in calls:
                        continue
                    match = LAUNCHED_RE.search(result_text(block))
                    if match:
                        launched.append(next(g for g in match.groups() if g))
    except OSError:
        return None
    pending = [job for job in launched if job not in finished]
    return None if cleared and not pending else pending


def waiting_problems(closeout, reason, path):
    """WAITING drops the prompt block, so it has to be true.

    A tab that ends a turn with a paste prompt while its own gate runs reads
    as stopped, and Eddy pastes into it (BUG-348). WAITING says the opposite --
    do nothing -- so it is refused when no job of this session is pending, and
    a prompt block under it is refused too: `prefix+b` would paste a resume
    into a session that is about to resume itself.
    """
    problems = []
    if not reason.strip(" -—:"):
        problems.append("WAITING does not name the job it waits on")
    if any("Ready-to-paste prompt" in line or line.lstrip().startswith("```")
           for line in closeout):
        problems.append("WAITING carries a ready-to-paste prompt; drop it")
    if pending_jobs(path) == []:
        problems.append(
            "WAITING with no background job pending in this session; start the "
            "wait as a background job, or end with the normal closeout"
        )
    return problems


def shape_problems(closeout):
    """What the closeout is missing, in the order the skeleton lists it.

    The prompt block must close the message: anything after the final fence
    is what `prefix+b` would miss.
    """
    if not closeout:
        return ["no closeout (`**Status:**` line not found)"]
    problems = []
    joined = "\n".join(closeout)
    if "**Next move:**" not in joined:
        problems.append("no `**Next move:**` line")
    labels = [
        index
        for index, line in enumerate(closeout)
        if "Ready-to-paste prompt" in line
    ]
    if not labels:
        return problems + ["no `**Ready-to-paste prompt:**` block"]
    rest = [line.strip() for line in closeout[labels[-1] + 1 :] if line.strip()]
    fences = [index for index, line in enumerate(rest) if line.startswith("```")]
    if len(fences) < 2 or fences[-1] != len(rest) - 1:
        problems.append("the fenced prompt is not the last thing in the message")
    return problems


def count(lines):
    """Cost in screen lines, not newlines.

    Counting newlines was the loophole every recorded violation used: a
    400-character paragraph is one source line and eight lines of terminal.
    Blank lines stay free -- they cost no reading, only the facts do.
    """
    total = 0
    for line in lines:
        stripped = line.strip()
        if stripped:
            total += -(-len(stripped) // WIDTH)
    return total


def load_state(path):
    """Consecutive rejections for the current turn, and the message they hit.

    Kept in a sidecar file keyed to the transcript, since the payload carries
    only a boolean. A file left by an older version holds a bare count and names
    no message, which reads as "nothing has been blocked yet" -- the safe way to
    be wrong, because it costs one honest measurement rather than a false one.
    """
    try:
        with open(state_path(path), encoding="utf-8") as handle:
            state = json.loads(handle.read() or "{}")
    except (OSError, ValueError):
        return 0, ""
    if not isinstance(state, dict):
        return 0, ""
    try:
        return int(state.get("blocks", 0)), str(state.get("uuid", "") or "")
    except (TypeError, ValueError):
        return 0, ""


def state_path(path):
    return path + ".closeout-blocks"


def record(path, blocked, uuid):
    try:
        with open(state_path(path), "w", encoding="utf-8") as handle:
            json.dump({"blocks": blocked, "uuid": uuid}, handle)
    except OSError:
        pass


def main():
    if "--contract" in sys.argv[1:]:
        sys.stdout.write(contract())
        return 0

    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0

    transcript = payload.get("transcript_path")
    if not transcript:
        return 0

    blocked, blocked_uuid = load_state(transcript)

    # A false `stop_hook_active` is the start of a fresh turn, so the budget
    # starts fresh too. Without this the count is a lifetime total: four
    # over-long turns in a row spend it, and from then on every re-send passes
    # unmeasured. The uuid survives -- it is the stale-read guard below, and a
    # new turn is exactly when the transcript is most likely to be behind.
    if not payload.get("stop_hook_active"):
        blocked = 0

    # Deliberately not `return 0` on stop_hook_active. Bailing there was the
    # hole: the first over-long turn was blocked and the re-send -- which was
    # usually still over -- went straight through unchecked. Consecutive blocks
    # are bounded instead, so a model that cannot get under the budget cannot
    # wedge the session either.
    if payload.get("stop_hook_active") and blocked >= MAX_BLOCKS:
        return 0

    try:
        uuid, text = settled_reply(transcript)
    except OSError:
        return 0
    if not text:
        return 0

    # Never reject the same message twice. Seeing the one already blocked means
    # the re-send has not reached the transcript yet, so measuring again would
    # quote the rejected turn's own counts back at a reply that already fixed
    # them -- a loop no amount of cutting can clear. Observed: an 11-line and
    # then a 10-line closeout both rejected as "14 lines". Letting an unseen
    # re-send through is the lesser failure, and MAX_BLOCKS already concedes it.
    if uuid and uuid == blocked_uuid:
        return 0

    body, closeout = split_at_closeout(text)
    body_lines = count(body)

    waiting = waiting_status(closeout)
    if waiting is None:
        problems = shape_problems(closeout)
    else:
        problems = waiting_problems(closeout, waiting, transcript)
    if body_lines > BODY_MAX:
        problems.append(f"body is {body_lines} lines, backstop is {BODY_MAX}")
    if not problems:
        record(transcript, 0, "")
        return 0
    record(transcript, blocked + 1, uuid)

    if waiting is not None:
        json.dump({"decision": "block", "reason": (
            "Response rejected: " + "; ".join(problems) + ". Re-send with "
            "`**Status:** WAITING — <the job>; resumes when it exits, nothing to "
            "paste` and no prompt block if a job of yours is still running; "
            "otherwise end with the normal closeout skeleton. Do not add a note "
            "about the rejection."
        )}, sys.stdout)
        return 0
    reason = (
        "Response rejected: " + "; ".join(problems) + ". "
        "Re-send the same facts with the closeout skeleton intact and the "
        "fenced ready-to-paste prompt last. If the body ran away, cut it: no "
        "per-commit or per-file enumeration, no restating reasoning already "
        "written to a file. Do not add a note about the rejection."
    )
    json.dump({"decision": "block", "reason": reason}, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
