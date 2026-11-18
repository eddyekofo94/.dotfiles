#!/usr/bin/env python3
"""reap's continue: which PARTIAL tab gets its own prompt back, and how.

    python3 herdr/tests/test_reap_continue.py                   # every case
    python3 herdr/tests/test_reap_continue.py --lever [--fixture <json>]

`--lever` runs only the API-error case (F-080, BibleStandard BS-IOS-TASK-1526): a tab
whose last turn is an API error gets `continue` once the API answers. A fixture
`{"rev": "<sha>"}` runs it against that revision of reap_idle.py; `{"rev": null}`
against the file on disk. Exit 1 when the case fails.
"""
import importlib.machinery
import importlib.util
import inspect
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

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


def api_error_row(text="API Error: Can't reach the API server (ENOTFOUND)"):
    """The row Claude Code writes when a turn is cut off by the API (`model` `<synthetic>`)."""
    return {"type": "assistant", "timestamp": "2026-10-25T02:59:53.707Z", "isApiErrorMessage": True,
            "apiError": "connection_failed", "message": {"model": "<synthetic>", "usage": {
                "input_tokens": 0, "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0},
                "content": [{"type": "text", "text": text}]}}


def api_error_transcript(directory: str, text: str | None = None) -> Path:
    path = Path(directory) / "s.jsonl"
    rows = [{"type": "assistant", "timestamp": "2026-10-25T02:50:00.000Z",
             "message": {"content": [{"type": "text", "text": "Running the gate."}]}},
            api_error_row(*([text] if text else []))]
    path.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
    return path


def api_error_resumes(module) -> bool:
    """F-080: the transcript ends on an API error and the API answers: reap sends `continue`."""
    with tempfile.TemporaryDirectory() as tmp:
        _, status, move = module.read_transcript(api_error_transcript(tmp))
    t = module.Tab(tab_id="w1:t1", label="2 ▸ fs200", focused=False, status="idle", pane_count=1,
                   cwd="/x/BibleStandard-sessions/fs200", quiet_for=600, closeout=status,
                   next_move=move, context=0, prompt="")
    extra = {"api_up": True} if "api_up" in inspect.signature(module.decide_continue).parameters else {}
    action, _ = module.decide_continue(t, 180, 120_000, {}, "", TODAY, **extra)
    return action == "continue" and module.continue_text(t) == "/build FS-200 continue"


class ApiErrorTest(unittest.TestCase):
    """F-080: three builds sat 30 h after `API Error: ... (ENOTFOUND)` (BS-IOS-TASK-1526)."""

    def test_api_error_reads_as_its_own_status(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, status, move = reap.read_transcript(api_error_transcript(tmp))
        self.assertEqual((status, move), ("API ERROR", ""))

    def test_login_and_model_errors_stay_for_eddy(self):
        for text in ("Please run /login · API Error: 403 Attention Required! | Cloudflare",
                     "There's an issue with the selected model (x). It may not exist (model_not_found)."):
            with tempfile.TemporaryDirectory() as tmp:
                _, status, _ = reap.read_transcript(api_error_transcript(tmp, text))
            self.assertIsNone(status, text)

    def test_continue_once_the_api_answers(self):
        self.assertTrue(api_error_resumes(reap))

    def test_held_while_the_api_is_down(self):
        action, reason = decide(tab(closeout="API ERROR", next_move="", prompt=""))
        self.assertEqual(action, "")
        self.assertIn("API", reason)

    def test_never_clears_and_shares_the_daily_cap(self):
        t = tab(closeout="API ERROR", next_move="", prompt="", context=170_000)
        go = lambda record=None: reap.decide_continue(t, 180, 120_000, record or {}, "", TODAY, api_up=True)
        self.assertEqual(go()[0], "continue")
        self.assertEqual(go({"day": TODAY, "count": 8, "move": ""})[0], "")
        self.assertEqual(go({"day": TODAY, "count": 1, "move": ""})[0], "continue")

    def test_guards_still_hold(self):
        for t in (tab(closeout="API ERROR", focused=True), tab(closeout="API ERROR", quiet_for=60),
                  tab(closeout="API ERROR", label="5 bug242-focus")):
            self.assertEqual(reap.decide_continue(t, 180, 120_000, {}, "", TODAY, api_up=True)[0], "", t)
        held = reap.decide_continue(tab(closeout="API ERROR"), 180, 120_000, {}, "five-hour 93%",
                                    TODAY, api_up=True)
        self.assertEqual(held[0], "")

    def test_plain_continue_off_a_build(self):
        t = tab(label="4 ▸ grill-x", closeout="API ERROR", prompt="")
        self.assertEqual(reap.continue_text(t), "continue")

    def test_any_http_status_means_it_answers(self):
        error = urllib.error.HTTPError("https://api.anthropic.com", 404, "nf", {}, None)
        with mock.patch("urllib.request.urlopen", side_effect=error):
            self.assertTrue(reap.api_answers())
        for down in (urllib.error.URLError("ENOTFOUND"), TimeoutError(), OSError("down")):
            with mock.patch("urllib.request.urlopen", side_effect=down):
                self.assertFalse(reap.api_answers(), down)


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


def lever(argv: list[str]) -> int:
    """The findings ledger's check (F-080): exit 0 when the API-error case passes."""
    rev = None
    if "--fixture" in argv:
        rev = json.loads(Path(argv[argv.index("--fixture") + 1]).read_text()).get("rev")
    module = reap
    if rev:
        source = subprocess.run(["git", "-C", str(HERE.parent), "show", f"{rev}:herdr/reap_idle.py"],
                                capture_output=True, text=True, check=True).stdout
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "reap_idle_rev.py"
            copy.write_text(source)
            old = importlib.machinery.SourceFileLoader("reap_idle_rev", str(copy))
            module = importlib.util.module_from_spec(importlib.util.spec_from_loader("reap_idle_rev", old))
            sys.modules["reap_idle_rev"] = module
            old.exec_module(module)
    ok = api_error_resumes(module)
    print(f"{'pass' if ok else 'FAIL'}: API-error tab {'gets' if ok else 'never gets'} continue"
          f" ({rev or 'reap_idle.py on disk'})")
    return 0 if ok else 1


if __name__ == "__main__":
    if "--lever" in sys.argv[1:]:
        sys.exit(lever(sys.argv[1:]))
    unittest.main()
