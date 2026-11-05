#!/usr/bin/env python3
"""A tab lives for one record (retro 2026-11-05, "the one change").

Session 6b31c6a5 ran 15 hours, landed 8 records and compacted 21 times in one
tab, $110 of a $656 window: each record paid cache reads on a context of ~86k
where a fresh tab starts at ~25k.

Stop: when a turn's tool output printed `LANDED <sha>`, run `herdr-goal-done`
(`--tab <id>` if that refuses because the checkout is gone). It ends the
session, so it runs detached, once per session. Only tool results count as
LANDED: a message that quotes the word does not.

UserPromptSubmit: a `/build` typed into a tab past 20 compactions or 600 turns
(distinct main-thread assistant messages) is refused, and `herdr-goals --build
<ID>` opens it in a fresh tab instead. Other prompts pass.

Any error exits 0 silently.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

LANDED = re.compile(r"^LANDED ([0-9a-f]{7,40})\b", re.M)
MAX_COMPACTIONS = 20
MAX_TURNS = 600
GOAL = re.compile(r"^\s*[/$]build(?![\w-])|<command-name>/build</command-name>")
GOAL_ID = re.compile(r"\b([A-Z][A-Z0-9]*(?:-[A-Z]+)*-[0-9]+)\b")


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


def age(transcript: str) -> tuple[int, int]:
    """(compactions, turns) of the whole session: the transcript survives compaction."""
    compactions, turns = 0, set()
    for line in open(transcript, encoding="utf-8", errors="replace"):
        if "compact_boundary" not in line and '"assistant"' not in line:
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("subtype") == "compact_boundary":
            compactions += 1
        elif event.get("type") == "assistant" and not event.get("isSidechain"):
            turns.add((event.get("message") or {}).get("id") or event.get("uuid"))
    return compactions, len(turns)


def refuse_old_tab(payload: dict) -> None:
    prompt = payload.get("prompt") or ""
    if not GOAL.search(prompt):
        return
    compactions, turns = age(payload["transcript_path"])
    if compactions <= MAX_COMPACTIONS and turns <= MAX_TURNS:
        return
    found = GOAL_ID.search(prompt.upper())
    reason = (f"This tab is at {compactions} compactions and {turns} turns (a tab takes no new "
              f"goal past {MAX_COMPACTIONS} or {MAX_TURNS}: every turn re-reads its context).")
    if found and os.environ.get("HERDR_TAB_ID"):
        binary = os.environ.get("CLOSE_ON_LAND_GOALS_BIN", "herdr-goals")
        try:
            done = subprocess.run([binary, "--build", found.group(1)], cwd=payload.get("cwd") or None,
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=40)
            last = (done.stderr or done.stdout).strip().splitlines()[-1:] or [""]
            reason += (f" Opened /build {found.group(1)} in a fresh tab." if done.returncode == 0 else
                       f" herdr-goals --build {found.group(1)} failed (exit {done.returncode}): {last[0]}")
        except (OSError, subprocess.TimeoutExpired) as error:
            reason += f" herdr-goals --build {found.group(1)} did not run: {error}"
    else:
        reason += " Start it in a fresh tab."
    print(json.dumps({"decision": "block", "reason": reason}))


def main() -> None:
    payload = json.load(sys.stdin)
    if payload.get("hook_event_name") == "UserPromptSubmit":
        refuse_old_tab(payload)
        return
    if payload.get("stop_hook_active"):
        return
    _, _, this_turn = read(payload["transcript_path"])
    if not this_turn:
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
