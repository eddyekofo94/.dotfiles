import sys, pathlib, unittest
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from tab_launch_guard import verdict

class Guard(unittest.TestCase):
    def test_high_is_denied(self):
        self.assertTrue(verdict('herdr pane run p "claude --model opus --effort high /spec X"'))
    def test_opus_spec_denied(self):
        self.assertTrue(verdict('claude --model opus --effort medium "/spec X"'))
    def test_build_opus_medium_ok(self):
        self.assertIsNone(verdict('claude --model opus --effort medium "/build X"'))
    def test_sonnet_medium_ok(self):
        self.assertIsNone(verdict('claude --model sonnet --effort medium "/verdict auto"'))
    def test_override(self):
        self.assertIsNone(verdict('HERDR_ALLOW_HIGH=1 claude --effort high x'))
    def test_unrelated(self):
        self.assertIsNone(verdict('ls --effort high'))

if __name__ == "__main__":
    unittest.main()
