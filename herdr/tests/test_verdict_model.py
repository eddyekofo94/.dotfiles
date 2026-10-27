"""The verdict lane runs on Sonnet: it writes records, not code (retro 2026-10-27)."""
import pathlib, re, unittest

SRC = (pathlib.Path(__file__).resolve().parents[1] / "goals.sh").read_text()


class VerdictModel(unittest.TestCase):
    def test_verdict_spec_is_sonnet(self):
        self.assertIn('SPECS+=("verdict:sonnet")', SRC)
        self.assertNotIn("verdict:opus", SRC)


if __name__ == "__main__":
    unittest.main()
