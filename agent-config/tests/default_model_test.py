#!/usr/bin/env python3
"""Default model: claude/settings.json "model" stays "sonnet" (retro 2026-10-29).

Builds and /spec get Opus from their launcher flag and skill pin; a hand-opened tab takes this
default. A `/model` pick rewrote it to "opus" on 2026-10-29 and that tab-type ran at 5x the cost.
"""
import json
import unittest
from pathlib import Path

SETTINGS = Path(__file__).resolve().parent.parent / "claude" / "settings.json"


class DefaultModelTest(unittest.TestCase):
    def test_default_model_is_sonnet(self):
        model = json.loads(SETTINGS.read_text()).get("model")
        self.assertEqual(model, "sonnet", f'settings.json "model" is {model!r}; set it back to "sonnet"')


if __name__ == "__main__":
    unittest.main()
