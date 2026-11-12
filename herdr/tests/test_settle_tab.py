"""`/focus` opens the settling tab itself (Eddy, 2026-11-03: "when /focus is
called we should run already settled and seek to settle anything on that
track that's not ready to build")."""
import os, pathlib, subprocess, unittest

HERDR = pathlib.Path(__file__).resolve().parents[1]
GOALS = HERDR / "goals.sh"
REPO = pathlib.Path.home() / "Programming/Projects/CanonFidei/biblestandard/ios"


class SettleTab(unittest.TestCase):
    def test_settle_tab_asks_the_routing_table(self):
        # BS-IOS-FEAT-597: no hard-coded model; test_model_route.py runs the pair.
        text = GOALS.read_text()
        self.assertIn('SPECS+=("settle-${slug}:::shared"); BOOTS+=("/spec track ${canon}")', text)
        self.assertIn('model_route "$REPO" spec --record "$first"', text)

    @unittest.skipUnless((REPO / "project/workflow/FOCUS.md").exists(), "no BibleStandard checkout")
    def test_dry_run_boots_spec_track(self):
        run = subprocess.run(["bash", str(GOALS), "--settle", "code quality and motion", "--dry-run"],
                             cwd=REPO, capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("settle-code-quality-and-motion (boot /spec track Code quality and motion)", run.stdout)

    @unittest.skipUnless((REPO / "project/workflow/FOCUS.md").exists(), "no BibleStandard checkout")
    def test_unknown_track_refused(self):
        run = subprocess.run(["bash", str(GOALS), "--settle", "no such track", "--dry-run"],
                             cwd=REPO, capture_output=True, text=True)
        self.assertEqual(run.returncode, 2)


if __name__ == "__main__":
    unittest.main()
