#!/usr/bin/env python3
"""Weekly disk-bloat cleanup for agent-driven iOS QA and job state.

Backstop for the leak diagnosed 2026-09-17: automated BibleStandard QA runs
create one Simulator per bug/feature ticket (`BS QA <slug>`, via
`tools/sim_input.py`) and shut it down when done, but until that tool's own
Booted-only reuse gap is fixed (tracked as FS-177), a shut-down device is
never reclaimed — it just sits on disk. This job is the safety net for
leases and worktrees an agent crashed out of, not a replacement for the
FS-177 fix.

What this does, each run:

  1. Deletes `BS QA *` Simulators that are Shutdown, hold no live lease
     (~/.bible-standard/sim-leases/<udid>, <6h old), and whose slug matches
     no open worktree under BibleStandard-sessions. Booted devices and
     leased devices are never touched, live or not.
  2. Runs `xcrun simctl delete unavailable` (stale runtime device records).
  3. Clears ~/Library/Developer/Xcode/DerivedData (Xcode regenerates it).
  4. Prunes ~/.claude/jobs directories older than JOBS_CUTOFF_DAYS, unless
     their state.json reports state "running" or "queued".

Dry run by default; pass --apply to actually delete/clear.
"""

import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

POOL_PREFIX = "BS QA"
LEASE_DIR = Path.home() / ".bible-standard" / "sim-leases"
LEASE_TTL = 6 * 3600
WORKTREES_DIR = Path.home() / "Programming" / "Projects" / "CanonFidei" / "BibleStandard-sessions"
DERIVED_DATA = Path.home() / "Library" / "Developer" / "Xcode" / "DerivedData"
JOBS_DIR = Path.home() / ".claude" / "jobs"
JOBS_CUTOFF_DAYS = 7


def _has_live_lease(udid: str) -> bool:
    path = LEASE_DIR / udid
    return path.exists() and time.time() - path.stat().st_mtime <= LEASE_TTL


def _open_worktree_slugs() -> set:
    if not WORKTREES_DIR.is_dir():
        return set()
    return {p.name for p in WORKTREES_DIR.iterdir() if p.is_dir()}


def stale_bs_qa_devices():
    """Shutdown `BS QA *` devices with no live lease and no open worktree."""
    completed = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "--json"],
        capture_output=True, text=True, check=True,
    )
    inventory = json.loads(completed.stdout)
    open_slugs = _open_worktree_slugs()
    stale = []
    for devices in inventory.get("devices", {}).values():
        for device in devices:
            name = device.get("name", "")
            if not name.startswith(f"{POOL_PREFIX} "):
                continue
            if device.get("state") != "Shutdown":
                continue
            udid = device["udid"]
            if _has_live_lease(udid):
                continue
            slug = name[len(POOL_PREFIX) + 1:]
            if slug in open_slugs:
                continue
            stale.append((udid, name))
    return stale


def delete_devices(devices, apply: bool):
    for udid, name in devices:
        print(f"  {'Deleting' if apply else 'Would delete'}: {name} ({udid})")
        if apply:
            subprocess.run(["xcrun", "simctl", "delete", udid], check=False)


def delete_unavailable(apply: bool):
    print(f"{'Running' if apply else 'Would run'}: xcrun simctl delete unavailable")
    if apply:
        subprocess.run(["xcrun", "simctl", "delete", "unavailable"], check=False)


def clear_derived_data(apply: bool):
    if not DERIVED_DATA.is_dir():
        print("DerivedData: not present, nothing to clear")
        return
    size = sum(f.stat().st_size for f in DERIVED_DATA.rglob("*") if f.is_file())
    print(f"{'Clearing' if apply else 'Would clear'} DerivedData: {size / 1e9:.1f} GB")
    if apply:
        shutil.rmtree(DERIVED_DATA, ignore_errors=True)


def prune_claude_jobs(days: int, apply: bool):
    if not JOBS_DIR.is_dir():
        return
    cutoff = time.time() - days * 86400
    for job_dir in JOBS_DIR.iterdir():
        if not job_dir.is_dir():
            continue
        if job_dir.stat().st_mtime >= cutoff:
            continue
        state_path = job_dir / "state.json"
        if state_path.exists():
            try:
                state = json.loads(state_path.read_text()).get("state")
            except (json.JSONDecodeError, OSError):
                state = None
            if state in ("running", "queued"):
                continue
        print(f"  {'Deleting' if apply else 'Would delete'} job: {job_dir.name}")
        if apply:
            shutil.rmtree(job_dir, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="actually delete/clear (default: dry run)")
    ap.add_argument("--jobs-cutoff-days", type=int, default=JOBS_CUTOFF_DAYS)
    args = ap.parse_args()

    print("Stale BS QA simulators:")
    delete_devices(stale_bs_qa_devices(), args.apply)
    delete_unavailable(args.apply)
    clear_derived_data(args.apply)
    print("Stale Claude job directories:")
    prune_claude_jobs(args.jobs_cutoff_days, args.apply)
    return 0


if __name__ == "__main__":
    sys.exit(main())
