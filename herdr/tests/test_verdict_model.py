"""The verdict lane opens at the routing table's verdict pair (Sonnet medium;
retro 2026-10-27, BS-IOS-FEAT-478 D11), never a hard-coded model (BS-IOS-FEAT-597).

Both launchers open it: `goals.sh` from /goals, `goal_done.sh` when a build
closes (retro 2026-10-28: all 56 drains in the window opened on Opus there).
test_model_route.py runs the pair end to end.
"""
import pathlib, re, unittest

HERDR = pathlib.Path(__file__).resolve().parents[1]
GOALS = (HERDR / "goals.sh").read_text()
GOAL_DONE = (HERDR / "goal_done.sh").read_text()


class VerdictModel(unittest.TestCase):
    def test_goals_verdict_asks_the_table(self):
        self.assertIn('SPECS+=("verdict")', GOALS)
        self.assertNotIn("verdict:opus", GOALS)
        self.assertIn('verdict) model_route "$REPO" verdict app', GOALS)

    def test_goal_done_opens_verdict_at_the_tables_pair(self):
        tabs = re.findall(r'open_tab .*"/verdict auto" (\S+)', GOAL_DONE)
        self.assertTrue(tabs, "goal_done.sh no longer opens the verdict lane")
        self.assertEqual(set(tabs), {'"$ROUTE_MODEL"'})
        self.assertIn('model_route "$shared" verdict app', GOAL_DONE)


if __name__ == "__main__":
    unittest.main()
