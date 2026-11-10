#!/usr/bin/env python3
"""The one build lane data, web and API share (BibleStandard BS-IOS-TASK-1619).

    herdr-group-lane check <ID> [--opener]

Exit 0 when the lane is free for <ID>; exit 3, printing the holder, when it is held. A holder is a
live `claude` booted `/build BS-(DATA|WEB|API)-<kind>-<n>` for another ID, or a data checkout the
data repo's `session_worktree.held()` counts. Stale web and API worktrees hold nothing.

Eddy's own tabs are never capped: the check passes when the caller's own `claude` was not booted
with `/build`. A chain opener passes `--opener` or sets HERDR_GROUP_LANE_OPENER and is always gated.
Python standard library only.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

EXIT_HELD = 3
GROUP_ID = re.compile(r"BS-(?:DATA|WEB|API)-[A-Z]+-\d+")
#: The agent's flags, then the verb and its argument: the prompt must start with the verb.
BOOT = re.compile(r"(?:-\S+(?: [^-\s]\S*)? )*?(/[a-z][a-z-]*)(?: (\S+))?(?: |$)")
AGENTS = {"claude", "codex", "pi"}
DEFAULT_DATA = Path.home() / "Programming/Projects/CanonFidei/biblestandard/data"

Table = dict[int, tuple[int, str]]


def process_table() -> Table:
    """{pid: (parent pid, full command line)}; empty when `ps` cannot run."""
    try:
        out = subprocess.run(["/bin/ps", "-axww", "-o", "pid=,ppid=,command="],
                             capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return {}
    table: Table = {}
    for line in out.splitlines():
        fields = line.split(None, 2)
        if len(fields) == 3 and fields[0].isdigit() and fields[1].isdigit():
            table[int(fields[0])] = (int(fields[1]), fields[2])
    return table


def agent_index(words: list[str]) -> int | None:
    """Where the agent's own name sits in a command line, directly or behind its interpreter."""
    if words and Path(words[0]).name in AGENTS:
        return 0
    interpreted = len(words) > 1 and Path(words[0]).name.startswith(("node", "bun", "python"))
    return 1 if interpreted and Path(words[1]).name in AGENTS else None


def boot(command: str) -> tuple[str, str] | None:
    """(slash verb, its upper-cased argument) an agent was booted with; None for anything else, so
    a shell or a prompt that merely mentions `/build` never counts."""
    words = command.split()
    index = agent_index(words)
    found = None if index is None else BOOT.match(" ".join(words[index + 1:]))
    return (found[1], (found[2] or "").upper()) if found else None


def own_agent(table: Table, pid: int) -> int | None:
    """The pid of the nearest agent above `pid`, or None."""
    seen = set()
    while pid in table and pid not in seen:
        seen.add(pid)
        if agent_index(table[pid][1].split()) is not None:
            return pid
        pid = table[pid][0]
    return None


def hand_opened(table: Table, pid: int) -> bool:
    agent = own_agent(table, pid)
    booted = boot(table[agent][1]) if agent is not None else None
    return booted is None or booted[0] != "/build"


def process_holder(table: Table, ident: str, skip: int | None = None) -> str:
    for pid, (_parent, command) in sorted(table.items()):
        booted = boot(command)
        if pid != skip and booted and booted[0] == "/build" and GROUP_ID.fullmatch(booted[1]) and booted[1] != ident:
            return f"{booted[1]} (pid {pid})"
    return ""


def data_holder(data: Path, ident: str) -> str:
    """The first data checkout the data repo counts, its own lane being this one; "" when the data
    repo is absent or too old to name them."""
    try:
        out = subprocess.run([sys.executable, "tools/session_worktree.py", "lanes"], cwd=data,
                             capture_output=True, text=True, check=True).stdout
        names = json.loads(out).get("held", [])
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError):
        return ""
    return next((f"data checkout {name}" for name in names if name.upper() != ident), "")


def holder(ident: str, opener: bool, table: Table, pid: int, data: Path, handing_over: bool = False) -> str:
    """What holds the lane against `ident`, or "" when it may build. A finishing tab handing over
    still runs while it opens the next build, so it holds nothing against it."""
    if not GROUP_ID.fullmatch(ident) or (not opener and hand_opened(table, pid)):
        return ""
    return process_holder(table, ident, own_agent(table, pid) if handing_over else None) or data_holder(data, ident)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    check = sub.add_parser("check")
    check.add_argument("ident")
    check.add_argument("--opener", action="store_true")
    args = parser.parse_args(argv)
    handing_over = bool(os.environ.get("HERDR_GROUP_LANE_OPENER"))
    data = Path(os.environ.get("BS_DATA_DIR") or DEFAULT_DATA)
    found = holder(args.ident.upper(), args.opener or handing_over, process_table(), os.getppid(), data, handing_over)
    if found:
        print(found)
        return EXIT_HELD
    return 0


if __name__ == "__main__":
    sys.exit(main())
