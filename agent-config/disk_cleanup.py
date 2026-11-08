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

# Tier 2: stale copies and backups. Listed in every dry run; deleted only with --tier2 --apply.
# (label, path, mode, exclude-suffix). Verified 2026-11-08: Xcode-26.6.app is installed, the Rust
# home ~/.local/share/rustup is unused (cargo uses ~/.rustup), Claude vm_bundles re-download on demand.
TIER2_ITEMS = [
    ("Backups/Xcode-26.6.zip (Xcode-26.6.app installed)", HOME / "Backups/Xcode-26.6.zip", "all", ""),
    ("Backups task folders (>14d, not *-raw)", HOME / "Backups", "aged", "-raw"),
    ("Downloads/Xcode_27.1.xip (installer)", HOME / "Downloads/Xcode_27.1.xip", "all", ""),
    ("Claude desktop vm_bundles (re-downloads)", HOME / "Library/Application Support/Claude/vm_bundles", "all", ""),
    ("unused 2nd Rust home ~/.local/share/rustup", HOME / ".local/share/rustup", "all", ""),
    ("Backups/bible-standard-usfx-raw (re-downloadable? CHECK first)", HOME / "Backups/bible-standard-usfx-raw", "all", ""),
    (".cache/huggingface (OCR models, re-download)", HOME / ".cache/huggingface", "all", ""),
    (".cache/biblestandard-libs (content-addressed; CHECK what rebuilds it)", HOME / ".cache/biblestandard-libs", "all", ""),
]


def du_kb(path: Path) -> int:
    if not path.exists():
        return 0
    out = subprocess.run(["du", "-sk", str(path)], capture_output=True, text=True).stdout.split()
    return int(out[0]) if out else 0


def free_kb() -> int:
    out = subprocess.run(["df", "-k", DATA_VOLUME], capture_output=True, text=True).stdout.splitlines()
    return int(out[1].split()[3])


def aged_children(path: Path, exclude: str = ""):
    cutoff = time.time() - KEEP_DAYS * 86400
    if not path.is_dir():
        return []
    return [
        c for c in path.iterdir()
        if c.stat().st_mtime < cutoff and not (exclude and c.name.endswith(exclude))
        and not c.name.startswith(".")
    ]


def target_size_kb(path: Path, mode: str, exclude: str = "") -> int:
    if mode == "all":
        return du_kb(path)
    return sum(du_kb(c) for c in aged_children(path, exclude))


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
    ap.add_argument("--skip", action="append", default=[], help="skip Tier 2 items whose label contains this text")
    ap.add_argument("--tier2", action="store_true", help="also delete the Tier 2 stale-copy list")
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
        rows.append((label, target_size_kb(path, mode), ("path", path, mode, "")))
    for name in old_toolchains():
        rows.append((f"rustup toolchain {name}", toolchain_kb(name), ("rustup", name)))
    rows.append((f"brew cleanup --prune={KEEP_DAYS}", brew_kb(), ("brew",)))
    rows.append(("simctl delete unavailable", 0, ("simctl",)))  # size not measurable up front
    tier2 = [(l, target_size_kb(p, m, x), ("path", p, m, x)) for l, p, m, x in TIER2_ITEMS]
    if args.tier2:
        rows += [r for r in tier2 if not any(k in r[0] for k in args.skip)]

    out(f"{'item':<66}{'MB':>9}")
    for label, kb, _ in rows:
        out(f"{label:<66}{kb / 1024:>9.0f}")
    expected = sum(kb for _, kb, _ in rows)
    out(f"{'EXPECTED TOTAL (excl. simctl)':<66}{expected / 1024:>9.0f}")
    if not args.tier2:
        out(f"\nTier 2 (needs --tier2; review each first):")
        for label, kb, _ in tier2:
            out(f"{label:<66}{kb / 1024:>9.0f}")
        out(f"{'TIER 2 TOTAL':<66}{sum(k for _, k, _ in tier2) / 1024:>9.0f}")

    if not args.apply:
        out("\nDry run only. Re-run with --apply to delete.")
        return 0

    out("\nDeleting...")
    for label, kb, action in rows:
        if action[0] == "path":
            _, path, mode, *rest = action
            if mode == "all":
                was_dir = path.is_dir()
                remove(path)
                if was_dir:
                    path.mkdir(parents=True, exist_ok=True)  # keep dirs so tools don't error
            else:
                for c in aged_children(path, rest[0] if rest else ""):
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
    with open(LOG_DIR / f"{datetime.date.today()}.txt", "a") as f:  # append: several runs a day
        f.write("\n".join(lines) + "\n\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
