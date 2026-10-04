#!/usr/bin/env python3
"""herdr-reap: close agent tabs that sit idle on landed work, and refill the slot.

Eddy, 2026-10-04: "I want a way to automatically close idle sessions that
their work is landed and open a new goal straightway if there's a free slot,
I don't want to clog space with idle sessions."

A tab finishes its goal and stops; unless its session ran `herdr-goal-done`,
it holds a build lane and a screen slot until Eddy closes it by hand. launchd
runs this every two minutes. A tab closes only when every one of these holds:

  * an agent opened it (`▸ ` label, FS-237 D8) — Eddy's own tabs stay his
  * it is not focused, has one pane, and Herdr reads it `idle`
  * its transcript has not moved for the grace period (default 10 minutes)
  * its last closeout reads `DONE` or `BLOCKED` — never `WAITING`, `AWAITING
    USER APPROVAL` or `PARTIAL`, which are still talking to Eddy
  * nothing is unlanded: a worktree is clean and `origin/main` holds its HEAD;
    a shared checkout holds no claim for the session and `main` is pushed

The close is `herdr-goal-done --tab <id>`, so the worktree sweep, the QA
simulators and the advance into free lanes are that script's, not a copy.

Usage:
  herdr-reap                 # close what qualifies, then advance
  herdr-reap --dry-run       # one line per tab: close or keep, and why
  herdr-reap --only <tab>    # consider just this tab
  herdr-reap --grace 600     # idle seconds before a tab may close
"""

import argparse
import fcntl
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
GOAL_DONE = HERE / "goal_done.sh"
AGENT_MARK = "▸ "
CLOSING_STATUSES = {"DONE", "BLOCKED"}
STATUS = re.compile(r"\*\*Status:\*\*\s*([A-Z][A-Z ]*[A-Z])")
NEXT_MOVE = re.compile(r"\*\*Next move:\*\*\s*(.+)")
LOCK = Path(os.environ.get("HERDR_REAP_LOCK", Path.home() / ".cache/herdr-reap.lock"))
TRANSCRIPTS = Path(os.environ.get("HERDR_REAP_TRANSCRIPTS", Path.home() / ".claude/projects"))


@dataclass
class Tab:
    tab_id: str
    label: str
    focused: bool
    status: str
    pane_count: int
    agent: str = ""
    session: str = ""
    cwd: str = ""
    quiet_for: float | None = None      # seconds since the transcript last moved
    closeout: str | None = None         # the last turn's Status word
    next_move: str = ""
    unlanded: list[str] = field(default_factory=list)


def decide(tab: Tab, grace: float) -> tuple[bool, str]:
    """Close or keep, and the reason. Pure: every fact is already on `tab`."""
    # The tab-status stamper prefixes a position (`2 ▸ fs307`), so look anywhere.
    if AGENT_MARK not in tab.label:
        return False, "Eddy's tab (no ▸)"
    if tab.focused:
        return False, "focused"
    if tab.pane_count != 1:
        return False, f"{tab.pane_count} panes"
    if tab.status != "idle":
        return False, f"agent {tab.status or 'unknown'}"
    if tab.quiet_for is None:
        return False, f"no transcript for {tab.agent or 'the agent'}"
    if tab.quiet_for < grace:
        return False, f"idle {int(tab.quiet_for // 60)}m < {int(grace // 60)}m grace"
    if tab.closeout is None:
        return False, "last turn has no closeout"
    if tab.closeout not in CLOSING_STATUSES:
        return False, f"last turn {tab.closeout}"
    if tab.unlanded:
        return False, "unlanded: " + "; ".join(tab.unlanded)
    return True, f"{tab.closeout}, idle {int(tab.quiet_for // 60)}m, landed"


def herdr(*args: str) -> dict:
    out = subprocess.run(["herdr", *args], capture_output=True, text=True, timeout=15)
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip() or f"herdr {' '.join(args)} failed")
    return json.loads(out.stdout)["result"]


