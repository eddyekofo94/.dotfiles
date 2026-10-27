#!/usr/bin/env python3
"""Bash output trim: a Bash result over 8,000 characters reaches the model as its head and tail (retro 2026-10-27).

PostToolUse hook on `Bash`. The 2026-10-27 retro measured 6,315 Bash results at 10.6M
characters (~3.0M tokens) in three days, 7x the Read tool, and every character is paid
again on each later turn. A result over LIMIT characters (stdout or stderr) is replaced
by the first HEAD and last TAIL characters of each stream, with a marker naming the
file that holds the full text: `$TMPDIR/claude-bash-output/<session>-<tool_use_id>.log`.
Read that file by range when the middle matters.

The replacement is `hookSpecificOutput.updatedToolOutput`: the tool_response object
Claude sent the hook, with only `stdout` and `stderr` replaced, so its shape is kept.
Fail open: any error, a response that is not an object of strings, or a result under
the limit prints nothing and exits 0.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

LIMIT = 8_000
HEAD = 3_000
TAIL = 3_000
STATE = Path(os.environ.get("TMPDIR", "/tmp")) / "claude-bash-output"


def trim(text: str, log: Path) -> str:
    if len(text) <= LIMIT:
        return text
    cut = len(text) - HEAD - TAIL
    return (f"{text[:HEAD]}\n[... {cut} characters trimmed; full output: {log} ...]\n{text[-TAIL:]}")


def main() -> int:
    try:
        data = json.load(sys.stdin)
        if data.get("tool_name") != "Bash":
            return 0
        response = data.get("tool_response")
        if not isinstance(response, dict):
            return 0
        out, err = response.get("stdout"), response.get("stderr")
        if not isinstance(out, str) or not isinstance(err, str):
            return 0
        if len(out) <= LIMIT and len(err) <= LIMIT:
            return 0
        name = re.sub(r"[^A-Za-z0-9_.-]", "_", f"{data.get('session_id', 'x')}-{data.get('tool_use_id', 'x')}")
        STATE.mkdir(parents=True, exist_ok=True)
        log = STATE / f"{name}.log"
        log.write_text(out + (f"\n--- stderr ---\n{err}" if err else ""), encoding="utf-8")
        updated = {**response, "stdout": trim(out, log), "stderr": trim(err, log)}
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PostToolUse", "updatedToolOutput": updated}}))
        return 0
    except Exception as error:  # fail open
        print(f"bash_output_trim: {error!r}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    sys.exit(main())
