#!/usr/bin/env python3
"""compact_handoff.py: what the summary keeps and what a compacted session is told."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "claude" / "compact_handoff.py"


def run(mode: str, payload: dict) -> str:
    out = subprocess.run([sys.executable, "-I", str(HOOK), mode], input=json.dumps(payload),
                         capture_output=True, text=True, timeout=20)
    assert out.returncode == 0, out.stderr
    return out.stdout


class CompactHandoffTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name) / "repo"
        root.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "feature/fs297-grill"], cwd=root, check=True)
        plan = root / ".working/interviews/fs297-cover-swing-open/plan.md"
        plan.parent.mkdir(parents=True)
        plan.write_text("# plan\n\n- [x] A1 done\n- [ ] A2 the close. Proof: frames\n- [ ] A3 later\n")
        self.root, self.plan = root, plan
        self.transcript = Path(self.tmp.name) / "t.jsonl"
        self.transcript.write_text("")

    def tearDown(self):
        self.tmp.cleanup()

    def payload(self, **extra):
        return {"cwd": str(self.root), "transcript_path": str(self.transcript), **extra}

    def test_resume_names_goal_plan_and_next_step_from_branch(self):
        ctx = json.loads(run("resume", self.payload(source="compact")))
        text = ctx["hookSpecificOutput"]["additionalContext"]
        self.assertIn("FS-297", text)
        self.assertIn(".working/interviews/fs297-cover-swing-open/plan.md", text)
        self.assertIn("A2 the close. Proof: frames", text)
        self.assertIn("keeps its goal, its authorization and its mode", text)

    def test_transcript_write_wins_over_branch(self):
        other = self.root / ".working/interviews/bug390-thing/plan.md"
        other.parent.mkdir(parents=True)
        other.write_text("- [ ] B1 fix it\n")
        line = {"message": {"content": [{"type": "tool_use", "name": "Edit",
                                         "input": {"file_path": str(other)}}]}}
        self.transcript.write_text(json.dumps(line) + "\n")
        text = json.loads(run("resume", self.payload(source="compact")))["hookSpecificOutput"]["additionalContext"]
        self.assertIn("BUG-390", text)
        self.assertIn("B1 fix it", text)

    def test_precompact_lists_what_to_keep(self):
        text = run("precompact", self.payload(trigger="auto"))
        self.assertIn("FS-297", text)
        self.assertIn("plan.md", text)
        self.assertIn("feature/fs297-grill", text)
        self.assertIn("correction Eddy gave", text)

    def test_subagent_is_silent(self):
        self.assertEqual(run("precompact", self.payload(agent_id="a1")), "")
        self.assertEqual(run("resume", self.payload(agent_id="a1", source="compact")), "")

    def test_resume_ignores_other_sources(self):
        self.assertEqual(run("resume", self.payload(source="clear")), "")

    def test_no_goal_still_continues(self):
        bare = Path(self.tmp.name) / "bare"
        bare.mkdir()
        text = json.loads(run("resume", {"cwd": str(bare), "source": "compact"}))
        self.assertIn("continues", text["hookSpecificOutput"]["additionalContext"])

    def test_record_from_reads_every_id_form_whole(self):
        """BibleStandard IOS-FEAT-537: a new id whole, never its `bug-537` tail."""
        import importlib.util
        path = Path(__file__).resolve().parent.parent / "claude" / "compact_handoff.py"
        spec = importlib.util.spec_from_file_location("compact_handoff", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for name, want in (("fs515-x", "FS-515"), ("bug-402", "BUG-402"), ("ios-feat-515-x", "IOS-FEAT-515"),
                           ("bs-ios-bug-537-x", "BS-IOS-BUG-537"), ("qa-ios-feat-9", "IOS-FEAT-9"), ("main", "")):
            self.assertEqual(module.record_from(name), want, name)

    def test_bad_input_exits_zero(self):
        out = subprocess.run([sys.executable, "-I", str(HOOK), "resume"], input="not json",
                             capture_output=True, text=True)
        self.assertEqual((out.returncode, out.stdout), (0, ""))


class ContextGuardMessageTest(unittest.TestCase):
    def test_no_band_asks_eddy_to_compact(self):
        sys.path.insert(0, str(HOOK.parent))
        import context_guard
        for band in ("early", "near"):
            text = context_guard.message(band, 130_000, 185_000)
            self.assertNotIn("so he can /compact", text)
            self.assertNotIn("open a fresh tab", text)


if __name__ == "__main__":
    unittest.main()
