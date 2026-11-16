import io, json, os, pathlib, subprocess, sys, tempfile, unittest
HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import model_route_warn as m


def line(model, effort):
    return json.dumps({"type": "assistant", "effort": effort, "message": {"model": model, "usage": {}}})


class Warn(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        self.tmp = {**os.environ, "TMPDIR": self.d}

    def run_hook(self, lines, session="s1", **extra):
        t = os.path.join(self.d, "t.jsonl")
        open(t, "w").write("\n".join(lines) + "\n")
        env = {**self.tmp, **extra.pop("env", {})}
        r = subprocess.run([sys.executable, "-I", str(HERE / "model_route_warn.py")], env=env,
                           input=json.dumps({"transcript_path": t, "session_id": session, **extra}),
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0)
        return r.stdout

    def test_opus_outside_build_warns(self):
        out = self.run_hook([line("claude-opus-5-5", "medium")])
        self.assertIn("Opus", json.loads(out)["hookSpecificOutput"]["additionalContext"])

    def test_effort_high_warns(self):
        self.assertIn("effort high", self.run_hook([line("claude-sonnet-5-5", "high")]))

    def test_sonnet_medium_silent(self):
        self.assertEqual(self.run_hook([line("claude-sonnet-5-5", "medium")]), "")

    def test_build_and_spec_exempt(self):
        for cmd in ("build", "spec"):
            head = json.dumps({"type": "user", "message": {"role": "user", "content": f"<command-name>/{cmd}</command-name>"}})
            self.assertEqual(self.run_hook([head, line("claude-opus-5-5", "medium")], session=cmd), "")

    def test_once_per_state(self):
        ls = [line("claude-opus-5-5", "high")]
        self.assertTrue(self.run_hook(ls))
        self.assertEqual(self.run_hook(ls), "")
        self.assertTrue(self.run_hook([line("claude-opus-5-5", "max")]))

    def test_subagent_and_override_silent(self):
        ls = [line("claude-opus-5-5", "high")]
        self.assertEqual(self.run_hook(ls, session="a", agent_id="x"), "")
        self.assertEqual(self.run_hook(ls, session="b", env={"HERDR_ALLOW_HIGH": "1"}), "")

    def test_garbage_silent(self):
        self.assertEqual(self.run_hook(["not json", "{}"]), "")

    def test_last_state_wins(self):
        self.assertEqual(self.run_hook([line("claude-opus-5-5", "high"), line("claude-sonnet-5-5", "medium")]), "")


if __name__ == "__main__":
    unittest.main()
