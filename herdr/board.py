#!/usr/bin/env python3
"""herdr-board: the master's read-only view of the whole workflow (master plan 1b, 1f).

    herdr-board                 tabs, their records and states, lanes, machine load
    herdr-board --json          the same, as one JSON object
    herdr-board --gate          exit 0 when the machine may take a new tab, 3 (with why) when not
    herdr-board --deps [--json] each held record, what it waits on, and whether it may open
    herdr-board --wake NAME     on a `notify_when_idle` notice: `decide` (exit 0), `quiet` (exit 1)
                                or `landed` (exit 2: run herdr-open-next)

Tabs come from every herdr server (`herdr tab list` / `pane list`), joined by agent
session to the status files `agent_state.py` writes under `~/.local/state/agents/`.
Lanes come from each `always-build` repository's worktree manager.

Machine (M4): it may take a tab unless memory pressure is warn or critical, or the
one-minute load is above 1.5x the core count. The repositories' own gates still refuse.

Dependencies (M9). A held record is any `waiting` row in the ios or data work graph
(`--focus --json`). Each upstream resolves to its repository by prefix (BS-API ->
api, ...), its merge commit is the newest commit on that repo's `main` naming it, and
its CI is the `production` Actions run for that commit (`gh run list`). The record is:

  release  every upstream landed, and green on production where the repo has CI
  hold     an upstream not landed: open the upstream first (the command is printed)
  hold     an upstream red on production: reopen the upstream, keep this held
  wait     an upstream landed, its production run not green yet

Wake (1e, orders 2026-11-12: `notify_when_idle`, never a timer). The master subscribes
to each tab it opens or messages, by the tab's `--name`; agent_state.py records that
name. On the notice, the newest status file for NAME says whether there is a decision:

  decide   BLOCKED, AWAITING USER APPROVAL, PARTIAL, or a blocked prompt: once per turn
           (`STATE_DIR/wakes/NAME` remembers the turn already escalated)
  landed   DONE with tabs the fill queued for the master (B6): run herdr-open-next,
           then subscribe to each name it prints
  quiet    DONE with nothing queued, WAITING (its own job re-invokes it),
           a turn already escalated, or no status file. Never re-subscribe to it now:
           an idle tab answers a new subscription at once.

Nothing here opens or closes a tab.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import reap_idle  # noqa: E402  (sockets, herdr, lanes, always_build)

STATE_DIR = Path(os.environ.get("AGENT_STATE_DIR", Path.home() / ".local/state/agents"))
ORG = Path(os.environ.get("HERDR_BOARD_ORG",
                          Path(os.environ.get("CANONFIDEI_ROOT", Path.home() / "Programming/Projects/CanonFidei"))
                          / "biblestandard"))
GH = os.environ.get("HERDR_BOARD_GH", "gh")
PREFIX_REPO = {"BS-IOS": "ios", "BS-API": "api", "BS-WEB": "web", "BS-DATA": "data", "BS-AND": "android",
               "BS-ANDROID": "android"}
GRAPH_TOOLS = ("tools/features_index.py", "tools/records.py")
LOAD_FACTOR = 1.5
PRESSURE = {1: "normal", 2: "warn", 4: "critical"}


def run(args: list[str], cwd: str | Path | None = None, timeout: int = 60) -> str:
    try:
        done = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return ""
    return done.stdout if done.returncode == 0 else ""


# ---- machine (M4) ----------------------------------------------------------

def machine() -> dict:
    level = run(["sysctl", "-n", "kern.memorystatus_vm_pressure_level"]).strip()
    pressure = os.environ.get("HERDR_BOARD_PRESSURE") or PRESSURE.get(int(level) if level.isdigit() else 0, "unknown")
    load = float(os.environ["HERDR_BOARD_LOAD"]) if os.environ.get("HERDR_BOARD_LOAD") else os.getloadavg()[0]
    cores = os.cpu_count() or 1
    sims = run(["xcrun", "simctl", "list", "devices", "booted", "-j"], timeout=15)
    try:
        booted = sum(len(v) for v in json.loads(sims)["devices"].values()) if sims else 0
    except (ValueError, KeyError):
        booted = 0
    why = []
    if pressure in ("warn", "critical"):
        why.append(f"memory pressure {pressure}")
    if load > LOAD_FACTOR * cores:
        why.append(f"load {load:.1f} over {LOAD_FACTOR * cores:.0f} ({cores} cores)")
    return {"pressure": pressure, "load": round(load, 2), "cores": cores, "simulators": booted,
            "may_open": not why, "why": "; ".join(why)}


# ---- tabs ------------------------------------------------------------------

def status_files() -> dict[str, dict]:
    found = {}
    for path in STATE_DIR.glob("*.json"):
        try:
            entry = json.loads(path.read_text())
        except (OSError, ValueError):
            continue
        found[entry.get("session") or path.stem] = entry
    return found


def tabs() -> list[dict]:
    states = status_files()
    rows = []
    for sock in reap_idle.sockets():
        try:
            listed = reap_idle.herdr(sock, "tab", "list").get("tabs", [])
            panes = reap_idle.herdr(sock, "pane", "list").get("panes", [])
        except Exception:  # noqa: BLE001 — a dead socket is just not a window
            continue
        first = {}
        for pane in panes:
            first.setdefault(pane["tab_id"], pane)
        for raw in listed:
            pane = first.get(raw["tab_id"], {})
            session = (pane.get("agent_session") or {}).get("value", "")
            state = states.get(session, {})
            label = raw.get("label", "")
            cwd = pane.get("cwd", "")
            found = reap_idle.RECORD.search(Path(cwd).name) if cwd else None
            rows.append({
                "window": Path(sock).parent.name, "tab": raw["tab_id"], "label": label,
                "master": label.split(" ", 1)[-1].lstrip("✻✼✽ ") == "master",
                "agent": pane.get("agent") or "", "herdr_state": raw.get("agent_status", ""),
                "focused": bool(raw.get("focused")), "cwd": cwd, "session": session,
                "record": state.get("record") or (found.group(1).upper() if found else ""),
                "state": state.get("state", ""), "status": state.get("status", ""),
                "next_move": state.get("next_move", ""), "context_tokens": state.get("context_tokens", 0),
                "updated": state.get("updated", 0),
            })
    return rows


def lanes() -> dict:
    out = {}
    for repo in reap_idle.always_build():
        held = reap_idle.lanes(repo)
        out[repo.name] = held if held is not None else "no manager"
    return out


# ---- dependencies (M9) -----------------------------------------------------

def repo_of(ident: str) -> Path | None:
    for prefix, name in sorted(PREFIX_REPO.items(), key=lambda kv: -len(kv[0])):
        if ident.upper().startswith(prefix + "-"):
            return ORG / name
    return None


def waiting_rows() -> list[dict]:
    rows = []
    for name in ("ios", "data"):
        repo = ORG / name
        tool = next((t for t in GRAPH_TOOLS if (repo / t).is_file()), None)
        if not tool:
            continue
        try:
            graph = json.loads(run([sys.executable, tool, "--focus", "--json"], cwd=repo) or "{}")
        except ValueError:
            continue
        for row in graph.get("waiting") or []:
            if row.get("waiting_on"):
                rows.append({**row, "repo": name})
    return rows


def merge_commit(repo: Path, ident: str) -> str:
    """The newest merge on `main` whose subject names the record (`land <ID>`, `Merge <ID>`,
    a PR from its slug). A plain commit naming it (a records edit) is not a land, nor is a
    merge whose body only lists it (`merge.log` shortlogs name other branches)."""
    out = run(["git", "-C", str(repo), "log", "main", "--merges", "-i", "-F", f"--grep={ident}",
               "--format=%H%x1f%s%x1e", "-n", "20"], timeout=20)
    whole = re.compile(rf"(?<![\w-]){re.escape(ident)}(?!\w)", re.I)
    for entry in out.split("\x1e"):
        sha, _, body = entry.strip().partition("\x1f")
        if sha and whole.search(body):
            return sha
    return ""


def ci_state(repo: Path, sha: str) -> str:
    """`none` (no CI here), `green`, `red`, `pending` (running) or `absent` (no run yet)."""
    if not any((repo / ".github/workflows").glob("*.y*ml")):
        return "none"
    out = run([GH, "run", "list", "--branch", "production", "--commit", sha, "--json",
               "status,conclusion,databaseId", "--limit", "5"], cwd=repo, timeout=30)
    try:
        runs = json.loads(out) if out else []
    except ValueError:
        runs = []
    if not runs:
        return "absent"
    if any(r.get("status") != "completed" for r in runs):
        return "pending"
    return "green" if all(r.get("conclusion") == "success" for r in runs) else "red"


def upstream(ident: str) -> dict:
    repo = repo_of(ident)
    if repo is None or not repo.is_dir():
        return {"id": ident, "repo": repo.name if repo else "", "sha": "", "ci": "", "state": "unknown repo"}
    sha = merge_commit(repo, ident)
    if not sha:
        return {"id": ident, "repo": repo.name, "sha": "", "ci": "", "state": "not landed",
                "open": f"cd {repo} && herdr-goals --build {ident}"}
    ci = ci_state(repo, sha)
    state = {"none": "live", "green": "live", "red": "red", "pending": "deploying", "absent": "not on production"}[ci]
    entry = {"id": ident, "repo": repo.name, "sha": sha[:12], "ci": ci, "state": state}
    if ci == "red":
        entry["open"] = f"cd {repo} && herdr-goals --build {ident}"
    return entry


def deps() -> list[dict]:
    out, cache = [], {}
    for row in waiting_rows():
        ups = [cache.setdefault(i, upstream(i)) for i in row["waiting_on"]]
        states = {u["state"] for u in ups}
        if states <= {"live"}:
            verdict = "release"
        elif states & {"not landed", "red", "unknown repo"}:
            verdict = "hold"
        else:
            verdict = "wait"
        out.append({"id": row["id"], "repo": row["repo"], "title": row.get("title", ""),
                    "verdict": verdict, "upstream": ups})
    return out


# ---- output ----------------------------------------------------------------

def age(stamp: float) -> str:
    if not stamp:
        return "-"
    secs = int(time.time() - stamp)
    return f"{secs // 60}m" if secs < 3600 else f"{secs // 3600}h"


def print_board(board: dict) -> None:
    m = board["machine"]
    gate = "may open" if m["may_open"] else f"HOLD: {m['why']}"
    print(f"machine  pressure {m['pressure']}  load {m['load']}/{m['cores']} cores  "
          f"simulators {m['simulators']}  — {gate}")
    for name, held in board["lanes"].items():
        if isinstance(held, dict):
            print(f"lanes    {name}: build {held['build']}/{held['build_cap']}  "
                  f"verdict {held['verdict']}/{held['verdict_seats']}")
        else:
            print(f"lanes    {name}: {held}")
    print(f"tabs     {len(board['tabs'])}")
    for t in board["tabs"]:
        state = "working" if t["herdr_state"] == "working" else (t["state"] or t["herdr_state"] or "-")
        status = t["status"] or "-"
        print(f"  {t['window']:<9} {t['label'][:34]:<34} {t['record'] or '-':<16} {state:<8} {status:<9} "
              f"{age(t['updated']):>4}  {t['next_move'][:60]}")


def print_deps(rows: list[dict]) -> None:
    if not rows:
        print("deps     no held record")
    for row in rows:
        print(f"{row['verdict']:<8} {row['id']} ({row['repo']}) — {row['title'][:60]}")
        for u in row["upstream"]:
            where = f" {u['sha']} ci {u['ci']}" if u["sha"] else ""
            print(f"           waits on {u['id']} ({u['repo']}): {u['state']}{where}")
            if row["verdict"] == "hold" and u.get("open"):
                verb = "reopen" if u["state"] == "red" else "open first"
                print(f"           {verb}: {u['open']}")


DECIDE = {"BLOCKED", "AWAITING USER APPROVAL", "PARTIAL"}


def queued_next() -> list[str]:
    """Boot lines goal_done.sh queued for the master (`next.tsv`: from, cwd, label, boot, launch)."""
    try:
        rows = (STATE_DIR / "next.tsv").read_text().splitlines()
    except OSError:
        return []
    return [r.split("\t")[3] for r in rows if r.count("\t") >= 4]


def wake(name: str) -> tuple[bool, str]:
    mine = [e for e in status_files().values() if e.get("name") == name]
    if not mine:
        return False, f"quiet: no status file names {name}"
    entry = max(mine, key=lambda e: e.get("updated", 0))
    status, state = entry.get("status", ""), entry.get("state", "")
    if status == "DONE":
        # Master plan B6: a live master opens what the fill queued, then subscribes.
        queued = queued_next()
        if queued:
            return True, f"landed: {name}; next {', '.join(queued)} (run herdr-open-next)"
        return False, f"quiet: {name} landed (DONE); nothing queued"
    if status == "WAITING":
        return False, f"quiet: {name} is waiting on its own job"
    if status not in DECIDE and state != "blocked":
        return False, f"quiet: {name} has nothing to decide ({status or state or 'no status'})"
    turn = f"{entry.get('session', '')}:{entry.get('updated', 0)}"
    seen = STATE_DIR / "wakes" / name
    try:
        if seen.read_text().strip() == turn:
            return False, f"quiet: {name} already escalated this turn"
    except OSError:
        pass
    seen.parent.mkdir(parents=True, exist_ok=True)
    seen.write_text(turn + "\n")
    tab = (entry.get("herdr") or {}).get("tab", "")
    what = "blocked on a prompt" if state == "blocked" else status
    return True, f"decide: {name} {what} (tab {tab or '?'}, {entry.get('record') or 'no record'}): {entry.get('next_move', '')}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--gate", action="store_true", help="exit 3 when the machine may not take a tab")
    ap.add_argument("--deps", action="store_true", help="held records and their upstreams")
    ap.add_argument("--wake", metavar="NAME", help="decide or stay quiet on a notify_when_idle notice")
    args = ap.parse_args()
    if args.wake:
        decide, line = wake(args.wake)
        print(line)
        return 2 if line.startswith("landed:") else 0 if decide else 1
    if args.gate:
        m = machine()
        print(json.dumps(m) if args.json else ("may open" if m["may_open"] else f"hold: {m['why']}"))
        return 0 if m["may_open"] else 3
    if args.deps:
        rows = deps()
        print(json.dumps(rows, indent=1)) if args.json else print_deps(rows)
        return 0
    board = {"machine": machine(), "lanes": lanes(), "tabs": tabs()}
    print(json.dumps(board, indent=1)) if args.json else print_board(board)
    return 0


if __name__ == "__main__":
    sys.exit(main())
