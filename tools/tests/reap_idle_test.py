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
        return subprocess.CompletedProcess([], 0, stdout="", stderr=self.output)

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

    def test_unreadable_output_is_a_reason(self):
        for stdout in ("not json", "{}"):
            done = subprocess.CompletedProcess([], 0, stdout=stdout, stderr="")
            with mock.patch.object(reap_idle.subprocess, "run", lambda *a, **k: done):
                self.assertEqual(reap_idle.lanes(self.manager()), "lane count unreadable")


if __name__ == "__main__":
    unittest.main()
