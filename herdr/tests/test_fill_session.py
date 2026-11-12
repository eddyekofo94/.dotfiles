"""Master plan B5: a fill opens its tabs in the session that seats the master, not the
caller's (2026-11-12: BS-IOS-FEAT-387 landed in detached window-113 and its fill opened
BS-IOS-FEAT-342 there). With no master live, the tab opens in the caller's session."""
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

    def opened(self, script, master=True):
        if not master:
            (self.sessions / "master-win/herdr.sock").unlink()
        repo, env = repo_with(SPEC)
        (repo / "bin/herdr").write_text(HERDR)
        log = repo / "calls.log"
        env.update(FAKE_LOG=str(log), HERDR_SESSIONS_DIR=str(self.sessions), HERDR_BIN_PATH=str(repo / "bin/herdr"),
                   HERDR_SOCKET_PATH=str(self.sessions / "window-113/herdr.sock"))
        args = ["--fill", str(repo)] if script == "goal_done.sh" else []
        done = subprocess.run(["bash", str(HERE / script), *args], env=env, cwd=repo,
                              capture_output=True, text=True, timeout=90)
        calls = log.read_text().splitlines() if log.exists() else []
        self.assertTrue(calls, done.stdout + done.stderr)
        return calls

    def test_the_reaper_fill_opens_in_the_masters_session(self):
        for call in self.opened("goal_done.sh"):
            self.assertIn("/master-win/herdr.sock|", call)

    def test_herdr_goals_opens_in_the_masters_session(self):
        for call in self.opened("goals.sh"):
            self.assertIn("/master-win/herdr.sock|", call)

    def test_with_no_master_the_tab_opens_in_the_callers_session(self):
        for call in self.opened("goal_done.sh", master=False):
            self.assertIn("/window-113/herdr.sock|", call)


if __name__ == "__main__":
    unittest.main()
