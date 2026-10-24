#!/usr/bin/env python3
"""worktree_sweep: which linked worktrees are removed, and which are kept, and why."""
import importlib.machinery
import importlib.util
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("worktree_sweep", str(HERE / "worktree_sweep.py"))
spec = importlib.util.spec_from_loader("worktree_sweep", loader)
ws = importlib.util.module_from_spec(spec)
sys.modules["worktree_sweep"] = ws
loader.exec_module(ws)


def run(cwd, *args):
    out = subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", *args],
                         cwd=cwd, capture_output=True, text=True)
    assert out.returncode == 0, out.stderr
    return out.stdout


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        ws.LOG = self.root / "log"
        ws.KEEP = self.root / "keep"
        origin = self.root / "origin.git"
        run(self.root, "init", "-q", "--bare", "-b", "main", str(origin))
        self.repo = self.root / "proj"
        run(self.root, "clone", "-q", str(origin), str(self.repo))
        (self.repo / "a.txt").write_text("a\n")
        run(self.repo, "add", "a.txt")
        run(self.repo, "commit", "-qm", "init")
        run(self.repo, "push", "-q", "origin", "HEAD:main")
        run(self.repo, "fetch", "-q")
        run(self.repo, "branch", "-q", "--set-upstream-to=origin/main")
        run(self.repo, "remote", "set-head", "origin", "main")

    def tearDown(self):
        self.tmp.cleanup()

    def add(self, name, where="sessions", commit=None):
        base = self.root / "proj-sessions" if where == "sessions" else self.repo / ".claude" / "worktrees"
        base.mkdir(parents=True, exist_ok=True)
        path = base / name
        run(self.repo, "worktree", "add", "-q", "-b", f"feature/{name}", str(path), "origin/main")
        if commit:
            (path / f"{name}.txt").write_text(commit)
            run(path, "add", f"{name}.txt")
            run(path, "commit", "-qm", commit)
        old = time.time() - 7200
        for p in (path, ):
            os.utime(p, (old, old))
        gd = Path((path / ".git").read_text().split(":", 1)[1].strip())
        for f in ("HEAD", "index"):
            if (gd / f).exists():
                os.utime(gd / f, (old, old))
        return path

    def land(self, path):
        run(path, "push", "-q", "origin", "HEAD:main")
        run(self.repo, "fetch", "-q")

    def verdict(self, name, live=(), grace=1800):
        out = ws.sweep(self.root, list(live), False, grace)
        return next(l for l in out if f"/{name}:" in l)


class SweepTests(Fixture):
    def test_merged_clean_is_removed_even_with_untracked_debris(self):
        p = self.add("done", commit="x")
        self.land(p)
        (p / "capture.mov").write_bytes(b"0" * 1000)
        old = time.time() - 7200
        os.utime(p, (old, old))
        self.assertIn("remove", self.verdict("done"))
        out = ws.sweep(self.root, [], True)
        self.assertTrue(any("removed (1 untracked" in l for l in out))
        self.assertFalse(p.exists())
        self.assertIn("head=", ws.LOG.read_text())

    def test_unlanded_commit_is_kept(self):
        self.add("wip", commit="y")
        self.assertIn("keep — has a commit", self.verdict("wip"))

    def test_patch_equal_commit_counts_as_landed(self):
        p = self.add("twin", commit="z")
        run(self.repo, "cherry-pick", f"feature/twin")
        run(self.repo, "push", "-q", "origin", "HEAD:main")
        run(self.repo, "fetch", "-q")
        self.assertIn("remove", self.verdict("twin"))

    def test_tracked_change_is_kept(self):
        p = self.add("edit")
        (p / "a.txt").write_text("changed\n")
        self.assertIn("keep — tracked changes", self.verdict("edit"))

    def test_open_tab_is_kept(self):
        p = self.add("open")
        self.assertIn("keep — a tab is open", self.verdict("open", live=[str(p / "sub")]))

    def test_fresh_checkout_is_kept_by_the_grace(self):
        p = self.add("fresh")
        now = time.time()
        os.utime(p, (now, now))
        self.assertIn("keep — touched", self.verdict("fresh"))

    def test_stale_lock_is_freed_and_removed(self):
        p = self.add("locked")
        run(self.repo, "worktree", "lock", str(p))
        ws.sweep(self.root, [], True)
        self.assertFalse(p.exists())

    def test_claude_worktrees_are_swept_too(self):
        p = self.add("agent-abc", where="claude")
        self.assertIn("remove", self.verdict("agent-abc"))

    def test_verdict_hook_can_keep(self):
        p = self.add("hooked")
        (self.repo / "tools").mkdir()
        (self.repo / "tools" / "worktree_verdict.py").write_text("import sys; print('not a pass'); sys.exit(1)\n")
        self.assertIn("keep — verdict is not a pass", self.verdict("hooked"))

    def test_keep_list_wins(self):
        self.add("owned")
        ws.KEEP.write_text("proj/owned  # Eddy's\n")
        self.assertIn("keep list", self.verdict("owned"))

    def test_other_worktrees_and_ruby_and_river_are_ignored(self):
        other = self.root / "elsewhere"
        run(self.repo, "worktree", "add", "-q", "-b", "feature/o", str(other), "origin/main")
        self.assertEqual([l for l in ws.sweep(self.root, [], False) if "elsewhere" in l], [])
        self.assertEqual(ws.repos(self.root), [self.repo])
        ruby = self.root / "rubyandriver_services"
        ruby.mkdir()
        (ruby / ".git").mkdir()
        self.assertEqual(ws.repos(self.root), [self.repo])


if __name__ == "__main__":
    unittest.main()
