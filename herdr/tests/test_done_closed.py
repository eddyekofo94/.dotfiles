"""Done means closed (Eddy, 2026-11-16): a finished tab closes, through one path.
`ensure_master.sh --here` closes the rotated-out master, `goal_done.sh --tab` works from any cwd
and still refuses unmerged work and the master, the reaper closes idle tabs that owe nothing,
and `open-next` closes the tab a queued row came from."""
import importlib.machinery, importlib.util, json, os, pathlib, subprocess, sys, tempfile, textwrap, unittest

HERE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))
loader = importlib.machinery.SourceFileLoader("reap_idle", str(HERE / "reap_idle.py"))
spec = importlib.util.spec_from_loader("reap_idle", loader)
reap = importlib.util.module_from_spec(spec)
sys.modules["reap_idle"] = reap
loader.exec_module(reap)

HERDR = textwrap.dedent("""\
    #!/bin/sh
    [ "$1" = --session ] && shift 2
    case "$1 $2" in
      "tab list") printf '%s' "$FAKE_TABS" ;;
      "pane list") printf '%s' "$FAKE_PANES" ;;
      "tab create") echo '{"result":{"root_pane":{"pane_id":"w1:p9"}}}' ;;
      *) echo "$*" >> "$FAKE_LOG" ;;
    esac
""")


def tabs(*labels):
    return json.dumps({"result": {"tabs": [{"tab_id": f"w1:t{i}", "label": l} for i, l in enumerate(labels, 1)]}})


def panes(*rows):  # (agent, cwd)
    return json.dumps({"result": {"panes": [{"tab_id": f"w1:t{i}", "pane_id": f"w1:p{i}", "agent": a, "cwd": c}
                                            for i, (a, c) in enumerate(rows, 1)]}})


class Fixture(unittest.TestCase):
    def setUp(self):
        self.dir = pathlib.Path(tempfile.mkdtemp())
        (self.dir / "bin").mkdir()
        (self.dir / "bin/herdr").write_text(HERDR)
        (self.dir / "bin/herdr").chmod(0o755)
        self.log = self.dir / "calls.log"
        self.state = self.dir / "state"
        self.state.mkdir()
        self.env = {k: v for k, v in os.environ.items() if k not in ("HERDR_NO_MASTER", "HERDR_SOCKET_PATH", "AGENT_ROLE")}
        self.env.update(PATH=f"{self.dir/'bin'}:{os.environ['PATH']}", HOME=str(self.dir), FAKE_LOG=str(self.log),
                        HERDR_BIN_PATH=str(self.dir / "bin/herdr"), AGENT_STATE_DIR=str(self.state),
                        HERDR_SESSIONS_DIR=str(self.dir / "none"), HERDR_GOAL_DONE_AGENT="claude",
                        HERDR_CHAIN_PAUSE=str(self.dir / "paused"))

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []


class MasterHere(Fixture):
    def here(self, tab_json, pane_json, tab="w1:t1"):
        env = {**self.env, "FAKE_TABS": tab_json, "FAKE_PANES": pane_json, "HERDR_SESSION": "window-114", "HERDR_TAB_ID": tab}
        return subprocess.run(["sh", str(HERE / "ensure_master.sh"), "--here"], env=env, capture_output=True, text=True, timeout=30)

    def test_here_closes_master_prev(self):
        done = self.here(tabs("1 ios", "2 master-prev", "3 ✻ master"), panes(("claude", "/x"), ("claude", "/x"), ("", "/x")), tab="w1:t1")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.calls(), ["tab rename w1:t1 ✻ master", "tab close w1:t2", "tab close w1:t3"])

    def test_here_never_closes_itself(self):
        done = self.here(tabs("1 master-prev", "2 ✻ master"), panes(("claude", "/x"), ("claude", "/x")), tab="w1:t2")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.calls(), ["tab close w1:t1"])  # already the seat: no rename, no self close

    def test_here_refuses_a_live_master_and_closes_nothing(self):
        done = self.here(tabs("1 ✻ master", "2 master-prev", "3 ios"), panes(("claude", "/x"), ("claude", "/x"), ("", "/x")), tab="w1:t3")
        self.assertEqual(done.returncode, 3)
        self.assertEqual(self.calls(), [])


def git(*a, cwd):
    subprocess.run(["git", "-c", "user.email=a@b", "-c", "user.name=t", *a], cwd=cwd, check=True, capture_output=True)


