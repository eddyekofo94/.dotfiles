#!/usr/bin/env python3

import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).parents[1] / "scripts" / "agent_status.py"
SPEC = importlib.util.spec_from_file_location("agent_status", SCRIPT)
assert SPEC and SPEC.loader
agent_status = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(agent_status)


class AgentStatusTests(unittest.TestCase):
    def test_completion_classification(self):
        self.assertEqual(agent_status.classify_message("Done."), "finished")
        self.assertEqual(agent_status.classify_message("Which layout do you prefer?"), "question")
        self.assertEqual(
            agent_status.classify_message("**Status**: AWAITING USER APPROVAL\nWhich layout?"),
            "permission",
        )
        self.assertEqual(
            agent_status.classify_message("```sh\nprintf '?\\n'\n```\nDone."),
            "finished",
        )

    def test_event_mapping(self):
        self.assertEqual(agent_status.state_for_event("session-start", {}), "ready")
        self.assertEqual(agent_status.state_for_event("prompt", {}), "running")
        self.assertEqual(agent_status.state_for_event("permission", {}), "permission")
        self.assertEqual(agent_status.state_for_event("failure", {}), "failed")
        self.assertEqual(
            agent_status.state_for_event("stop", {"last_assistant_message": "Need an answer?"}),
            "question",
        )
        self.assertEqual(
            agent_status.state_for_event("stop", {"terminationReason": "error"}),
            "failed",
        )

    def test_labels(self):
        self.assertEqual(agent_status.truncate_project("BibleStandard"), "BibleStandard")
        self.assertEqual(
            agent_status.truncate_project("VeryLongProjectTitle"),
            "VeryLong…ctTitle",
        )
        self.assertEqual(agent_status.sanitize_label("bad #[format]"), "bad-format")

    def test_process_detection_uses_aliases_and_start_command(self):
        self.assertEqual(agent_status.agent_from_process("antigravity"), "agy")
        self.assertEqual(agent_status.agent_from_process("node", '"exec gemini"'), "gemini")

    def test_multi_agent_render_and_fallback(self):
        panes = [
            {
                "command": "codex",
                "path": "/repo/ignored",
                "agent": "codex",
                "project": ".dotfiles",
                "state": "running",
            },
            {
                "command": "claude",
                "path": "/repo/ignored",
                "agent": "claude",
                "project": "BibleStandard",
                "state": "permission",
            },
            {"command": "nvim", "path": "/repo", "agent": "", "project": "", "state": ""},
        ]
        rendered = agent_status.render_entries(panes, 1, "fallback")
        self.assertIn("codex:.dotfiles", rendered)
        self.assertIn("claude:BibleStandard", rendered)
        self.assertIn("⣽", rendered)
        self.assertIn("", rendered)
        self.assertEqual(rendered.count("#[bold]"), 2)
        self.assertEqual(rendered.count("#[nobold]"), 2)
        self.assertNotIn("nvim:", rendered)
        self.assertEqual(
            agent_status.render_entries([panes[-1]], 1, "nvim"),
            "nvim",
        )

    def test_animation_targets_twelve_frames_per_second(self):
        self.assertAlmostEqual(agent_status.ANIMATION_INTERVAL, 1 / 12)

    def test_render_reports_running_activity(self):
        panes = [
            {
                "command": "codex",
                "path": "/repo",
                "agent": "codex",
                "project": "Project",
                "state": "running",
            }
        ]

        first, first_running = agent_status.render_entries_with_activity(
            panes, 0, "fallback"
        )
        second, second_running = agent_status.render_entries_with_activity(
            panes, 1, "fallback"
        )

        self.assertTrue(first_running)
        self.assertTrue(second_running)
        self.assertNotEqual(first, second)

        crashed, crashed_running = agent_status.render_entries_with_activity(
            [{**panes[0], "command": "fish", "start_command": "fish"}],
            2,
            "fallback",
        )
        self.assertFalse(crashed_running)
        self.assertIn("", crashed)

    def test_failed_state_survives_process_exit(self):
        rendered = agent_status.render_entries(
            [
                {
                    "command": "fish",
                    "path": "/repo",
                    "agent": "agy",
                    "project": "Project",
                    "state": "failed",
                }
            ],
            0,
            "fish",
        )
        self.assertIn("agy:Project", rendered)
        self.assertIn("", rendered)

        crashed_while_running = agent_status.render_entries(
            [
                {
                    "command": "fish",
                    "path": "/repo",
                    "agent": "codex",
                    "project": "Project",
                    "state": "running",
                }
            ],
            0,
            "fish",
        )
        self.assertIn("codex:Project", crashed_while_running)
        self.assertIn("", crashed_while_running)


if __name__ == "__main__":
    unittest.main()
