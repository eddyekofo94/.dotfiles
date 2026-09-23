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
import sys

BODY_MAX = 60  # runaway backstop, not a budget; Eddy's number
WIDTH = 100  # terminal columns; a paragraph costs what it costs to read
MAX_BLOCKS = 4  # consecutive rejections per turn before the hook gives up


CONTRACT = """
## Enforced Closeout (mechanical, not advice)

Length follows the Response Style rules: precise, plain, only what the reader
needs. A Stop hook rejects a turn when:
- the closeout below is missing, or the fenced prompt is not the last thing
- the body (everything before `**Status**`) exceeds {body} screen lines, a
  runaway backstop -- not a target ({width} columns per line, blanks free)

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


def split_at_closeout(text):
    """Body is everything before the Status line; the rest is the closeout."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.lstrip().startswith(("**Status:**", "**Status**", "Status:")):
            return lines[:index], lines[index:]
    return lines, []


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

    problems = shape_problems(closeout)
    if body_lines > BODY_MAX:
        problems.append(f"body is {body_lines} lines, backstop is {BODY_MAX}")
    if not problems:
        record(transcript, 0, "")
        return 0
    record(transcript, blocked + 1, uuid)

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
