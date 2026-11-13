#!/usr/bin/env python3
"""BS-IOS-TASK-1738 D5: a reap fill that queues a tab wakes the master (`wake_master.py
fill`), logs the queue as it logs an open, and an orphaned verdict drain reaches the fill."""
import subprocess, sys, tempfile, unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))
import reap_idle  # noqa: E402

QUEUED = "goal-done: queued /build BS-IOS-FEAT-9 for the master (open-next) — /w/feat-9"


class FillWake(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.held = {"build": 1, "build_cap": 2, "verdict": 1, "verdict_seats": 1}
        self.calls, self.logged, self.said = [], [], []
        self.goal_done_out, self.wake_exit = QUEUED + "\n", 0
        for name, value in (("FILLS", self.root / "fill.json"), ("lanes", lambda repo: self.held),
                            ("orphaned", lambda repo: False), ("window_for", lambda repo, tabs: "sock"),
                            ("log", self.logged.append),
                            ("say_once", lambda repo, state, line=None: self.said.append(state))):
            patcher = mock.patch.object(reap_idle, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        patcher = mock.patch.object(reap_idle.subprocess, "run", self.ran)
        patcher.start()
        self.addCleanup(patcher.stop)

    def ran(self, args, **kwargs):
        self.calls.append((list(args), kwargs))
        if "wake_master.py" in " ".join(map(str, args)):
            return subprocess.CompletedProcess(args, self.wake_exit, stdout="woke the master (w1:p1): landed: fill\n", stderr="")
        return subprocess.CompletedProcess(args, 0, stdout=self.goal_done_out, stderr="")

    def wakes(self):
        return [(a, k) for a, k in self.calls if any(str(x).endswith("wake_master.py") for x in a)]

    def test_a_fill_that_queues_wakes_the_master(self):
        reap_idle.fill(self.root, [], False)
        wakes = self.wakes()
        self.assertEqual(len(wakes), 1, self.calls)
        args, kwargs = wakes[0]
        self.assertEqual(args, [sys.executable, str(HERE / "wake_master.py"), "fill"])
        self.assertEqual(kwargs.get("timeout"), 10)
        self.assertTrue(kwargs.get("capture_output"))
        self.assertTrue(any(line.startswith("fill: ") for line in self.logged), self.logged)
        self.assertIn(f"  {QUEUED}", self.logged)
        self.assertEqual(self.said, ["opened"])  # H6: a queued /build clears the reason

    def test_a_queued_verdict_tab_wakes_but_keeps_the_reason(self):
        self.goal_done_out = "goal-done: queued /verdict auto for the master (open-next) — /w/vd\n"
        self.held.update(build=2, verdict=0)  # builds full, the verdict seat free
        reap_idle.fill(self.root, [], False)
        self.assertEqual(len(self.wakes()), 1)
        self.assertEqual(self.said, ["full"])

    def test_a_failed_wake_is_logged_and_swallowed(self):
        self.wake_exit = 1
        reap_idle.fill(self.root, [], False)
        self.assertTrue(any("wake-master fill failed" in line for line in self.logged), self.logged)

    def test_a_fill_that_queues_nothing_wakes_nobody(self):
        self.goal_done_out = "goal-done: nothing Ready — /spec when you have the attention (no tab opened)\n"
        reap_idle.fill(self.root, [], False)
        self.assertEqual(self.wakes(), [])


class OrphanedDrain(unittest.TestCase):
    """H5: an orphaned verdict drain passes the full-lane gate like an orphaned build."""

    def focus(self, payload):
        repo = Path(tempfile.mkdtemp())
        (repo / "tools").mkdir()
        (repo / "tools/features_index.py").write_text(f"print({payload!r})\n")
        return reap_idle.orphaned(repo)

    def test_states(self):
        self.assertTrue(self.focus('{"resume": [], "verdict_seat": "orphaned"}'))
        self.assertTrue(self.focus('{"resume": [{"id": "X"}]}'))
        for seat in ("held", "capped", "free"):
            self.assertFalse(self.focus(f'{{"resume": [], "verdict_seat": "{seat}"}}'), seat)


if __name__ == "__main__":
    unittest.main()
