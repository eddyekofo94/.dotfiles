#!/usr/bin/env python3
"""Legwork subagents must name Sonnet (retro data-2026-11-11).

    python3 agent-config/tests/legwork_model_guard_test.py
"""
import json
import subprocess
import sys
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parents[1] / "claude" / "build_budget_guard.py"


def run(tool_input, **extra):
    payload = {"tool_name": "Agent", "tool_input": tool_input, **extra}
    out = subprocess.run([sys.executable, "-I", str(HOOK)], input=json.dumps(payload),
                         capture_output=True, text=True)
    return json.loads(out.stdout)["hookSpecificOutput"]["permissionDecision"] if out.stdout else "allow"


class LegworkModel(unittest.TestCase):
    def test_inherited_model_is_denied(self):
        self.assertEqual(run({"subagent_type": "general-purpose", "description": "survey", "prompt": "read-only legwork"}), "deny")

    def test_opus_legwork_is_denied(self):
        self.assertEqual(run({"model": "opus", "description": "survey", "prompt": "x"}), "deny")

    def test_sonnet_is_allowed(self):
        self.assertEqual(run({"model": "sonnet", "description": "survey", "prompt": "x"}), "allow")

    def test_review_may_use_opus(self):
        self.assertEqual(run({"model": "opus", "description": "Review diff", "prompt": "x"}), "allow")

    def test_other_tools_untouched(self):
        payload = {"tool_name": "Bash", "tool_input": {"command": "ls"}}
        out = subprocess.run([sys.executable, "-I", str(HOOK)], input=json.dumps(payload), capture_output=True, text=True)
        self.assertEqual(out.stdout, "")


if __name__ == "__main__":
    unittest.main()
