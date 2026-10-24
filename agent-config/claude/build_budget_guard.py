#!/usr/bin/env python3
"""Build budget guard: stop a /build session past 2 hours or past two missed tries (Eddy, 2026-10-24).

PreToolUse hook (all tools; subagents carry `agent_id` and are skipped). It makes
`.claude/playbooks/build.md` §2 mechanical: "A step that misses its proof twice is
parked ... A record that runs past ... about two hours stops at its next landable
point and is split into small records."

Active only in a build session: the transcript holds a user message that starts
`/build` (or `$build`, or the slash-command wrapper `<command-name>/build`). Build
start = that first message's timestamp (the transcript file survives compaction).

Rules, each denying the tool call with a "park and split" reason:
  time   now - build start > 2 h
  tries  in the build's plan.md (the last plan.md the transcript Edit/Write'd), one
         step (a top-level `- [ ]` / `- [x]` bullet plus its indented lines) holds two
         or more markers ("missed its proof", "failed, not ticked", "**failed") and is
         not marked parked (`parked`, `skip:`)

Calls still allowed so the agent can park:
  Read, Glob, Grep; Edit/Write/MultiEdit on `plan.md`, `AGENTS.md`, or files under
  `project/specs/` or `project/bugs/`; Bash made only of: git diff, git status, cp,
  mkdir, cat, ls, grep, sed -n, python3 tools/features_index.py, herdr-goal-done
  (joined by && ; |, with no redirects, `$(` or backticks).

Escape hatch: env BUILD_BUDGET_EXTEND=1, or a file `.working/<goal>/budget-extend`
(goal = the /build argument lowercased, e.g. FS-487 -> fs487) under the session cwd.
Eddy's okay lives in that file; the agent never creates it on its own.

Fail open: any error allows the call and prints to stderr.
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

LIMIT_SECONDS = 2 * 3600
MISS = ("missed its proof", "failed, not ticked", "**failed")
PARKED = ("parked", "skip:")
OKAY_TOOLS = {"Read", "Glob", "Grep"}
EDIT_TOOLS = {"Edit", "Write", "MultiEdit"}
BASH_OK = (r"git diff\b", r"git status\b", r"cp\b", r"mkdir\b", r"cat\b", r"ls\b", r"grep\b",
           r"sed -n\b", r"python3 tools/features_index\.py\b", r"herdr-goal-done\b")
BUILD_START = re.compile(r"^\s*(?:<command-message>build</command-message>\s*)?"
                         r"(?:<command-name>)?[/$]build\b")
STEP = re.compile(r"^- \[[ xX]\]")


def when(stamp: str) -> float:
    return datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp()


def scan(transcript: str):
    """Return (build start epoch, goal, last plan.md path) from the transcript."""
    start = goal = plan = None
    with open(transcript, encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            if start is None and '"user"' in raw:
                try:
                    row = json.loads(raw)
                except ValueError:
                    continue
                content = (row.get("message") or {}).get("content")
                if row.get("type") == "user" and not row.get("isSidechain"):
                    text = content if isinstance(content, str) else " ".join(
                        b.get("text", "") for b in content or [] if isinstance(b, dict))
                    if BUILD_START.match(text):
                        start = when(row["timestamp"])
                        args = re.search(r"<command-args>\s*([^\s<]+)", text) or re.search(
                            r"[/$]build\s+(\S+)", text)
                        goal = args.group(1).lower().replace("-", "") if args else None
            elif '"tool_use"' in raw and "plan.md" in raw:
                try:
                    row = json.loads(raw)
                except ValueError:
                    continue
                for block in (row.get("message") or {}).get("content") or []:
                    if not isinstance(block, dict) or block.get("type") != "tool_use":
                        continue
                    path = (block.get("input") or {}).get("file_path", "")
                    if block.get("name") in EDIT_TOOLS and os.path.basename(path) == "plan.md":
                        plan = path
    return start, goal, plan


def missed_step(plan: str) -> str | None:
    """First step with two or more miss markers that is not parked, else None."""
    steps, current = [], []
    for line in Path(plan).read_text(errors="replace").splitlines():
        if STEP.match(line) and not line.startswith((" ", "\t")):
            current = [line]
            steps.append(current)
        elif current and (line.startswith((" ", "\t")) or not line.strip()):
            current.append(line)
        else:
            current = []
    for lines in steps:
        text = "\n".join(lines).lower()
        if sum(text.count(m) for m in MISS) >= 2 and not any(p in text for p in PARKED):
            return lines[0].strip()[:80]
    return None


def allowed_bash(command: str) -> bool:
    if "`" in command or "$(" in command or ">" in command:
        return False
    parts = [p.strip() for p in re.split(r"&&|;|\|", command) if p.strip()]
    return bool(parts) and all(any(re.match(ok, p) for ok in BASH_OK) for p in parts)


def allowed_call(tool: str, tool_input: dict) -> bool:
    if tool in OKAY_TOOLS:
        return True
    if tool in EDIT_TOOLS:
        path = tool_input.get("file_path", "")
        return (os.path.basename(path) in ("plan.md", "AGENTS.md")
                or "/project/specs/" in path or "/project/bugs/" in path)
    if tool == "Bash":
        return allowed_bash(tool_input.get("command", ""))
    return False


def reason(why: str) -> str:
    return (f"Build budget guard: {why} (build.md §2): park now. Back up the diff to /tmp, write "
            "the numbers into plan.md, split the record into child records, end the turn. "
            "Only plan.md, AGENTS.md, project/specs and project/bugs edits and read-only git/ls/cat "
            "calls are allowed. Eddy extends with .working/<goal>/budget-extend.")


def main() -> int:
    try:
        data = json.load(sys.stdin)
        transcript = data.get("transcript_path")
        if data.get("agent_id") or not transcript or not os.path.exists(transcript):
            return 0
        if os.environ.get("BUILD_BUDGET_EXTEND"):
            return 0
        start, goal, plan = scan(transcript)
        if start is None:
            return 0
        cwd = Path(data.get("cwd") or os.getcwd())
        if goal and (cwd / ".working" / goal / "budget-extend").exists():
            return 0
        why = None
        if datetime.now(timezone.utc).timestamp() - start > LIMIT_SECONDS:
            why = "build past 2 h"
        elif plan and os.path.exists(plan) and (step := missed_step(plan)):
            why = f"a step missed its proof twice ({step})"
        if why is None or allowed_call(data.get("tool_name", ""), data.get("tool_input") or {}):
            return 0
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "permissionDecision": "deny",
            "permissionDecisionReason": reason(why)}}))
        return 0
    except Exception as error:  # fail open: never brick a session
        print(f"build_budget_guard: {error!r}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    sys.exit(main())
