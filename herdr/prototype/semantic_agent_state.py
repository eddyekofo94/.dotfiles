#!/usr/bin/env python3
"""Report the existing agent event model as display-only Herdr metadata."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any


PROTOTYPE = Path(__file__).resolve().parent
TMUX_MODEL = PROTOTYPE.parents[1] / "tmux" / "scripts" / "agent_status.py"
SOURCE = "prototype:semantic-state"
DISPLAY_STATE = {
    "ready": "ready",
    "running": "running",
    "question": "question",
    "permission": "approval",
    "finished": "finished",
    "failed": "failure",
}
STATE_LABELS = {
    "ready": (("idle", "ready"),),
    "running": (("working", "running"),),
    "question": (("blocked", "question"),),
    "permission": (("blocked", "approval"),),
    "finished": (("done", "finished"), ("idle", "finished")),
    "failed": (
        ("done", "failure"),
        ("idle", "failure"),
        ("blocked", "failure"),
    ),
}


def load_event_model() -> Any:
    spec = importlib.util.spec_from_file_location("tmux_agent_status", TMUX_MODEL)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load shared agent event model: {TMUX_MODEL}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_payload() -> dict[str, Any]:
    try:
        value = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return {}
    return value if isinstance(value, dict) else {}


def report_metadata(agent: str, state: str, pane: str) -> None:
    herdr = os.environ.get("HERDR_BIN_PATH", "herdr")
    display = DISPLAY_STATE[state]
    command = [
        herdr,
        "pane",
        "report-metadata",
        pane,
        "--source",
        SOURCE,
        "--agent",
        agent,
        "--token",
        f"semantic_state={display}",
        "--token",
        f"summary={display}",
    ]
    for semantic, label in STATE_LABELS[state]:
        command.extend(("--state-label", f"{semantic}={label}"))
    ttl = os.environ.get("HERDR_SEMANTIC_TTL_MS", "3600000")
    if ttl:
        command.extend(("--ttl-ms", ttl))
    subprocess.run(
        command,
        check=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("hook",))
    parser.add_argument("--agent", required=True)
    parser.add_argument("--event", required=True)
    parser.add_argument("--pane")
    args = parser.parse_args()

    # The same hook can remain configured while tmux is production: outside a
    # Herdr pane it is deliberately inert and does not claim lifecycle authority.
    pane = args.pane or os.environ.get("HERDR_PANE_ID") or os.environ.get(
        "HERDR_TARGET_PANE_ID"
    )
    if not pane or not os.environ.get("HERDR_ENV"):
        print("{}")
        return 0

    try:
        model = load_event_model()
        if args.agent not in model.SUPPORTED_AGENTS:
            raise ValueError(f"unsupported agent: {args.agent}")
        state = model.state_for_event(args.event, read_payload())
        report_metadata(args.agent, state, pane)
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError):
        # Agent hooks must never interrupt the agent itself. Validation reads
        # Herdr state back and fails closed if a report was not applied.
        pass
    print("{}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
