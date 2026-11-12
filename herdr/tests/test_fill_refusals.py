"""The fill writes why each ready record did not open to chain.log, and when
none opened on a free lane it tries once more (BibleStandard BS-IOS-TASK-1428:
BS-IOS-BUG-1396 did not open when BS-IOS-TASK-1356 closed, and nothing said why)."""
import os as _os, tempfile as _tempfile  # master plan B6: never find the live master
_os.environ["HERDR_SESSIONS_DIR"] = _tempfile.mkdtemp(prefix="no-master-"); _os.environ["AGENT_STATE_DIR"] = _tempfile.mkdtemp(prefix="state-")
import json, os, pathlib, subprocess, tempfile, textwrap, unittest
ROUTES = pathlib.Path(__file__).resolve().parents[1] / "tests/fixtures/routes"  # BS-IOS-FEAT-597: never the real iOS table

GOAL_DONE = pathlib.Path(__file__).resolve().parents[1] / "goal_done.sh"

MANAGER = textwrap.dedent("""
    import json, os, pathlib, sys
    if "--help" in sys.argv:
        print("usage: open [--place]"); sys.exit(0)
    goal = sys.argv[sys.argv.index("--goal") + 1]
    seen = pathlib.Path("tries-" + goal)
    n = int(seen.read_text()) if seen.exists() else 0
    seen.write_text(str(n + 1))
    plan = json.loads(os.environ["FAKE_OPENS"]).get(goal, [[0, ""]])
    rc, msg = plan[min(n, len(plan) - 1)]
    if msg: print(msg, file=sys.stderr)
    if rc == 0: print(os.getcwd())
    sys.exit(rc)
""")

HERDR = textwrap.dedent("""\
    #!/bin/sh
    case "$1 $2" in
      "tab create") echo '{"result":{"root_pane":{"pane_id":"p1"}}}' ;;
    esac
    exit 0
""")


def fill(rows: list[dict], opens: dict) -> tuple[str, str]:
    repo = pathlib.Path(tempfile.mkdtemp())
    (repo / "tools").mkdir()
    graph = {"next": rows, "focus": "Code quality", "waiting": []}
    (repo / "tools" / "features_index.py").write_text(f"print({json.dumps(json.dumps(graph))})\n")
    (repo / "tools" / "session_worktree.py").write_text(MANAGER)
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    bin_dir = repo / "bin"
    bin_dir.mkdir()
    (bin_dir / "herdr").write_text(HERDR)
    (bin_dir / "herdr").chmod(0o755)
    log = repo / "chain.log"
    env = {**os.environ, "HERDR_ROUTES_REPO": str(ROUTES), "PATH": f"{bin_dir}:{os.environ['PATH']}",
           "HERDR_TAB_ID": "t", "HERDR_GOAL_DONE_AGENT": "claude",
           "HERDR_CHAIN_PAUSE": str(repo / "absent"), "HERDR_CHAIN_LOG": str(log),
           "HERDR_CHAIN_NOTIFY": "0", "HERDR_FILL_RETRY_SECS": "0",
           "FAKE_OPENS": json.dumps(opens)}
    done = subprocess.run(["bash", str(GOAL_DONE), "--fill", str(repo)],
                          env=env, capture_output=True, text=True)
    return done.stdout + done.stderr, log.read_text() if log.exists() else ""


class FillRefusals(unittest.TestCase):
    def test_each_refusal_is_logged_with_its_reason(self):
        rows = [{"id": f"BS-IOS-TASK-{n}"} for n in (1, 2, 3, 4)]
        out, log = fill(rows, {
            "BS-IOS-TASK-1": [[4, "BS-IOS-TASK-1 overlaps bs-ios-task-9's seams"]],
            "BS-IOS-TASK-2": [[5, "bs-ios-task-2: a live session holds it"]],
            "BS-IOS-TASK-3": [[1, "Traceback: boom"]],
            "BS-IOS-TASK-4": [[3, "build cap full: 3 of 3 lanes"]],
        })
        self.assertIn("skipped BS-IOS-TASK-1 — overlaps a live build: BS-IOS-TASK-1 overlaps bs-ios-task-9's seams", log)
        self.assertIn("skipped BS-IOS-TASK-2 — a live session holds it: bs-ios-task-2: a live session holds it", log)
        self.assertIn("skipped BS-IOS-TASK-3 — exit 1: Traceback: boom", log)
        self.assertIn("skipped BS-IOS-TASK-4 — build lanes full: build cap full: 3 of 3 lanes", log)
        self.assertIn("overlaps bs-ios-task-9's seams", out)  # the manager's line still prints

    def test_a_clash_that_clears_opens_on_the_retry(self):
        out, log = fill([{"id": "BS-IOS-BUG-7"}],
                        {"BS-IOS-BUG-7": [[4, "overlaps bs-ios-task-8"], [0, ""]]})
        self.assertIn("queued /build BS-IOS-BUG-7", out)
        self.assertIn("skipped BS-IOS-BUG-7", log)
        self.assertIn("retrying the fill", log)
        self.assertNotIn("build chain stopped", log)

    def test_the_stop_line_names_the_last_refusal(self):
        out, log = fill([{"id": "BS-IOS-BUG-7"}],
                        {"BS-IOS-BUG-7": [[4, "overlaps bs-ios-task-8"]]})
        stop = [l for l in log.splitlines() if "build chain stopped" in l]
        self.assertEqual(len(stop), 1, log)
        self.assertIn("last refusal: BS-IOS-BUG-7 — overlaps a live build: overlaps bs-ios-task-8", stop[0])
        self.assertEqual(log.count("skipped BS-IOS-BUG-7"), 2)  # once per pass

    def test_a_full_cap_does_not_retry(self):
        out, log = fill([{"id": "BS-IOS-BUG-7"}], {"BS-IOS-BUG-7": [[3, "cap full"]]})
        self.assertNotIn("retrying the fill", log)
        self.assertEqual(log.count("skipped BS-IOS-BUG-7"), 1)


if __name__ == "__main__":
    unittest.main()
