"""Master plan 1c (M1): `ensure_master.sh` seats the master in tab 1 of the session Eddy
starts in (`main` or `window-N`), `--here` seats a tab where `/master` was typed, and
`herdr-goal-done` never retires the master's seat."""
import os as _os, tempfile as _tempfile  # master plan B6: never find the live master
_os.environ["HERDR_SESSIONS_DIR"] = _tempfile.mkdtemp(prefix="no-master-"); _os.environ["AGENT_STATE_DIR"] = _tempfile.mkdtemp(prefix="state-")
import json, os, pathlib, subprocess, tempfile, textwrap, unittest

HERE = pathlib.Path(__file__).resolve().parents[1]

# A herdr that answers from $FAKE_TABS / $FAKE_PANES and logs every other call.
HERDR = textwrap.dedent("""\
    #!/bin/sh
    [ "$1" = --session ] && shift 2
    case "$1 $2" in
      "tab list") printf '%s' "$FAKE_TABS" ;;
      "pane list") printf '%s' "$FAKE_PANES" ;;
      *) echo "$*" >> "$FAKE_LOG" ;;
    esac
""")


def tabs(*labels):
    return json.dumps({"result": {"tabs": [{"tab_id": f"w1:t{i}", "label": l} for i, l in enumerate(labels, 1)]}})


def panes(*agents):
    return json.dumps({"result": {"panes": [{"tab_id": f"w1:t{i}", "pane_id": f"w1:p{i}", "agent": a,
                                             "cwd": "/tmp"} for i, a in enumerate(agents, 1)]}})


class Seat(unittest.TestCase):
    def setUp(self):
        self.dir = pathlib.Path(tempfile.mkdtemp())
        self.herdr = self.dir / "herdr"
        self.herdr.write_text(HERDR)
        self.herdr.chmod(0o755)
        self.log = self.dir / "calls.log"

    def seat(self, session="main", tab_json=None, pane_json=None, **extra):
        base = {k: v for k, v in os.environ.items() if k != "HERDR_NO_MASTER"}
        env = {**base, "HOME": str(self.dir), "HERDR_BIN_PATH": str(self.herdr),
               "FAKE_LOG": str(self.log), "FAKE_TABS": tab_json or tabs("1"),
               "FAKE_PANES": pane_json or panes(""), "HERDR_BOARD_ORG": "/org", **extra}
        done = subprocess.run(["sh", str(HERE / "ensure_master.sh"), session], env=env,
                              capture_output=True, text=True, timeout=30)
        self.assertEqual(done.returncode, 0, done.stderr)
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_a_fresh_main_session_seats_fable_in_tab_one(self):
        calls = self.seat()
        self.assertEqual(calls[0], "tab rename w1:t1 ✻ master")
        self.assertIn("pane run w1:p1 cd '/org' && env AGENT_ROLE=master AGENT_NAME=master claude --name master --model fable \"/master\"", calls[1])

    def test_a_restart_reseats_a_master_tab_left_without_its_agent(self):
        self.assertEqual(len(self.seat(tab_json=tabs("1 ✻ master", "2 ios"), pane_json=panes("", "claude"))), 2)

    def test_a_live_master_or_someones_tab_is_never_taken_over(self):
        self.assertEqual(self.seat(tab_json=tabs("1 ✻ master"), pane_json=panes("claude")), [])
        self.assertEqual(self.seat(tab_json=tabs("1 notes", "2 ios"), pane_json=panes("", "")), [])

    def test_a_window_session_is_seated_and_the_off_switch_does_nothing(self):
        self.assertEqual(self.seat(session="window-114")[0], "tab rename w1:t1 ✻ master")
        self.log.unlink()
        self.assertEqual(self.seat(HERDR_NO_MASTER="1"), [])

    def here(self, tab_json, tab="w1:t1"):
        base = {k: v for k, v in os.environ.items() if k not in ("HERDR_NO_MASTER", "HERDR_SOCKET_PATH")}
        env = {**base, "HOME": str(self.dir), "HERDR_BIN_PATH": str(self.herdr), "FAKE_LOG": str(self.log),
               "FAKE_TABS": tab_json, "FAKE_PANES": panes("claude"), "HERDR_SESSION": "window-114",
               "HERDR_TAB_ID": tab}
        done = subprocess.run(["sh", str(HERE / "ensure_master.sh"), "--here"], env=env,
                              capture_output=True, text=True, timeout=30)
        return done, (self.log.read_text().splitlines() if self.log.exists() else [])

    def test_master_typed_in_a_tab_labels_that_tab_the_seat(self):
        done, calls = self.here(tabs("1 ios", "2 bs-ios-feat-9"))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(calls, ["tab rename w1:t1 ✻ master"])

    def test_here_refuses_when_another_tab_is_the_master(self):
        done, calls = self.here(tabs("1 ✻ master", "2 ios"), tab="w1:t2")
        self.assertEqual(done.returncode, 3)
        self.assertIn("already sits in window-114 tab w1:t1", done.stderr)
        self.assertEqual(calls, [])
        (self.dir / ".config/herdr").mkdir(parents=True)
        (self.dir / ".config/herdr/no-master").touch()
        self.assertEqual(self.seat(), [])


class GoalDoneGuard(unittest.TestCase):
    def setUp(self):
        self.repo = pathlib.Path(tempfile.mkdtemp())
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        bin_dir = self.repo / "bin"
        bin_dir.mkdir()
        (bin_dir / "herdr").write_text(HERDR)
        (bin_dir / "herdr").chmod(0o755)
        self.env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "FAKE_LOG": str(self.repo / "log"),
                    "FAKE_TABS": tabs("1 ✻ master", "2 bs-ios-feat-9"), "FAKE_PANES": panes("claude", "claude"),
                    "HERDR_GOAL_DONE_AGENT": "claude", "HERDR_CHAIN_PAUSE": str(self.repo / "paused")}
        self.env.pop("AGENT_ROLE", None)

    def done(self, *args, **extra):
        return subprocess.run(["bash", str(HERE / "goal_done.sh"), "--dry-run", *args], cwd=self.repo,
                              env={**self.env, **extra}, capture_output=True, text=True, timeout=60)

    def test_the_master_tab_is_refused_by_label_or_role(self):
        for run in (self.done(HERDR_TAB_ID="w1:t1"), self.done("--tab", "w1:t1"),
                    self.done(HERDR_TAB_ID="w1:t2", AGENT_ROLE="master")):
            self.assertNotEqual(run.returncode, 0)
            self.assertIn("is the master's seat", run.stderr)

    def test_the_master_may_close_a_worker_tab(self):
        run = self.done("--tab", "w1:t2", AGENT_ROLE="master", HERDR_TAB_ID="w1:t1")
        self.assertNotIn("master's seat", run.stderr)


if __name__ == "__main__":
    unittest.main()
