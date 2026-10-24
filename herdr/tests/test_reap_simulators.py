#!/usr/bin/env python3
"""herdr-reap's simulator pass: each repo's own doctor closes owner-less QA simulators."""
import contextlib
import importlib.machinery
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("reap_idle", str(HERE / "reap_idle.py"))
spec = importlib.util.spec_from_loader("reap_idle", loader)
reap = importlib.util.module_from_spec(spec)
sys.modules["reap_idle"] = reap
loader.exec_module(reap)

FAKE_DOCTOR = """import sys
print("args", " ".join(sys.argv[1:]))
print("doctor: ran `python3 tools/sim_input.py release X orphan` (simulator BS QA orphan X)")
print("memory: 4.0 GB available")
"""


class ReapSimulatorsTests(unittest.TestCase):
    def repo(self, doctor: bool) -> Path:
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        if doctor:
            (root / "tools").mkdir()
            (root / "tools/doctor.py").write_text(FAKE_DOCTOR, encoding="utf-8")
        return root

    def run_pass(self, repo: Path, dry_run: bool) -> str:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            reap.reap_simulators(repo, dry_run)
        return out.getvalue()

    def test_a_live_pass_fixes_and_logs_only_what_it_freed(self) -> None:
        said = self.run_pass(self.repo(True), dry_run=False)
        self.assertIn("doctor: ran `python3 tools/sim_input.py release X orphan`", said)
        self.assertNotIn("memory:", said)
        self.assertNotIn("args", said)

    def test_a_dry_run_reports_without_fix(self) -> None:
        said = self.run_pass(self.repo(True), dry_run=True)
        self.assertIn("args --simulators\n", said)
        self.assertNotIn("--fix", said)

    def test_a_repo_without_a_doctor_is_skipped(self) -> None:
        self.assertEqual(self.run_pass(self.repo(False), dry_run=False), "")


if __name__ == "__main__":
    unittest.main()
