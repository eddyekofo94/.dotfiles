#!/usr/bin/env python3
"""Read size guard: an unbounded Read of a big file is denied once (retro 2026-11-07).

PreToolUse hook on `Read`. The 2026-11-07 retro found 25-37k-character Reads (records,
diffs, tool sources), some twice in a session; each is re-read on every later turn.
A Read with no `limit` of a text file over LIMIT bytes is denied the first time per
session and path, with a message to grep or read a line range. The same Read repeated
is allowed, so the guard never blocks a read the agent really needs whole.
Images, PDFs and notebooks are skipped. Fail open: any error prints nothing, exit 0.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

LIMIT = 20_000
SKIP = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".pdf", ".ipynb"}
STATE = Path(os.environ.get("TMPDIR", "/tmp")) / "claude-read-guard"


def main() -> int:
    try:
        data = json.load(sys.stdin)
        if data.get("tool_name") != "Read":
            return 0
        args = data.get("tool_input") or {}
        path = args.get("file_path")
        if not isinstance(path, str) or args.get("limit") or args.get("allow_large"):
            return 0
        p = Path(path)
        if p.suffix.lower() in SKIP or not p.is_file():
            return 0
        size = p.stat().st_size
        if size <= LIMIT:
            return 0
        session = re.sub(r"[^A-Za-z0-9_.-]", "_", str(data.get("session_id", "x")))
        STATE.mkdir(parents=True, exist_ok=True)
        seen = STATE / f"{session}.txt"
        done = seen.read_text(encoding="utf-8").splitlines() if seen.exists() else []
        if str(p) in done:
            return 0
        with seen.open("a", encoding="utf-8") as handle:
            handle.write(f"{p}\n")
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"{p} is {size} bytes and every later turn pays for it again. "
                "Use grep -n for what you need, or Read with offset and limit. "
                "If you need all of it, repeat this exact Read and it will go through.")}}))
        return 0
    except Exception as error:  # fail open
        print(f"read_size_guard: {error!r}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    sys.exit(main())
