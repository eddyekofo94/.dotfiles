#!/usr/bin/env python3
"""Context guard: make a session save its place before auto-compact (Eddy, 2026-10-12).

Hook for PreToolUse, PostToolUse, UserPromptSubmit and SessionStart on
compact (main sessions only;
subagents carry `agent_id` and are skipped). It reads the session's last
`message.usage` from the transcript tail, the same measure the statusline
shows, against the context where this transcript last compacted (retro
2026-10-29: tabs compact near 87k although `autoCompactWindow` says 120k).
With no compaction in the tail it uses FALLBACK_WINDOW. It speaks once per
band per session:

  70%  make the resume file current at the next step boundary
  90%  compaction is near: write the resume file now, start nothing new

Past the 90% note, PreToolUse refuses every tool call except writing the
resume file (plan.md, decisions.md or handoff*.md) and reading or finding
it; the first successful write lifts the hold. BS-IOS-TASK-1027 (session
d29b02d1, 2026-10-29) read four notes and compacted twice without saving.

Auto-compact does the compacting (Eddy, 2026-10-12: "I don't want to be sitting
here and doing it"); compact_handoff.py carries the goal across it. The guard
never asks Eddy to /compact or open a tab.

A compaction (SessionStart, source compact) or a context under 50% re-arms
the bands and lifts any hold: a session that compacted lands near 60% of its
window (2026-10-29: 53k of 85k), so the 50% line alone kept a stale hold. Any error exits 0 silently: a broken guard never blocks a session.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

STATE = Path(os.environ.get("TMPDIR", "/tmp")) / "claude-context-guard"
TAIL_BYTES = 4_000_000
BANDS = [(0.90, "near"), (0.70, "early")]
FALLBACK_WINDOW = 87_000
MIN_PEAK = 60_000  # a drop from below this is not a compaction
HELD = "near"  # the marker while the near note waits for its save
SAVED = "near-saved"
RESUME_NAME = re.compile(r"^(plan|decisions)\.md$|^[\w.-]*handoff[\w.-]*\.md$")
RESUME_IN_SHELL = re.compile(
    r"(>>?|\btee\b(\s+-a)?)\s*['\"]?[^\s'\";|&]*(?<![\w-])(plan|decisions|[\w.-]*handoff[\w.-]*)\.md\b")
WRITE_TOOLS = {"Write", "Edit", "MultiEdit"}
LOOK_TOOLS = {"Glob"}


def contexts(transcript: str) -> list[int]:
    """Context size of each usage-bearing line in the transcript tail, oldest first."""
    with open(transcript, "rb") as handle:
        handle.seek(0, os.SEEK_END)
        handle.seek(max(0, handle.tell() - TAIL_BYTES))
        lines = handle.read().splitlines()
    sizes = []
    for raw in lines:
        if b'"usage"' not in raw:
            continue
        try:
            usage = (json.loads(raw).get("message") or {}).get("usage")
        except ValueError:
            continue
        if usage:
            sizes.append(usage.get("input_tokens", 0) + usage.get("cache_read_input_tokens", 0)
                         + usage.get("cache_creation_input_tokens", 0))
    return sizes


def window(sizes: list[int]) -> int:
    """The context just before the last drop under 60% of itself; FALLBACK_WINDOW if none."""
    for before, after in zip(reversed(sizes[:-1]), reversed(sizes[1:])):
        if before >= MIN_PEAK and after < 0.6 * before:
            return before
    return FALLBACK_WINDOW


def context_tokens(transcript: str) -> int:
    sizes = contexts(transcript)
    return sizes[-1] if sizes else 0


RESUME = ("the resume file (plan.md for a build; the decisions file for a grill; otherwise "
          "a short handoff.md beside the record): done, next step, open questions, files in play")


def message(band: str, used: int, limit: int) -> str:
    where = (f"{used // 1000}k of the {limit // 1000}k auto-compact window")
    if band == "near":
        return (f"Context guard: this session holds {where}; compaction is near. Start nothing new: "
                f"write {RESUME} now, then continue. Every other tool call is refused until it is "
                f"written. After compaction, re-read only that file.")
    return (f"Context guard: this session holds {where}. At your next step boundary, make {RESUME} "
            f"current. Auto-compact runs by itself; do not ask Eddy to /compact or open a tab.")


def is_resume(path: str) -> bool:
    return bool(path) and bool(RESUME_NAME.match(os.path.basename(path)))


def saves(tool: str, tool_input: dict) -> bool:
    """True when this call writes a resume file."""
    if tool in WRITE_TOOLS:
        return is_resume(tool_input.get("file_path", ""))
    if tool == "Bash":
        return bool(RESUME_IN_SHELL.search(tool_input.get("command", "")))
    return False


def allowed_while_held(tool: str, tool_input: dict) -> bool:
    if saves(tool, tool_input) or tool in LOOK_TOOLS:
        return True
    return tool == "Read" and is_resume(tool_input.get("file_path", ""))


def deny(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse", "permissionDecision": "deny",
        "permissionDecisionReason": reason}}))


def measure(transcript: str) -> tuple[int, int]:
    sizes = contexts(transcript)
    return (sizes[-1] if sizes else 0), window(sizes)


def main() -> int:
    try:
        data = json.load(sys.stdin)
        if data.get("agent_id"):
            return 0
        session, transcript = data.get("session_id"), data.get("transcript_path")
        event = data.get("hook_event_name", "PostToolUse")
        if session and event == "SessionStart":  # wired for source=compact: the bands re-arm
            (STATE / session).unlink(missing_ok=True)
            return 0
        if not session or not transcript or not os.path.exists(transcript):
            return 0
        tool, tool_input = data.get("tool_name", ""), data.get("tool_input") or {}
        STATE.mkdir(parents=True, exist_ok=True)
        marker = STATE / session
        said = marker.read_text().strip() if marker.exists() else ""
        if event == "PreToolUse":
            if said != HELD or allowed_while_held(tool, tool_input):
                return 0
            used, limit = measure(transcript)
            if used < 0.5 * limit:  # compacted since the note: the hold has nothing left to save
                marker.unlink()
                return 0
            deny(f"Context guard: compaction is near ({used // 1000}k of {limit // 1000}k) and "
                 f"this session has not saved its place. Write {RESUME} first, with Write, Edit "
                 f"or a shell redirect; that lifts this hold.")
            return 0
        if event == "PostToolUse" and said == HELD and saves(tool, tool_input):
            marker.write_text(SAVED)
            return 0
        used, limit = measure(transcript)
        if used < 0.5 * limit:
            if said:
                marker.unlink()
            return 0
        for share, band in BANDS:
            if used >= share * limit:
                if said == band or said == SAVED or (said == HELD and band == "early"):
                    return 0
                marker.write_text(band)
                print(json.dumps({"hookSpecificOutput": {
                    "hookEventName": event, "additionalContext": message(band, used, limit)}}))
                return 0
    except Exception:  # a broken guard never blocks a session
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
