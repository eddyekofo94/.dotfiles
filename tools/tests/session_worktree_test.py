#!/usr/bin/env python3
import fcntl
import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "session_worktree.py"


class Worktrees(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "dotfiles"
        self.root.mkdir()
        self.command("git", "init", "-b", "main")
        self.command("git", "config", "user.email", "test@example.com")
        self.command("git", "config", "user.name", "Test")
        (self.root / "a").write_text("a")
        (self.root / "b").write_text("b")
        (self.root / "area").mkdir()
        (self.root / "area/file").write_text("nested")
        (self.root / "tools").mkdir()
        (self.root / "tools/session_worktree.py").write_text(SCRIPT.read_text())
        self.command("git", "add", ".")
        self.command("git", "commit", "-m", "base")

    def tearDown(self):
        self.tmp.cleanup()

    def command(self, *args, cwd=None, env=None):
        return subprocess.run(args, cwd=cwd or self.root, env=env, text=True,
                              capture_output=True, check=True)

    def invoke(self, *args):
        return subprocess.run(["python3", "tools/session_worktree.py", *args],
                              cwd=self.root, text=True, capture_output=True)

    def worktree(self, slug):
        return self.root.parent / "dotfiles-sessions" / slug

    def claims(self):
        return json.loads((self.root / ".git/named-worktree-claims.json").read_text())

    def test_create_and_reuse_return_the_same_declared_path(self):
        created = self.invoke("create", "one", "--path", "a")
        reused = self.invoke("open", "one", "--path", "a")
        self.assertEqual(created.returncode, 0, created.stderr)
        self.assertEqual(reused.returncode, 0, reused.stderr)
        self.assertEqual(created.stdout, reused.stdout)
        self.assertEqual(Path(created.stdout.strip()).resolve(), self.worktree("one").resolve())
        self.assertEqual(self.claims(), {"one": ["a"]})

    def test_dirty_shared_checkout_refuses_without_mutation(self):
        (self.root / "a").write_text("dirty")
        result = self.invoke("open", "one", "--path", "a")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("shared checkout is dirty", result.stderr)
        self.assertFalse(self.worktree("one").exists())
        self.assertFalse((self.root / ".git/named-worktree-claims.json").exists())

    def test_malformed_names_refuse_without_mutation(self):
        for name in ("Upper", "two words", "-leading", "trailing-", "../escape"):
            with self.subTest(name=name):
                args = ("open", "--path", "a", "--", name) if name.startswith("-") else (
                    "open", name, "--path", "a")
                result = self.invoke(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("lower-case kebab-case", result.stderr)
        self.assertFalse((self.root.parent / "dotfiles-sessions").exists())

    def test_existing_path_with_wrong_branch_refuses_without_claim(self):
        target = self.worktree("one")
        target.parent.mkdir()
        self.command("git", "worktree", "add", "-b", "feature/wrong", str(target),
                     "main")
        result = self.invoke("open", "one", "--path", "a")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("worktree mismatch", result.stderr)
        self.assertFalse((self.root / ".git/named-worktree-claims.json").exists())

    def test_existing_branch_without_expected_worktree_refuses(self):
        self.command("git", "branch", "feature/one")
        result = self.invoke("open", "one", "--path", "a")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("branch exists without expected worktree", result.stderr)
        self.assertFalse(self.worktree("one").exists())
        self.assertFalse((self.root / ".git/named-worktree-claims.json").exists())

    def test_close_removes_clean_merged_worktree_and_releases_claim(self):
        self.invoke("open", "one", "--path", "a")
        result = self.invoke("remove", "one")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.worktree("one").exists())
        self.assertEqual(self.claims(), {})
        reopened = self.invoke("open", "two", "--path", "a")
        self.assertEqual(reopened.returncode, 0, reopened.stderr)

    def test_close_refuses_dirty_worktree_and_retains_claim(self):
        self.invoke("open", "one", "--path", "a")
        (self.worktree("one") / "a").write_text("dirty")
        result = self.invoke("close", "one")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("worktree is dirty", result.stderr)
        self.assertTrue(self.worktree("one").exists())
        self.assertEqual(self.claims(), {"one": ["a"]})

    def test_close_refuses_clean_unmerged_worktree_and_retains_claim(self):
        self.invoke("open", "one", "--path", "a")
        tree = self.worktree("one")
        (tree / "a").write_text("committed")
        self.command("git", "add", "a", cwd=tree)
        self.command("git", "commit", "-m", "unmerged", cwd=tree)
        result = self.invoke("close", "one")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not contained in main", result.stderr)
        self.assertTrue(tree.exists())
        self.assertEqual(self.claims(), {"one": ["a"]})

    def test_collision_and_transfer(self):
        self.assertEqual(self.invoke("open", "one", "--path", "a").returncode, 0)
        self.assertNotEqual(self.invoke("open", "two", "--path", "a").returncode, 0)
        self.assertEqual(self.invoke("open", "two", "--path", "b").returncode, 0)
        self.assertEqual(self.invoke("transfer", "one", "two", "--path", "a").returncode, 0)
        self.assertEqual(self.claims(), {"one": [], "two": ["a", "b"]})

    def test_transfer_carves_one_file_out_of_a_folder_claim(self):
        (self.root / "herdr").mkdir()
        (self.root / "herdr/x.sh").write_text("x")
        (self.root / "herdr/y.sh").write_text("y")
        self.command("git", "add", "herdr")
        self.command("git", "commit", "-m", "herdr fixture")
        folder = self.invoke("open", "folder", "--path", "herdr")
        self.assertEqual(folder.returncode, 0, folder.stderr)
        refused = self.invoke("open", "fix", "--path", "herdr/x.sh")
        self.assertIn("paths owned by folder: herdr/x.sh; use transfer", refused.stderr)

        # The target need not be open; it owns the file before its worktree exists.
        moved = self.invoke("transfer", "folder", "fix", "--path", "herdr/x.sh")
        self.assertEqual(moved.returncode, 0, moved.stderr)
        self.assertEqual(self.claims(),
                         {"folder": ["!herdr/x.sh", "herdr"], "fix": ["herdr/x.sh"]})
        opened = self.invoke("open", "fix", "--path", "herdr/x.sh")
        self.assertEqual(opened.returncode, 0, opened.stderr)
        self.assertEqual(Path(opened.stdout.strip()).resolve(), self.worktree("fix").resolve())

        # The folder goal keeps the rest of herdr, and reopening keeps the carve-out.
        self.assertNotEqual(self.invoke("open", "other", "--path", "herdr/y.sh").returncode, 0)
        self.assertNotEqual(self.invoke("open", "other", "--path", "herdr").returncode, 0)
        reopened = self.invoke("open", "folder", "--path", "herdr")
        self.assertEqual(reopened.returncode, 0, reopened.stderr)
        self.assertEqual(self.claims()["folder"], ["!herdr/x.sh", "herdr"])

        # A carved-out file cannot be handed out a second time by the folder goal.
        again = self.invoke("transfer", "folder", "other", "--path", "herdr/x.sh")
        self.assertNotEqual(again.returncode, 0)
        self.assertIn("source does not own every transferred path", again.stderr)

        # Handing it back folds it into the folder claim again.
        back = self.invoke("transfer", "fix", "folder", "--path", "herdr/x.sh")
        self.assertEqual(back.returncode, 0, back.stderr)
        self.assertEqual(self.claims(), {"folder": ["herdr"], "fix": []})

    def test_claims_are_canonical_and_ancestor_overlaps_are_rejected(self):
        opened = self.invoke("open", "one", "--path", "./area/file")
        self.assertEqual(opened.returncode, 0, opened.stderr)
        self.assertEqual(self.claims(), {"one": ["area/file"]})
        conflict = self.invoke("open", "two", "--path", "area")
        self.assertNotEqual(conflict.returncode, 0)
        self.assertIn("paths owned by one: area", conflict.stderr)
        root_conflict = self.invoke("open", "three", "--path", ".")
        self.assertNotEqual(root_conflict.returncode, 0)
        self.assertIn("paths owned by one: .", root_conflict.stderr)

    def test_claim_transaction_waits_for_repository_lock(self):
        lock_path = self.root / ".git/named-worktree-claims.lock"
        lock_path.touch()
        with lock_path.open("a+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            process = subprocess.Popen(
                ["python3", "tools/session_worktree.py", "open", "one", "--path", "a"],
                cwd=self.root, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            time.sleep(0.1)
            self.assertIsNone(process.poll(), "open bypassed the repository claim lock")
        stdout, stderr = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual(Path(stdout.strip()).resolve(), self.worktree("one").resolve())

    def test_herdr_tab_uses_exact_worktree_path_for_declared_paths(self):
        (self.root / "herdr").mkdir()
        goals = self.root / "herdr/goals.sh"
        goals.write_text((SCRIPT.parents[1] / "herdr/goals.sh").read_text())
        goals.chmod(0o755)
        bin_dir = self.root / "test-bin"
        bin_dir.mkdir()
        calls = self.root.parent / "herdr-calls.jsonl"
        stub = bin_dir / "herdr"
        stub.write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ['HERDR_CALLS'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:3] == ['status', 'server']:
    raise SystemExit(0)
if sys.argv[1:3] == ['tab', 'create']:
    print('{\"result\":{\"root_pane\":{\"pane_id\":\"p1\"}}}')
""")
        stub.chmod(0o755)
        self.command("git", "add", ".")
        self.command("git", "commit", "-m", "integration fixture")
        env = os.environ.copy()
        env.update(HERDR_GOALS_REPO=str(self.root.resolve()), HERDR_CALLS=str(calls),
                   PATH=f"{bin_dir}:{env['PATH']}")
        result = subprocess.run([str(goals), "one:opus::one:a,b"], cwd=self.root,
                                env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = [json.loads(line) for line in calls.read_text().splitlines()]
        create = next((call for call in recorded if call[:2] == ["tab", "create"]), None)
        self.assertIsNotNone(create, f"stdout={result.stdout!r} stderr={result.stderr!r} calls={recorded!r}")
        self.assertEqual(Path(create[create.index("--cwd") + 1]).resolve(),
                         self.worktree("one").resolve())
        self.assertEqual(create[create.index("--label") + 1], "▸ one")
        self.assertEqual(self.claims(), {"one": ["a", "b"]})

        (self.root / "a").write_text("dirty")
        failed = subprocess.run([str(goals), "two:opus::two:a"], cwd=self.root,
                                env=env, text=True, capture_output=True)
        self.assertEqual(failed.returncode, 0)
        self.assertIn("could not open worktree two", failed.stderr)
        after_failure = [json.loads(line) for line in calls.read_text().splitlines()]
        creates = [call for call in after_failure if call[:2] == ["tab", "create"]]
        self.assertEqual(len(creates), 1)

    def test_herdr_tab_from_linked_worktree_keeps_declared_paths(self):
        (self.root / "herdr").mkdir()
        goals = self.root / "herdr/goals.sh"
        goals.write_text((SCRIPT.parents[1] / "herdr/goals.sh").read_text())
        goals.chmod(0o755)
        bin_dir = self.root / "test-bin"
        bin_dir.mkdir()
        calls = self.root.parent / "linked-herdr-calls.jsonl"
        stub = bin_dir / "herdr"
        stub.write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ['HERDR_CALLS'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:3] == ['tab', 'create']:
    print('{\"result\":{\"root_pane\":{\"pane_id\":\"p1\"}}}')
""")
        stub.chmod(0o755)
        self.command("git", "add", ".")
        self.command("git", "commit", "-m", "linked integration fixture")
        linked = self.root.parent / "linked"
        self.command("git", "worktree", "add", "-b", "linked", str(linked), "main")
        env = os.environ.copy()
        env.update(HERDR_CALLS=str(calls), PATH=f"{bin_dir}:{env['PATH']}")
        result = subprocess.run(
            [str(goals), "one:opus::one:a"], cwd=linked, env=env,
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.claims(), {"one": ["a"]})

    def run_lanes(self, ranked, unjudged, seat="free", cap=4, args=(), resume=()):
        """BibleStandard FS-262: `herdr-goals` against a fake manager and a
        fake work graph. Returns (result, [(label, launch)] per opened tab)."""
        repo = self.root.parent / "lanes-repo"
        (repo / "tools").mkdir(parents=True, exist_ok=True)
        (repo / ".claude/skills/deliver").mkdir(parents=True, exist_ok=True)
        graph = {"next": [{"id": f"FS-{n}", "title": "Ranked"} for n in ranked],
                 "unjudged": unjudged, "verdict_seat": seat,
                 "resume": [{"id": ident, "slug": slug, "title": "Orphan"} for ident, slug in resume]}
        (repo / "tools/features_index.py").write_text(f"print({json.dumps(json.dumps(graph))})\n")
        sessions = self.root.parent / "lanes-sessions"
        (repo / "tools/session_worktree.py").write_text(f"""import json, os, sys
from pathlib import Path
args = sys.argv[1:]
if args[:1] == ['open']:
    if '--help' in args:
        print('--place')
        raise SystemExit(0)
    slug = args[1]
    log = Path({str(sessions)!r}) / 'opened'
    log.parent.mkdir(parents=True, exist_ok=True)
    if slug == 'verdict-drain' and '--place' in args and (Path({str(sessions)!r}) / slug).exists():
        print('verdict lane already open', file=sys.stderr)
        raise SystemExit(3)
    builds = [l for l in (log.read_text().split() if log.exists() else []) if l != 'verdict-drain']
    if slug != 'verdict-drain' and len(builds) >= {cap}:
        print('cap reached: build cap', file=sys.stderr)
        raise SystemExit(3)
    with log.open('a') as out:
        out.write(slug + '\\n')
    path = Path({str(sessions)!r}) / slug
    path.mkdir(parents=True, exist_ok=True)
    print(path)
""")
        bin_dir = self.root / "lanes-bin"
        bin_dir.mkdir(exist_ok=True)
        calls = self.root.parent / "lanes-calls.jsonl"
        calls.write_text("")
        if sessions.exists():
            import shutil
            shutil.rmtree(sessions)
        (bin_dir / "herdr").write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ['HERDR_CALLS'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:3] == ['tab', 'create']:
    print('{"result":{"root_pane":{"pane_id":"p1"}}}')
""")
        (bin_dir / "herdr").chmod(0o755)
        env = os.environ.copy()
        env.update(HERDR_GOALS_REPO=str(repo), HERDR_CALLS=str(calls),
                   HERDR_GOALS_AGENT="claude", PATH=f"{bin_dir}:{env['PATH']}")
        result = subprocess.run([str(SCRIPT.parents[1] / "herdr/goals.sh"), *args], cwd=repo,
                                env=env, text=True, capture_output=True)
        recorded = [json.loads(line) for line in calls.read_text().splitlines()]
        labels = [c[c.index("--label") + 1] for c in recorded if c[:2] == ["tab", "create"]]
        runs = [c[3] for c in recorded if c[:2] == ["pane", "run"]]
        return result, list(zip(labels, runs))

    def test_goals_opens_four_builds_then_the_verdict_lane_and_nothing_else(self):
        result, tabs = self.run_lanes([101, 102, 103, 104, 105], unjudged=3)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([label for label, _ in tabs],
                         ["▸ fs101", "▸ fs102", "▸ fs103", "▸ fs104", "▸ verdict-drain"])
        self.assertEqual(tabs[-1][1], 'claude --model opus --effort medium '
                                      '--permission-mode auto "/verdict-next agent"')
        self.assertTrue(all("--effort medium" in launch for _, launch in tabs))
        self.assertFalse(any("grill" in launch or "/todo" in launch or "plan" in launch
                             for _, launch in tabs))
        self.assertIn("build lanes full", result.stderr)
        self.assertNotIn("/deliver", result.stderr)

    def test_goals_resumes_an_orphaned_build_before_new_records(self):
        # BibleStandard FS-262 D9: `resume` opens first, in its own checkout.
        result, tabs = self.run_lanes([101, 102, 103, 104], unjudged=0,
                                      resume=[("FS-90", "fs90-old")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([label for label, _ in tabs],
                         ["▸ fs90-old", "▸ fs101", "▸ fs102", "▸ fs103"])
        self.assertTrue(tabs[0][1].endswith('"/deliver FS-90 — resumed (FS-262 D9): git merge main first"'),
                        tabs[0][1])

    def test_goals_opens_no_verdict_lane_without_unjudged_rows_or_a_free_seat(self):
        for unjudged, seat in ((0, "free"), (4, "held")):
            with self.subTest(unjudged=unjudged, seat=seat):
                result, tabs = self.run_lanes([101], unjudged=unjudged, seat=seat)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual([label for label, _ in tabs], ["▸ fs101"])

    def test_goals_with_nothing_to_do_opens_nothing(self):
        result, tabs = self.run_lanes([], unjudged=0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(tabs, [])
        self.assertIn("/grill-next when you have the attention", result.stderr)

    def test_an_explicit_grill_opens_in_the_shared_checkout_at_max(self):
        result, tabs = self.run_lanes([101], unjudged=3, args=("grill:opus",))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(tabs, [("▸ grill", 'claude --model opus --effort max '
                                           '--permission-mode auto "/grill-next"')])

    def test_an_explicit_verdict_is_refused_while_the_seat_is_held(self):
        result, tabs = self.run_lanes([], unjudged=3, args=("verdict:opus", "verdict:opus"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([label for label, _ in tabs], ["▸ verdict-drain"])
        self.assertIn("verdict lane is already open", result.stderr)

    def test_goals_preserves_claude_codex_and_pi_agent_families(self):
        (self.root / "herdr").mkdir()
        goals = self.root / "herdr/goals.sh"
        goals.write_text((SCRIPT.parents[1] / "herdr/goals.sh").read_text())
        goals.chmod(0o755)
        bin_dir = self.root / "test-bin"
        bin_dir.mkdir()
        calls = self.root.parent / "agent-routing-calls.jsonl"
        stub = bin_dir / "herdr"
        stub.write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ['HERDR_CALLS'], 'a') as out:
    out.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:3] == ['status', 'server']:
    raise SystemExit(0)
if sys.argv[1:3] == ['pane', 'get']:
    agent = os.environ.get('TEST_CALLER_AGENT', '')
    if agent == '__fail__':
        raise SystemExit(1)
    print(json.dumps({'result': {'pane': {'agent': agent}}}))
if sys.argv[1:3] == ['tab', 'create']:
    print('{\"result\":{\"root_pane\":{\"pane_id\":\"p1\"}}}')
""")
        stub.chmod(0o755)
        env = os.environ.copy()
        env.update(HERDR_GOALS_REPO=str(self.root.resolve()), HERDR_CALLS=str(calls),
                   HERDR_PANE_ID="source-pane", PATH=f"{bin_dir}:{env['PATH']}")
        for name in ("HERDR_GOALS_AGENT", "CLAUDECODE", "CODEX_SESSION_ID",
                     "PI_SESSION_ID", "PI_CODING_AGENT_DIR"):
            env.pop(name, None)

        for caller, expected in (
            ("claude", "claude --model opus --effort medium --permission-mode auto"),
            ("codex", "codex"),
            ("pi", "pi"),
        ):
            with self.subTest(caller=caller):
                calls.write_text("")
                env["TEST_CALLER_AGENT"] = caller
                result = subprocess.run(
                    [str(goals), "notes:opus::shared"], cwd=self.root, env=env,
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                recorded = [json.loads(line) for line in calls.read_text().splitlines()]
                run = next(call for call in recorded if call[:2] == ["pane", "run"])
                command = run[3]
                self.assertEqual(command, expected)

        for caller, resume, expected in (
            (
                "claude", "pick",
                "claude --model opus --effort medium --permission-mode auto --resume",
            ),
            (
                "claude", "session-123",
                "claude --model opus --effort medium --permission-mode auto --resume session-123",
            ),
            ("codex", "pick", "codex resume"),
            ("codex", "session-123", "codex resume session-123"),
            ("pi", "pick", "pi --resume"),
            ("pi", "session-123", "pi --session session-123"),
        ):
            with self.subTest(caller=caller, resume=resume):
                calls.write_text("")
                env["TEST_CALLER_AGENT"] = caller
                result = subprocess.run(
                    [str(goals), f"notes:opus:{resume}:shared"], cwd=self.root,
                    env=env, text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                recorded = [json.loads(line) for line in calls.read_text().splitlines()]
                run = next(call for call in recorded if call[:2] == ["pane", "run"])
                self.assertEqual(run[3], expected)

        # The real ranked path boots every new tab into its assigned workflow
        # without changing the invoking agent family.
        plain_repo = self.root.parent / "plain-repo"
        plain_repo.mkdir()
        (plain_repo / "tools").mkdir()
        features = plain_repo / "tools/features_index.py"
        features.write_text("print('{\"next\":[{\"id\":\"FS-123\",\"title\":\"Ranked\"}]}')\n")
        for caller, expected_commands in (
            (
                "claude",
                [
                    'claude --model opus --effort medium --permission-mode auto "feature-plan FS-123"',
                ],
            ),
            ("codex", ['codex "feature-plan FS-123"']),
            ("pi", ['pi "feature-plan FS-123"']),
        ):
            with self.subTest(caller=caller, automatic=True):
                calls.write_text("")
                env.update(TEST_CALLER_AGENT=caller,
                           HERDR_GOALS_REPO=str(plain_repo.resolve()))
                result = subprocess.run(
                    [str(goals)], cwd=plain_repo, env=env,
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                recorded = [json.loads(line) for line in calls.read_text().splitlines()]
                commands = [call[3] for call in recorded if call[:2] == ["pane", "run"]]
                self.assertEqual(commands, expected_commands)

        # Explicit override outranks pane metadata and conflicting inherited
        # environment evidence. Unknown explicit identities fail before create.
        calls.write_text("")
        env.update(HERDR_GOALS_AGENT="codex", TEST_CALLER_AGENT="claude",
                   CLAUDECODE="1", CODEX_SESSION_ID="conflict")
        overridden = subprocess.run(
            [str(goals), "notes:opus::shared"], cwd=self.root, env=env,
            text=True, capture_output=True,
        )
        self.assertEqual(overridden.returncode, 0, overridden.stderr)
        recorded = [json.loads(line) for line in calls.read_text().splitlines()]
        self.assertEqual(next(call[3] for call in recorded
                              if call[:2] == ["pane", "run"]), "codex")

        for fallback_var, expected in (("CLAUDECODE", "claude"),
                                       ("CODEX_SESSION_ID", "codex"),
                                       ("PI_SESSION_ID", "pi"),
                                       ("PI_CODING_AGENT_DIR", "pi")):
            with self.subTest(fallback=fallback_var):
                calls.write_text("")
                for name in ("HERDR_GOALS_AGENT", "CLAUDECODE",
                             "CODEX_SESSION_ID", "PI_SESSION_ID",
                             "PI_CODING_AGENT_DIR"):
                    env.pop(name, None)
                env.update(TEST_CALLER_AGENT="__fail__", **{fallback_var: "1"})
                result = subprocess.run(
                    [str(goals), "notes:opus::shared"], cwd=self.root, env=env,
                    text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                recorded = [json.loads(line) for line in calls.read_text().splitlines()]
                command = next(call[3] for call in recorded
                               if call[:2] == ["pane", "run"])
                self.assertEqual(command.split()[0], expected)

        calls.write_text("")
        env.update(HERDR_GOALS_AGENT="unknown", TEST_CALLER_AGENT="claude")
        rejected = subprocess.run(
            [str(goals), "notes:opus::shared"], cwd=self.root, env=env,
            text=True, capture_output=True,
        )
        self.assertEqual(rejected.returncode, 2)
        self.assertIn("unsupported caller agent: unknown", rejected.stderr)
        recorded = [json.loads(line) for line in calls.read_text().splitlines()]
        self.assertFalse(any(call[:2] == ["tab", "create"] for call in recorded))

if __name__ == "__main__":
    unittest.main()
