#!/usr/bin/env python3
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class GoalDone(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name) / "repo"
        (self.repo / "herdr").mkdir(parents=True)
        (self.repo / "tools").mkdir()
        (self.repo / "herdr/goal_done.sh").write_text(
            (ROOT / "herdr/goal_done.sh").read_text()
        )
        (self.repo / "tools/features_index.py").write_text("""import json, os
if os.environ.get('EMPTY_RANKING') == '1':
    print(json.dumps({'next': []}))
else:
    print(json.dumps({'next':[{'id':'DF-1','owned_paths':['a','b']}]}))
""")
        (self.repo / "tools/session_worktree.py").write_text("""#!/usr/bin/env python3
import argparse, json, os, sys
parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest='command', required=True)
opening = sub.add_parser('open')
opening.add_argument('slug')
opening.add_argument('--goal')
opening.add_argument('--paths', nargs='*')
args = parser.parse_args()
with open(os.environ['WORKTREE_CALLS'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
if os.environ.get('WORKTREE_FAIL') == '1':
    raise SystemExit(1)
print(os.environ['WORKTREE_PATH'])
""")
        self.bin = self.repo / "bin"
        self.bin.mkdir()
        (self.bin / "herdr").write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ['HERDR_CALLS'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:3] == ['tab', 'create']:
    print('{"result":{"root_pane":{"pane_id":"p-new"}}}')
if sys.argv[1:3] == ['pane', 'get']:
    print(json.dumps({'result': {'pane': {'agent': os.environ.get('TEST_CALLER_AGENT', '')}}}))
""")
        (self.bin / "herdr").chmod(0o755)
        self.command("git", "init", "-b", "main")
        self.command("git", "config", "user.email", "test@example.com")
        self.command("git", "config", "user.name", "Test")
        self.command("git", "add", ".")
        self.command("git", "commit", "-m", "fixture")
        self.worktree_calls = self.repo / "worktree-calls.jsonl"
        self.herdr_calls = self.repo / "herdr-calls.jsonl"

    def tearDown(self):
        self.tmp.cleanup()

    def command(self, *args, env=None):
        return subprocess.run(
            args, cwd=self.repo, env=env, text=True, capture_output=True, check=True
        )

    def invoke(
        self, fail=False, dry_run=False, caller="claude", ranked=True,
        identity_env=None,
    ):
        env = os.environ.copy()
        for name in (
            "HERDR_GOAL_DONE_AGENT", "CLAUDECODE", "CODEX_SESSION_ID",
            "PI_SESSION_ID", "PI_CODING_AGENT_DIR",
        ):
            env.pop(name, None)
        env.update(
            PATH=f"{self.bin}:{env['PATH']}",
            HERDR_TAB_ID="w1:t1",
            HERDR_PANE_ID="w1:p1",
            TEST_CALLER_AGENT=caller,
            EMPTY_RANKING="0" if ranked else "1",
            WORKTREE_CALLS=str(self.worktree_calls),
            HERDR_CALLS=str(self.herdr_calls),
            WORKTREE_PATH=str(self.repo.parent / "repo-sessions/df1"),
            WORKTREE_FAIL="1" if fail else "0",
        )
        if identity_env:
            env.update(identity_env)
        args = ["bash", "herdr/goal_done.sh", "--keep-tab"]
        if dry_run:
            args.append("--dry-run")
        return subprocess.run(
            args, cwd=self.repo,
            env=env, text=True, capture_output=True,
        )

    def calls(self, path):
        return [json.loads(line) for line in path.read_text().splitlines()]

    def test_ranked_goal_passes_plural_owned_paths_to_manager(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.calls(self.worktree_calls),
            [["open", "df1", "--goal", "DF-1", "--paths", "a", "b"]],
        )
        calls = self.calls(self.herdr_calls)
        create = next(call for call in calls if call[:2] == ["tab", "create"])
        self.assertEqual(create[create.index("--label") + 1], "df1")
        self.assertIn("/deliver DF-1", next(call for call in calls if call[:2] == ["pane", "run"])[3])

    def test_manager_refusal_opens_fable_todo_in_shared_checkout(self):
        result = self.invoke(fail=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("opening the planning backlog instead", result.stderr)
        calls = self.calls(self.herdr_calls)
        create = next(call for call in calls if call[:2] == ["tab", "create"])
        self.assertEqual(
            Path(create[create.index("--cwd") + 1]).resolve(), self.repo.resolve()
        )
        self.assertEqual(create[create.index("--label") + 1], "todo")
        launch = next(call for call in calls if call[:2] == ["pane", "run"])[3]
        self.assertIn("--model fable --permission-mode plan", launch)
        self.assertIn('"/todo"', launch)

    def test_dry_run_reports_manager_resolved_destination(self):
        result = self.invoke(dry_run=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("<resolved by repository worktree manager>", result.stdout)
        self.assertFalse(self.worktree_calls.exists())

    def test_todo_preserves_the_current_agent_family(self):
        for caller, expected in (
            ("claude", 'claude --model fable --permission-mode plan "/todo"'),
            ("codex", 'codex "/todo"'),
            ("pi", 'pi "/todo"'),
        ):
            with self.subTest(caller=caller):
                self.herdr_calls.write_text("")
                result = self.invoke(caller=caller, ranked=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = self.calls(self.herdr_calls)
                launch = next(
                    call for call in calls if call[:2] == ["pane", "run"]
                )[3]
                self.assertEqual(launch, expected)

    def test_ranked_delivery_preserves_the_current_agent_family(self):
        for caller, expected in (
            (
                "claude",
                'claude --model opus --permission-mode auto "/deliver DF-1"',
            ),
            ("codex", 'codex "/deliver DF-1"'),
            ("pi", 'pi "/deliver DF-1"'),
        ):
            with self.subTest(caller=caller):
                self.herdr_calls.write_text("")
                self.worktree_calls.write_text("")
                result = self.invoke(caller=caller)
                self.assertEqual(result.returncode, 0, result.stderr)
                launch = next(
                    call for call in self.calls(self.herdr_calls)
                    if call[:2] == ["pane", "run"]
                )[3]
                self.assertEqual(launch, expected)

    def test_environment_fallback_preserves_the_agent_family(self):
        for variable, expected in (
            ("CLAUDECODE", "claude"),
            ("CODEX_SESSION_ID", "codex"),
            ("PI_SESSION_ID", "pi"),
            ("PI_CODING_AGENT_DIR", "pi"),
        ):
            with self.subTest(variable=variable):
                self.herdr_calls.write_text("")
                result = self.invoke(
                    caller="", ranked=False, identity_env={variable: "1"}
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                launch = next(
                    call for call in self.calls(self.herdr_calls)
                    if call[:2] == ["pane", "run"]
                )[3]
                self.assertTrue(launch.startswith(expected), launch)

    def test_explicit_agent_override_wins_and_unknown_refuses_before_mutation(self):
        result = self.invoke(
            caller="claude",
            ranked=False,
            identity_env={"HERDR_GOAL_DONE_AGENT": "pi", "CLAUDECODE": "1"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        launch = next(
            call for call in self.calls(self.herdr_calls)
            if call[:2] == ["pane", "run"]
        )[3]
        self.assertEqual(launch, 'pi "/todo"')

        self.herdr_calls.unlink()
        result = self.invoke(
            caller="claude",
            ranked=False,
            identity_env={"HERDR_GOAL_DONE_AGENT": "unknown"},
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("unsupported caller agent: unknown", result.stderr)
        self.assertFalse(self.herdr_calls.exists())


if __name__ == "__main__":
    unittest.main()
