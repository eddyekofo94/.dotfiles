"""The verdict lane runs on Sonnet: it writes records, not code (retro 2026-10-27).

Both launchers open it: `goals.sh` from /goals, `goal_done.sh` when a build
closes (retro 2026-10-28: all 56 drains in the window opened on Opus there).
"""
import pathlib, re, unittest

HERDR = pathlib.Path(__file__).resolve().parents[1]
GOALS = (HERDR / "goals.sh").read_text()
GOAL_DONE = (HERDR / "goal_done.sh").read_text()


class VerdictModel(unittest.TestCase):
    def test_verdict_spec_is_sonnet(self):
        self.assertIn('SPECS+=("verdict:sonnet")', GOALS)
        self.assertNotIn("verdict:opus", GOALS)

    def test_goal_done_opens_verdict_on_sonnet(self):
        tabs = re.findall(r'open_tab .*"/verdict auto" (\w+)', GOAL_DONE)
        self.assertTrue(tabs, "goal_done.sh no longer opens the verdict lane")
        self.assertEqual(set(tabs), {"sonnet"})


if __name__ == "__main__":
    unittest.main()
