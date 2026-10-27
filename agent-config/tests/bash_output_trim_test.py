#!/usr/bin/env python3
"""Cover the Bash output trim hook (retro 2026-10-27).

    python3 agent-config/tests/bash_output_trim_test.py
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parents[1] / "claude" / "bash_output_trim.py"


class Trim(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def run_hook(self, payload, raw=None):
        env = {**os.environ, "TMPDIR": self.tmp.name}
        return subprocess.run([sys.executable, "-I", str(HOOK)],
                              input=raw if raw is not None else json.dumps(payload),
                              capture_output=True, text=True, env=env)

    def payload(self, out="", err="", tool="Bash", **extra):
        response = {"stdout": out, "stderr": err, "interrupted": False, "isImage": False, **extra}
        return {"session_id": "s1", "tool_use_id": "tu1", "tool_name": tool, "tool_response": response}

    def test_short_output_is_untouched(self):
        out = self.run_hook(self.payload("a" * 8000, "e" * 8000))
        self.assertEqual((out.returncode, out.stdout), (0, ""))

    def test_long_output_keeps_head_tail_and_shape(self):
        text = "H" * 3000 + "M" * 10000 + "T" * 3000
        out = self.run_hook(self.payload(text, "warn", extra_key=7))
        result = json.loads(out.stdout)["hookSpecificOutput"]
        self.assertEqual(result["hookEventName"], "PostToolUse")
        new = result["updatedToolOutput"]
        self.assertEqual(set(new), {"stdout", "stderr", "interrupted", "isImage", "extra_key"})
        self.assertEqual((new["stderr"], new["interrupted"], new["extra_key"]), ("warn", False, 7))
        self.assertTrue(new["stdout"].startswith("H" * 3000) and new["stdout"].endswith("T" * 3000))
        self.assertNotIn("M", new["stdout"].replace("trimmed", "").replace("characters", ""))
        self.assertLess(len(new["stdout"]), 6300)
        self.assertIn("10000 characters trimmed", new["stdout"])

    def test_log_holds_the_full_text(self):
        text = "".join(f"line {i}\n" for i in range(3000))
        out = self.run_hook(self.payload(text))
        log = Path(self.tmp.name) / "claude-bash-output" / "s1-tu1.log"
        self.assertEqual(log.read_text(), text)
        self.assertIn(str(log), json.loads(out.stdout)["hookSpecificOutput"]["updatedToolOutput"]["stdout"])

    def test_long_stderr_alone_is_trimmed(self):
        out = self.run_hook(self.payload("ok", "E" * 9000))
        new = json.loads(out.stdout)["hookSpecificOutput"]["updatedToolOutput"]
        self.assertEqual(new["stdout"], "ok")
        self.assertLess(len(new["stderr"]), 6300)

    def test_other_tools_and_bad_input_fail_open(self):
        for case in (self.run_hook(self.payload("x" * 20000, tool="Read")),
                     self.run_hook(None, raw="not json"),
                     self.run_hook({"tool_name": "Bash", "tool_response": "a string"}),
                     self.run_hook({"tool_name": "Bash", "tool_response": {"stdout": 5, "stderr": ""}})):
            self.assertEqual((case.returncode, case.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
