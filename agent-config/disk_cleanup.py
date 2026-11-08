#!/usr/bin/env python3
"""Disk cleanup, Tier 1 of .working/disk-cleanup/plan.md: regenerable caches only.

Dry run by default: measures every item and prints free space on the Data
volume. With --apply it deletes, re-measures, and logs before/after/delta to
agent-config/evidence/disk_cleanup/<date>.txt. Nothing outside ITEMS is touched.
Two-week rule: `aged` items delete only children older than KEEP_DAYS.
"""

import argparse
import datetime
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
KEEP_DAYS = 14
DATA_VOLUME = "/System/Volumes/Data"
LOG_DIR = HOME / ".dotfiles" / "agent-config" / "evidence" / "disk_cleanup"
# Toolchains that must stay: default nightly and herdr's pinned Rust (pins.env).
KEEP_TOOLCHAINS = {"nightly-aarch64-apple-darwin", "1.96.1-aarch64-apple-darwin"}

HERDR_INCREMENTAL = HOME / ".dotfiles/herdr/source-build/.work/target/debug/incremental"
CACHES = HOME / "Library/Caches"
# (label, path, mode) mode: "all" = remove path; "aged" = remove children older than KEEP_DAYS
PATH_ITEMS = [
    ("herdr cargo incremental", HERDR_INCREMENTAL, "all"),
    ("Caches/Google", CACHES / "Google", "all"),
    ("Caches/BraveSoftware", CACHES / "BraveSoftware", "all"),
    ("Caches/com.brave.Browser", CACHES / "com.brave.Browser", "all"),
    ("Caches/pip", CACHES / "pip", "all"),
    ("Caches/ms-playwright (browsers; npx playwright install restores)", CACHES / "ms-playwright", "all"),
    ("Caches/go-build", CACHES / "go-build", "all"),
    ("Caches/Discord ShipIt", CACHES / "com.hnc.Discord.ShipIt", "all"),
    (".cache/yarn", HOME / ".cache/yarn", "all"),
    (".cache/zig", HOME / ".cache/zig", "all"),
    (".cache/puppeteer (browsers; re-download on use)", HOME / ".cache/puppeteer", "all"),
    (".cache/nvim", HOME / ".cache/nvim", "all"),
    ("Xcode device-install deltas (next install is a full push)",
     HOME / "Library/Containers/com.apple.CoreDevice.CoreDeviceService/Data/Library/Caches/AppInstallationBinaryDeltas",
     "all"),
    ("Xcode DerivedData (>14d)", HOME / "Library/Developer/Xcode/DerivedData", "aged"),
    ("Xcode iOS DeviceSupport (>14d)", HOME / "Library/Developer/Xcode/iOS DeviceSupport", "aged"),
]


def du_kb(path: Path) -> int:
    if not path.exists():
        return 0
    out = subprocess.run(["du", "-sk", str(path)], capture_output=True, text=True).stdout.split()
    return int(out[0]) if out else 0


def free_kb() -> int:
    out = subprocess.run(["df", "-k", DATA_VOLUME], capture_output=True, text=True).stdout.splitlines()
    return int(out[1].split()[3])


def aged_children(path: Path):
    cutoff = time.time() - KEEP_DAYS * 86400
    if not path.is_dir():
        return []
    return [c for c in path.iterdir() if c.stat().st_mtime < cutoff]


def target_size_kb(path: Path, mode: str) -> int:
    if mode == "all":
        return du_kb(path)
    return sum(du_kb(c) for c in aged_children(path))


def remove(path: Path):
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path, ignore_errors=True)
    elif path.exists() or path.is_symlink():
        path.unlink()


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def old_toolchains():
    r = run(["rustup", "toolchain", "list"])
    names = [line.split()[0] for line in r.stdout.splitlines() if line.strip()]
    return [n for n in names if n not in KEEP_TOOLCHAINS]


def toolchain_kb(name: str) -> int:
    return du_kb(HOME / ".rustup" / "toolchains" / name)


def brew_kb() -> int:
    r = run(["brew", "cleanup", "-n", f"--prune={KEEP_DAYS}"])
    kb = 0
    for line in r.stdout.splitlines():
        if "approximately" in line:  # "...would free approximately 1.2GB of disk space."
            tok = line.split("approximately")[1].split()[0]
            num = float("".join(c for c in tok if c.isdigit() or c == "."))
            kb = int(num * {"KB": 1, "MB": 1024, "GB": 1024**2}.get(tok.lstrip("0123456789."), 0))
    return kb


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="delete (default: dry run)")
    args = ap.parse_args()

    lines = []

    def out(s=""):
        print(s)
        lines.append(s)

    free_before = free_kb()
    out(f"{'APPLY' if args.apply else 'DRY RUN'}  {datetime.datetime.now():%Y-%m-%d %H:%M}")
    out(f"Free on Data volume before: {free_before / 1048576:.1f} GB")
    out()

    rows = []  # (label, before_kb, action)
    for label, path, mode in PATH_ITEMS:
        rows.append((label, target_size_kb(path, mode), ("path", path, mode)))
    for name in old_toolchains():
        rows.append((f"rustup toolchain {name}", toolchain_kb(name), ("rustup", name)))
    rows.append((f"brew cleanup --prune={KEEP_DAYS}", brew_kb(), ("brew",)))
    rows.append(("simctl delete unavailable", 0, ("simctl",)))  # size not measurable up front

    out(f"{'item':<66}{'MB':>9}")
    for label, kb, _ in rows:
        out(f"{label:<66}{kb / 1024:>9.0f}")
    expected = sum(kb for _, kb, _ in rows)
    out(f"{'EXPECTED TOTAL (excl. simctl)':<66}{expected / 1024:>9.0f}")

    if not args.apply:
        out("\nDry run only. Re-run with --apply to delete.")
        return 0

    out("\nDeleting...")
    for label, kb, action in rows:
        if action[0] == "path":
            _, path, mode = action
            if mode == "all":
                remove(path)
                path.mkdir(parents=True, exist_ok=True)  # keep the dir so tools don't error
            else:
                for c in aged_children(path):
                    remove(c)
        elif action[0] == "rustup":
            run(["rustup", "toolchain", "uninstall", action[1]])
        elif action[0] == "brew":
            run(["brew", "cleanup", f"--prune={KEEP_DAYS}"])
        elif action[0] == "simctl":
            run(["xcrun", "simctl", "delete", "unavailable"])
        out(f"  done: {label}")

    free_after = free_kb()
    out()
    out(f"Free before: {free_before / 1048576:.1f} GB")
    out(f"Free after:  {free_after / 1048576:.1f} GB")
    out(f"Freed:       {(free_after - free_before) / 1048576:.1f} GB  (expected {expected / 1048576:.1f} GB)")
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    (LOG_DIR / f"{datetime.date.today()}.txt").write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
