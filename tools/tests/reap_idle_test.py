#!/usr/bin/env python3
import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "herdr"))

import reap_idle  # noqa: E402
from reap_idle import Tab, decide  # noqa: E402

GRACE = 600


def tab(**overrides):
    base = dict(tab_id="w1:t1", label="3 ▸ fs307", focused=False, status="idle", pane_count=1,
                agent="claude", session="s", cwd="/repo", quiet_for=900.0, closeout="DONE")
    base.update(overrides)
    return Tab(**base)


class Decide(unittest.TestCase):
    def test_an_idle_landed_agent_tab_closes(self):
        self.assertEqual(decide(tab(), GRACE)[0], True)

    def test_a_blocked_tab_with_nothing_unlanded_closes(self):
        self.assertEqual(decide(tab(closeout="BLOCKED"), GRACE)[0], True)

    def test_eddys_own_tab_stays(self):
        self.assertEqual(decide(tab(label="1 grill-fs200"), GRACE), (False, "Eddy's tab (no ▸)"))

    def test_focused_working_and_split_tabs_stay(self):
        self.assertEqual(decide(tab(focused=True), GRACE), (False, "focused"))
        self.assertEqual(decide(tab(status="working"), GRACE), (False, "agent working"))
        self.assertEqual(decide(tab(pane_count=2), GRACE), (False, "2 panes"))

    def test_inside_the_grace_period_it_stays(self):
        self.assertEqual(decide(tab(quiet_for=120.0), GRACE), (False, "idle 2m < 10m grace"))

    def test_a_turn_still_talking_to_eddy_stays(self):
        for word in ("WAITING", "AWAITING USER APPROVAL", "PARTIAL", "EDDY SPOKE LAST"):
            self.assertEqual(decide(tab(closeout=word), GRACE), (False, f"last turn {word}"))
        self.assertEqual(decide(tab(closeout=None), GRACE), (False, "last turn has no closeout"))

    def test_no_transcript_stays(self):
        self.assertEqual(decide(tab(agent="codex", quiet_for=None), GRACE),
                         (False, "no transcript for codex"))

    def test_unlanded_work_stays(self):
        self.assertEqual(decide(tab(unlanded=["worktree dirty"]), GRACE),
                         (False, "unlanded: worktree dirty"))


class Fill(unittest.TestCase):
    def test_always_build_reads_one_root_per_line_and_skips_comments(self):
        with tempfile.NamedTemporaryFile("w", delete=False) as handle:
            handle.write("# repos\n~/Code/App  # the app\n\n/abs/Other\n")
        self.addCleanup(Path(handle.name).unlink)
        real = reap_idle.ALWAYS_BUILD
        reap_idle.ALWAYS_BUILD = Path(handle.name)
        self.addCleanup(setattr, reap_idle, "ALWAYS_BUILD", real)
        self.assertEqual(reap_idle.always_build(),
                         [Path("~/Code/App").expanduser(), Path("/abs/Other")])

    def test_new_builds_open_in_the_window_already_showing_the_repo(self):
        tabs = [tab(cwd="/r/App", socket="a"), tab(cwd="/r/App-sessions/fs1", socket="b"),
                tab(cwd="/r/App-sessions/fs2", socket="b"), tab(cwd="/r/Apple", socket="c")]
        self.assertEqual(reap_idle.window_for(Path("/r/App"), tabs), "b")
        self.assertIsNone(reap_idle.window_for(Path("/r/Elsewhere"), tabs))


class Transcript(unittest.TestCase):
    def write(self, *entries):
        handle = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
        for entry in entries:
            handle.write(json.dumps(entry) + "\n")
        handle.close()
        self.addCleanup(Path(handle.name).unlink)
        return Path(handle.name)

    @staticmethod
    def said(text, at="2026-10-04T10:00:00Z"):
        return {"type": "assistant", "timestamp": at,
                "message": {"content": [{"type": "text", "text": text}]}}

    def test_reads_the_last_closeout_and_when_it_spoke(self):
        path = self.write(
            self.said("**Status:** PARTIAL"),
            self.said("done.\n\n**Status:** DONE\n**Next move:** let the chain take FS-343"),
            {"type": "system", "timestamp": "2026-10-04T10:05:00Z"},
        )
        spoke, status, move = reap_idle.read_transcript(path)
        self.assertEqual((status, move), ("DONE", "let the chain take FS-343"))
        self.assertEqual(spoke, 1791108300.0)

    def test_a_prompt_after_the_closeout_makes_it_stale(self):
        path = self.write(
            self.said("**Status:** DONE"),
            {"type": "user", "timestamp": "2026-10-04T10:06:00Z",
             "message": {"content": "wait, one more thing"}},
        )
        self.assertEqual(reap_idle.read_transcript(path)[1], "EDDY SPOKE LAST")

    def test_a_tool_result_is_not_a_prompt(self):
        path = self.write(
            self.said("**Status:** DONE"),
            {"type": "user", "timestamp": "2026-10-04T10:06:00Z",
             "message": {"content": [{"type": "tool_result", "content": "ok"}]}},
        )
        self.assertEqual(reap_idle.read_transcript(path)[1], "DONE")


