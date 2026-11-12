"""Master plan 1e (orders 2026-11-12): a `notify_when_idle` notice wakes the master for
a decision only. `board --wake NAME` says `decide` once per turn for BLOCKED,
AWAITING or PARTIAL, `landed` (exit 2) for a DONE tab whose fill queued tabs for the
master (B6), and `quiet` for a DONE tab with nothing queued or one already escalated."""
import json, os, pathlib, subprocess, sys, tempfile, unittest

HERE = pathlib.Path(__file__).resolve().parents[1]


class Wake(unittest.TestCase):
    def setUp(self):
        self.state = pathlib.Path(tempfile.mkdtemp())

    def write(self, session, name, status, state="idle", updated=1.0):
        (self.state / f"{session}.json").write_text(json.dumps({
            "session": session, "name": name, "status": status, "state": state, "updated": updated,
            "record": "BS-IOS-FEAT-9", "next_move": "👉 Eddy picks the copy", "herdr": {"tab": "w1:t3"}}))

    def wake(self, name):
        done = subprocess.run([sys.executable, str(HERE / "board.py"), "--wake", name], capture_output=True,
                              text=True, env={**os.environ, "AGENT_STATE_DIR": str(self.state)}, timeout=30)
        return done.returncode, done.stdout.strip()

    def test_a_blocked_tab_wakes_the_master_once(self):
        self.write("s1", "ios-home", "BLOCKED")
        code, line = self.wake("ios-home")
        self.assertEqual(code, 0)
        self.assertTrue(line.startswith("decide: ios-home BLOCKED (tab w1:t3, BS-IOS-FEAT-9)"), line)
        self.assertEqual(self.wake("ios-home")[0], 1)
        self.write("s1", "ios-home", "BLOCKED", updated=2.0)  # a new turn blocks again
        self.assertEqual(self.wake("ios-home")[0], 0)

    def test_a_blocked_prompt_and_awaiting_decide(self):
        self.write("s2", "bs-ios-bug-7", "", state="blocked")
        self.assertIn("blocked on a prompt", self.wake("bs-ios-bug-7")[1])
        self.write("s3", "verdict", "AWAITING USER APPROVAL")
        self.assertEqual(self.wake("verdict")[0], 0)

    def test_a_landed_tab_with_nothing_queued_stays_quiet(self):
        self.write("s4", "bs-ios-feat-9", "DONE")
        self.assertEqual(self.wake("bs-ios-feat-9"), (1, "quiet: bs-ios-feat-9 landed (DONE); nothing queued"))

    def test_a_landed_tab_names_what_the_fill_queued(self):  # B6
        self.write("s6", "bs-ios-feat-387", "DONE")
        (self.state / "next.tsv").write_text(
            "bs-ios-feat-387\t/w/342\t▸ bs-ios-feat-342\t/build BS-IOS-FEAT-342\tenv AGENT_NAME=x claude --name x\n")
        self.assertEqual(self.wake("bs-ios-feat-387"),
                         (2, "landed: bs-ios-feat-387; next /build BS-IOS-FEAT-342 (run open-next)"))

    def test_waiting_unknown_and_the_newest_file_rule(self):
        self.write("s5", "spec-batch-home", "WAITING")
        self.assertEqual(self.wake("spec-batch-home")[0], 1)
        self.assertEqual(self.wake("nobody")[0], 1)
        self.write("old", "ios-reader", "BLOCKED", updated=1.0)
        self.write("new", "ios-reader", "DONE", updated=5.0)  # resumed session landed
        self.assertEqual(self.wake("ios-reader")[0], 1)


if __name__ == "__main__":
    unittest.main()
