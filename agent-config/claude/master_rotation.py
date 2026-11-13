#!/usr/bin/env python3
"""Master rotation guard (retro ios-2026-11-13, finding 1).

The master tab ran 896 turns and 24 compactions in a day ($146 of $619). After
ROTATE_AT compactions it hands its state to `master/handoff.md` and a fresh
master takes the seat. Master role only (`AGENT_ROLE=master`), main session only.

  count   PreCompact: count this compaction; the ROTATE_AT-th arms the rotation.
  resume  SessionStart `compact`: when armed, tell the master to hand off and rotate.
  rotate  the master runs it after rewriting handoff.md; --dry-run prints the calls.

Any hook error exits 0 silently: it never blocks a compaction.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROTATE_AT = 8
MASTER_DIR = Path(os.environ.get("MASTER_DIR", Path.home() / ".dotfiles/agent-config/master"))
STATE = MASTER_DIR / "state"
HANDOFF = MASTER_DIR / "handoff.md"
SELF = Path(__file__).resolve()


def is_master_main(payload: dict) -> bool:
    return os.environ.get("AGENT_ROLE") == "master" and not payload.get("agent_id")


def safe(session: str) -> str:
    return "".join(c for c in session if c.isalnum() or c in "-_") or "unknown"


def count(payload: dict) -> str:
    if not is_master_main(payload):
        return ""
    STATE.mkdir(parents=True, exist_ok=True)
    base = STATE / safe(payload.get("session_id", ""))
    counter = base.with_suffix(".count")
    n = int(counter.read_text() or 0) + 1 if counter.exists() else 1
    counter.write_text(str(n))
    if n < ROTATE_AT:
        return ""
    base.with_suffix(".armed").write_text(str(time.time()))
    return (f"This master has compacted {n} times. Keep in the summary: rewrite {HANDOFF} "
            "(current state only) and rotate to a fresh master.")


def resume(payload: dict) -> str:
    if not is_master_main(payload):
        return ""
    armed = (STATE / safe(payload.get("session_id", ""))).with_suffix(".armed")
    if not armed.exists():
        return ""
    return (f"ROTATE: this master has compacted {ROTATE_AT}+ times. Now: rewrite {HANDOFF} (current state only; "
            f"the journal keeps the log), run `python3 -I {SELF} rotate`, then stop. "
            "A fresh master reads both. Do not start new work in this tab.")


def rotate(session: str, dry: bool) -> int:
    armed = (STATE / safe(session)).with_suffix(".armed")
    if not armed.exists():
        print("rotate: this session is not armed (fewer than %d compactions)" % ROTATE_AT, file=sys.stderr)
        return 2
    if not HANDOFF.exists() or HANDOFF.stat().st_mtime < float(armed.read_text()):
        print(f"rotate: rewrite {HANDOFF} first; it predates the arming", file=sys.stderr)
        return 3
    tab, herdr = os.environ.get("HERDR_TAB_ID", ""), os.environ.get("HERDR_BIN_PATH", str(Path.home() / ".local/bin/herdr"))
    org = os.environ.get("HERDR_BOARD_ORG", str(Path.home() / "Programming/Projects/CanonFidei/biblestandard"))
    launch = f"env AGENT_ROLE=master AGENT_NAME=master claude --name master --model fable \"/master\""
    if not tab:
        print("rotate: not inside a herdr tab", file=sys.stderr)
        return 64
    steps = [[herdr, "tab", "rename", tab, "master-prev"],
             [herdr, "tab", "create", "--cwd", org, "--label", "✻ master", "--no-focus"]]
    if dry:
        for s in steps:
            print("would run:", " ".join(s))
        print(f"would run: {herdr} pane run <new root pane> {launch}")
        return 0
    subprocess.run(steps[0], check=True, capture_output=True)
    created = subprocess.run(steps[1], check=True, capture_output=True, text=True).stdout
    pane = json.loads(created)["result"]["root_pane"]["pane_id"]
    subprocess.run([herdr, "pane", "run", pane, launch], check=True, capture_output=True)
    armed.rename(armed.with_suffix(".done"))
    print(f"rotate: fresh master seated in pane {pane}; this tab is master-prev, leave it for the reaper")
    return 0


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "rotate":
        return rotate(os.environ.get("CLAUDE_SESSION_ID", ""), "--dry-run" in sys.argv)
    try:
        payload = json.load(sys.stdin)
        text = {"count": count, "resume": resume}.get(mode, lambda p: "")(payload)
        if text:
            print(text)
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
