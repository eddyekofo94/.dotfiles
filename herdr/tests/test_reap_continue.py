#!/usr/bin/env python3
"""herdr-reap's continue: which PARTIAL tab gets its own prompt back, and how."""
import importlib.machinery
import importlib.util
import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("reap_idle", str(HERE / "reap_idle.py"))
spec = importlib.util.spec_from_loader("reap_idle", loader)
reap = importlib.util.module_from_spec(spec)
sys.modules["reap_idle"] = reap
loader.exec_module(reap)

TODAY = "2026-10-12"
CLOSEOUT = """Work left.

**Status:** PARTIAL
Picked / gave up / why: x
Not run: y
**Next move:** Fix review items 1-5.

**Ready-to-paste prompt:**
```
FS-200 §3: fold the review.
Stop when the gate passes.
```"""


def tab(**over) -> "reap.Tab":
    base = dict(tab_id="w1:t1", label="2 ▸ fs200", focused=False, status="idle", pane_count=1,
                cwd="/x/BibleStandard-sessions/fs200", quiet_for=600, closeout="PARTIAL",
                next_move="Fix review items 1-5.", context=60_000,
                prompt="FS-200 §3: fold the review.\nStop when the gate passes.")
    base.update(over)
    return reap.Tab(**base)


def decide(t, record=None, hold=""):
    return reap.decide_continue(t, 180, 120_000, record or {}, hold, TODAY)


class DecideContinueTest(unittest.TestCase):
    def test_low_context_continues(self):
        self.assertEqual(decide(tab())[0], "continue")

    def test_full_context_clears_first(self):
        self.assertEqual(decide(tab(context=149_000))[0], "clear")

    def test_eddys_tab_is_never_touched(self):
        self.assertEqual(decide(tab(label="5 bug242-focus")), ("", ""))

    def test_other_closeouts_are_not_continued(self):
        for status in ("AWAITING USER APPROVAL", "WAITING", "DONE", "EDDY SPOKE LAST", None):
            self.assertEqual(decide(tab(closeout=status)), ("", ""), status)

    def test_guards_leave_it(self):
        cases = [tab(focused=True), tab(status="working"), tab(pane_count=2), tab(quiet_for=60),
                 tab(prompt="")]
        for t in cases:
            self.assertEqual(decide(t)[0], "", t)
        self.assertEqual(decide(tab(), hold="five-hour allowance 93% used")[0], "")

    def test_no_progress_stops(self):
        action, reason = decide(tab(), record={"day": TODAY, "count": 1, "move": "Fix review items 1-5."})
        self.assertEqual(action, "")
        self.assertIn("no progress", reason)

    def test_daily_cap(self):
        self.assertEqual(decide(tab(), record={"day": TODAY, "count": 8, "move": "old"})[0], "")
        self.assertEqual(decide(tab(), record={"day": "2026-10-11", "count": 8, "move": "old"})[0],
                         "continue")

    def test_done_state_counts_as_idle(self):
        self.assertEqual(decide(tab(status="done"))[0], "continue")


class BuildRecordTest(unittest.TestCase):
    def test_each_id_form_reads_whole(self):
        """BibleStandard IOS-FEAT-537: `bs-ios-feat-9` is BS-IOS-FEAT-9, never IOS-FEAT-9."""
        cases = {"2 ▸ fs200": "FS-200", "2 ▸ ios-feat-515-x": "IOS-FEAT-515",
                 "2 ▸ bs-ios-feat-9-ids": "BS-IOS-FEAT-9", "2 ▸ bs-ios-bug-10": "BS-IOS-BUG-10",
                 "2 ▸ qa-ios-feat-515-x": "IOS-FEAT-515", "2 ▸ review-bs-ios-bug-9": "BS-IOS-BUG-9"}
        for label, want in cases.items():
            self.assertEqual(reap.build_record(tab(label=label, cwd="")), want, label)


class TextTest(unittest.TestCase):
    def test_build_tab_gets_build_prefix_on_one_line(self):
        self.assertEqual(reap.continue_text(tab()),
                         "/build FS-200 FS-200 §3: fold the review. Stop when the gate passes.")

    def test_grill_tab_sends_prompt_as_is(self):
        t = tab(label="4 ▸ grill-bug254", prompt="/spec BUG-254\nQ4: A")
        self.assertEqual(reap.continue_text(t), "/spec BUG-254 Q4: A")

    def test_prompt_and_context_read_from_transcript(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "s.jsonl"
            entries = [
                {"type": "assistant", "message": {"usage": {"input_tokens": 10,
                 "cache_read_input_tokens": 140_000, "cache_creation_input_tokens": 990},
                 "content": [{"type": "text", "text": CLOSEOUT}]}},
            ]
            path.write_text("\n".join(json.dumps(e) for e in entries) + "\n")
            context, prompt = reap.read_handoff(path)
        self.assertEqual(context, 141_000)
        self.assertEqual(prompt, "FS-200 §3: fold the review.\nStop when the gate passes.")


class AllowanceTest(unittest.TestCase):
    def check(self, payload) -> str:
        with tempfile.TemporaryDirectory() as tmp:
            reap.ALLOWANCE = Path(tmp) / "a.json"
            if payload is not None:
                reap.ALLOWANCE.write_text(json.dumps(payload))
            return reap.allowance_hold(time.time())

    def test_holds_when_low(self):
        self.assertIn("five-hour", self.check({"at": time.time(), "five_hour": 91, "seven_day": 10}))
        self.assertIn("seven-day", self.check({"at": time.time(), "five_hour": 1, "seven_day": 96}))

    def test_open_when_fine_stale_or_missing(self):
        self.assertEqual(self.check({"at": time.time(), "five_hour": 40, "seven_day": 50}), "")
        self.assertEqual(self.check({"at": time.time() - 3600, "five_hour": 99}), "")
        self.assertEqual(self.check(None), "")


if __name__ == "__main__":
    unittest.main()
