"""Both openers launch at the routing table's model and effort (BibleStandard
BS-IOS-FEAT-597, `tools/model_routes.py` from BS-IOS-FEAT-596); a table that
cannot answer opens Sonnet medium with one line, never Opus."""
import json, os, pathlib, subprocess, tempfile, textwrap, unittest

HERDR = pathlib.Path(__file__).resolve().parents[1]

# A stand-in table: builds Opus medium, the verdict lane Sonnet medium, a spec
# of the app-kind record (or `app`) Opus xhigh and any other Sonnet high.
TABLE = textwrap.dedent("""\
    import sys
    verb, kind = sys.argv[1], sys.argv[-1]
    if verb == "spec":
        print("opus xhigh" if kind in ("app", "BS-IOS-FEAT-1") else "sonnet high")
    else:
        print({"build": "opus medium", "verdict": "sonnet medium"}.get(verb, "sonnet medium"))
""")
STUB_HERDR = "#!/bin/sh\necho '{\"result\":{\"tabs\":[]}}'\n"


def repo(table: str | None, graph: dict | None = None, track_first: dict | None = None) -> pathlib.Path:
    root = pathlib.Path(tempfile.mkdtemp())
    tools = root / "tools"
    tools.mkdir()
    (tools / "features_index.py").write_text(textwrap.dedent(f"""\
        import sys
        if "--list" in sys.argv:
            print({track_first or {}!r}.get(sys.argv[sys.argv.index("--track") + 1], "0 records"))
        else:
            print({json.dumps(json.dumps(graph or {"next": []}))})
    """))
    (tools / "session_worktree.py").write_text(textwrap.dedent("""\
        import sys
        if "--help" in sys.argv: print("usage: open [--place]")
        else: print(0)
    """))
    if table is not None:
        (tools / "model_routes.py").write_text(table)
    (root / "project" / "workflow").mkdir(parents=True)
    (root / "project" / "workflow" / "FOCUS.md").write_text("### Home\n\n### Tools\n")
    (root / "bin").mkdir()
    (root / "bin" / "herdr").write_text(STUB_HERDR)
    (root / "bin" / "herdr").chmod(0o755)
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    return root


def env(root: pathlib.Path) -> dict:
    # HERDR_ROUTES_REPO: never fall through to the real iOS checkout's table.
    return {**os.environ, "PATH": f"{root / 'bin'}:{os.environ['PATH']}", "HERDR_TAB_ID": "t",
            "HERDR_GOAL_DONE_AGENT": "claude", "HERDR_CHAIN_PAUSE": str(root / "absent"),
            "HERDR_CHAIN_LOG": str(root / "state" / "chain.log"), "HERDR_CHAIN_NOTIFY": "0",
            "HERDR_FILL_RETRY_SECS": "0", "HERDR_GOALS_REPO": str(root),
            "HERDR_ROUTES_REPO": str(root / "no-ios")}


def goal_done_fill(root: pathlib.Path) -> str:
    run = subprocess.run(["bash", str(HERDR / "goal_done.sh"), "--fill", str(root), "--dry-run"],
                         env=env(root), capture_output=True, text=True)
    return run.stdout + run.stderr


def goals(root: pathlib.Path, *args: str) -> str:
    run = subprocess.run(["bash", str(HERDR / "goals.sh"), *args, "--dry-run"],
                         env=env(root), capture_output=True, text=True, cwd=root)
    return run.stdout + run.stderr


LANES = {"next": [{"id": "BS-IOS-TASK-9"}], "unjudged": 1, "verdict_seat": "free"}


class GoalDone(unittest.TestCase):
    def test_build_and_verdict_lane_open_at_the_tables_pairs(self):
        out = goal_done_fill(repo(TABLE, LANES))
        self.assertIn('--model opus --effort medium --permission-mode auto "/build BS-IOS-TASK-9"', out)
        self.assertIn('--model sonnet --effort medium --permission-mode bypassPermissions "/verdict auto"', out)

    def test_a_missing_table_opens_sonnet_medium_with_one_line(self):
        out = goal_done_fill(repo(None, LANES))
        self.assertIn('--model sonnet --effort medium --permission-mode auto "/build BS-IOS-TASK-9"', out)
        self.assertIn('--model sonnet --effort medium --permission-mode bypassPermissions "/verdict auto"', out)
        self.assertEqual(out.count("opening sonnet medium"), 1, out)
        self.assertNotIn("--model opus", out)

    def test_an_unreadable_table_opens_sonnet_medium(self):
        out = goal_done_fill(repo("import sys; sys.exit('model_routes.json: bad JSON')\n", LANES))
        self.assertIn('--model sonnet --effort medium --permission-mode auto "/build BS-IOS-TASK-9"', out)
        self.assertEqual(out.count("opening sonnet medium"), 1, out)


class Goals(unittest.TestCase):
    def test_a_build_opens_opus_medium(self):
        out = goals(repo(TABLE), "--build", "BS-IOS-TASK-9")
        self.assertIn("launch: claude --model opus --effort medium", out)

    def test_an_app_kind_spec_opens_opus_xhigh(self):
        out = goals(repo(TABLE, track_first={"Home": "BS-IOS-FEAT-1 Spec Needed  a"}), "--settle", "Home")
        self.assertIn("launch: claude --model opus --effort xhigh", out)

    def test_a_tool_kind_spec_opens_sonnet_high(self):
        out = goals(repo(TABLE, track_first={"Tools": "BS-IOS-TASK-2 Spec Needed  b"}), "--settle", "Tools")
        self.assertIn("launch: claude --model sonnet --effort high", out)

    def test_a_missing_table_opens_sonnet_medium(self):
        out = goals(repo(None), "--settle", "Home")
        self.assertIn("launch: claude --model sonnet --effort medium", out)
        self.assertEqual(out.count("opening sonnet medium"), 1, out)


if __name__ == "__main__":
    unittest.main()
