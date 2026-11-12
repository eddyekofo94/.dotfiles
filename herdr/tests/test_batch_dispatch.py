"""Master plan 1d (M3, BS-IOS-TASK-1709): the fills open the work graph's batch by its
verb — `/build batch <lane>` or `/spec batch <lane>` — and a lone record as `/build <ID>`."""
import os as _os, tempfile as _tempfile  # master plan B6: never find the live master
_os.environ["HERDR_SESSIONS_DIR"] = _tempfile.mkdtemp(prefix="no-master-")
import json, os, pathlib, subprocess, tempfile, textwrap, unittest

HERE = pathlib.Path(__file__).resolve().parents[1]
ROUTES = HERE / "tests/fixtures/routes"  # never the real iOS table

HERDR = textwrap.dedent("""\
    #!/bin/sh
    case "$1 $2" in
      "status server") exit 0 ;;
      "tab list") echo '{"result":{"tabs":[]}}' ;;
      "tab create") echo '{"result":{"root_pane":{"pane_id":"p1"}}}' ;;
    esac
    exit 0
""")
MANAGER = textwrap.dedent("""
    import os, sys
    if "--help" in sys.argv:
        print("usage: open [--place] [--dry-run]"); sys.exit(0)
    print(os.getcwd())
""")


def repo_with(graph: dict) -> tuple[pathlib.Path, dict]:
    repo = pathlib.Path(tempfile.mkdtemp())
    (repo / "tools").mkdir()
    (repo / "project/workflow").mkdir(parents=True)
    (repo / "project/workflow/FOCUS.md").write_text("### Home\n- State: focus\n")
    (repo / "tools" / "features_index.py").write_text(f"print({json.dumps(json.dumps(graph))})\n")
    (repo / "tools" / "session_worktree.py").write_text(MANAGER)
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    bin_dir = repo / "bin"
    bin_dir.mkdir()
    (bin_dir / "herdr").write_text(HERDR)
    (bin_dir / "herdr").chmod(0o755)
    env = {**os.environ, "HERDR_ROUTES_REPO": str(ROUTES), "PATH": f"{bin_dir}:{os.environ['PATH']}",
           "HERDR_TAB_ID": "t", "HERDR_GOAL_DONE_AGENT": "claude", "HERDR_GOALS_AGENT": "claude",
           "HERDR_GOALS_REPO": str(repo), "HERDR_CHAIN_PAUSE": str(repo / "absent"),
           "HERDR_CHAIN_LOG": str(repo / "chain.log"), "HERDR_CHAIN_NOTIFY": "0", "HERDR_FILL_RETRY_SECS": "0"}
    env.pop("HERDR_PANE_ID", None)
    return repo, env


def goals_dry(graph: dict) -> str:
    repo, env = repo_with(graph)
    done = subprocess.run(["bash", str(HERE / "goals.sh"), "--dry-run"], env=env, cwd=repo,
                          capture_output=True, text=True)
    return done.stdout + done.stderr


def fill_dry(graph: dict) -> str:
    repo, env = repo_with(graph)
    done = subprocess.run(["bash", str(HERE / "goal_done.sh"), "--fill", str(repo), "--dry-run"],
                          env=env, cwd=repo, capture_output=True, text=True)
    return done.stdout + done.stderr


BATCH = {"focus": "Home", "waiting": [],
         "next": [{"id": "BS-IOS-FEAT-372", "title": "hero"}, {"id": "BS-IOS-BUG-7", "title": "lone fix"}],
         "batch": {"lane": "Home", "verb": "/build batch Home", "spec_needed": [],
                   "ids": ["BS-IOS-FEAT-372", "BS-IOS-BUG-997", "BS-IOS-TASK-1498"]}}
SPEC = {**BATCH, "batch": {**BATCH["batch"], "verb": "/spec batch Home", "spec_needed": ["BS-IOS-FEAT-453"]}}
LONE = {**BATCH, "batch": {"lane": "", "verb": "/build BS-IOS-FEAT-372", "spec_needed": [],
                           "ids": ["BS-IOS-FEAT-372"]}}
# The graph ranked a lone fix and a member above the head (orders 2026-11-12: batch first).
LOW = {**BATCH, "next": [{"id": "BS-IOS-BUG-7", "title": "lone fix"}, {"id": "BS-IOS-BUG-997", "title": "member"},
                         {"id": "BS-IOS-FEAT-372", "title": "hero"}]}
ABSENT = {**BATCH, "next": [{"id": "BS-IOS-BUG-7", "title": "lone fix"}]}


class GoalsDryRun(unittest.TestCase):
    def test_the_batch_head_opens_first_and_its_members_never_alone(self):
        for graph in (LOW, ABSENT):
            out = goals_dry(graph)
            head = out.find("would open bs-ios-feat-372 (boot /build batch Home)")
            lone = out.find("would open bs-ios-bug-7 (boot /build BS-IOS-BUG-7)")
            self.assertTrue(0 <= head < lone, out)
            self.assertNotIn("bs-ios-bug-997", out)

    def test_every_tab_is_named_a_batch_by_repo_and_lane(self):
        out = goals_dry(BATCH)
        self.assertRegex(out, r"(?m)^  name: tmp\w*-home$|^  name: [\w.-]+-home$")
        self.assertIn("  name: bs-ios-bug-7", out)

    def test_a_batch_head_opens_the_batch_verb_and_a_lone_record_its_own_build(self):
        out = goals_dry(BATCH)
        self.assertIn("would open bs-ios-feat-372 (boot /build batch Home)", out)
        self.assertIn("would open bs-ios-bug-7 (boot /build BS-IOS-BUG-7)", out)

    def test_a_batch_with_spec_needed_members_opens_one_shared_spec_batch(self):
        out = goals_dry(SPEC)
        self.assertIn("would open spec-batch-home (boot /spec batch Home)", out)
        self.assertNotIn("bs-ios-feat-372 (boot", out)

    def test_a_batch_of_one_stays_a_single_build(self):
        self.assertIn("would open bs-ios-feat-372 (boot /build BS-IOS-FEAT-372)", goals_dry(LONE))

    def test_no_batch_key_keeps_single_builds(self):
        out = goals_dry({k: v for k, v in BATCH.items() if k != "batch"})
        self.assertIn("(boot /build BS-IOS-FEAT-372)", out)


class FillDryRun(unittest.TestCase):
    def test_the_reaper_fill_opens_the_batch_verb(self):
        out = fill_dry(BATCH)
        self.assertIn('"/build batch Home"', out)
        self.assertIn('"/build BS-IOS-BUG-7"', out)

    def test_the_reaper_fill_opens_the_head_first_and_names_its_tabs(self):
        out = fill_dry(LOW)
        self.assertTrue(0 <= out.find('"/build batch Home"') < out.find('"/build BS-IOS-BUG-7"'), out)
        self.assertNotIn("BS-IOS-BUG-997", out)
        self.assertRegex(out, r'env AGENT_NAME=([\w.-]+-home) claude --name \1 ')

    def test_the_reaper_fill_opens_a_spec_batch_in_the_shared_checkout(self):
        out = fill_dry(SPEC)
        self.assertRegex(out, r'--label "▸ spec-batch-home"')
        self.assertIn('"/spec batch Home"', out)
        self.assertNotIn('"/build BS-IOS-FEAT-372"', out)


if __name__ == "__main__":
    unittest.main()
