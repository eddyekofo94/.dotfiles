"""`herdr-goal-done --park --for <ID>`: Eddy's order displaces a still-Ready build; the
park carries the order and the freed lane opens `/build <ID>` before the fill's pick
(BibleStandard BS-IOS-TASK-1250)."""
import json, os, pathlib, subprocess, tempfile, textwrap, unittest
ROUTES = pathlib.Path(__file__).resolve().parents[1] / "tests/fixtures/routes"  # BS-IOS-FEAT-597: never the real iOS table

GOAL_DONE = pathlib.Path(__file__).resolve().parents[1] / "goal_done.sh"


def dry_park(*flags: str) -> str:
    repo = pathlib.Path(tempfile.mkdtemp()) / "app"
    (repo / "tools").mkdir(parents=True)
    rows = [{"id": "BS-IOS-TASK-7"}, {"id": "BS-IOS-TASK-8"}]
    (repo / "tools" / "features_index.py").write_text(
        f"print({json.dumps(json.dumps({'next': rows}))})\n")
    (repo / "tools" / "session_worktree.py").write_text(textwrap.dedent("""
        import sys
        if "--help" in sys.argv: print("usage: open [--place]")
        else: print(0)
    """))
    git = ["git", "-c", "user.name=t", "-c", "user.email=t@t"]
    subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
    subprocess.run([*git, "-C", str(repo), "add", "-A"], check=True)
    subprocess.run([*git, "-C", str(repo), "commit", "-qm", "seed"], check=True)
    tree = repo.parent / "bs-ios-task-6"
    subprocess.run(["git", "-C", str(repo), "worktree", "add", "-q", "-b",
                    "feature/bs-ios-task-6", str(tree)], check=True)
    env = {**os.environ, "HERDR_ROUTES_REPO": str(ROUTES), "HERDR_TAB_ID": "t", "HERDR_GOAL_DONE_AGENT": "claude",
           "HERDR_CHAIN_PAUSE": str(repo / "absent")}
    done = subprocess.run(["bash", str(GOAL_DONE), "--park", *flags, "--dry-run"], cwd=tree,
                          env=env, capture_output=True, text=True)
    return done.stdout + done.stderr


class ParkFor(unittest.TestCase):
    def test_the_order_is_parked_for_and_opens_first(self):
        out = dry_park("--for", "BS-IOS-TASK-8")
        self.assertIn("would run: python3 tools/session_worktree.py park bs-ios-task-6 --for BS-IOS-TASK-8", out)
        advances = [line for line in out.splitlines() if line.startswith("would advance to:")]
        self.assertEqual(advances[0], "would advance to: BS-IOS-TASK-8", out)
        self.assertEqual(sum("BS-IOS-TASK-8" in line for line in advances), 1, "opened once")

    def test_a_plain_park_keeps_the_fill_order(self):
        out = dry_park()
        self.assertIn("would run: python3 tools/session_worktree.py park bs-ios-task-6\n", out)
        self.assertIn("would advance to: BS-IOS-TASK-7", out.splitlines()[
            next(i for i, l in enumerate(out.splitlines()) if l.startswith("would advance to:"))])


if __name__ == "__main__":
    unittest.main()
