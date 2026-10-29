#!/usr/bin/env python3
"""context_guard.py: past the near note, a tool call is refused until the resume file is written."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "claude" / "context_guard.py"
SESSION = "d29b02d1-test"


class ContextGuardHoldTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.transcript = self.dir / "t.jsonl"
        self.at(20_000)

    def tearDown(self):
        self.tmp.cleanup()

    def at(self, *sizes: int) -> None:
        """The transcript's usage lines; the window is the 87k fallback unless a size drops."""
        with self.transcript.open("a") as handle:
            for size in sizes:
                handle.write(json.dumps({"message": {"usage": {"input_tokens": size}}}) + "\n")

    def hook(self, event: str, tool: str = "", tool_input: dict | None = None, **extra) -> dict:
        payload = {"session_id": SESSION, "transcript_path": str(self.transcript),
                   "hook_event_name": event, "tool_name": tool, "tool_input": tool_input or {}, **extra}
        out = subprocess.run([sys.executable, "-I", str(HOOK)], input=json.dumps(payload),
                             capture_output=True, text=True, timeout=20,
                             env={**os.environ, "TMPDIR": str(self.dir)})
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout) if out.stdout.strip() else {}

    def refused(self, tool: str, tool_input: dict, **extra) -> bool:
        spoken = self.hook("PreToolUse", tool, tool_input, **extra).get("hookSpecificOutput", {})
        return spoken.get("permissionDecision") == "deny"

    def near(self) -> None:
        self.at(80_000)  # 92% of 87k
        note = self.hook("PostToolUse", "Bash", {"command": "ls"})
        self.assertIn("compaction is near", note["hookSpecificOutput"]["additionalContext"])

    def test_tool_call_refused_until_the_resume_file_is_written(self):
        self.near()
        self.assertTrue(self.refused("Bash", {"command": "git status"}))
        self.assertTrue(self.refused("Edit", {"file_path": "/r/Sources/App.swift"}))
        self.assertTrue(self.refused("Read", {"file_path": "/r/Sources/App.swift"}))
        save = {"file_path": "/r/.working/bs-ios-task-1027/handoff.md", "content": "next: A3"}
        self.assertFalse(self.refused("Write", save))
        self.hook("PostToolUse", "Write", save)
        self.assertFalse(self.refused("Bash", {"command": "git status"}))
        self.assertFalse(self.refused("Edit", {"file_path": "/r/Sources/App.swift"}))

    def test_reading_and_finding_the_resume_file_stay_open(self):
        self.near()
        self.assertFalse(self.refused("Read", {"file_path": "/r/.working/x/plan.md"}))
        self.assertFalse(self.refused("Glob", {"pattern": "**/plan.md"}))

    def test_each_resume_file_lifts_the_hold(self):
        for call in [("Edit", {"file_path": "/r/.working/interviews/x/plan.md"}),
                     ("MultiEdit", {"file_path": "/r/.working/interviews/x/decisions.md"}),
                     ("Write", {"file_path": "/tmp/handoff-context-guard.md"}),
                     ("Bash", {"command": "printf 'next' >> /tmp/handoff-context-guard.md"}),
                     ("Bash", {"command": "cat <<'EOF' > .working/x/plan.md\nnext\nEOF"}),
                     ("Bash", {"command": "echo next | tee -a \"/r/x/handoff.md\""})]:
            with self.subTest(call=call):
                self.tearDown()
                self.setUp()
                self.near()
                self.assertFalse(self.refused(*call))
                self.hook("PostToolUse", *call)
                self.assertFalse(self.refused("Bash", {"command": "git status"}))

    def test_a_read_or_other_name_does_not_count_as_a_save(self):
        self.near()
        for call in [("Bash", {"command": "cat .working/x/plan.md"}),
                     ("Write", {"file_path": "/r/notes.md"}),
                     ("Write", {"file_path": "/r/myplan.md"})]:
            self.hook("PostToolUse", *call)
        self.assertTrue(self.refused("Bash", {"command": "git status"}))

    def test_a_compaction_lifts_an_unsaved_hold(self):
        self.near()
        self.at(10_000)
        self.assertFalse(self.refused("Bash", {"command": "git status"}))

    def test_compaction_above_half_lifts_the_hold(self):
        self.near()
        self.at(30_000, 53_000)  # 2026-10-29: this session resumed at 53k of 85k, still held
        self.hook("SessionStart", source="compact")
        self.assertFalse(self.refused("Bash", {"command": "git status"}))

    def test_stale_reading_after_compaction_is_not_a_new_note(self):
        """BS-IOS-TASK-1022, 2026-10-29: the log still ended on 86k when the next call ran."""
        self.near()
        self.hook("PostToolUse", "Write", {"file_path": "/r/plan.md"})
        self.hook("SessionStart", source="compact")
        self.assertEqual(self.hook("PostToolUse", "ToolSearch", {}), {})
        self.assertFalse(self.refused("Bash", {"command": "git status"}))
        self.at(37_000)
        self.assertEqual(self.hook("PostToolUse", "Bash", {"command": "ls"}), {})
        self.at(76_000)  # 95% of the 80k this session compacted at: the bands re-armed
        self.assertIn("compaction is near",
                      self.hook("PostToolUse", "Bash", {"command": "ls"})["hookSpecificOutput"]["additionalContext"])
        self.assertTrue(self.refused("Bash", {"command": "git status"}))

    def test_a_python_script_that_writes_the_plan_is_a_save(self):
        """BS-IOS-TASK-1021 and 1031 (2026-10-29) were refused `python3 - <<EOF` rewriting plan.md."""
        for command in ["python3 - <<'EOF'\np='.working/x/plan-bs-ios-task-1021.md'\ns=open(p).read()\nopen(p,'w').write(s)\nEOF",
                        "python3 - <<'EOF'\nfrom pathlib import Path\np = Path(\".working/x/plan.md\"); s = p.read_text()\np.write_text(s)\nEOF",
                        "sed -i '' 's/State: none/State: step 2/' .working/x/plan.md"]:
            with self.subTest(command=command):
                self.tearDown()
                self.setUp()
                self.near()
                self.assertFalse(self.refused("Bash", {"command": command}))
                self.hook("PostToolUse", "Bash", {"command": command})
                self.assertFalse(self.refused("Bash", {"command": "git status"}))

    def test_a_script_that_only_reads_the_plan_or_writes_elsewhere_is_no_save(self):
        self.near()
        for command in ["python3 -c \"print(open('.working/x/plan.md').read())\"",
                        "python3 -c \"open('/tmp/out.txt','w').write('x')\""]:
            self.hook("PostToolUse", "Bash", {"command": command})
        self.assertTrue(self.refused("Bash", {"command": "git status"}))

    def test_a_named_plan_file_is_a_save(self):
        """BS-IOS-TASK-1022 was refused an Edit of its own plan-bs-ios-task-1022.md."""
        self.near()
        call = ("Edit", {"file_path": "/r/.working/interviews/risk-scan/plan-bs-ios-task-1022.md"})
        self.assertFalse(self.refused(*call))
        self.hook("PostToolUse", *call)
        self.assertFalse(self.refused("Bash", {"command": "git status"}))

    def test_no_hold_before_the_near_note(self):
        self.at(65_000)  # 75%: the early note only
        note = self.hook("PostToolUse", "Bash", {"command": "ls"})
        self.assertNotIn("near", note["hookSpecificOutput"]["additionalContext"])
        self.assertFalse(self.refused("Bash", {"command": "git status"}))

    def test_saved_session_hears_no_second_note(self):
        self.near()
        self.hook("PostToolUse", "Write", {"file_path": "/r/handoff.md"})
        self.at(84_000)
        self.assertEqual(self.hook("PostToolUse", "Bash", {"command": "ls"}), {})

    def test_big_whole_file_read_is_refused_once_then_allowed(self):
        big, small = self.dir / "Big.swift", self.dir / "Small.swift"
        big.write_text("x" * 40_000)
        small.write_text("x" * 1_000)
        self.assertTrue(self.refused("Read", {"file_path": str(big)}))
        self.assertFalse(self.refused("Read", {"file_path": str(big)}))
        self.assertFalse(self.refused("Read", {"file_path": str(small)}))

    def test_ranged_read_and_resume_file_are_never_refused(self):
        big, plan = self.dir / "Big.swift", self.dir / "plan.md"
        big.write_text("x" * 40_000)
        plan.write_text("x" * 40_000)
        self.assertFalse(self.refused("Read", {"file_path": str(big), "limit": 80}))
        self.assertFalse(self.refused("Read", {"file_path": str(plan)}))

    def test_subagent_is_never_held(self):
        self.near()
        self.assertFalse(self.refused("Bash", {"command": "git status"}, agent_id="a1"))

    def test_broken_input_fails_open(self):
        out = subprocess.run([sys.executable, "-I", str(HOOK)], input="not json",
                             capture_output=True, text=True, timeout=20)
        self.assertEqual((out.returncode, out.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