class TabClose(Fixture):
    def setUp(self):
        super().setUp()
        self.repo = self.dir / "repo"
        self.repo.mkdir()
        git("init", "-q", "-b", "main", cwd=self.repo)
        git("commit", "-q", "--allow-empty", "-m", "base", cwd=self.repo)
        self.wt = self.dir / "wt"
        git("worktree", "add", "-q", "-b", "feature/x", str(self.wt), cwd=self.repo)
        self.nogit = self.dir / "elsewhere"
        self.nogit.mkdir()
        self.env.update(FAKE_TABS=tabs("1 ✻ master", "2 ▸ bs-x-feat-1"))

    def record(self, cwd):  # the agent's status file names the tab's checkout
        (self.state / "s.json").write_text(json.dumps({"updated": 1, "cwd": str(cwd), "herdr": {"tab": "w1:t2"}}))

    def run_done(self, tab="w1:t2", pane_cwd=None, caller=None):
        env = {**self.env, "FAKE_PANES": panes(("claude", str(self.nogit)), ("claude", str(pane_cwd or self.nogit)))}
        return subprocess.run(["bash", str(HERE / "goal_done.sh"), "--dry-run", "--no-todo", "--tab", tab],
                              cwd=caller or self.nogit, env=env, capture_output=True, text=True, timeout=60)

    def test_tab_from_a_non_git_caller_cwd_resolves_the_tabs_own_repo(self):
        self.record(self.wt)
        done = self.run_done()
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertNotIn("not in a git repository", done.stderr)
        self.assertIn("would run: herdr tab close w1:t2", done.stdout)

    def test_tab_in_no_repo_and_no_record_still_says_so(self):
        done = self.run_done()
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("not in a git repository", done.stderr)

    def test_tab_with_unmerged_work_is_refused(self):
        (self.wt / "work.txt").write_text("unmerged")
        git("add", "work.txt", cwd=self.wt)
        git("commit", "-q", "-m", "work", cwd=self.wt)
        done = self.run_done(pane_cwd=self.wt)
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("main does not contain feature/x", done.stderr)

    def test_the_master_tab_is_refused_from_any_cwd(self):
        done = self.run_done(tab="w1:t1")
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("master's seat", done.stderr)


def tab(**over):
    base = dict(tab_id="w1:t2", label="2 ▸ bs-x-feat-1", focused=False, status="idle", pane_count=1, quiet_for=900,
                closeout="DONE", cwd="/x")
    base.update(over)
    return reap.Tab(**base)


class ReaperClose(unittest.TestCase):
    def test_a_tab_owing_a_decision_or_judgment_stays(self):
        close, why = reap.decide(tab(owed="decide: bs-x-feat-1 AWAITING USER APPROVAL"), 600)
        self.assertFalse(close)
        self.assertIn("owes", why)

    def test_a_held_tab_stays_and_a_tab_owing_nothing_closes(self):
        with tempfile.TemporaryDirectory() as d:
            hold = pathlib.Path(d, "hold")
            hold.write_text("bs-x-feat-1\n")
            os.environ["HERDR_MASTER_HOLD"] = str(hold)
            try:
                held = reap.held_names()
                self.assertEqual(reap.owed_by(tab(), held), "held in master_hold.txt")
                hold.write_text("")
                os.environ["AGENT_STATE_DIR"] = d
                self.assertEqual(reap.owed_by(tab(), reap.held_names()), "")
            finally:
                os.environ.pop("HERDR_MASTER_HOLD"); os.environ.pop("AGENT_STATE_DIR", None)
        self.assertTrue(reap.decide(tab(), 600)[0])

    def test_a_rotated_out_master_closes_once_idle_but_the_seat_never(self):
        self.assertTrue(reap.decide(tab(label="1 master-prev", closeout=None), 600)[0])
        self.assertFalse(reap.decide(tab(label="1 ✻ master", closeout="DONE"), 600)[0])
        self.assertFalse(reap.decide(tab(label="1 master-prev", closeout=None, status="working"), 600)[0])


class OpenNext(Fixture):
    def test_open_next_closes_the_tab_a_queued_row_came_from(self):
        co = self.dir / "co"
        co.mkdir()
        (self.state / "next.tsv").write_text(f"bs-x-feat-1\t{co}\t▸ bs-x-feat-2\t/build X\techo launch\n")
        fake = self.dir / "goal_done_fake.sh"
        fake.write_text('#!/bin/bash\necho "goal-done $*" >> "$FAKE_LOG"\n')
        env = {**self.env, "HERDR_GOAL_DONE": str(fake), "FAKE_PANES": panes(("claude", "/x")),
               "FAKE_TABS": tabs("1 ✻ master", "2 ▸ bs-x-feat-1")}
        done = subprocess.run(["bash", str(HERE / "open_next.sh")], env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("closed bs-x-feat-1 (tab w1:t2)", done.stdout)
        self.assertIn("goal-done --tab w1:t2 --no-todo", self.calls())


if __name__ == "__main__":
    unittest.main()
