"""BS-IOS-TASK-1754: the fill never queues a tab next.tsv already has (the queue held 75
rows, 31 for one checkout), and `open-next --drop LABEL` drops a queued tab and asks its
repository to remove the empty checkout."""
import os, pathlib, subprocess, sys, tempfile, textwrap, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import test_fill_session as fs  # noqa: E402  (sets HERDR_SESSIONS_DIR / AGENT_STATE_DIR first)

HERE = fs.HERE
OPEN_NEXT = HERE / "open_next.sh"


def rows(path):
    return [r.split("\t") for r in path.read_text().splitlines()] if path.exists() else []


class FillDedupe(unittest.TestCase):
    setUp, opened = fs.FillSession.setUp, fs.FillSession.opened  # borrowed, not its tests

    def test_a_second_fill_leaves_one_row_per_tab(self):
        self.opened("goal_done.sh", expect_calls=False)
        first = rows(self.state / "next.tsv")
        self.assertTrue(first, self.out)
        again = subprocess.run(["bash", str(HERE / "goal_done.sh"), "--fill", str(self.repo)], env=self.env,
                               cwd=self.repo, capture_output=True, text=True, timeout=90)
        self.assertEqual(rows(self.state / "next.tsv"), first, again.stdout + again.stderr)
        self.assertIn("goal-done: already queued ", again.stdout)

    def test_a_different_label_for_the_same_checkout_still_queues(self):
        self.opened("goal_done.sh", expect_calls=False)
        first = rows(self.state / "next.tsv")
        other = list(first[0])
        other[2] = "▸ another-tab"
        (self.state / "next.tsv").write_text("\t".join(other) + "\n")
        subprocess.run(["bash", str(HERE / "goal_done.sh"), "--fill", str(self.repo)], env=self.env,
                       cwd=self.repo, capture_output=True, text=True, timeout=90)
        self.assertEqual(rows(self.state / "next.tsv"), [other, *first])

    def test_a_different_checkout_with_the_same_label_still_queues(self):
        self.opened("goal_done.sh", expect_calls=False)
        first = rows(self.state / "next.tsv")
        other = list(first[0])
        other[1] = str(self.repo / "elsewhere")
        (self.state / "next.tsv").write_text("\t".join(other) + "\n")
        subprocess.run(["bash", str(HERE / "goal_done.sh"), "--fill", str(self.repo)], env=self.env,
                       cwd=self.repo, capture_output=True, text=True, timeout=90)
        self.assertEqual(rows(self.state / "next.tsv"), [other, *first])


STUB = textwrap.dedent("""\
    import os, sys
    with open(os.environ["REMOVE_LOG"], "a") as f:
        f.write(" ".join(sys.argv[1:]) + "\\n")
    if os.environ.get("REMOVE_REFUSE"):
        print("fatal: contains modified or untracked files", file=sys.stderr)
        print("bs-ios-task-9 holds 1 tracked change(s) no commit has.", file=sys.stderr)
        sys.exit(1)
""")


