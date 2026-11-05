#!/usr/bin/env python3
"""close_on_land.py: a tab that landed a second record, or compacted 3+ times, retires itself on LANDED."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "claude" / "close_on_land.py"


def user(text):
    return {"type": "user", "message": {"role": "user", "content": text}}


def result(text):
    return {"type": "user", "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": "t", "content": text}]}}


def compact():
    return {"type": "system", "subtype": "compact_boundary"}


class CloseOnLandTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.log = self.dir / "calls.log"
        stub = self.dir / "herdr-goal-done"
        stub.write_text(f'#!/bin/sh\necho "$@" >> "{self.log}"\n')
        stub.chmod(0o755)

    def tearDown(self):
        self.tmp.cleanup()

    def run_hook(self, events, session="s1", active=False):
        transcript = self.dir / f"{session}.jsonl"
        transcript.write_text("".join(json.dumps(e) + "\n" for e in events))
        env = dict(os.environ, CLOSE_ON_LAND_BIN=str(self.dir / "herdr-goal-done"),
                   CLOSE_ON_LAND_STATE=str(self.dir / "state"), HERDR_TAB_ID="w1:t9")
        payload = {"session_id": session, "transcript_path": str(transcript), "stop_hook_active": active}
        proc = subprocess.run([sys.executable, "-I", str(HOOK)], input=json.dumps(payload),
                              text=True, capture_output=True, env=env, timeout=20)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return proc

    def calls(self):
        import time
        for _ in range(20):
            if self.log.exists():
                break
            time.sleep(0.1)
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_session_6b31c6a5_shape_closes(self):
        events = [user("go")]
        for n in range(8):
            events += [compact()] * 3 + [result(f"merged\nLANDED {n:08x}")]
        events += [user("next"), result("LANDED deadbeef")]
        self.run_hook(events)
        self.assertEqual(len(self.calls()), 1)

    def test_second_landed_record_closes(self):
        self.run_hook([user("go"), result("LANDED 0000aaaa"), user("again"), result("LANDED 0000bbbb")])
        self.assertEqual(len(self.calls()), 1)

    def test_three_compactions_close(self):
        self.run_hook([user("go"), compact(), compact(), compact(), result("LANDED 0000aaaa")])
        self.assertEqual(len(self.calls()), 1)

    def test_first_land_in_fresh_tab_stays(self):
        self.run_hook([user("go"), compact(), result("LANDED 0000aaaa")])
        self.assertEqual(self.calls(), [])

    def test_no_land_this_turn_stays(self):
        self.run_hook([user("go"), result("LANDED 0000aaaa"), result("LANDED 0000bbbb"), user("question")])
        self.assertEqual(self.calls(), [])

    def test_quoted_landed_in_assistant_text_does_not_count(self):
        text = {"type": "assistant", "message": {"role": "assistant", "content": [
            {"type": "text", "text": "LANDED 0000aaaa"}]}}
        self.run_hook([user("go"), compact(), compact(), compact(), text])
        self.assertEqual(self.calls(), [])

    def test_runs_once_per_session(self):
        events = [user("go"), compact(), compact(), compact(), result("LANDED 0000aaaa")]
        self.run_hook(events)
        self.run_hook(events)
        self.assertEqual(len(self.calls()), 1)

    def test_broken_transcript_is_silent(self):
        proc = subprocess.run([sys.executable, "-I", str(HOOK)], input="not json", text=True,
                              capture_output=True, timeout=20)
        self.assertEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
