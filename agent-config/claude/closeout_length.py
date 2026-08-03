#!/usr/bin/env python3
"""Stop hook: reject a turn whose final message busts the line budget.

Eddy's response contract caps the body at 15 lines before the closeout. Five
recorded violations show that instructions and memory notes do not hold, so the
budget is enforced here instead: an over-long turn is blocked once, with the
actual counts, and the model has to re-send a shorter one.

Blocks at most once per turn (`stop_hook_active` guards the loop), and stays
silent on anything it cannot parse -- a broken transcript must never wedge a
session.
"""

import json
import sys

BODY_MAX = 15  # lines before the closeout; Eddy's number, do not invent another
CLOSEOUT_MAX = 12  # Status..Next move (5) + prompt block (3-4) + fences


def last_assistant_text(path):
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
                text = joined
    return text


def split_at_closeout(text):
    """Body is everything before the Status line; the rest is the closeout."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.lstrip().startswith(("**Status:**", "**Status**", "Status:")):
            return lines[:index], lines[index:]
    return lines, []


def count(lines):
    """Blank lines are free: they cost no reading, only the facts do."""
    return sum(1 for line in lines if line.strip())


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0

    if payload.get("stop_hook_active"):
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
        return 0

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
