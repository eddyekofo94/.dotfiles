#!/usr/bin/env python3
"""Weekly Claude Code session cleanup: archive, never hard-delete.

Moves session transcripts under ~/.claude/projects older than CUTOFF_DAYS
into a dated local archive instead of removing them, so "delete old
sessions" stays reversible. What is NOT touched, ever:

  * `memory/` directories (durable per-project knowledge — MEMORY.md and
    individual notes) — these are not sessions and never age out.
  * a session id currently open in Herdr (`herdr pane list`), so an
    in-progress conversation is never yanked out from under you.

What moves, once older than CUTOFF_DAYS:
  * top-level `<project>/<session-id>.jsonl` transcripts and their
    `.closeout-blocks` sidecars
  * `<project>/<session-id>/subagents/*.jsonl` fork transcripts

Archived files land under ARCHIVE_ROOT, mirroring their original relative
path, so restoring one is `mv` back to where it came from. Nothing under
ARCHIVE_ROOT is deleted unless you pass --prune-archive-days, which is not
run by the default weekly job — run it by hand once you're comfortable.
"""

import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

PROJECTS_ROOT = Path.home() / ".claude" / "projects"
ARCHIVE_ROOT = Path.home() / ".dotfiles" / "agent-config" / "evidence" / "session_archive"
CUTOFF_DAYS = 7


def live_session_ids() -> set:
    try:
        raw = subprocess.run(
            ["herdr", "pane", "list"], capture_output=True, text=True, timeout=10
        ).stdout
        panes = json.loads(raw)["result"]["panes"]
    except Exception:
        return set()
    return {
        p["agent_session"]["value"]
        for p in panes
        if p.get("agent_session", {}).get("kind") == "id"
    }


def session_id_of(path: Path) -> str:
    # <id>.jsonl, <id>.jsonl.closeout-blocks, or .../<id>/subagents/agent-*.jsonl
    name = path.name
    if name.endswith(".jsonl.closeout-blocks"):
        return name[: -len(".jsonl.closeout-blocks")]
    if name.endswith(".jsonl"):
        stem = name[: -len(".jsonl")]
        if path.parent.name == "subagents":
            return path.parent.parent.name
        return stem
    return ""


def candidates(cutoff_days: int):
    cutoff = time.time() - cutoff_days * 86400
    live = live_session_ids()
    for project_dir in PROJECTS_ROOT.iterdir():
        if not project_dir.is_dir():
            continue
        for path in project_dir.rglob("*"):
            if not path.is_file():
                continue
            if "memory" in path.relative_to(project_dir).parts[:1]:
                continue  # never touch durable memory
            if path.suffix == ".jsonl" or path.name.endswith(".jsonl.closeout-blocks"):
                sid = session_id_of(path)
                if sid and sid in live:
                    continue
                if path.stat().st_mtime < cutoff:
                    yield path


def archive(path: Path, apply: bool) -> Path:
    rel = path.relative_to(PROJECTS_ROOT)
    dest = ARCHIVE_ROOT / rel
    if apply:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), str(dest))
    return dest


def prune_archive(days: int, apply: bool):
    cutoff = time.time() - days * 86400
    freed = 0
    count = 0
    for path in ARCHIVE_ROOT.rglob("*"):
        if path.is_file() and path.stat().st_mtime < cutoff:
            freed += path.stat().st_size
            count += 1
            if apply:
                path.unlink()
    return count, freed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="actually move files (default: dry run)")
    ap.add_argument("--cutoff-days", type=int, default=CUTOFF_DAYS)
    ap.add_argument(
        "--prune-archive-days",
        type=int,
        default=None,
        help="also permanently delete archived files older than N days (not run by default)",
    )
    args = ap.parse_args()

    files = list(candidates(args.cutoff_days))
    total_bytes = sum(f.stat().st_size for f in files)
    verb = "Archiving" if args.apply else "Would archive (dry run, pass --apply to move)"
    print(f"{verb}: {len(files)} files, {total_bytes / 1e6:.1f} MB, older than {args.cutoff_days}d")
    for f in files:
        archive(f, args.apply)

    if args.prune_archive_days is not None:
        count, freed = prune_archive(args.prune_archive_days, args.apply)
        verb2 = "Deleting" if args.apply else "Would delete (dry run)"
        print(
            f"{verb2} from archive: {count} files, {freed / 1e6:.1f} MB, "
            f"older than {args.prune_archive_days}d in archive"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
