#!/usr/bin/env python3
"""Cover the Read size guard hook (retro 2026-11-07).

    python3 agent-config/tests/read_size_guard_test.py
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parents[1] / "claude" / "read_size_guard.py"


class Guard(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def make(self, name, size):
        path = self.dir / name
        path.write_text("x" * size)
        return str(path)

    def run_hook(self, args, session="s1", tool="Read"):
        env = {**os.environ, "TMPDIR": self.tmp.name}
        out = subprocess.run([sys.executable, "-I", str(HOOK)], env=env, text=True, capture_output=True,
                             input=json.dumps({"tool_name": tool, "session_id": session, "tool_input": args}))
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout) if out.stdout else None

    def test_big_unbounded_read_denied_once(self):
        big = self.make("big.md", 30_000)
        first = self.run_hook({"file_path": big})
        self.assertEqual(first["hookSpecificOutput"]["permissionDecision"], "deny")
        self.assertIn("offset and limit", first["hookSpecificOutput"]["permissionDecisionReason"])
        self.assertIsNone(self.run_hook({"file_path": big}))

    def test_new_session_denied_again(self):
        big = self.make("big.md", 30_000)
        self.run_hook({"file_path": big}, session="a")
        self.assertIsNotNone(self.run_hook({"file_path": big}, session="b"))

    def test_allowed_cases(self):
        small = self.make("small.md", 100)
        big = self.make("big.md", 30_000)
        self.assertIsNone(self.run_hook({"file_path": small}))
        self.assertIsNone(self.run_hook({"file_path": big, "limit": 200}))
        self.assertIsNone(self.run_hook({"file_path": big, "allow_large": True}))
        self.assertIsNone(self.run_hook({"file_path": self.make("a.pdf", 30_000)}))
        self.assertIsNone(self.run_hook({"file_path": str(self.dir / "missing.md")}))
        self.assertIsNone(self.run_hook({"file_path": big}, tool="Bash"))

    def test_bad_input_fails_open(self):
        out = subprocess.run([sys.executable, "-I", str(HOOK)], input="not json", text=True, capture_output=True)
        self.assertEqual((out.returncode, out.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
