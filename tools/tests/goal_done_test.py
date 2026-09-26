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
if os.environ.get('MANAGER_CLOSING') == '1':
    opening.add_argument('--place', action='store_true')
    opening.add_argument('--closing', action='store_true')
args = parser.parse_args()
with open(os.environ['WORKTREE_CALLS'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
if os.environ.get('WORKTREE_EXIT', '0') != '0':
    raise SystemExit(int(os.environ['WORKTREE_EXIT']))
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
        self, manager_exit=0, dry_run=False, caller="claude", ranked=True,
        identity_env=None, keep_tab=True, closing_manager=False,
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
            WORKTREE_EXIT=str(manager_exit),
            MANAGER_CLOSING="1" if closing_manager else "0",
        )
        if identity_env:
            env.update(identity_env)
        args = ["bash", "herdr/goal_done.sh"] + (["--keep-tab"] if keep_tab else [])
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
        self.assertEqual(create[create.index("--label") + 1], "▸ df1")
        self.assertIn("/deliver DF-1", next(call for call in calls if call[:2] == ["pane", "run"])[3])

    def test_nothing_startable_names_the_decision_lane_and_opens_no_tab(self):
        # FS-243 D5 as amended (Eddy, 2026-09-25): a decision tab waits on
        # Eddy, so the chain names the lane and opens nothing.
        for manager_exit, ranked, lane in (
            (3, True, "/grill-next"),  # the cap is full
            (1, True, "/todo"),        # the manager refused for another reason
            (0, False, "/todo"),       # nothing ranked
        ):
            with self.subTest(manager_exit=manager_exit, ranked=ranked):
                self.herdr_calls.write_text("")
                result = self.invoke(manager_exit=manager_exit, ranked=ranked)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(
                    f"{lane} when you have the attention (no tab opened)",
                    result.stdout,
                )
                self.assertEqual(
                    [call for call in self.calls(self.herdr_calls)
                     if call[:2] == ["tab", "create"]],
                    [],
                )

    def test_the_closing_tab_gives_its_tab_back_unless_it_stays(self):
        # FS-245 D1: goal-done closes its own tab last, so the tab ceiling
        # counts it as given back — but not under `--keep-tab`.
        for keep_tab, expected in ((False, True), (True, False)):
            with self.subTest(keep_tab=keep_tab):
                self.worktree_calls.write_text("")
                result = self.invoke(keep_tab=keep_tab, closing_manager=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                opened = [call for call in self.calls(self.worktree_calls) if call[0] == "open"]
                self.assertEqual(len(opened), 1, opened)
                self.assertIn("--place", opened[0])
                self.assertEqual("--closing" in opened[0], expected)

    def test_a_manager_without_closing_is_not_passed_it(self):
        result = self.invoke(keep_tab=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("--closing", self.calls(self.worktree_calls)[0])

    def test_exit_3_says_either_count_may_be_full(self):
        # FS-245 D6: exit 3 is the build cap or the tab ceiling; the manager's
        # own lines say which, so this line must not claim one.
        result = self.invoke(manager_exit=3)
        self.assertIn("cap full (builds or tabs", result.stdout)
        self.assertNotIn("build cap full", result.stdout)

    def test_dry_run_reports_manager_resolved_destination(self):
        result = self.invoke(dry_run=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("<resolved by repository worktree manager>", result.stdout)
        self.assertFalse(self.worktree_calls.exists())

    def test_ranked_delivery_preserves_the_current_agent_family(self):
        for caller, expected in (
            (
                "claude",
                'claude --model opus --effort medium --permission-mode auto "/deliver DF-1"',
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
                result = self.invoke(caller="", identity_env={variable: "1"})
                self.assertEqual(result.returncode, 0, result.stderr)
                launch = next(
                    call for call in self.calls(self.herdr_calls)
                    if call[:2] == ["pane", "run"]
                )[3]
                self.assertTrue(launch.startswith(expected), launch)

    def test_explicit_agent_override_wins_and_unknown_refuses_before_mutation(self):
        result = self.invoke(
            caller="claude",
            identity_env={"HERDR_GOAL_DONE_AGENT": "pi", "CLAUDECODE": "1"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        launch = next(
            call for call in self.calls(self.herdr_calls)
            if call[:2] == ["pane", "run"]
        )[3]
        self.assertEqual(launch, 'pi "/deliver DF-1"')

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
