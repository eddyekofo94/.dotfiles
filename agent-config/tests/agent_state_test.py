#!/usr/bin/env python3
"""agent_state.py: the Stop and Notification hooks write one status file per session."""
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "claude" / "agent_state.py"
CLOSEOUT = """Done the thing.

**Status:** DONE ✅
Picked / gave up / why: x
Not run: nothing
**Next move:** open BS-IOS-FEAT-9 next

**Ready-to-paste prompt:**
```
go
```"""


class AgentStateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.state = root / "state"
        self.repo = root / "ios"
        subprocess.run(["git", "init", "-q", "-b", "main", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "commit", "-q", "--allow-empty", "-m", "x"],
                       check=True, env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
                                        "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"})
        self.tree = root / "ios-sessions" / "bs-ios-feat-12-home"
        subprocess.run(["git", "-C", str(self.repo), "worktree", "add", "-q", "-b",
                        "feature/bs-ios-feat-12-home", str(self.tree)], check=True)
        self.transcript = root / "t.jsonl"
        self.transcript.write_text(json.dumps({"type": "assistant", "message": {
            "model": "claude-opus-5-5", "usage": {"input_tokens": 10, "cache_read_input_tokens": 41000,
                                                  "cache_creation_input_tokens": 200}}}) + "\n")

    def tearDown(self):
        self.tmp.cleanup()

    def run_hook(self, payload, **env):
        full = {**os.environ, "AGENT_STATE_DIR": str(self.state), "HERDR_PANE_ID": "w1:p3",
                "HERDR_TAB_ID": "w1:t3", "AGENT_WAKE_BIN": str(self.wake_stub()), **env}
        if "AGENT_ROLE" not in env:
            full.pop("AGENT_ROLE", None)
        started = time.monotonic()
        subprocess.run([sys.executable, str(HOOK)], input=json.dumps(payload), text=True, env=full,
                       check=True)
        self.assertLess(time.monotonic() - started, 2.0)
        return json.loads((self.state / f"{payload['session_id']}.json").read_text())

    def wake_stub(self) -> Path:
        """B8: never the real wake-master; a stub that records the name it was given."""
        stub = Path(self.tmp.name) / "wake_stub.py"
        if not stub.exists():
            stub.write_text("import sys, pathlib\n"
                            f"pathlib.Path({str(Path(self.tmp.name) / 'woke')!r}).write_text(sys.argv[1])\n")
        return stub

    def woke(self, wait=3.0):
        flag = Path(self.tmp.name) / "woke"
        end = time.monotonic() + wait
        while time.monotonic() < end and not flag.exists():
            time.sleep(0.05)
        return flag.read_text() if flag.exists() else None

    def test_a_named_worker_hands_its_wake_to_the_master(self):  # master plan B8
        self.run_hook(self.stop(), AGENT_NAME="bs-ios-feat-12")
        self.assertEqual(self.woke(), "bs-ios-feat-12")

    def test_no_wake_from_the_master_an_unnamed_tab_or_when_off(self):
        self.run_hook(self.stop(), AGENT_NAME="master", AGENT_ROLE="master")
        self.run_hook(self.stop(session="abc-2"), AGENT_NAME="")
        self.run_hook(self.stop(session="abc-3"), AGENT_NAME="bs-ios-feat-12", AGENT_WAKE="0")
        self.assertIsNone(self.woke(wait=0.5))

    def stop(self, message=CLOSEOUT, session="abc-1"):
        return {"hook_event_name": "Stop", "session_id": session, "cwd": str(self.tree),
                "transcript_path": str(self.transcript), "last_assistant_message": message}

    def test_a_stop_records_closeout_place_and_context(self):
        entry = self.run_hook(self.stop())
        self.assertEqual(entry["state"], "idle")
        self.assertEqual(entry["status"], "DONE")
        self.assertEqual(entry["next_move"], "open BS-IOS-FEAT-9 next")
        self.assertEqual(entry["repo"], str(self.repo.resolve()))
        self.assertEqual(entry["branch"], "feature/bs-ios-feat-12-home")
        self.assertEqual(entry["record"], "BS-IOS-FEAT-12")
        self.assertEqual(entry["context_tokens"], 41210)
        self.assertEqual(entry["herdr"]["pane"], "w1:p3")

    def test_a_permission_notification_marks_blocked_and_the_next_stop_clears_it(self):
        self.run_hook(self.stop())
        entry = self.run_hook({"hook_event_name": "Notification", "session_id": "abc-1",
                               "cwd": str(self.tree), "notification_type": "permission_prompt",
                               "message": "Claude needs your permission to use Bash"})
        self.assertEqual(entry["state"], "blocked")
        self.assertEqual(entry["status"], "DONE")  # kept from the stop before
        entry = self.run_hook(self.stop("**Status:** PARTIAL 🟡\n**Next move:** keep going"))
        self.assertEqual((entry["state"], entry["status"]), ("idle", "PARTIAL"))
        self.assertNotIn("notice", entry)

    def test_an_idle_prompt_writes_nothing(self):
        subprocess.run([sys.executable, str(HOOK)], input=json.dumps({
            "hook_event_name": "Notification", "session_id": "abc-2", "cwd": str(self.tree),
            "notification_type": "idle_prompt"}), text=True,
            env={**os.environ, "AGENT_STATE_DIR": str(self.state)}, check=True)
        self.assertFalse((self.state / "abc-2.json").exists())

    def test_the_master_role_is_recorded(self):
        self.assertEqual(self.run_hook(self.stop(), AGENT_ROLE="master")["role"], "master")

    def test_the_session_name_is_recorded(self):
        self.assertEqual(self.run_hook(self.stop(), AGENT_NAME="ios-home")["name"], "ios-home")

    def test_garbage_exits_zero_and_writes_nothing(self):
        for body in ("not json", json.dumps({"session_id": "../../etc", "hook_event_name": "Stop"})):
            done = subprocess.run([sys.executable, str(HOOK)], input=body, text=True,
                                  env={**os.environ, "AGENT_STATE_DIR": str(self.state)})
            self.assertEqual(done.returncode, 0)
        self.assertFalse(self.state.exists())


if __name__ == "__main__":
    unittest.main()
