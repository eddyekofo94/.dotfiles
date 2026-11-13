#!/usr/bin/env python3
"""master_rotation.py: arms on the 8th compaction, injects once armed, rotates only after a fresh handoff."""
import json, os, stat, subprocess, sys, tempfile, time, unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "claude" / "master_rotation.py"


class RotationTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.log = self.dir / "calls.log"
        fake = self.dir / "herdr"
        fake.write_text(f'#!/bin/sh\necho "$@" >> {self.log}\n'
                        '[ "$2" = create ] && echo \'{"result":{"root_pane":{"pane_id":"w1:p9"}}}\'\nexit 0\n')
        fake.chmod(fake.stat().st_mode | stat.S_IEXEC)
        self.env = dict(os.environ, MASTER_DIR=str(self.dir / "master"), HERDR_BIN_PATH=str(fake),
                        HERDR_TAB_ID="w1:t1", CLAUDE_SESSION_ID="s1", AGENT_ROLE="master")
        (self.dir / "master").mkdir()

    def run_mode(self, mode, payload=None, env=None, *args):
        out = subprocess.run([sys.executable, "-I", str(HOOK), mode, *args], input=json.dumps(payload or {}),
                             capture_output=True, text=True, env=env or self.env)
        return out.returncode, out.stdout, out.stderr

    def compact(self, n, **kw):
        for _ in range(n):
            out = self.run_mode("count", {"session_id": "s1", **kw})[1]
        return out

    def test_quiet_until_eighth(self):
        self.assertEqual(self.compact(7), "")
        self.assertIn("compacted 8 times", self.compact(1))

    def test_non_master_and_subagent_ignored(self):
        env = dict(self.env, AGENT_ROLE="worker")
        for _ in range(9):
            self.assertEqual(self.run_mode("count", {"session_id": "s1"}, env)[1], "")
        self.assertEqual(self.compact(9, agent_id="a1"), "")

    def test_resume_only_when_armed(self):
        self.assertEqual(self.run_mode("resume", {"session_id": "s1"})[1], "")
        self.compact(8)
        self.assertIn("ROTATE", self.run_mode("resume", {"session_id": "s1"})[1])

    def test_rotate_refuses_unarmed_and_stale_handoff(self):
        self.assertEqual(self.run_mode("rotate")[0], 2)
        self.compact(8)
        handoff = self.dir / "master" / "handoff.md"
        handoff.write_text("old")
        os.utime(handoff, (time.time() - 100, time.time() - 100))
        self.assertEqual(self.run_mode("rotate")[0], 3)
        self.assertFalse(self.log.exists())

    def test_rotate_makes_three_calls_in_order(self):
        self.compact(8)
        (self.dir / "master" / "handoff.md").write_text("fresh")
        code, out, _ = self.run_mode("rotate")
        self.assertEqual(code, 0, out)
        calls = self.log.read_text().splitlines()
        self.assertTrue(calls[0].startswith("tab rename w1:t1 master-prev"))
        self.assertIn("tab create", calls[1])
        self.assertTrue(calls[2].startswith("pane run w1:p9 env AGENT_ROLE=master"))
        self.assertEqual(self.run_mode("rotate")[0], 2)  # armed file consumed: no second rotation


if __name__ == "__main__":
    unittest.main()