class Drop(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp(prefix="drop-"))
        self.state = self.tmp / "state"
        self.state.mkdir()
        self.root = self.tmp / "repo"
        git = lambda *a, cwd=None: subprocess.run(["git", *a], cwd=cwd or self.root, check=True,
                                                  capture_output=True)
        self.root.mkdir()
        git("init", "-q", "-b", "main")
        (self.root / "tools").mkdir()
        (self.root / "tools/session_worktree.py").write_text(STUB)
        git("add", ".")
        git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
        self.wt = self.tmp / "sessions/bs-ios-task-9"
        git("worktree", "add", "-q", "-b", "feature/bs-ios-task-9", str(self.wt))
        self.log = self.tmp / "remove.log"
        self.env = {**os.environ, "AGENT_STATE_DIR": str(self.state), "REMOVE_LOG": str(self.log)}
        self.queue = self.state / "next.tsv"

    def row(self, cwd, label):
        return "\t".join(["from", str(cwd), f"▸ {label}", f"/build {label}", "claude"])

    def drop(self, *args, **env):
        return subprocess.run(["bash", str(OPEN_NEXT), "--drop", *args], env={**self.env, **env},
                              capture_output=True, text=True, timeout=30)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_drop_removes_the_rows_and_the_checkout_and_keeps_the_rest(self):
        keep = self.row(self.root, "bs-ios-task-8")
        self.queue.write_text("\n".join([self.row(self.wt, "bs-ios-task-9"), keep,
                                         self.row(self.wt, "bs-ios-task-9")]) + "\n")
        done = self.drop("bs-ios-task-9")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(done.stdout.strip(), "dropped bs-ios-task-9")
        self.assertEqual(self.queue.read_text(), keep + "\n")
        self.assertEqual(self.calls(), ["remove bs-ios-task-9"])

    def test_the_tab_label_with_its_marker_drops_too(self):
        self.queue.write_text(self.row(self.wt, "bs-ios-task-9") + "\n")
        done = self.drop("▸ bs-ios-task-9")
        self.assertEqual(done.stdout.strip(), "dropped bs-ios-task-9")
        self.assertEqual(self.queue.read_text(), "")

    def test_a_refused_remove_keeps_the_checkout_and_still_drops(self):
        self.queue.write_text(self.row(self.wt, "bs-ios-task-9") + "\n")
        done = self.drop("bs-ios-task-9", REMOVE_REFUSE="1")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(done.stdout.splitlines(),
                         ["kept bs-ios-task-9 — bs-ios-task-9 holds 1 tracked change(s) no commit has.",
                          "dropped bs-ios-task-9"])
        self.assertEqual(self.queue.read_text(), "")

    def test_a_shared_tree_is_dropped_as_a_row_only(self):  # F5
        self.queue.write_text(self.row(self.root, "bs-ios-task-9") + "\n")
        done = self.drop("bs-ios-task-9")
        self.assertEqual(done.stdout.strip(), "dropped bs-ios-task-9")
        self.assertEqual(self.calls(), [])

    def test_a_gone_or_empty_cwd_is_dropped_as_a_row_only(self):
        self.queue.write_text("\n".join([self.row(self.tmp / "swept", "bs-ios-task-9"),
                                         self.row("", "bs-ios-task-9")]) + "\n")
        done = self.drop("bs-ios-task-9")
        self.assertEqual(done.stdout.strip(), "dropped bs-ios-task-9")
        self.assertEqual((self.queue.read_text(), self.calls()), ("", []))

    def test_an_absent_or_unlisted_label_changes_nothing(self):  # F3
        self.assertEqual(self.drop("bs-ios-task-9").stdout.strip(), "nothing queued for bs-ios-task-9")
        keep = self.row(self.wt, "bs-ios-task-8") + "\n"
        self.queue.write_text(keep)
        self.assertEqual(self.drop("bs-ios-task-9").stdout.strip(), "nothing queued for bs-ios-task-9")
        self.assertEqual((self.queue.read_text(), self.calls()), (keep, []))

    def test_dry_run_changes_nothing(self):  # F4
        queued = self.row(self.wt, "bs-ios-task-9") + "\n"
        self.queue.write_text(queued)
        done = self.drop("bs-ios-task-9", "--dry-run")
        self.assertEqual(done.stdout.strip(), "would drop bs-ios-task-9")
        self.assertEqual((self.queue.read_text(), self.calls()), (queued, []))

    def test_drop_takes_exactly_one_label(self):  # F4
        for args in ([], ["a", "b"], ["--dry-run"]):
            done = self.drop(*args)
            self.assertEqual(done.returncode, 2, args)
            self.assertIn("usage: open-next --drop LABEL", done.stderr)


if __name__ == "__main__":
    unittest.main()
