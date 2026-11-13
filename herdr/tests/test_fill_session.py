"""Master plan B5/B6: with a master live, a fill opens no tab; it queues it for the master
(2026-11-12: BS-IOS-FEAT-387 landed in detached window-113 and its fill opened
BS-IOS-FEAT-342 there), and `open-next` opens it in the master's own session.
`tasks` (the master's opener) opens in the master's session. B7: with no master
live the fill still queues; nothing opens itself (the master opens it on seat)."""
import os as _os, tempfile as _tempfile  # master plan B6: never find the live master
_os.environ["HERDR_SESSIONS_DIR"] = _tempfile.mkdtemp(prefix="no-master-"); _os.environ["AGENT_STATE_DIR"] = _tempfile.mkdtemp(prefix="state-")
import os, pathlib, shutil, socket, subprocess, sys, tempfile, textwrap, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from test_batch_dispatch import HERE, SPEC, fill_dry, goals_dry, repo_with  # noqa: E402

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

    def test_open_next_drops_a_row_whose_checkout_is_gone(self):  # BS-IOS-TASK-1738 D6
        self.opened("goal_done.sh", expect_calls=False)
        queued = (self.state / "next.tsv").read_text().splitlines()
        gone = queued[0].split("\t")
        gone[1], gone[2] = str(self.repo / "swept-checkout"), "▸ verdict-drain"
        empty = list(gone)
        empty[1], empty[2] = "", "▸ no-cwd"
        (self.state / "next.tsv").write_text("\n".join(["\t".join(gone), "\t".join(empty), *queued]) + "\n")
        env = {**self.env, "HERDR_SOCKET_PATH": str(self.sessions / "master-win/herdr.sock")}
        done = subprocess.run(["bash", str(HERE / "open_next.sh")], env=env, capture_output=True,
                              text=True, timeout=30)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("dropped verdict-drain — checkout gone", done.stdout)
        self.assertIn("dropped no-cwd — checkout gone", done.stdout)
        creates = [c for c in self.log.read_text().splitlines() if "tab create" in c]
        self.assertEqual(len(creates), len(queued), done.stdout)
        self.assertFalse(any("swept-checkout" in c for c in creates), creates)
        self.assertFalse((self.state / "next.tsv").exists())  # not re-queued

    def test_open_next_forgets_the_fill_push_so_the_same_row_wakes_again(self):
        self.opened("goal_done.sh", expect_calls=False)
        (self.state / "pushed").mkdir(parents=True, exist_ok=True)
        (self.state / "pushed/fill").write_text("fill|hash\n")
        env = {**self.env, "HERDR_SOCKET_PATH": str(self.sessions / "master-win/herdr.sock")}
        dry = subprocess.run(["bash", str(HERE / "open_next.sh"), "--dry-run"], env=env, capture_output=True, text=True)
        self.assertIn("would open: ▸ ", dry.stdout)
        self.assertTrue((self.state / "pushed/fill").exists())  # a dry run takes nothing
        subprocess.run(["bash", str(HERE / "open_next.sh")], env=env, capture_output=True, text=True, timeout=30)
        self.assertFalse((self.state / "pushed/fill").exists())

    def test_herdr_goals_opens_in_the_masters_session(self):
        for call in self.opened("goals.sh"):
            self.assertIn("/master-win/herdr.sock|", call)

    def test_with_no_master_the_fill_still_queues(self):
        calls = self.opened("goal_done.sh", master=False, expect_calls=False)
        self.assertEqual([c for c in calls if "tab create" in c or "pane run" in c], [], self.out)
        self.assertTrue((self.state / "next.tsv").read_text().strip(), self.out)

RESUME = "/verdict auto — resumed: land what is routed first"


class OrphanedDrain(unittest.TestCase):
    """BS-IOS-TASK-1738 D4 (H7-H10): an orphaned drain resumes in its own checkout with no
    `open --place`; capped, held, free with nothing unjudged and no checkout open nothing."""

    def setUp(self):
        self.drain = pathlib.Path(tempfile.mkdtemp(prefix="ios-sessions-")) / "verdict-drain"
        self.drain.mkdir()
        self.addCleanup(shutil.rmtree, self.drain.parent)

    def graph(self, seat, unjudged=0, checkout=None):
        return {"next": [], "resume": [], "unjudged": unjudged, "verdict_seat": seat,
                "verdict_checkout": str(self.drain) if checkout is None else checkout}

    def test_the_fill_resumes_an_orphaned_drain_in_place(self):
        for unjudged in (0, 3):
            out = fill_dry(self.graph("orphaned", unjudged))
            self.assertIn(f"would queue: ▸ verdict-drain — {RESUME}", out)
            self.assertIn(f"  cwd: {self.drain}", out)
            self.assertIn("--permission-mode bypassPermissions", out)
            self.assertNotIn("would run: python3 tools/session_worktree.py open verdict-drain", out)

    def test_tasks_resumes_an_orphaned_drain_in_place(self):
        out = goals_dry(self.graph("orphaned"))
        self.assertIn(f"would open verdict-resume (boot {RESUME})", out)

    def test_the_rest_open_nothing(self):
        for graph in (self.graph("capped", 3), self.graph("held", 3), self.graph("free", 0),
                      self.graph("orphaned", 3, checkout=""), self.graph("orphaned", 3, checkout="/gone/verdict-drain"),
                      {"next": [], "resume": [], "unjudged": 3}):
            for out in (fill_dry(graph), goals_dry(graph)):
                self.assertNotIn("resumed: land", out, graph)
                self.assertNotIn("would queue: ▸ verdict-drain", out, graph)
                self.assertNotIn("would open verdict", out, graph)

    def test_a_free_seat_still_opens_the_drain_by_the_manager(self):
        out = fill_dry(self.graph("free", 2))
        self.assertIn("would run: python3 tools/session_worktree.py open verdict-drain", out)
        self.assertNotIn("resumed: land", out)

    def test_a_live_fill_queues_the_resume_in_the_drain(self):
        repo, env = repo_with(self.graph("orphaned", 1))
        state = repo / "state"
        env.update(AGENT_STATE_DIR=str(state), HERDR_SESSIONS_DIR=str(repo / "none"))
        done = subprocess.run(["bash", str(HERE / "goal_done.sh"), "--fill", str(repo)], env=env, cwd=repo,
                              capture_output=True, text=True, timeout=90)
        rows = [r.split("\t") for r in (state / "next.tsv").read_text().splitlines()]
        self.assertEqual([(r[1], r[2], r[3]) for r in rows], [(str(self.drain), "▸ verdict-drain", RESUME)],
                         done.stdout + done.stderr)
        self.assertIn(f"goal-done: queued {RESUME}", done.stdout + done.stderr)


if __name__ == "__main__":
    unittest.main()
