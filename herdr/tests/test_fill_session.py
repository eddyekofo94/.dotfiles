"""Master plan B5/B6: with a master live, a fill opens no tab; it queues it for the master
(2026-11-12: BS-IOS-FEAT-387 landed in detached window-113 and its fill opened
BS-IOS-FEAT-342 there), and `herdr-open-next` opens it in the master's own session.
`herdr-goals` (the master's opener) opens in the master's session. With no master live,
the fill opens in the caller's session as before."""
import os as _os, tempfile as _tempfile  # master plan B6: never find the live master
_os.environ["HERDR_SESSIONS_DIR"] = _tempfile.mkdtemp(prefix="no-master-")
import os, pathlib, shutil, socket, subprocess, sys, tempfile, textwrap, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from test_batch_dispatch import HERE, SPEC, repo_with  # noqa: E402

# Answers `tab list` per socket: the master's window shows `1 ✻ master`.
HERDR = textwrap.dedent("""\
    #!/bin/sh
    sock=${HERDR_SOCKET_PATH:-own}
    case "$1 $2" in
      "status server") exit 0 ;;
      "tab list") case "$sock" in */master-win/*) echo '{"result":{"tabs":[{"tab_id":"w1:t1","label":"1 ✻ master"}]}}' ;;
                  *) echo '{"result":{"tabs":[{"tab_id":"w1:t1","label":"1 bs-ios-feat-387"}]}}' ;; esac ;;
      "tab create") echo "$sock|$*" >> "$FAKE_LOG"; echo '{"result":{"root_pane":{"pane_id":"p9"}}}' ;;
      "pane run") echo "$sock|$*" >> "$FAKE_LOG" ;;
    esac
    exit 0
""")


class FillSession(unittest.TestCase):
    def setUp(self):
        self.sessions = pathlib.Path(tempfile.mkdtemp(dir="/tmp", prefix="fs"))  # short: AF_UNIX path cap
        self.socks = []
        for win in ("master-win", "window-113"):
            (self.sessions / win).mkdir()
            s = socket.socket(socket.AF_UNIX)
            s.bind(str(self.sessions / win / "herdr.sock"))
            self.socks.append(s)
        self.addCleanup(lambda: ([s.close() for s in self.socks], shutil.rmtree(self.sessions)))

    def opened(self, script, master=True, expect_calls=True):
        if not master:
            (self.sessions / "master-win/herdr.sock").unlink()
        repo, env = repo_with(SPEC)
        (repo / "bin/herdr").write_text(HERDR)
        log = repo / "calls.log"
        self.state = repo / "state"
        env.update(AGENT_STATE_DIR=str(self.state), AGENT_NAME="bs-ios-feat-387")
        env.update(FAKE_LOG=str(log), HERDR_SESSIONS_DIR=str(self.sessions), HERDR_BIN_PATH=str(repo / "bin/herdr"),
                   HERDR_SOCKET_PATH=str(self.sessions / "window-113/herdr.sock"))
        args = ["--fill", str(repo)] if script == "goal_done.sh" else []
        done = subprocess.run(["bash", str(HERE / script), *args], env=env, cwd=repo,
                              capture_output=True, text=True, timeout=90)
        calls = log.read_text().splitlines() if log.exists() else []
        if expect_calls:
            self.assertTrue(calls, done.stdout + done.stderr)
        self.env, self.repo, self.log, self.out = env, repo, log, done.stdout + done.stderr
        return calls

    def test_with_a_master_live_the_fill_queues_and_opens_nothing(self):
        calls = self.opened("goal_done.sh", expect_calls=False)
        self.assertEqual([c for c in calls if "tab create" in c or "pane run" in c], [], self.out)
        rows = [r.split("\t") for r in (self.state / "next.tsv").read_text().splitlines()]
        self.assertTrue(rows, self.out)
        self.assertTrue(all(r[0] == "bs-ios-feat-387" and r[2].startswith("▸ ") and "--name " in r[4]
                            for r in rows), rows)

    def test_open_next_opens_the_queue_once_in_its_own_session(self):
        self.opened("goal_done.sh", expect_calls=False)
        queued = (self.state / "next.tsv").read_text()
        env = {**self.env, "HERDR_SOCKET_PATH": str(self.sessions / "master-win/herdr.sock")}
        (self.state / "next.tsv").write_text(queued + queued)  # two fills queued the same tab
        done = subprocess.run(["bash", str(HERE / "open_next.sh")], env=env, capture_output=True,
                              text=True, timeout=30)
        self.assertEqual(done.returncode, 0, done.stderr)
        creates = [c for c in self.log.read_text().splitlines() if "tab create" in c]
        self.assertEqual(len(creates), len(queued.splitlines()), done.stdout)
        self.assertTrue(all("/master-win/herdr.sock|" in c for c in creates), creates)
        self.assertIn("opened ", done.stdout)
        self.assertFalse((self.state / "next.tsv").exists())
        again = subprocess.run(["bash", str(HERE / "open_next.sh")], env=env, capture_output=True, text=True)
        self.assertEqual(again.stdout.strip(), "nothing queued")

    def test_herdr_goals_opens_in_the_masters_session(self):
        for call in self.opened("goals.sh"):
            self.assertIn("/master-win/herdr.sock|", call)

    def test_with_no_master_the_tab_opens_in_the_callers_session(self):
        for call in self.opened("goal_done.sh", master=False):
            self.assertIn("/window-113/herdr.sock|", call)


if __name__ == "__main__":
    unittest.main()
