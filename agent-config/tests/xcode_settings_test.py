#!/usr/bin/env python3
"""Cover Xcode's Claude settings: shared settings without the terminal-tab hooks (BS-IOS-TASK-720).

    python3 agent-config/tests/xcode_settings_test.py
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CONFIG = Path(__file__).resolve().parents[1] / "claude"
SCRIPT = CONFIG / "xcode_settings.py"
SHARED = CONFIG / "settings.json"


def commands(settings):
    return [hook["command"] for matchers in settings["hooks"].values()
            for matcher in matchers for hook in matcher["hooks"]]


class XcodeSettings(unittest.TestCase):
    def generate(self, path):
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), str(path)],
                                capture_output=True, text=True, check=True)
        return json.loads(result.stdout)

    def test_shared_settings_lose_only_terminal_hooks(self):
        shared = json.loads(SHARED.read_text())
        xcode = self.generate(SHARED)
        kept = commands(xcode)
        for name in ("closeout.sh", "agent_status.py", "herdr-agent-state.sh", "retro_due.py"):
            self.assertFalse(any(name in command for command in kept), name)
        for name in ("build_budget_guard.py", "context_guard.py", "compact_handoff.py",
                     "bash_output_trim.py"):
            self.assertTrue(any(name in command for command in kept), name)
        self.assertNotIn("statusLine", xcode)
        for key in set(shared) - {"statusLine", "hooks", "env"}:
            self.assertEqual(xcode[key], shared[key], key)
        # The shared env is kept; only PATH is Xcode's, Homebrew's python3 first.
        self.assertEqual({k: v for k, v in xcode["env"].items() if k != "PATH"}, shared.get("env", {}))
        self.assertTrue(xcode["env"]["PATH"].startswith("/opt/homebrew/bin:"))

    def test_event_with_only_terminal_hooks_is_dropped(self):
        shared = {"model": "opus", "hooks": {
            "Stop": [{"hooks": [{"type": "command", "command": "closeout.sh length"}]}],
            "PreToolUse": [{"matcher": "*", "hooks": [
                {"type": "command", "command": "agent_status.py hook"},
                {"type": "command", "command": "build_budget_guard.py"}]}]}}
        with tempfile.NamedTemporaryFile("w", suffix=".json") as handle:
            json.dump(shared, handle)
            handle.flush()
            xcode = self.generate(handle.name)
        self.assertEqual(xcode["model"], "opus")
        self.assertNotIn("Stop", xcode["hooks"])
        self.assertEqual(xcode["hooks"]["PreToolUse"],
                         [{"matcher": "*", "hooks": [
                             {"type": "command", "command": "build_budget_guard.py"}]}])


if __name__ == "__main__":
    unittest.main()