class RefusedFill(unittest.TestCase):
    """BS-IOS-BUG-410: a pass that leaves a free build lane empty says why, once per change."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.repo = self.root / "App"
        self.held = {"build": 1, "build_cap": 2, "verdict": 1, "verdict_seats": 1}
        self.output = ""
        self.exit = 0
        self.logged = []
        for name, value in (
            ("FILLS", self.root / "fill.json"),
            ("lanes", lambda repo: self.held),
            ("orphaned", lambda repo: False),
            ("window_for", lambda repo, tabs: "sock"),
            ("log", self.logged.append),
        ):
            patcher = mock.patch.object(reap_idle, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        patcher = mock.patch.object(reap_idle.subprocess, "run", self.ran)
        patcher.start()
        self.addCleanup(patcher.stop)

    def ran(self, *_args, **_kwargs):
        return subprocess.CompletedProcess([], self.exit, stdout="", stderr=self.output)

    def fill(self, repo=None):
        before = len(self.logged)
        reap_idle.fill(repo or self.repo, [], False)
        return self.logged[before:]

    def refusal(self, *waits):
        return "".join(f"goal-done: refused: {who} — overlaps a live build: {who} waits on {slug}: its seams overlap\n"
                       for who, slug in waits)

    def test_a_refused_pass_names_each_record_and_its_blocker_once(self):
        self.output = self.refusal(("FS-1", "fs200"), ("FS-2", "fs200"))
        first = self.fill()
        self.assertEqual(len(first), 1, first)
        self.assertIn("FS-1, FS-2", first[0])
        self.assertIn("waits on fs200", first[0])
        self.assertEqual(self.fill(), [])

    def test_a_new_blocker_logs_again(self):
        self.output = self.refusal(("FS-1", "fs200"))
        self.fill()
        self.output = self.refusal(("FS-1", "fs300"))
        self.assertEqual(len(self.fill()), 1)

    def test_figures_in_a_machine_busy_reason_are_not_a_change(self):
        self.output = "goal-done: refused: FS-1 — build lanes full: machine busy: 2.0 GB memory available\n"
        self.assertEqual(len(self.fill()), 1)
        self.output = "goal-done: refused: FS-1 — build lanes full: machine busy: 2.7 GB memory available\n"
        self.assertEqual(self.fill(), [])

    def test_a_full_pass_lets_the_same_refusal_log_again(self):
        self.output = self.refusal(("FS-1", "fs200"))
        self.fill()
        self.held = {**self.held, "build": 2}
        self.assertEqual(self.fill(), [])
        self.held = {**self.held, "build": 1}
        self.assertEqual(len(self.fill()), 1)

    def test_a_build_open_logs_as_before_and_clears_the_memory(self):
        self.output = self.refusal(("FS-1", "fs200"))
        self.fill()
        self.output = "goal-done: opened /build FS-9 in p (claude) — /x\n"
        self.assertTrue(self.fill()[0].startswith("fill: App"))
        self.output = self.refusal(("FS-1", "fs200"))
        self.assertEqual(len(self.fill()), 1)

    def test_a_verdict_tab_alone_is_not_a_build_open(self):
        self.output = self.refusal(("FS-1", "fs200")) + "goal-done: opened /verdict auto in p (claude) — /x\n"
        self.assertTrue(any("waits on fs200" in line for line in self.fill()))

    def test_only_the_retrys_walk_counts(self):
        self.output = (self.refusal(("FS-1", "fs200"))
                       + "goal-done: 1 ranked, none opened — retrying the fill in 20s\n"
                       + self.refusal(("FS-2", "fs300")))
        line = "".join(self.fill())
        self.assertIn("FS-2", line)
        self.assertNotIn("FS-1", line)

    def test_a_paused_chain_and_nothing_ready_are_reasons(self):
        self.output = "goal-done: chain paused (/p) — retiring without opening a tab\n"
        self.assertIn("chain paused", self.fill()[0])
        self.assertEqual(self.fill(), [])
        self.output = "goal-done: nothing Ready — /spec when you have the attention (no tab opened)\n"
        self.assertIn("nothing Ready", self.fill()[0])

    def test_no_window_is_a_reason(self):
        with mock.patch.object(reap_idle, "window_for", lambda repo, tabs: None):
            self.assertIn("no Herdr window", self.fill()[0])

    def test_two_repositories_keep_separate_memories(self):
        self.output = self.refusal(("FS-1", "fs200"))
        self.assertEqual(len(self.fill()), 1)
        self.assertEqual(len(self.fill(self.root / "Other")), 1)
        self.assertEqual(self.fill(), [])

    def test_a_lane_count_failure_is_one_line_and_no_crash(self):
        with mock.patch.object(reap_idle, "lanes", lambda repo: "lane count did not answer in 60 s"):
            self.assertIn("did not answer", self.fill()[0])
            self.assertEqual(self.fill(), [])

    def test_a_dry_run_prints_refusals_and_writes_no_memory(self):
        self.output = self.refusal(("FS-1", "fs200"))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            reap_idle.fill(self.repo, [], True)
        self.assertIn("waits on fs200", out.getvalue())
        self.assertEqual(self.logged, [])
        self.assertFalse((self.root / "fill.json").exists())


    def test_a_live_owners_long_refusal_groups_under_d3s_words(self):
        said = "a live session holds it: Stop and ask Eddy. His exits are the ones to take here"
        self.output = f"goal-done: refused: FS-297 — {said}\ngoal-done: refused: BUG-254 — {said}\n"
        line = self.fill()[0]
        self.assertIn("BUG-254, FS-297 are live sessions' checkouts", line)
        self.assertNotIn("Stop and ask", line)

    def test_a_cap_refusal_keeps_only_its_blocker(self):
        self.output = "goal-done: refused: FS-1 — build lanes full: Eddy has room for a decision.\n"
        line = self.fill()[0]
        self.assertIn("FS-1 build lanes full", line)
        self.assertNotIn("Eddy has room", line)

    def test_a_verdict_tab_over_nothing_ranked_reads_as_nothing_ready(self):
        self.output = "goal-done: opened /verdict auto in p (claude) — /x\n"
        self.assertTrue(any("nothing Ready" in line for line in self.fill()))
        self.output = "goal-done: nothing Ready — /spec when you have the attention (no tab opened)\n"
        self.assertEqual(self.fill(), [])

    def test_a_pass_that_opens_logs_no_refusal_lines_of_its_own(self):
        self.output = self.refusal(("FS-1", "fs200")) + "goal-done: opened /build FS-9 in p (claude) — /x\n"
        self.assertFalse(any("goal-done: refused" in line for line in self.fill()))

    def test_an_unwritable_memory_says_so_and_the_pass_finishes(self):
        (self.root / "file").write_text("")
        self.output = self.refusal(("FS-1", "fs200"))
        with mock.patch.object(reap_idle, "FILLS", self.root / "file/fill.json"):
            lines = self.fill()
        self.assertTrue(any("waits on fs200" in line for line in lines), lines)
        self.assertTrue(any("cannot write" in line for line in lines), lines)

    def test_a_failed_goal_done_says_what_failed(self):
        self.exit = 1
        self.output = "\ngoal-done: jq required\n\n"
        self.assertIn("opened nothing: goal-done failed: goal-done: jq required", self.fill()[0])

    def test_a_silent_failure_gives_its_exit_code(self):
        self.exit = 3
        self.assertIn("opened nothing: goal-done failed: exit 3", self.fill()[0])

    def test_a_failed_pass_still_names_its_refusals(self):
        self.exit = 1
        self.output = self.refusal(("FS-1", "fs200")) + "goal-done: jq required\n"
        self.assertIn("waits on fs200", self.fill()[0])

    def test_a_dry_run_prints_a_verdict_lane_refusal(self):
        self.output = "goal-done: could not open the verdict lane (exit 1)\n"
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            reap_idle.fill(self.repo, [], True)
        self.assertIn("could not open the verdict lane", out.getvalue())


class LaneCount(unittest.TestCase):
    def manager(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        repo = Path(tmp.name)
        (repo / "tools").mkdir()
        (repo / "tools/session_worktree.py").write_text("")
        return repo

    def test_no_manager_stays_silent(self):
        self.assertIsNone(reap_idle.lanes(Path("/nonexistent")))

    def test_a_timeout_is_a_reason(self):
        def slow(*_args, **_kwargs):
            raise subprocess.TimeoutExpired("x", 60)
        with mock.patch.object(reap_idle.subprocess, "run", slow):
            self.assertEqual(reap_idle.lanes(self.manager()), "lane count did not answer in 60 s")

    def test_a_timed_out_count_logs_once_and_the_pass_still_keeps_awake(self):
        repo = self.manager()
        logged, awake = [], mock.Mock()
        def slow(*_args, **_kwargs):
            raise subprocess.TimeoutExpired("x", 60)
        patches = dict(FILLS=repo / "fill.json", LOCK=repo / "lock", log=logged.append, keep_awake=awake,
                       sockets=lambda: [], resume_partial=lambda *a: None, sweep_worktrees=lambda *a: None,
                       always_build=lambda: [repo], reap_simulators=lambda *a: None)
        with mock.patch.multiple(reap_idle, **patches), mock.patch.object(reap_idle.subprocess, "run", slow), \
                mock.patch.object(sys, "argv", ["reap"]):
            self.assertEqual(reap_idle.main(), 0)
            self.assertEqual(reap_idle.main(), 0)
        self.assertEqual([line for line in logged if "did not answer" in line],
                         [f"fill: {repo.name} — lane count did not answer in 60 s"])
        self.assertEqual(awake.call_count, 2)

    def test_unreadable_output_is_a_reason(self):
        for stdout in ("not json", "{}"):
            done = subprocess.CompletedProcess([], 0, stdout=stdout, stderr="")
            with mock.patch.object(reap_idle.subprocess, "run", lambda *a, **k: done):
                self.assertEqual(reap_idle.lanes(self.manager()), "lane count unreadable")


if __name__ == "__main__":
    unittest.main()
