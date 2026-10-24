#!/usr/bin/env python3
"""herdr worktree sweep: remove the worktrees of finished work, in every repo.

Eddy, 2026-10-24: "when user stories are merged and verdicts are pass … these
files should be removed … we should be cleaning them after the job is done."
`.claude/worktrees/` held 39 GB and `ios-sessions/` 30 GB of checkouts no one
used: a subagent's `agent-*` copy, a landed checkout kept by a stale lock.

It walks every git repository under `~/Programming/Projects/CanonFidei` (the
main checkouts, never a linked worktree) and judges each linked worktree that
sits in `<repo>-sessions/` or `<repo>/.claude/worktrees/`. One is removed
whole, untracked captures and `.build` included, only when ALL hold:

  * no Herdr tab has its cwd inside it
  * no tracked change (untracked files are debris once the work is merged)
  * every commit is in `origin/main` (ancestor, or `git cherry` shows all `-`)
  * it has been quiet for the grace period (default 30 min), so a checkout the
    chain just opened for a session about to start is never taken
  * it is not on `~/.config/herdr/worktree-sweep-keep`
  * the repo's optional `tools/worktree_verdict.py <branch> <path>` exits 0
    (a repo without one: merged is enough)

A lock whose tab is gone is freed first; the lock never outlives its tab.
Nothing with tracked changes or an unlanded commit is ever removed. Each
removal is logged to `~/.local/state/herdr/worktree_sweep.log` with the HEAD
commit, the branch and the untracked count and size. Ruby and River is skipped.

Usage:
  worktree_sweep.py            # dry run: one line per worktree, remove or keep and why
  worktree_sweep.py --apply    # remove what qualifies
  worktree_sweep.py --auto     # --apply only when ~/.config/herdr/worktree-sweep reads "on"
"""
import argparse
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

PROJECTS = Path(os.environ.get("HERDR_SWEEP_ROOT", "~/Programming/Projects/CanonFidei")).expanduser()
SKIP = ("rubyandriver",)
SWITCH = Path("~/.config/herdr/worktree-sweep").expanduser()
KEEP = Path("~/.config/herdr/worktree-sweep-keep").expanduser()
LOG = Path("~/.local/state/herdr/worktree_sweep.log").expanduser()
GRACE = float(os.environ.get("HERDR_SWEEP_GRACE", 1800))


@dataclass
class Tree:
    path: Path
    head: str = ""
    branch: str = ""
    locked: bool = False


def git(cwd, *args, timeout=60):
    return subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, text=True, timeout=timeout)


def repos(root: Path = PROJECTS) -> list[Path]:
    """Main checkouts: a directory holding a `.git` directory (a linked worktree has a file)."""
    found = []
    for depth in ("*", "*/*"):
        for p in sorted(root.glob(depth)):
            if (p / ".git").is_dir() and not any(s in p.name.lower() for s in SKIP):
                found.append(p)
    return found


def trees(repo: Path) -> list[Tree]:
    out = git(repo, "worktree", "list", "--porcelain").stdout
    result, cur = [], None
    for line in out.splitlines() + [""]:
        if line.startswith("worktree "):
            cur = Tree(Path(line[9:]))
        elif cur and line.startswith("HEAD "):
            cur.head = line[5:]
        elif cur and line.startswith("branch "):
            cur.branch = line[7:].removeprefix("refs/heads/")
        elif cur and line.startswith("locked"):
            cur.locked = True
        elif not line and cur:
            result.append(cur)
            cur = None
    return result[1:]  # the first entry is the main checkout


def candidate(repo: Path, tree: Tree) -> bool:
    sessions = repo.parent / f"{repo.name}-sessions"
    claude = repo / ".claude" / "worktrees"
    return tree.path.parent in (sessions, claude)


def base_ref(repo: Path) -> str | None:
    head = git(repo, "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD").stdout.strip()
    for ref in (head, "origin/main", "origin/master", "origin/development"):
        if ref and git(repo, "rev-parse", "--verify", "-q", ref).returncode == 0:
            return ref
    return None


def kept_by_name(repo: Path, tree: Tree) -> bool:
    """`~/.config/herdr/worktree-sweep-keep`: one `<repo>/<worktree>` per line, never swept."""
    if not KEEP.exists():
        return False
    names = {l.split("#", 1)[0].strip() for l in KEEP.read_text().splitlines()}
    return f"{repo.name}/{tree.path.name}" in names


