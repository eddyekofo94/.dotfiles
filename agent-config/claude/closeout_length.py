#!/usr/bin/env python3
"""Stop hook: reject a turn whose final message busts the line budget.

Eddy's response contract caps the body at 15 lines before the closeout. Five
recorded violations show that instructions and memory notes do not hold, so the
budget is enforced here instead: an over-long turn is blocked once, with the
actual counts, and the model has to re-send a shorter one.

Blocks at most once per turn (`stop_hook_active` guards the loop), never twice
for the same message, and stays silent on anything it cannot parse -- a broken
transcript must never wedge a session.
"""

import json
import sys

BODY_MAX = 15  # lines before the closeout; Eddy's number, do not invent another
CLOSEOUT_MAX = 12  # Status..Next move (5) + prompt block (3-4) + fences
WIDTH = 100  # terminal columns; a paragraph costs what it costs to read
MAX_BLOCKS = 4  # consecutive rejections per turn before the hook gives up


CONTRACT = """
## Enforced Line Budget (mechanical, not advice)

A Stop hook measures every turn and rejects it when:
- the body (everything before `**Status**`) exceeds {body} lines
- the closeout (`**Status**` to the end) exceeds {closeout} lines

Lines are screen lines at {width} columns: a line of N characters costs
ceil(N / {width}). Blank lines are free. A paragraph is not one line.

Write the closeout from this skeleton, one line per label, no sub-bullets:

**Status:** DONE | PARTIAL | BLOCKED | AWAITING USER APPROVAL
Artifacts: paths, or none
Verification: what ran, and what did not
Risks: one line, or none
**Next move:** one action

**Ready-to-paste prompt:**
```
3-4 lines: the task, then the stop condition
```

A rejected turn is already on the user's screen; the hook cannot unprint it.
Fitting the budget on the first send is the only thing that works.
"""


def contract():
    """The budget, rendered from the same constants the check enforces.

    Injected every turn by `closeout.sh context`. Kept here, not in the prose
    contract, so the numbers the model is told can never drift from the numbers
    it is measured against.
    """
    return CONTRACT.format(body=BODY_MAX, closeout=CLOSEOUT_MAX, width=WIDTH)


def last_assistant_entry(path):
    """The final assistant text in the transcript, and the entry's uuid.

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


def last_assistant_text(path):
    """Just the text. `closeout_capture` imports this; keep it returning a str."""
    return last_assistant_entry(path)[1]


def split_at_closeout(text):
    """Body is everything before the Status line; the rest is the closeout."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.lstrip().startswith(("**Status:**", "**Status**", "Status:")):
            return lines[:index], lines[index:]
    return lines, []


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
        uuid, text = last_assistant_entry(transcript)
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
    closeout_lines = count(closeout)

    problems = []
    if body_lines > BODY_MAX:
        problems.append(f"body is {body_lines} lines, cap is {BODY_MAX}")
    if closeout_lines > CLOSEOUT_MAX:
        problems.append(
            f"closeout is {closeout_lines} lines, cap is {CLOSEOUT_MAX}"
        )
    if not problems:
        record(transcript, 0, "")
        return 0
    record(transcript, blocked + 1, uuid)

    reason = (
        "Response rejected: " + "; ".join(problems) + ". "
        "Re-send the same facts inside the budget. Cut, do not summarize: "
        "one line per section, no sub-bullets, no per-commit or per-file "
        "enumeration (that is what git log and the diff are for), no "
        "restating reasoning already written to a file. Ready-to-paste "
        "prompt: 3-4 lines, task plus stop condition only. Do not add a "
        "note about having been too long."
    )
    json.dump({"decision": "block", "reason": reason}, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
