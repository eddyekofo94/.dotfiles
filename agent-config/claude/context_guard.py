#!/usr/bin/env python3
"""Context guard: warn a session before auto-compact, so its resume file is current (Eddy, 2026-10-12).

Hook for PostToolUse and UserPromptSubmit (main sessions only; subagents carry
`agent_id` and are skipped). It reads the session's last `message.usage` from
the transcript tail, the same measure the statusline shows, against the
auto-compact window in ~/.claude/settings.json (`autoCompactWindow`, default
200k). It speaks once per band per session, then stays silent:

  70%  make the resume file current at the next step boundary
  90%  compaction is near: write the resume file now, start nothing new

Auto-compact does the compacting (Eddy, 2026-10-12: "I don't want to be sitting
here and doing it"); compact_handoff.py carries the goal across it. The guard
never asks Eddy to /compact or open a tab.

After a compaction drops the context under 50%, the bands re-arm. Any error
exits 0 silently: the guard never blocks a tool call or a prompt.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

STATE = Path(os.environ.get("TMPDIR", "/tmp")) / "claude-context-guard"
SETTINGS = Path.home() / ".claude" / "settings.json"
TAIL_BYTES = 4_000_000
BANDS = [(0.90, "near"), (0.70, "early")]


def window() -> int:
    try:
        value = json.loads(SETTINGS.read_text()).get("autoCompactWindow")
        return int(value) if value else 200_000
    except (OSError, ValueError, TypeError):
        return 200_000


def context_tokens(transcript: str) -> int:
    with open(transcript, "rb") as handle:
        handle.seek(0, os.SEEK_END)
        handle.seek(max(0, handle.tell() - TAIL_BYTES))
        lines = handle.read().splitlines()
    for raw in reversed(lines):
        if b'"usage"' not in raw:
            continue
        try:
            usage = (json.loads(raw).get("message") or {}).get("usage")
        except ValueError:
            continue
        if usage:
            return (usage.get("input_tokens", 0) + usage.get("cache_read_input_tokens", 0)
                    + usage.get("cache_creation_input_tokens", 0))
    return 0


def message(band: str, used: int, limit: int) -> str:
    where = (f"{used // 1000}k of the {limit // 1000}k auto-compact window")
    resume = ("the resume file (plan.md for a build; the decisions file for a grill; otherwise "
              "a short handoff.md beside the record): done, next step, open questions, files in play")
    if band == "near":
        return (f"Context guard: this session holds {where}; compaction is near. Start nothing new: "
                f"write {resume} now, then continue. After compaction, re-read only that file.")
    return (f"Context guard: this session holds {where}. At your next step boundary, make {resume} "
            f"current. Auto-compact runs by itself; do not ask Eddy to /compact or open a tab.")


def main() -> int:
    try:
        data = json.load(sys.stdin)
        if data.get("agent_id"):
            return 0
        session, transcript = data.get("session_id"), data.get("transcript_path")
        if not session or not transcript or not os.path.exists(transcript):
            return 0
        limit = window()
        used = context_tokens(transcript)
        STATE.mkdir(parents=True, exist_ok=True)
        marker = STATE / session
        said = marker.read_text().strip() if marker.exists() else ""
        if used < 0.5 * limit:
            if said:
                marker.unlink()
            return 0
        for share, band in BANDS:
            if used >= share * limit:
                if said == band or (said == "near" and band == "early"):
                    return 0
                marker.write_text(band)
                print(json.dumps({"hookSpecificOutput": {
                    "hookEventName": data.get("hook_event_name", "PostToolUse"),
                    "additionalContext": message(band, used, limit)}}))
                return 0
    except Exception:  # the guard never blocks a session
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
