#!/usr/bin/env python3
import json
import sys
import tempfile
import unittest
from pathlib import Path

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


if __name__ == "__main__":
    unittest.main()
