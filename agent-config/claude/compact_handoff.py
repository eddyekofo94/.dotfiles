#!/usr/bin/env python3
"""Compaction handoff: compaction runs itself and the session keeps its goal (Eddy, 2026-10-12).

Eddy: "I don't want to be sitting here and doing it." Auto-compact
(`autoCompactWindow` in settings.json) replaces his manual `/compact`; this hook
makes it safe to leave alone. Two modes, main sessions only (a subagent carries
`agent_id` and is skipped):

  precompact  PreCompact: print what the summary must keep. Claude appends a
              PreCompact hook's stdout to the compaction instructions. Any
              output skips the precomputed summary, so a compaction takes a
              full pass (about a minute) in exchange for a goal-aware summary.
  resume      SessionStart, matcher `compact`: inject the goal, the resume file
              and its next unchecked step, and say the session continues: its
              authorization and mode stand.

The resume file is found, in order: the last `plan.md`, `decisions.md` or
`handoff.md` this session wrote (from its transcript), then a record ID read
off the branch (`feature/fs297-grill` -> FS-297) and its
`.working/interviews/fs297*/plan.md`. Any error exits 0 silently: the hook
never blocks a compaction or a session start.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

TAIL_BYTES = 4_000_000
RESUME_NAMES = ("plan.md", "decisions.md", "handoff.md")
#: An old `fs515` / `bug-402`, or a new id whole: `ios-feat-515`, `bs-ios-bug-537`
#: (BibleStandard IOS-FEAT-537), never its `bug-537` tail.
RECORD = re.compile(r"\b(?:((?:bs-)?[a-z]+-(?:feat|task|bug)-\d+)|(fs|bug)-?(\d{3,}))\b", re.IGNORECASE)
UNCHECKED = re.compile(r"^\s*[-*] \[ \] (.+)$")


def git(cwd: str, *args: str) -> str:
    try:
        out = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=5)
        return out.stdout.strip() if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def written_resume_file(transcript: str) -> Path | None:
    """The last resume file this session wrote or edited."""
    if not transcript or not os.path.exists(transcript):
        return None
    with open(transcript, "rb") as handle:
        handle.seek(0, os.SEEK_END)
        handle.seek(max(0, handle.tell() - TAIL_BYTES))
        lines = handle.read().splitlines()
    for raw in reversed(lines):
        if b'"tool_use"' not in raw:
            continue
        try:
            content = (json.loads(raw).get("message") or {}).get("content") or []
        except ValueError:
            continue
        for block in reversed(content if isinstance(content, list) else []):
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            if block.get("name") not in ("Write", "Edit", "MultiEdit"):
                continue
            path = (block.get("input") or {}).get("file_path") or ""
            if path.endswith(RESUME_NAMES) and os.path.exists(path):
                return Path(path)
    return None


def record_from(*names: str) -> str:
    for name in names:
        match = RECORD.search(name or "")
        if match:
            return match.group(1).upper() if match.group(1) else f"{match.group(2).upper()}-{match.group(3)}"
    return ""


def branch_plan(root: Path, record: str) -> Path | None:
    if not record:
        return None
    prefix = record.lower().replace("-", "")
    plans = sorted(root.glob(f".working/interviews/{prefix}*/plan.md"),
                   key=lambda p: p.stat().st_mtime, reverse=True)
    return plans[0] if plans else None


def next_step(path: Path | None) -> str:
    if not path or path.name != "plan.md":
        return ""
    try:
        for line in path.read_text().splitlines():
            match = UNCHECKED.match(line)
            if match:
                step = match.group(1).strip()
                return step if len(step) <= 240 else step[:237] + "..."
    except OSError:
        pass
    return ""


def context(data: dict) -> dict:
    cwd = data.get("cwd") or os.getcwd()
    top = git(cwd, "rev-parse", "--show-toplevel")
    branch = git(cwd, "branch", "--show-current")
    root = Path(top) if top else Path(cwd)
    resume = written_resume_file(data.get("transcript_path") or "")
    record = record_from(str(resume or ""), branch, root.name)
    resume = resume or branch_plan(root, record)
    return {"cwd": cwd, "root": root, "branch": branch, "record": record,
            "resume": resume, "step": next_step(resume)}


def shown(path: Path | None, root: Path) -> str:
    if not path:
        return ""
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def precompact(ctx: dict) -> str:
    keep = [
        "This summary replaces the conversation for a session that continues unattended. Keep, "
        "verbatim where they are short:",
        "- the goal" + (f" ({ctx['record']})" if ctx["record"] else "")
        + " and the record or decision file it cites;",
        "- the resume file" + (f" `{shown(ctx['resume'], ctx['root'])}`" if ctx["resume"] else "")
        + ", the step in progress and how that step is proved;",
        "- the checkout and branch" + (f" (`{ctx['branch']}` in `{ctx['root']}`)" if ctx["branch"] else "")
        + ", and what is uncommitted or unlanded;",
        "- every correction Eddy gave in his own words, and any question still waiting on him;",
        "- checks run with their results, and checks not yet run;",
        "- any background job or subagent still running, and what it will report.",
        "Drop file dumps and tool output already acted on.",
    ]
    return "\n".join(keep)


def resume(ctx: dict) -> str:
    parts = ["COMPACTION HANDOFF: this conversation was auto-compacted and continues; the session "
             "keeps its goal, its authorization and its mode."]
    if ctx["record"]:
        parts.append(f"Goal: {ctx['record']}.")
    if ctx["resume"]:
        parts.append(f"Re-read `{shown(ctx['resume'], ctx['root'])}` before the next edit.")
    if ctx["step"]:
        parts.append(f"Its first unchecked step: {ctx['step']}")
    parts.append("A TAB CONTEXT note that calls this a clear, or says it is not authorization, "
                 "is written for /clear and does not apply after a compaction.")
    return " ".join(parts)


def main() -> int:
    try:
        mode = sys.argv[1] if len(sys.argv) > 1 else ""
        data = json.load(sys.stdin)
        if data.get("agent_id"):
            return 0
        if mode == "precompact":
            print(precompact(context(data)))
        elif mode == "resume":
            if data.get("source") not in (None, "compact"):
                return 0
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": resume(context(data))}}))
    except Exception:  # the hook never blocks a compaction or a session start
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
