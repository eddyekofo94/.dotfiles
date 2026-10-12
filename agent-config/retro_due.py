#!/usr/bin/env python3
"""Every N finished sessions in a project, open a `▸ retro` tab (Eddy, 2026-10-12).

    retro_due.py hook                      # SessionEnd hook: reads the hook JSON on stdin
    retro_due.py status --cwd <repo>       # the count, and whether a retro is due
    retro_due.py check --cwd <repo> [--dry-run]

A session counts when its main transcript (a top-level `<id>.jsonl` in the
project's `~/.claude/projects/` dirs or in the session archive) starts after
the project's marker, `~/.claude/retro/<project>.json`. With no marker the
first check seeds it and opens nothing. When RETRO_EVERY (default 50)
sessions wait, `check` opens one `▸ retro` tab in the project's shared
checkout, booted into `/retro`, then moves the marker. A tab that fails to
open leaves the marker, so the next session end tries again. It never fails
the session: every error exits 0. No model runs until the retro is due.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

EVERY = int(os.environ.get("RETRO_EVERY", "50"))
STATE = Path.home() / ".claude" / "retro"
ROOTS = [Path.home() / ".claude" / "projects",
         Path.home() / ".dotfiles" / "agent-config" / "evidence" / "session_archive"]


def shared_checkout(cwd: Path) -> Path | None:
    """The main checkout behind cwd, worktrees included."""
    out = subprocess.run(["git", "-C", str(cwd), "rev-parse", "--path-format=absolute", "--git-common-dir"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return None
    return Path(out.stdout.strip()).parent


def first_timestamp(path: Path) -> str | None:
    try:
        with path.open(errors="replace") as handle:
            for _, line in zip(range(40), handle):
                stamp = json.loads(line).get("timestamp")
                if stamp:
                    return stamp
    except (OSError, ValueError):
        return None
    return None


def sessions_since(project: str, since: str) -> int:
    seen: set[str] = set()
    for root in ROOTS:
        if not root.is_dir():
            continue
        for folder in root.iterdir():
            if project not in folder.name or not folder.is_dir():
                continue
            for transcript in folder.glob("*.jsonl"):
                if transcript.stem in seen:
                    continue
                stamp = first_timestamp(transcript)
                if stamp and stamp > since:
                    seen.add(transcript.stem)
    return len(seen)


def marker(project: str) -> Path:
    return STATE / f"{project}.json"


def boot(count: int, since: str, report: Path) -> str:
    return (f"/retro the {count} sessions of this project since {since[:16]}Z. Unattended: never ask. "
            f"Run the token audit with --days covering that window, write the findings to {report}, "
            f"and end with the one change that would make next week cheapest.")


def open_tab(shared: Path, prompt: str) -> None:
    created = subprocess.run(
        ["herdr", "tab", "create", "--cwd", str(shared), "--label", "▸ retro", "--no-focus"],
        capture_output=True, text=True, check=True, timeout=10)
    result = json.loads(created.stdout)["result"]
    pane = result["root_pane"]["pane_id"]
    launch = "claude --model sonnet --effort medium --permission-mode auto " + shlex.quote(prompt)
    try:
        subprocess.run(["herdr", "pane", "run", pane, launch],
                       capture_output=True, text=True, check=True, timeout=10)
    except subprocess.SubprocessError:
        tab = (result.get("tab") or {}).get("tab_id") or result["root_pane"].get("tab_id")
        if tab:
            subprocess.run(["herdr", "tab", "close", tab], capture_output=True, timeout=10)
        raise


def check(cwd: Path, dry_run: bool = False, status_only: bool = False) -> str:
    shared = shared_checkout(cwd)
    if shared is None:
        return "retro: not a git checkout; nothing counted"
    project = shared.name
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    path = marker(project)
    if not path.is_file():
        if dry_run or status_only:
            return f"retro: no marker for {project}; the next session end seeds it"
        STATE.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"since": now}) + "\n")
        return f"retro: marker seeded for {project} at {now}"
    since = json.loads(path.read_text()).get("since", now)
    count = sessions_since(project, since)
    if count < EVERY or status_only:
        return f"retro: {count}/{EVERY} sessions in {project} since {since[:16]}Z"
    report = STATE / "reports" / f"{project}-{now[:10]}.md"
    prompt = boot(count, since, report)
    if dry_run:
        return f"retro: due ({count} sessions) — would open: {prompt}"
    report.parent.mkdir(parents=True, exist_ok=True)
    open_tab(shared, prompt)
    path.write_text(json.dumps({"since": now, "last_report": str(report)}) + "\n")
    return f"retro: opened ▸ retro over {count} sessions since {since[:16]}Z"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["hook", "status", "check"])
    parser.add_argument("--cwd", default=os.getcwd())
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    cwd = Path(args.cwd)
    if args.command == "hook":
        try:
            cwd = Path(json.load(sys.stdin).get("cwd") or cwd)
        except ValueError:
            pass
    try:
        line = check(cwd, dry_run=args.dry_run, status_only=args.command == "status")
    except Exception as failed:  # a session end is never blocked by the retro counter
        line = f"retro: check failed ({failed}); the marker stays"
    print(line, file=sys.stderr if args.command == "hook" else sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
