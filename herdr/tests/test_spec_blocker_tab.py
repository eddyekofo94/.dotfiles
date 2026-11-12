"""A stopped chain that only a /spec can restart opens that /spec as a tab
(Eddy, 2026-11-09: "If spec is needed tell me ... it just stopped")."""
import json, os, pathlib, subprocess, tempfile, textwrap, unittest
ROUTES = pathlib.Path(__file__).resolve().parents[1] / "tests/fixtures/routes"  # BS-IOS-FEAT-597: never the real iOS table

GOAL_DONE = pathlib.Path(__file__).resolve().parents[1] / "goal_done.sh"

HERDR = textwrap.dedent("""\
    #!/bin/sh
    echo "$*" >> "$HERDR_CALLS"
    case "$1 $2" in
      "tab create") echo '{"result":{"root_pane":{"pane_id":"p1"}}}' ;;
    esac
    exit 0
""")


class Repo:
    def __init__(self, statuses: dict, waiting_on: list[str]):
        self.root = pathlib.Path(tempfile.mkdtemp())
        # As the real graph does: --focus --json carries no statuses; --show prints the record.
        graph = {"next": [], "focus": "Xcode plugin",
                 "waiting": [{"id": "BS-IOS-TASK-2", "track": "Xcode plugin", "waiting_on": waiting_on}]}
        (self.root / "tools").mkdir()
        (self.root / "tools" / "features_index.py").write_text(textwrap.dedent(f"""\
            import sys
            if "--show" in sys.argv:
                print("- Status: " + {statuses!r}[sys.argv[sys.argv.index("--show") + 1]])
            else:
                print({json.dumps(json.dumps(graph))})
        """))
        (self.root / "tools" / "session_worktree.py").write_text("import sys; sys.exit(0)\n")
        # BS-IOS-FEAT-597: the routing table's spec pair for an app-kind record.
        (self.root / "tools" / "model_routes.py").write_text(
            "import sys; print('opus xhigh' if sys.argv[1] == 'spec' else 'opus medium')\n")
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        (bin_dir / "herdr").write_text(HERDR)
        (bin_dir / "herdr").chmod(0o755)
        self.calls = self.root / "calls"
        self.calls.touch()
        self.env = {**os.environ, "HERDR_ROUTES_REPO": str(ROUTES), "PATH": f"{bin_dir}:{os.environ['PATH']}", "HERDR_TAB_ID": "t",
                    "HERDR_GOAL_DONE_AGENT": "claude", "HERDR_CHAIN_PAUSE": str(self.root / "absent"),
                    "HERDR_CHAIN_LOG": str(self.root / "state" / "chain.log"), "HERDR_CHAIN_NOTIFY": "0",
                    "HERDR_FILL_RETRY_SECS": "0", "HERDR_CALLS": str(self.calls)}

    def fill(self) -> str:
        done = subprocess.run(["bash", str(GOAL_DONE), "--fill", str(self.root)],
                              env=self.env, capture_output=True, text=True)
        return done.stdout + done.stderr

    def tabs(self) -> list[str]:
        return [line for line in self.calls.read_text().splitlines() if line.startswith("tab create")]

    def runs(self) -> list[str]:
        return [line for line in self.calls.read_text().splitlines() if line.startswith("pane run")]


class SpecBlockerTab(unittest.TestCase):
    def test_a_spec_needed_blocker_opens_its_spec_tab_at_the_tables_pair(self):
        repo = Repo({"BS-IOS-TASK-1": "Spec Needed — does it stay?"}, ["BS-IOS-TASK-1"])
        out = repo.fill()
        self.assertEqual(len(repo.tabs()), 1, out)
        self.assertIn("spec-bs-ios-task-1", repo.tabs()[0])
        self.assertIn("/spec BS-IOS-TASK-1", repo.runs()[0])
        self.assertIn("--model opus --effort xhigh", repo.runs()[0])

    def test_the_next_fill_does_not_open_a_second_tab(self):
        repo = Repo({"BS-IOS-TASK-1": "Spec Needed"}, ["BS-IOS-TASK-1"])
        repo.fill()
        repo.fill()
        self.assertEqual(len(repo.tabs()), 1)

    def test_two_blockers_open_one_tab_at_a_time(self):
        repo = Repo({"BS-IOS-TASK-1": "Spec Needed", "BS-IOS-TASK-3": "Spec Needed"},
                    ["BS-IOS-TASK-1", "BS-IOS-TASK-3"])
        repo.fill()
        repo.fill()
        self.assertEqual(len(repo.tabs()), 1)

    def test_a_blocker_still_building_opens_no_tab(self):
        repo = Repo({"BS-IOS-TASK-1": "In Progress"}, ["BS-IOS-TASK-1"])
        out = repo.fill()
        self.assertEqual(repo.tabs(), [], out)


if __name__ == "__main__":
    unittest.main()
