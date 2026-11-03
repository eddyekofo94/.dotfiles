#!/usr/bin/env python3
"""autoCompactWindow in the committed settings.json and the guard's FALLBACK_WINDOW stay in step.

Retro ios-2026-11-03 (live check, claude 2.1.317): `/autocompact` reports "from settings", so the
setting is honored. Tabs opened before a change keep their old window (compactions at 87k came from
the 120000 value until commit 90cc4e67; tabs opened after it compacted at 151-152k, about 0.82 of
185000). The guard's fallback is the compaction point, so it must sit under the window and near it.
"""
import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = ROOT / "claude" / "context_guard.py"


def committed_window() -> int:
    blob = subprocess.run(["git", "-C", str(ROOT), "show", "HEAD:agent-config/claude/settings.json"],
                          capture_output=True, text=True, check=True).stdout
    return json.loads(blob)["autoCompactWindow"]


class CompactWindowTest(unittest.TestCase):
    def test_fallback_tracks_the_window(self):
        window = committed_window()
        fallback = int(re.search(r"^FALLBACK_WINDOW = ([\d_]+)", GUARD.read_text(), re.M)
                       .group(1).replace("_", ""))
        self.assertLessEqual(fallback, window)
        self.assertGreaterEqual(fallback, 0.75 * window, "guard would warn long before compaction")

    def test_window_is_not_the_old_trial_value(self):
        self.assertGreaterEqual(committed_window(), 150_000)


if __name__ == "__main__":
    unittest.main()