def merged(repo: Path, tree: Tree, base: str) -> bool:
    ref = tree.head
    if git(repo, "merge-base", "--is-ancestor", ref, base).returncode == 0:
        return True
    cherry = git(repo, "cherry", base, ref).stdout.splitlines()
    return not any(line.startswith("+") for line in cherry)


def quiet_for(tree: Tree) -> float:
    stamps = [tree.path.stat().st_mtime]
    gitfile = tree.path / ".git"
    if gitfile.is_file():
        gd = Path(gitfile.read_text().split(":", 1)[1].strip())
        stamps += [p.stat().st_mtime for p in (gd / "HEAD", gd / "index") if p.exists()]
    return time.time() - max(stamps)


def debris(tree: Tree) -> str:
    out = git(tree.path, "--no-optional-locks", "status", "--porcelain", "--untracked-files=all").stdout.splitlines()
    files = [l[3:] for l in out if l.startswith("??")]
    size = 0
    for f in files[:5000]:
        try:
            size += (tree.path / f).stat().st_size
        except OSError:
            pass
    return f"{len(files)} untracked, {size >> 20} MB"


def judge(repo: Path, tree: Tree, live: list[str], base: str | None, grace: float) -> tuple[bool, str]:
    if not tree.path.exists():
        return False, "gone from disk (git worktree prune)"
    here = str(tree.path)
    if kept_by_name(repo, tree):
        return False, "on the keep list (worktree-sweep-keep)"
    if any(c == here or c.startswith(here + "/") for c in live):
        return False, "a tab is open in it"
    if base is None:
        return False, "no origin/main to compare with"
    idle = quiet_for(tree)  # before `status`, which can touch the index
    if git(tree.path, "--no-optional-locks", "status", "--porcelain", "--untracked-files=no").stdout.strip():
        return False, "tracked changes (commit or discard first)"
    if not merged(repo, tree, base):
        return False, f"has a commit {base} does not (land it or drop it by hand)"
    if idle < grace:
        return False, f"touched {int(idle // 60)} min ago (grace {int(grace // 60)} min)"
    hook = repo / "tools" / "worktree_verdict.py"
    if hook.exists():
        ran = subprocess.run([sys.executable, str(hook), tree.branch or tree.head, here],
                             cwd=str(repo), capture_output=True, text=True, timeout=60)
        if ran.returncode != 0:
            return False, "verdict is not a pass: " + (ran.stdout + ran.stderr).strip()[:80]
    return True, f"merged to {base}, clean, quiet, tab gone"


def record(repo: Path, tree: Tree, note: str) -> None:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a") as fh:
        fh.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} removed {tree.path} branch={tree.branch or '-'} "
                 f"head={tree.head[:10]} {note}\n")


def remove(repo: Path, tree: Tree) -> str:
    note = debris(tree)
    if tree.locked:
        git(repo, "worktree", "unlock", str(tree.path))
    done = git(repo, "worktree", "remove", "--force", str(tree.path))
    if done.returncode != 0:
        return "git worktree remove failed: " + done.stderr.strip()[:100]
    if tree.branch:
        git(repo, "branch", "-d", tree.branch)  # -d only: an unmerged branch survives
    record(repo, tree, note)
    return f"removed ({note})"


def live_cwds() -> list[str]:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import reap_idle
    cwds = []
    for sock in reap_idle.sockets():
        try:
            cwds += [t.cwd for t in reap_idle.gather(sock, None) if t.cwd]
        except Exception:
            continue
    return cwds


def sweep(root: Path, live: list[str], apply: bool, grace: float = GRACE) -> list[str]:
    lines = []
    for repo in repos(root):
        base = base_ref(repo)
        for tree in trees(repo):
            if not candidate(repo, tree):
                continue
            ok, why = judge(repo, tree, live, base, grace)
            if ok and apply:
                why = remove(repo, tree)
            lines.append(f"{repo.name}/{tree.path.name}: {'remove' if ok else 'keep'} — {why}"
                         if not (ok and apply) else f"{repo.name}/{tree.path.name}: {why}")
        if apply:
            git(repo, "worktree", "prune")
    return lines


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--auto", action="store_true")
    ap.add_argument("--grace", type=float, default=GRACE)
    args = ap.parse_args()
    apply = args.apply or (args.auto and SWITCH.exists() and SWITCH.read_text().strip() == "on")
    for line in sweep(PROJECTS, live_cwds(), apply, args.grace):
        print(line)
    if args.auto and not apply:
        print("worktree-sweep: dry run (switch off; `echo on > ~/.config/herdr/worktree-sweep` turns it on)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
