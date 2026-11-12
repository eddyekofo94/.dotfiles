#!/usr/bin/env python3
"""herdr-reap and herdr-goal-done read a repo's records.py where it has no features_index.py
(BibleStandard BS-DATA-TASK-84: the data checkout builds one record at a time)."""
import os as _os, tempfile as _tempfile  # master plan B6: never find the live master
_os.environ["HERDR_SESSIONS_DIR"] = _tempfile.mkdtemp(prefix="no-master-")
import importlib.machinery
import importlib.util
import subprocess
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

FOCUS = 'import json; print(json.dumps({"next": [], "resume": [{"id": "X"}] if %s else []}))'


class FocusToolTests(unittest.TestCase):
    def repo(self, name: str, resume: bool) -> Path:
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        (root / "tools").mkdir()
        (root / "tools" / name).write_text(FOCUS % resume)
        return root

    def test_records_py_answers_when_there_is_no_features_index(self):
        self.assertTrue(reap.orphaned(self.repo("records.py", resume=True)))
        self.assertFalse(reap.orphaned(self.repo("records.py", resume=False)))

    def test_features_index_still_answers_first(self):
        self.assertTrue(reap.orphaned(self.repo("features_index.py", resume=True)))

    def test_goal_done_picks_records_py_only_beside_a_worktree_manager(self):
        text = (HERE / "goal_done.sh").read_text()
        self.assertIn('[ -f "$shared/tools/records.py" ] && [ -f "$shared/tools/session_worktree.py" ]', text)
        self.assertEqual(subprocess.run(["bash", "-n", str(HERE / "goal_done.sh")]).returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
