#!/usr/bin/env python3
"""Stop hook: a tab that has landed work retires itself (retro 2026-11-05).

Session 6b31c6a5 ran 15 hours, landed 8 records and compacted 21 times in one
tab, $110 of a $656 window: each record paid cache reads on a context of ~86k
where a fresh tab starts at ~25k. When a turn's tool output printed
`LANDED <sha>` and the tab has landed more than one record or compacted 3+
times, run `herdr-goal-done` (the lesson's own close; `--tab <id>` if that
refuses because the checkout is gone). It ends the session, so it runs
detached, once per session. Only tool results count as LANDED: a message that
quotes the word does not. Any error exits 0 silently.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

LANDED = re.compile(r"^LANDED ([0-9a-f]{7,40})\b", re.M)
MIN_RECORDS = 2
MIN_COMPACTIONS = 3


def result_text(event: dict) -> str:
    content = event.get("message", {}).get("content")
    if not isinstance(content, list):
        return ""
    out = []
    for block in content:
        if block.get("type") == "tool_result":
            body = block.get("content")
            out.append(body if isinstance(body, str) else
                       " ".join(b.get("text", "") for b in body or [] if isinstance(b, dict)))
    return "\n".join(out)


def is_prompt(event: dict) -> bool:
    if event.get("type") != "user":
        return False
    content = event.get("message", {}).get("content")
    return isinstance(content, str) or (
        isinstance(content, list) and not any(b.get("type") == "tool_result" for b in content))


def read(transcript: str) -> tuple[set[str], int, bool]:
    landed: set[str] = set()
    compactions = 0
    this_turn = False
    for line in open(transcript, encoding="utf-8"):
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("subtype") == "compact_boundary":
            compactions += 1
        elif is_prompt(event):
            this_turn = False
        else:
            shas = LANDED.findall(result_text(event))
            if shas:
                landed.update(shas)
                this_turn = True
    return landed, compactions, this_turn


def main() -> None:
    payload = json.load(sys.stdin)
    if payload.get("stop_hook_active"):
        return
    landed, compactions, this_turn = read(payload["transcript_path"])
    if not this_turn or not (len(landed) >= MIN_RECORDS or compactions >= MIN_COMPACTIONS):
        return
    state = Path(os.environ.get("CLOSE_ON_LAND_STATE", Path(os.environ.get("TMPDIR", "/tmp")) / "claude-close-on-land"))
    state.mkdir(parents=True, exist_ok=True)
    marker = state / re.sub(r"[^\w.-]", "_", str(payload.get("session_id", "none")))
    if marker.exists():
        return
    marker.write_text("")
    binary = os.environ.get("CLOSE_ON_LAND_BIN", "herdr-goal-done")
    tab = os.environ.get("HERDR_TAB_ID", "")
    command = f'"{binary}" || "{binary}" --tab "{tab}"' if tab else f'"{binary}"'
    subprocess.Popen(["sh", "-c", command], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
