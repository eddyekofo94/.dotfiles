"""`herdr-goals --build` opens a data record's tab in the data checkout (BibleStandard
BS-IOS-FEAT-1365; Eddy, 2026-11-04: "we can always spin a tab with that userstory from the
data repo, land it and then update here")."""
import os, pathlib, subprocess, tempfile, unittest

GOALS = pathlib.Path(__file__).resolve().parents[1] / "goals.sh"


class DataBuildTab(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = pathlib.Path(tmp.name)
        self.ios, self.data = root / "ios", root / "data"
        (self.ios / "project/workflow").mkdir(parents=True)
        (self.ios / "project/workflow/moved.tsv").write_text("# moved\nBS-IOS-BUG-1003\tBS-DATA-BUG-72\n")
        (self.ios / "project/workflow/id_map.tsv").write_text("BUG-1003\tBS-IOS-BUG-1003\n")
        (self.data / "tools").mkdir(parents=True)

    def dry_run(self, ident, data=None):
        env = {**os.environ, "HERDR_GOALS_REPO": str(self.ios), "BS_DATA_DIR": str(data or self.data)}
        return subprocess.run(["bash", str(GOALS), "--build", ident, "--dry-run"],
                              cwd=self.ios, env=env, capture_output=True, text=True)

    def test_a_data_id_opens_in_the_data_checkout(self):
        run = self.dry_run("BS-DATA-BUG-72")
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout.strip(), f"would open bs-data-bug-72 (boot /build BS-DATA-BUG-72) in {self.data}")

    def test_a_moved_ios_id_opens_under_its_new_id(self):
        for old in ("BS-IOS-BUG-1003", "bs-ios-bug-1003", "BUG-1003"):
            run = self.dry_run(old)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn("(boot /build BS-DATA-BUG-72) in " + str(self.data), run.stdout, old)

    def test_a_missing_data_checkout_is_reported(self):
        run = self.dry_run("BS-DATA-BUG-72", data=self.data / "missing")
        self.assertEqual(run.returncode, 2)
        self.assertIn("no data checkout", run.stderr)
        self.assertIn("BS_DATA_DIR", run.stderr)

    def test_an_app_id_is_unchanged(self):
        run = self.dry_run("BS-IOS-FEAT-1365")
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout.strip(), f"would open bs-ios-feat-1365 (boot /build BS-IOS-FEAT-1365) in {self.ios}")


if __name__ == "__main__":
    unittest.main()
