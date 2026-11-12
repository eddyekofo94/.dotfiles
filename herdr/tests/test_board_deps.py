"""Master plan 1f (M9): an iOS record held on an API record opens only once the API
record has landed and its `production` run is green."""
import json, os, pathlib, subprocess, sys, tempfile, textwrap, unittest

BOARD = pathlib.Path(__file__).resolve().parents[1] / "board.py"
GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
GH = textwrap.dedent("""\
    #!/bin/sh
    # stub gh: answers `run list` from $FAKE_RUNS
    printf '%s' "$FAKE_RUNS"
""")


class Deps(unittest.TestCase):
    def setUp(self):
        self.org = pathlib.Path(tempfile.mkdtemp())
        ios = self.org / "ios"
        (ios / "tools").mkdir(parents=True)
        graph = {"waiting": [{"id": "BS-IOS-FEAT-900", "title": "Home shows the API's verse count",
                              "waiting_on": ["BS-API-FEAT-12"]}]}
        (ios / "tools/features_index.py").write_text(f"print({json.dumps(json.dumps(graph))})\n")
        self.api = self.org / "api"
        (self.api / ".github/workflows").mkdir(parents=True)
        (self.api / ".github/workflows/ci.yml").write_text("on: {push: {branches: [production]}}\n")
        self.git("init", "-q", "-b", "main")
        self.git("commit", "-q", "--allow-empty", "-m", "start")
        self.gh = self.org / "gh"
        self.gh.write_text(GH)
        self.gh.chmod(0o755)

    def git(self, *args):
        subprocess.run(["git", "-C", str(self.api), *args], check=True, env={**os.environ, **GIT_ENV})

    def land(self, message="merge: land BS-API-FEAT-12 — verse counts"):
        self.git("checkout", "-q", "-b", "feature/bs-api-feat-12")
        self.git("commit", "-q", "--allow-empty", "-m", "verse counts")
        self.git("checkout", "-q", "main")
        self.git("merge", "-q", "--no-ff", "-m", message, "feature/bs-api-feat-12")

    def deps(self, runs):
        env = {**os.environ, "HERDR_BOARD_ORG": str(self.org), "HERDR_BOARD_GH": str(self.gh),
               "FAKE_RUNS": json.dumps(runs)}
        out = subprocess.run([sys.executable, str(BOARD), "--deps", "--json"], env=env,
                             capture_output=True, text=True, check=True).stdout
        text = subprocess.run([sys.executable, str(BOARD), "--deps"], env=env,
                              capture_output=True, text=True, check=True).stdout
        return json.loads(out)[0], text

    def test_an_unlanded_upstream_opens_first_and_holds_the_dependent(self):
        row, text = self.deps([])
        self.assertEqual(row["verdict"], "hold")
        self.assertEqual(row["upstream"][0]["state"], "not landed")
        self.assertIn(f"open first: cd {self.api} && herdr-goals --build BS-API-FEAT-12", text)

    def test_a_green_production_run_releases_the_dependent(self):
        self.land()
        row, text = self.deps([{"status": "completed", "conclusion": "success", "databaseId": 1}])
        self.assertEqual(row["verdict"], "release")
        self.assertEqual((row["upstream"][0]["ci"], row["upstream"][0]["state"]), ("green", "live"))
        self.assertIn("release  BS-IOS-FEAT-900", text)

    def test_a_red_production_run_keeps_it_held_and_reopens_the_upstream(self):
        self.land()
        row, text = self.deps([{"status": "completed", "conclusion": "failure", "databaseId": 2}])
        self.assertEqual(row["verdict"], "hold")
        self.assertIn("reopen: cd", text)

    def test_a_records_commit_or_a_longer_id_is_not_a_land(self):
        self.git("commit", "-q", "--allow-empty", "-m", "records: BS-API-FEAT-12 settled")
        self.land("Merge pull request #9 from canonfidei/bs-api-feat-123")
        row, _ = self.deps([])
        self.assertEqual(row["upstream"][0]["state"], "not landed")

    def test_a_pr_merge_from_the_record_branch_is_a_land(self):
        self.land("Merge pull request #130 from canonfidei/bs-api-feat-12")
        row, _ = self.deps([{"status": "completed", "conclusion": "success", "databaseId": 1}])
        self.assertEqual(row["verdict"], "release")

    def test_a_run_still_going_waits(self):
        self.land()
        row, _ = self.deps([{"status": "in_progress", "conclusion": "", "databaseId": 3}])
        self.assertEqual(row["verdict"], "wait")

    def test_a_repo_without_ci_is_live_once_landed(self):
        (self.api / ".github/workflows/ci.yml").unlink()
        self.land()
        row, _ = self.deps([])
        self.assertEqual((row["verdict"], row["upstream"][0]["ci"]), ("release", "none"))


if __name__ == "__main__":
    unittest.main()
