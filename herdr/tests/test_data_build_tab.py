"""`herdr-goals --build` opens a data record's tab in the data checkout (BibleStandard
BS-IOS-FEAT-1365; Eddy, 2026-11-04: "we can always spin a tab with that userstory from the
data repo, land it and then update here")."""
import os as _os, tempfile as _tempfile  # master plan B6: never find the live master
_os.environ["HERDR_SESSIONS_DIR"] = _tempfile.mkdtemp(prefix="no-master-")
import os, pathlib, subprocess, tempfile, unittest
ROUTES = pathlib.Path(__file__).resolve().parents[1] / "tests/fixtures/routes"  # BS-IOS-FEAT-597: never the real iOS table

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

    def dry_run(self, ident, data=None, extra=None, lane=False):
        env = {**os.environ, "HERDR_ROUTES_REPO": str(ROUTES), "HERDR_GOALS_REPO": str(self.ios), "BS_DATA_DIR": str(data or self.data), **(extra or {})}
        env["PATH"] = os.pathsep.join(p for p in env["PATH"].split(os.pathsep)
                                      if lane or not os.path.exists(os.path.join(p, "herdr-group-lane")))
        return subprocess.run(["bash", str(GOALS), "--build", ident, "--dry-run"],
                              cwd=self.ios, env=env, capture_output=True, text=True)

    def fake_lane(self, code, out):
        bin_dir = self.ios / "bin"; bin_dir.mkdir()
        tool = bin_dir / "herdr-group-lane"
        tool.write_text(f"#!/bin/sh\necho '{out}'\nexit {code}\n"); tool.chmod(0o755)
        return {"PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}"}

    def test_a_held_shared_lane_refuses_a_data_web_or_api_id(self):
        extra = self.fake_lane(3, "BS-DATA-BUG-81 (pid 100)")
        for ident in ("BS-DATA-BUG-72", "BS-WEB-FEAT-2", "BS-API-TASK-3"):
            run = self.dry_run(ident, extra=extra, lane=True)
            self.assertEqual(run.returncode, 3, ident)
            self.assertIn("held by BS-DATA-BUG-81 (pid 100)", run.stderr)

    def test_a_free_shared_lane_or_a_broken_tool_opens(self):
        run = self.dry_run("BS-DATA-BUG-72", extra=self.fake_lane(1, "boom"), lane=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("would open bs-data-bug-72", run.stdout)

    def test_an_ios_id_never_asks_the_shared_lane(self):
        run = self.dry_run("BS-IOS-TASK-5", extra=self.fake_lane(3, "x"), lane=True)
        self.assertNotIn("held by", run.stderr)

    def test_a_data_id_opens_in_the_data_checkout(self):
        run = self.dry_run("BS-DATA-BUG-72")
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout.splitlines()[0], f"would open bs-data-bug-72 (boot /build BS-DATA-BUG-72) in {self.data}")

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
        self.assertEqual(run.stdout.splitlines()[0], f"would open bs-ios-feat-1365 (boot /build BS-IOS-FEAT-1365) in {self.ios}")


if __name__ == "__main__":
    unittest.main()
