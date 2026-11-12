"""Master plan B8: the master has no SendMessage, so a worker's Stop hook types its
wake line into the master's pane (`wake-master NAME`), once per turn; and `ready judge`
types the verdict back into the worker's pane."""
import json, os, pathlib, shutil, socket, subprocess, sys, tempfile, textwrap, time, unittest

HERE = pathlib.Path(__file__).resolve().parents[1]

HERDR = textwrap.dedent("""\
    #!/bin/sh
    case "$1 $2" in
      "tab list") echo '{"result":{"tabs":[{"tab_id":"w1:t1","label":"1 ✻ master"}]}}' ;;
      "pane list") echo '{"result":{"panes":[{"tab_id":"w1:t1","pane_id":"w1:p1"}]}}' ;;
      "pane run") echo "${HERDR_SOCKET_PATH}|$3|$4" >> "$FAKE_LOG" ;;
    esac
    exit 0
""")


class WakeMaster(unittest.TestCase):
    def setUp(self):
        self.root = pathlib.Path(tempfile.mkdtemp(dir="/tmp", prefix="wm"))  # short: AF_UNIX path cap
        (self.root / "sessions/win").mkdir(parents=True)
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.bind(str(self.root / "sessions/win/herdr.sock"))
        self.addCleanup(lambda: (self.sock.close(), shutil.rmtree(self.root)))
        fake = self.root / "herdr"
        fake.write_text(HERDR)
        fake.chmod(0o755)
        self.state, self.log = self.root / "state", self.root / "calls.log"
        self.state.mkdir()
        self.env = {**os.environ, "AGENT_STATE_DIR": str(self.state), "HERDR_BIN_PATH": str(fake),
                    "HERDR_SESSIONS_DIR": str(self.root / "sessions"), "FAKE_LOG": str(self.log),
                    "HERDR_PANE_ID": "w1:p4", "HERDR_SOCKET_PATH": str(self.root / "sessions/win/herdr.sock"),
                    "AGENT_NAME": "bs-ios-feat-9"}
        self.env.pop("AGENT_ROLE", None)
        (self.state / "s1.json").write_text(json.dumps({
            "session": "s1", "name": "bs-ios-feat-9", "status": "AWAITING USER APPROVAL", "state": "idle",
            "updated": time.time(), "herdr": {"pane": "w1:p4", "socket": self.env["HERDR_SOCKET_PATH"]}}))

    def run_tool(self, *args, **env):
        return subprocess.run([sys.executable, *map(str, args)], env={**self.env, **env},
                              capture_output=True, text=True, timeout=60)

    def sent(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_a_ready_tab_wakes_the_master_once_per_turn(self):
        self.run_tool(HERE / "ready.py", "mark", "BS-IOS-FEAT-9")
        out = self.run_tool(HERE / "wake_master.py", "bs-ios-feat-9").stdout
        self.assertIn("woke the master (w1:p1)", out)
        self.assertEqual(len(self.sent()), 1)
        self.assertTrue(self.sent()[0].endswith("|w1:p1|judge: bs-ios-feat-9 BS-IOS-FEAT-9 (waited 0m)"),
                        self.sent())
        self.assertIn("already sent", self.run_tool(HERE / "wake_master.py", "bs-ios-feat-9").stdout)
        self.assertEqual(len(self.sent()), 1)

    def test_the_master_pane_and_no_master_send_nothing(self):
        self.run_tool(HERE / "ready.py", "mark", "BS-IOS-FEAT-9")
        self.run_tool(HERE / "wake_master.py", "bs-ios-feat-9", HERDR_PANE_ID="w1:p1")
        self.run_tool(HERE / "wake_master.py", "master")
        self.sock.close()
        (self.root / "sessions/win/herdr.sock").unlink()
        self.assertIn("no master sits", self.run_tool(HERE / "wake_master.py", "bs-ios-feat-9").stdout)
        self.assertEqual(self.sent(), [])

    def test_judge_types_the_verdict_into_the_workers_pane(self):
        self.run_tool(HERE / "ready.py", "mark", "BS-IOS-FEAT-9")
        done = self.run_tool(HERE / "ready.py", "judge", "bs-ios-feat-9", "back", "no empty state")
        self.assertEqual(done.stdout.strip(), "sent back: no empty state")
        self.assertIn("sent to w1:p4", done.stderr)
        self.assertTrue(self.sent()[-1].endswith("|w1:p4|sent back: no empty state"), self.sent())


if __name__ == "__main__":
    unittest.main()
