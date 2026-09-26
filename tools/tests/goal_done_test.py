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
graph = {'unjudged': int(os.environ.get('UNJUDGED', '0')), 'eddy_waiting': 7,
         'verdict_seat': os.environ.get('SEAT', 'free')}
if os.environ.get('EMPTY_RANKING') == '1':
    graph['next'] = []
else:
    graph['next'] = [{'id':'DF-1','owned_paths':['a','b']}]
print(json.dumps(graph))
""")
        (self.repo / "tools/session_worktree.py").write_text("""#!/usr/bin/env python3
import argparse, json, os, sys
parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest='command', required=True)
opening = sub.add_parser('open')
opening.add_argument('slug')
opening.add_argument('--goal')
opening.add_argument('--paths', nargs='*')
if os.environ.get('MANAGER_PLACE') == '1':
    opening.add_argument('--place', action='store_true')
removing = sub.add_parser('remove')
removing.add_argument('slug')
removing.add_argument('--delete-branch', action='store_true')
sub.add_parser('park').add_argument('slug')
args = parser.parse_args()
with open(os.environ['WORKTREE_CALLS'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
if args.command != 'open':
    raise SystemExit(0)
if args.slug != 'verdict-drain' and os.environ.get('WORKTREE_EXIT', '0') != '0':
    raise SystemExit(int(os.environ['WORKTREE_EXIT']))
print(os.path.join(os.path.dirname(os.environ['WORKTREE_PATH']), args.slug))
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
        identity_env=None, keep_tab=True, place_manager=False, unjudged=0, seat="free",
        cwd=None, extra=(),
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
            MANAGER_PLACE="1" if place_manager else "0",
            UNJUDGED=str(unjudged),
            SEAT=seat,
        )
        if identity_env:
            env.update(identity_env)
        args = ["bash", str(self.repo / "herdr/goal_done.sh")] + (["--keep-tab"] if keep_tab else [])
        if dry_run:
            args.append("--dry-run")
        args += list(extra)
        return subprocess.run(
            args, cwd=cwd or self.repo,
            env=env, text=True, capture_output=True,
        )

    def opened(self):
        """(label, launch) per tab the run opened."""
        calls = self.calls(self.herdr_calls) if self.herdr_calls.exists() else []
        labels = [c[c.index("--label") + 1] for c in calls if c[:2] == ["tab", "create"]]
        return list(zip(labels, [c[3] for c in calls if c[:2] == ["pane", "run"]]))

    def worktree(self, slug, merged=True):
        """A session checkout beside the repo, as the manager would make it."""
        path = self.repo.parent / "repo-sessions" / slug
        self.command("git", "worktree", "add", "-q", "-b", f"feature/{slug}", str(path), "main")
        if not merged:
            (path / "work").write_text("half-built")
            subprocess.run(["git", "add", "work"], cwd=path, check=True)
            subprocess.run(["git", "commit", "-qm", "work"], cwd=path, check=True)
        return path

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

    def test_nothing_startable_names_grill_next_and_opens_no_tab(self):
        # BibleStandard FS-262 D4: never a grill tab; the line offers it.
        for manager_exit, ranked in ((3, True), (1, True), (0, False)):
            with self.subTest(manager_exit=manager_exit, ranked=ranked):
                self.herdr_calls.write_text("")
                result = self.invoke(manager_exit=manager_exit, ranked=ranked)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("/grill-next when you have the attention (no tab opened)",
                              result.stdout)
                self.assertNotIn("/todo", result.stdout)
                self.assertEqual(self.opened(), [])

    def test_the_refill_opens_builds_then_the_verdict_lane_never_a_grill(self):
        result = self.invoke(unjudged=2, place_manager=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.opened(), [
            ("▸ df1", 'claude --model opus --effort medium --permission-mode auto "/deliver DF-1"'),
            ("▸ verdict-drain",
             'claude --model opus --effort medium --permission-mode auto "/verdict-next agent"'),
        ])
        self.assertEqual(self.calls(self.worktree_calls)[-1], ["open", "verdict-drain", "--place"])

    def test_a_full_build_cap_still_opens_the_verdict_lane(self):
        result = self.invoke(manager_exit=3, unjudged=2)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([label for label, _ in self.opened()], ["▸ verdict-drain"])
        self.assertIn("build lanes full", result.stdout)

    def test_no_verdict_lane_without_unjudged_rows_or_a_free_seat(self):
        for unjudged, seat in ((0, "free"), (2, "held")):
            with self.subTest(unjudged=unjudged, seat=seat):
                self.herdr_calls.write_text("")
                self.invoke(unjudged=unjudged, seat=seat)
                self.assertEqual([label for label, _ in self.opened()], ["▸ df1"])

    def test_the_drains_goal_done_removes_it_with_its_branch(self):
        drain = self.worktree("verdict-drain")
        result = self.invoke(cwd=drain, ranked=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(["remove", "verdict-drain", "--delete-branch"],
                      self.calls(self.worktree_calls))
        self.assertEqual(self.opened(), [], "nothing left: no verdict lane reopens")
        self.assertIn("7 wait on Eddy: /verdict-next", result.stdout)

    def test_park_takes_a_stuck_unmerged_build_instead_of_refusing(self):
        stuck = self.worktree("df9-stuck", merged=False)
        (stuck / "work").write_text("dirty too")
        refused = self.invoke(cwd=stuck, ranked=False)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("--park a stuck build", refused.stderr)
        result = self.invoke(cwd=stuck, ranked=False, extra=("--park",))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(["park", "df9-stuck"], self.calls(self.worktree_calls))
        self.assertNotIn("remove", [c[0] for c in self.calls(self.worktree_calls)])

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
