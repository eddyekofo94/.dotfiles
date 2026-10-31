"""A record the graph marks escalated opens its build tab at high, with its own
boot (BibleStandard BS-IOS-TASK-1140); every other build stays at medium."""
import json, os, pathlib, subprocess, tempfile, textwrap, unittest

GOAL_DONE = pathlib.Path(__file__).resolve().parents[1] / "goal_done.sh"


def dry_fill(rows: list[dict]) -> str:
    repo = pathlib.Path(tempfile.mkdtemp())
    (repo / "tools").mkdir()
    (repo / "tools" / "features_index.py").write_text(
        f"print({json.dumps(json.dumps({'next': rows}))})\n")
    (repo / "tools" / "session_worktree.py").write_text(textwrap.dedent("""
        import sys
        if "--help" in sys.argv: print("usage: open [--place]")
        else: print(0)
    """))
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    env = {**os.environ, "HERDR_TAB_ID": "t", "HERDR_GOAL_DONE_AGENT": "claude",
           "HERDR_CHAIN_PAUSE": str(repo / "absent")}
    done = subprocess.run(["bash", str(GOAL_DONE), "--fill", str(repo), "--dry-run"],
                          env=env, capture_output=True, text=True)
    return done.stdout + done.stderr


class EscalatedEffort(unittest.TestCase):
    def test_an_escalated_row_opens_at_high_with_its_boot(self):
        out = dry_fill([{"id": "BS-IOS-TASK-9", "effort": "high",
                         "boot": "/build BS-IOS-TASK-9 — escalated"}])
        self.assertIn('--effort high --permission-mode auto "/build BS-IOS-TASK-9 — escalated"', out)

    def test_a_plain_row_stays_at_medium(self):
        out = dry_fill([{"id": "BS-IOS-TASK-9"}])
        self.assertIn('--effort medium --permission-mode auto "/build BS-IOS-TASK-9"', out)


if __name__ == "__main__":
    unittest.main()
