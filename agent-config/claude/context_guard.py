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
window (2026-10-29: 53k of 85k), so the 50% line alone kept a stale hold. The
guard stays quiet until the first reading after the compaction lands. Any error exits 0 silently: a broken guard never blocks a session.
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
COMPACTED = "compacted"  # + the stale reading the transcript still ends on
# plan-bs-ios-task-1022.md is a plan too (2026-10-29: refused as one)
RESUME_NAME = re.compile(r"^(plan[\w.-]*|decisions)\.md$|^[\w.-]*handoff[\w.-]*\.md$")
RESUME_IN_SHELL = re.compile(
    r"(>>?|\btee\b(\s+-a)?)\s*['\"]?[^\s'\";|&]*(?<![\w-])(plan[\w.-]*|decisions|[\w.-]*handoff[\w.-]*)\.md\b")
# A script that names a resume file and writes with Python or sed -i saves it too
# (2026-10-29: BS-IOS-TASK-1021 and 1031 were refused `python3 - <<EOF ... open(p, 'w')`)
RESUME_MENTION = re.compile(r"(?<![\w-])(plan[\w.-]*|decisions|[\w.-]*handoff[\w.-]*)\.md\b")
SCRIPT_WRITE = re.compile(r"\.write_text\(|\.write\(|\bopen\([^)]*,\s*['\"][wa]|\bsed\s+-i\b")
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
        command = tool_input.get("command", "")
        return bool(RESUME_IN_SHELL.search(command)
                    or (RESUME_MENTION.search(command) and SCRIPT_WRITE.search(command)))
    return False


def allowed_while_held(tool: str, tool_input: dict) -> bool:
    if saves(tool, tool_input) or tool in LOOK_TOOLS:
        return True
    return tool == "Read" and is_resume(tool_input.get("file_path", ""))


BIG_READ = 30_000  # bytes; retro 2026-10-29: whole 35-39k-char Swift reads rode 100+ turns each
BIG_READ_SKIP = re.compile(r"(^|/)(plan|decisions)[\w.-]*\.md$|handoff")


def big_read_refusal(session: str, tool_input: dict) -> str:
    """Refuse the first whole-file Read of a big file; the same file's retry goes through."""
    path = tool_input.get("file_path", "")
    if tool_input.get("offset") or tool_input.get("limit") or BIG_READ_SKIP.search(path):
        return ""
    try:
        size = os.path.getsize(path)
    except OSError:
        return ""
    if size < BIG_READ:
        return ""
    seen = STATE / f"{session}.bigreads"
    done = seen.read_text().splitlines() if seen.exists() else []
    if path in done:
        return ""
    with seen.open("a") as handle:
        handle.write(path + "\n")
    return (f"Context guard: {os.path.basename(path)} is {size // 1000}k bytes (~{size // 3500}k tokens) "
            f"and would ride every later turn. grep -n for the symbol, then Read with offset and limit. "
            f"Need all of it? Repeat the same Read and it goes through.")


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
            # The transcript still ends on the pre-compaction reading for a call or two
            # (BS-IOS-TASK-1022, 2026-10-29: a stale 86k fired a second near note), so
            # remember it and stay quiet until a fresh reading lands.
            stale = context_tokens(transcript) if transcript and os.path.exists(transcript) else 0
            STATE.mkdir(parents=True, exist_ok=True)
            (STATE / session).write_text(f"{COMPACTED} {stale}")
            return 0
        if not session or not transcript or not os.path.exists(transcript):
            return 0
        tool, tool_input = data.get("tool_name", ""), data.get("tool_input") or {}
        STATE.mkdir(parents=True, exist_ok=True)
        if event == "PreToolUse" and tool == "Read":
            refusal = big_read_refusal(session, tool_input)
            if refusal:
                deny(refusal)
                return 0
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
        if said.startswith(COMPACTED):
            if said == f"{COMPACTED} {used}":
                return 0
            marker.unlink()
            said = ""
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
