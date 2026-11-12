#!/usr/bin/env python3
"""herdr-ready: the judge step between a green /build and its landing (master plan B7).

A /build whose gate and review are green never lands on its own. It marks itself
ready and ends its turn; the master (or Eddy) judges it against the record.

    herdr-ready mark ID [--name N]        the worker: gate + review green, waiting
    herdr-ready judge NAME land           the judge: prints the line to send the tab
    herdr-ready judge NAME back "<why>"   the judge: sent back, with why
    herdr-ready clear [--name N]          the worker, after it landed
    herdr-ready list [--json]             every tab waiting on a judge, with wait time
    herdr-ready show NAME                 one entry as JSON (exit 1: none)

NAME is the tab's `claude --name` (AGENT_NAME in the worker). State lives in
AGENT_STATE_DIR/ready/NAME.json: name, record, state (ready | landing | sent_back),
why, at (when the state began), cwd.
"""
from __future__ import annotations

import argparse, json, os, sys, time
from pathlib import Path

STATE_DIR = Path(os.environ.get("AGENT_STATE_DIR", Path.home() / ".local/state/agents"))
READY = STATE_DIR / "ready"


def path(name: str) -> Path:
    return READY / f"{name}.json"


def load(name: str) -> dict | None:
    try:
        return json.loads(path(name).read_text())
    except (OSError, ValueError):
        return None


def save(entry: dict) -> None:
    READY.mkdir(parents=True, exist_ok=True)
    tmp = path(entry["name"]).with_suffix(".tmp")
    tmp.write_text(json.dumps(entry) + "\n")
    tmp.replace(path(entry["name"]))


def waited(entry: dict, now: float | None = None) -> str:
    secs = int((now or time.time()) - entry.get("at", 0))
    return f"{secs // 60}m" if secs < 3600 else f"{secs // 3600}h{secs % 3600 // 60:02d}m"


def entries() -> list[dict]:
    rows = []
    for f in sorted(READY.glob("*.json")) if READY.is_dir() else []:
        try:
            rows.append(json.loads(f.read_text()))
        except (OSError, ValueError):
            continue
    return sorted(rows, key=lambda e: e.get("at", 0))


def own_name(given: str | None) -> str:
    name = given or os.environ.get("AGENT_NAME", "")
    if not name:
        sys.exit("herdr-ready: no --name and no AGENT_NAME in this tab")
    return name


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("mark"); m.add_argument("record"); m.add_argument("--name")
    j = sub.add_parser("judge"); j.add_argument("name"); j.add_argument("verdict", choices=["land", "back"])
    j.add_argument("why", nargs="?", default="")
    c = sub.add_parser("clear"); c.add_argument("--name")
    li = sub.add_parser("list"); li.add_argument("--json", action="store_true")
    sh = sub.add_parser("show"); sh.add_argument("name")
    a = ap.parse_args()

    if a.cmd == "mark":
        name = own_name(a.name)
        save({"name": name, "record": a.record, "state": "ready", "why": "", "at": time.time(),
              "cwd": os.getcwd()})
        print(f"ready: {name} {a.record} — waiting on the judge; end the turn, do not land")
        return 0
    if a.cmd == "judge":
        entry = load(a.name)
        if not entry or entry.get("state") != "ready":
            print(f"herdr-ready: {a.name} is not waiting on a judge"
                  f" ({entry.get('state') if entry else 'no entry'})", file=sys.stderr)
            return 1
        if a.verdict == "back" and not a.why.strip():
            print("herdr-ready: sent back needs a why", file=sys.stderr)
            return 2
        entry.update(state="landing" if a.verdict == "land" else "sent_back", why=a.why.strip(), at=time.time())
        save(entry)
        print("land" if a.verdict == "land" else f"sent back: {entry['why']}")
        return 0
    if a.cmd == "clear":
        path(own_name(a.name)).unlink(missing_ok=True)
        return 0
    if a.cmd == "show":
        entry = load(a.name)
        if not entry:
            return 1
        print(json.dumps(entry))
        return 0
    rows = entries()
    if a.json:
        print(json.dumps([{**e, "waited": waited(e)} for e in rows], indent=1))
    else:
        for e in rows:
            why = f" — {e['why']}" if e.get("why") else ""
            print(f"{e['state']:<9} {e['name']:<28} {e.get('record', ''):<18} {waited(e):>6}{why}")
        if not rows:
            print("nobody waiting on a judge")
    return 0


if __name__ == "__main__":
    sys.exit(main())