def git(cwd: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


def is_prompt(entry: dict) -> bool:
    """A message Eddy typed, not a tool result the harness filed as `user`."""
    content = entry.get("message", {}).get("content")
    if isinstance(content, str):
        return bool(content.strip())
    return any(isinstance(p, dict) and p.get("type") == "text" for p in content or [])


def read_transcript(transcript: Path, tail: int = 4 << 20) -> tuple[float | None, str | None, str]:
    """When the session last spoke, and its last turn's Status word and Next move.

    Read from the entries' own timestamps, not the file's mtime: Claude Code
    touches an idle session's file without adding to it. Only the tail is read;
    a long session's transcript runs to tens of megabytes.
    """
    with transcript.open("rb") as raw:
        raw.seek(max(0, transcript.stat().st_size - tail))
        lines = raw.read().decode("utf-8", "replace").splitlines()
    spoke, text = None, None
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if spoke is None and entry.get("timestamp"):
            spoke = datetime.fromisoformat(entry["timestamp"].replace("Z", "+00:00")).timestamp()
        if entry.get("type") == "user" and not entry.get("isMeta") and is_prompt(entry):
            # Eddy spoke after the agent's last word (an interrupted turn, a
            # prompt it never answered): the closeout above it is stale.
            return spoke, "EDDY SPOKE LAST", ""
        if entry.get("type") == "assistant":
            parts = [p.get("text", "") for p in entry.get("message", {}).get("content", [])
                     if isinstance(p, dict) and p.get("type") == "text"]
            if any(part.strip() for part in parts):
                text = "\n".join(parts)
                break
    if text is None:
        return spoke, None, ""
    status = STATUS.search(text)
    move = NEXT_MOVE.search(text)
    return spoke, (status.group(1).strip() if status else None), (move.group(1).strip() if move else "")


def unlanded(cwd: str, session: str) -> list[str]:
    """What closing this tab could strand; empty means everything is on origin/main."""
    top = git(cwd, "rev-parse", "--show-toplevel")
    if top.returncode != 0:
        return ["not a git checkout"]
    root = top.stdout.strip()
    common = git(root, "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip()
    shared = str(Path(common).parent)
    problems = []
    if root != shared:
        if git(root, "status", "--porcelain").stdout.strip():
            problems.append("worktree dirty")
        if git(root, "merge-base", "--is-ancestor", "HEAD", "origin/main").returncode != 0:
            problems.append("origin/main lacks its HEAD")
        return problems
    ahead = git(root, "rev-list", "--count", "origin/main..main").stdout.strip()
    if ahead not in ("", "0"):
        problems.append(f"main {ahead} ahead of origin/main")
    lock = Path(root) / "tools/repo_lock.py"
    if session and lock.exists():
        status = subprocess.run(
            [sys.executable, str(lock), "status", "--json"], cwd=root, capture_output=True, text=True,
        )
        try:
            claims = json.loads(status.stdout).get("claims", [])
        except json.JSONDecodeError:
            return problems + ["claims unreadable"]
        held = [c for c in claims if c.get("session_id") == session]
        if held:
            problems.append(f"{len(held)} path claim(s) held")
    return problems


def gather(only: str | None) -> list[Tab]:
    panes = {}
    for pane in herdr("pane", "list").get("panes", []):
        panes.setdefault(pane["tab_id"], pane)
    tabs = []
    now = time.time()
    for raw in herdr("tab", "list").get("tabs", []):
        if only and raw["tab_id"] != only:
            continue
        tab = Tab(raw["tab_id"], raw.get("label", ""), bool(raw.get("focused")),
                  raw.get("agent_status", ""), int(raw.get("pane_count", 1)))
        pane = panes.get(tab.tab_id)
        if pane:
            tab.agent = pane.get("agent") or ""
            tab.session = (pane.get("agent_session") or {}).get("value", "")
            tab.cwd = pane.get("cwd", "")
        if tab.agent == "claude" and tab.session:
            found = next(TRANSCRIPTS.glob(f"*/{tab.session}.jsonl"), None)
            if found:
                spoke, tab.closeout, tab.next_move = read_transcript(found)
                tab.quiet_for = None if spoke is None else now - spoke
        if tab.cwd and tab.closeout in CLOSING_STATUSES:
            tab.unlanded = unlanded(tab.cwd, tab.session)
        tabs.append(tab)
    return tabs


def log(message: str) -> None:
    print(f"{datetime.now():%Y-%m-%d %H:%M:%S} {message}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--only", metavar="TAB")
    parser.add_argument("--grace", type=float, default=float(os.environ.get("HERDR_REAP_GRACE", 600)))
    args = parser.parse_args()

    LOCK.parent.mkdir(parents=True, exist_ok=True)
    with LOCK.open("w") as held:
        try:
            fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            log("another herdr-reap is running; skipping this pass")
            return 0
        try:
            tabs = gather(args.only)
        except (RuntimeError, OSError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
            # No Herdr server yet (login, before the first `herdr`) is the normal case.
            if args.dry_run or args.only:
                log(f"herdr unavailable: {error}")
            return 0
        for tab in tabs:
            close, reason = decide(tab, args.grace)
            line = f"{tab.tab_id} {tab.label!r}: {'close' if close else 'keep'} — {reason}"
            if args.dry_run or not close:
                if args.dry_run:
                    print(line)
                continue
            log(line + (f" · next move was: {tab.next_move}" if tab.next_move else ""))
            done = subprocess.run(["bash", str(GOAL_DONE), "--tab", tab.tab_id],
                                  capture_output=True, text=True)
            for out in (done.stdout + done.stderr).splitlines():
                log(f"  {out}")
            if done.returncode != 0:
                log(f"  goal-done exit {done.returncode}: {tab.tab_id} left open")
    return 0


if __name__ == "__main__":
    sys.exit(main())
