#!/usr/bin/env python3
"""wake-master: type a worker's wake line into the master's pane (master plan B8).

The master seat has no SendMessage tool, so `notify_when_idle` cannot wake it. Every
tab's Stop and Notification hook (agent-config/claude/agent_state.py) runs this after
writing its status file. It asks `board --wake NAME`; a `decide:`, `landed:` or
`judge:` line (exit 0, 2, 3) is typed into the master's pane with `herdr pane run`,
once per turn (STATE_DIR/pushed/NAME). `quiet`, no master, or the master's own tab
send nothing.

    wake-master NAME [--dry-run]   exit 0 always; prints what it sent or why not
"""
from __future__ import annotations

import json, os, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STATE_DIR = Path(os.environ.get("AGENT_STATE_DIR", Path.home() / ".local/state/agents"))
HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")


def turn(name: str) -> str:
    """The newest status file's session and update time: one key per worker turn."""
    newest: dict = {}
    for f in STATE_DIR.glob("*.json"):
        try:
            e = json.loads(f.read_text())
        except (OSError, ValueError):
            continue
        if e.get("name") == name and e.get("updated", 0) >= newest.get("updated", 0):
            newest = e
    return f"{newest.get('session', '')}:{newest.get('updated', 0)}" if newest else ""


def master_pane() -> tuple[str, str]:
    out = subprocess.run(["sh", str(HERE / "master_socket.sh"), "--pane"], capture_output=True,
                         text=True, timeout=15).stdout.strip()
    sock, _, pane = out.partition("\t")
    return sock, pane


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--dry-run"]
    dry = "--dry-run" in sys.argv
    if len(args) != 1 or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    name = args[0]
    if name == "master" or os.environ.get("AGENT_ROLE") == "master":
        print("wake-master: the master does not wake itself")
        return 0
    done = subprocess.run([sys.executable, str(HERE / "board.py"), "--wake", name], capture_output=True,
                          text=True, timeout=30)
    line = done.stdout.strip()
    if done.returncode not in (0, 2, 3) or not line:
        print(f"wake-master: {line or 'nothing to say'}")
        return 0
    key = f"{turn(name)}|{line.split(':', 1)[0]}"
    seen = STATE_DIR / "pushed" / name
    try:
        if seen.read_text().strip() == key:
            print(f"wake-master: already sent this turn: {line}")
            return 0
    except OSError:
        pass
    sock, pane = master_pane()
    if not sock or not pane:
        print(f"wake-master: no master sits; not sent: {line}")
        return 0
    if os.environ.get("HERDR_PANE_ID") == pane and os.environ.get("HERDR_SOCKET_PATH") == sock:
        print("wake-master: this is the master's own pane")
        return 0
    if dry:
        print(f"would type into {pane}: {line}")
        return 0
    sent = subprocess.run([HERDR, "pane", "run", pane, line], env={**os.environ, "HERDR_SOCKET_PATH": sock},
                          capture_output=True, text=True, timeout=15)
    if sent.returncode == 0:
        seen.parent.mkdir(parents=True, exist_ok=True)
        seen.write_text(key + "\n")
        print(f"woke the master ({pane}): {line}")
    else:
        print(f"wake-master: herdr pane run failed: {sent.stderr.strip()}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
