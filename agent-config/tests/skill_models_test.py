#!/usr/bin/env python3
"""Skill model pins: /build stays on Opus; /report and /retro run on Sonnet (retro 2026-10-29)."""
import re
import unittest
from pathlib import Path

SKILLS = Path.home() / ".agent-skills"
PINS = {"build": "opus", "report": "sonnet", "retro": "sonnet"}


def model_of(name: str) -> str:
    text = (SKILLS / name / "SKILL.md").read_text()
    front = text.split("---")[1]
    found = re.search(r"^model:\s*(\S+)", front, re.M)
    return found.group(1) if found else ""


class SkillModelTest(unittest.TestCase):
    def test_each_skill_pins_its_model(self):
        for name, model in PINS.items():
            with self.subTest(skill=name):
                self.assertEqual(model_of(name), model)


if __name__ == "__main__":
    unittest.main()
