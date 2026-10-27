#!/usr/bin/env python3
"""Cover the build budget guard's hold (BS-IOS-BUG-581 D6, BS-IOS-BUG-670).

    python3 agent-config/tests/build_budget_guard_test.py

Each case runs the hook as Claude does: a PreToolUse payload on stdin, a transcript
whose `/build` began three hours ago and has worked since, in a scratch git repo with an
`origin/main`.
"""

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime, timezone
from pathlib import Path

HOOK = Path(__file__).resolve().parents[1] / "claude" / "build_budget_guard.py"
GOAL = "BS-IOS-BUG-9001"
SLUG = "bsiosbug9001"


def stamp(seconds_ago):
    return datetime.fromtimestamp(time.time() - seconds_ago, timezone.utc).isoformat().replace(
        "+00:00", "Z")


def build_row(seconds_ago):
    return {"type": "user", "timestamp": stamp(seconds_ago), "origin": {"kind": "human"},
            "message": {"content": f"<command-name>/build</command-name>\n"
                                   f"<command-args>{GOAL}</command-args>"}}


def work(start_ago, end_ago, every=300, tag="w"):
    """Assistant rows every `every` seconds from `start_ago` to `end_ago` (working time)."""
    return [{"type": "assistant", "timestamp": stamp(ago), "message": {"id": f"{tag}{ago}"}}
            for ago in range(start_ago, end_ago - 1, -every)]


def typed(seconds_ago=0, text="go on"):
    return {"type": "user", "timestamp": stamp(seconds_ago), "origin": {"kind": "human"},
            "message": {"content": text}}


def git(repo, *args):
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    out = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, env=env)
    assert out.returncode == 0, out.stderr
    return out.stdout.strip()


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.origin = root / "origin.git"
        self.repo = root / "repo"
        git(root, "init", "-q", "--bare", "-b", "main", str(self.origin))
        git(root, "init", "-q", "-b", "main", str(self.repo))
        self.write_record("OPEN — Ready To Build")
        git(self.repo, "add", "-A")
        # The base commit predates the build, as `main` does when /build opens.
        old = str(int(time.time()) - 4 * 3600)
        os.environ.update(GIT_AUTHOR_DATE=old, GIT_COMMITTER_DATE=old)
        try:
            git(self.repo, "commit", "-qm", "base")
        finally:
            os.environ.pop("GIT_AUTHOR_DATE")
            os.environ.pop("GIT_COMMITTER_DATE")
        git(self.repo, "remote", "add", "origin", str(self.origin))
        git(self.repo, "push", "-q", "origin", "main")
        git(self.repo, "switch", "-qc", "feature/bug-9001")
        (self.repo / "tool.py").write_text("x = 1\n")
        git(self.repo, "add", "tool.py")
        git(self.repo, "commit", "-qm", "the build's change")
        self.transcript = root / "t.jsonl"
        self.rows([build_row(3 * 3600), *work(3 * 3600, 0)])

    def rows(self, rows, append=False):
        with open(self.transcript, "a" if append else "w") as handle:
            handle.writelines(json.dumps(r) + "\n" for r in rows)

    def denied(self, command="python3 tools/verify_app.py"):
        """Run the hook and write its denial into the transcript, as Claude does."""
        out = self.run_hook(command)
        reason = json.loads(out)["hookSpecificOutput"]["permissionDecisionReason"]
        self.rows([{"type": "user", "timestamp": stamp(0), "message": {"content": [
            {"type": "tool_result", "is_error": True,
             "content": f"PreToolUse:Bash hook error: {reason}"}]}}], append=True)
        return reason

    def write_record(self, status):
        bugs = self.repo / "project" / "bugs"
        bugs.mkdir(parents=True, exist_ok=True)
        (bugs / f"{GOAL}-a-bug.md").write_text(f"### A bug\n\n- ID: {GOAL}\n- Status: {status}\n")

    def run_hook(self, command, tool="Bash"):
        payload = {"transcript_path": str(self.transcript), "cwd": str(self.repo),
                   "tool_name": tool, "tool_input": {"command": command}}
        env = {k: v for k, v in os.environ.items() if k != "BUILD_BUDGET_EXTEND"}
        return subprocess.run([sys.executable, "-I", str(HOOK)], input=json.dumps(payload),
                              capture_output=True, text=True, env=env).stdout

    def hook(self, command, tool="Bash"):
        return "deny" if '"deny"' in self.run_hook(command, tool) else "allow"

    def land(self):
        git(self.repo, "switch", "-q", "main")
        git(self.repo, "merge", "-q", "--no-ff", "-m", "land", "feature/bug-9001")
        git(self.repo, "push", "-q", "origin", "main")
        git(self.repo, "switch", "-q", "feature/bug-9001")
        git(self.repo, "merge", "-q", "--ff-only", "main")


G = "g" + "it"  # the splice keeps this file's own lines out of a shell matcher


class Held(Fixture):
    """Past 2 h and unlanded: work is refused, reads and the split pass."""

    def test_work_is_refused(self):
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")
        self.assertEqual(self.hook(f"echo x > tool.py"), "deny")
        self.assertEqual(self.hook(f"{G} log $(echo -1)"), "deny")

    def test_read_only_commands_pass(self):  # D3, sighting 2
        for command in (f"{G} log --oneline -2 origin/main", f"{G} worktree list",
                        "tail -20 /tmp/task.output", f"{G} status --short", f"{G} fetch -q",
                        "head -5 a.txt | grep x", "sed -n 1,5p a.txt", "wc -l a.txt"):
            self.assertEqual(self.hook(command), "allow", command)

    def test_git_globals_and_flags_are_parsed(self):  # D2, sighting 3
        self.assertEqual(self.hook(f"{G} -C {self.repo} push -q origin main"), "allow")
        self.assertEqual(self.hook(f"{G} -c color.ui=never --no-pager log -1"), "allow")
        self.assertEqual(self.hook(f"{G} -C {self.repo} reset --hard"), "deny")

    def test_chains_pass_when_every_part_does(self):  # D2, sighting 3
        line = f"{G} add project/bugs/x.md && {G} commit -q -m split -- project/bugs/x.md"
        self.assertEqual(self.hook(line), "allow")
        self.assertEqual(self.hook(f"{G} status&&{G} log -1;ls"), "allow")
        self.assertEqual(self.hook(f"{G} log -1 2>&1 | tail -3"), "allow")
        self.assertEqual(self.hook(f"{G} status && rm -rf build"), "deny")
        self.assertEqual(self.hook(f"{G} status\nrm tool.py"), "deny")

    def test_no_unlock_file_is_made_or_read(self):  # BS-IOS-BUG-670 D2
        self.hook("python3 tools/verify_app.py")
        self.assertFalse((self.repo / ".working").exists())
        (self.repo / ".working" / SLUG).mkdir(parents=True)
        (self.repo / ".working" / SLUG / "budget-extend").touch()
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")

    def test_reason_asks_for_a_reply_never_a_command(self):  # BS-IOS-BUG-670 D2, D4
        reason = json.loads(self.run_hook("python3 tools/verify_app.py"))[
            "hookSpecificOutput"]["permissionDecisionReason"]
        self.assertIn("reply to give it 2 more hours", reason)
        self.assertNotIn("! ", reason)
        self.assertNotIn("touch", reason)

    def test_unlanded_worktree_removal_is_refused(self):
        tree = Path(self.tmp.name) / "wt"
        git(self.repo, "worktree", "add", "-q", "-b", "side", str(tree))
        (tree / "f").write_text("y")
        git(tree, "add", "f")
        git(tree, "commit", "-qm", "unlanded")
        self.assertEqual(self.hook(f"{G} worktree remove {tree}"), "deny")
        self.assertEqual(self.hook(f"{G} branch -D side"), "deny")


class WorkingTime(Fixture):
    """BS-IOS-BUG-670 D1: the 2 h count only time the tab spent working."""

    def test_an_idle_night_adds_ten_minutes(self):
        # 1 h 40 of work, a 20 h silence, then the next call: 1 h 50 counted.
        self.rows([build_row(22 * 3600), *work(22 * 3600, 22 * 3600 - 6000), typed(0)])
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")

    def test_two_hours_of_work_across_a_night_is_held(self):
        self.rows([build_row(30 * 3600), *work(30 * 3600, 29 * 3600),
                   *work(5 * 3600, 3 * 3600 + 1200, tag="x")])  # 1 h + idle + 1 h 40
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")

    def test_a_waiting_that_never_woke_holds_nothing(self):  # BS-IOS-TASK-614's night
        self.rows([build_row(40 * 3600), *work(40 * 3600, 39 * 3600)])
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")


class Reply(Fixture):
    """BS-IOS-BUG-670 D2: Eddy's message typed after a denial opens a new 2 h window."""

    def test_a_reply_after_the_denial_lifts_the_hold(self):
        self.denied()
        self.rows([typed(0, "keep going")], append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")

    def test_a_message_before_any_denial_lifts_nothing(self):
        self.rows([typed(0, "what are you waiting for?")], append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")

    def test_text_eddy_did_not_type_lifts_nothing(self):
        self.denied()
        self.rows([
            {"type": "user", "timestamp": stamp(0), "origin": {"kind": "task-notification"},
             "message": {"content": "<task-notification> done"}},
            {"type": "user", "timestamp": stamp(0), "isMeta": True,
             "message": {"content": [{"type": "text", "text": "hook context"}]}},
            {"type": "user", "timestamp": stamp(0), "message": {"content": [
                {"type": "tool_result", "content": "ok"}]}},
            {"type": "user", "timestamp": stamp(0),
             "message": {"content": "<system-reminder>x</system-reminder>"}}], append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")

    def test_the_new_window_runs_out_too(self):
        denial = {"type": "user", "timestamp": stamp(3 * 3600), "message": {"content": [
            {"type": "tool_result", "content": "PreToolUse:Bash hook error: Build budget guard: "
                                               "build past 2 h of working time (build.md §2)"}]}}
        self.rows([build_row(6 * 3600), *work(6 * 3600, 3 * 3600), denial,
                   typed(3 * 3600 - 60), *work(3 * 3600 - 60, 0, tag="y")])
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")
        self.rows([typed(0)], append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")  # no denial since
        self.denied()
        self.rows([typed(0)], append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")

    def test_a_reply_waves_on_the_missed_step(self):
        self.rows([build_row(600), *work(600, 0)])
        plan = self.repo / ".working" / SLUG / "plan.md"
        plan.parent.mkdir(parents=True)
        plan.write_text("- [ ] step one\n  missed its proof\n  missed its proof\n- [ ] step two\n")
        self.rows([{"type": "assistant", "timestamp": stamp(0), "message": {"id": "p", "content": [
            {"type": "tool_use", "name": "Write", "input": {"file_path": str(plan)}}]}}],
            append=True)
        self.assertIn("step one", self.denied())
        self.rows([typed(0, "try it once more")], append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")
        plan.write_text(plan.read_text() + "  missed its proof\n  missed its proof\n")
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")  # step two now


class Compactions(Fixture):
    """A build inside its 2 h that has compacted twice is held (retro 2026-10-27)."""

    def begin(self, boundaries, sidechain=False, before=0):
        rows = [{"type": "system", "subtype": "compact_boundary"}] * before
        started = datetime.fromtimestamp(time.time() - 600, timezone.utc)
        rows.append({"type": "user", "timestamp": started.isoformat().replace("+00:00", "Z"),
                     "message": {"content": f"<command-name>/build</command-name>\n"
                                            f"<command-args>{GOAL}</command-args>"}})
        rows += [{"type": "system", "subtype": "compact_boundary",
                  **({"isSidechain": True} if sidechain else {})}] * boundaries
        self.transcript.write_text("".join(json.dumps(r) + "\n" for r in rows))

    def test_one_compaction_passes_two_are_held(self):
        self.begin(1)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")
        self.begin(2)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")

    def test_parking_calls_pass_at_two(self):
        self.begin(2)
        self.assertEqual(self.hook(f"{G} status --short"), "allow")
        self.assertEqual(self.hook("x", tool="Read"), "allow")

    def test_not_counted_sidechain_or_before_the_build(self):
        self.begin(2, sidechain=True, before=3)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")

    def test_a_reply_and_the_record_moving_on_lift_it(self):
        self.begin(3)
        self.denied()
        self.rows([typed(0)], append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")
        self.rows([{"type": "system", "subtype": "compact_boundary"}] * 2, append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")
        self.write_record("DONE")
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")


class Turns(Fixture):
    """A build inside its 2 h that has run 400 main-thread turns is held (BS-IOS-TASK-671 D2)."""

    def begin(self, turns, sidechain=0, before=0, repeats=0):
        def turn(n, **extra):
            return {"type": "assistant", "message": {"id": f"msg_{n}", "content": []}, **extra}
        rows = [turn(f"old{n}") for n in range(before)]
        started = datetime.fromtimestamp(time.time() - 600, timezone.utc)
        rows.append({"type": "user", "timestamp": started.isoformat().replace("+00:00", "Z"),
                     "message": {"content": f"<command-name>/build</command-name>\n"
                                            f"<command-args>{GOAL}</command-args>"}})
        rows += [turn(n) for n in range(turns)]
        rows += [turn(0) for _ in range(repeats)]  # one turn streamed as several rows
        rows += [turn(f"side{n}", isSidechain=True) for n in range(sidechain)]
        self.transcript.write_text("".join(json.dumps(r) + "\n" for r in rows))

    def test_399_passes_400_is_held(self):
        self.begin(399)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")
        self.begin(400)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")

    def test_reason_names_the_turns(self):
        self.begin(400)
        payload = {"transcript_path": str(self.transcript), "cwd": str(self.repo),
                   "tool_name": "Bash", "tool_input": {"command": "python3 tools/verify_app.py"}}
        out = subprocess.run([sys.executable, "-I", str(HOOK)], input=json.dumps(payload),
                             capture_output=True, text=True,
                             env={k: v for k, v in os.environ.items() if k != "BUILD_BUDGET_EXTEND"})
        self.assertIn("build past 400 turns", out.stdout)

    def test_parking_calls_pass_at_400(self):
        self.begin(400)
        self.assertEqual(self.hook(f"{G} status --short"), "allow")
        self.assertEqual(self.hook("x", tool="Read"), "allow")

    def test_not_counted_sidechain_repeats_or_before_the_build(self):
        self.begin(399, sidechain=50, before=50, repeats=50)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")

    def test_a_reply_and_landing_lift_it(self):
        self.begin(400)
        self.denied()
        self.rows([typed(0)], append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")
        self.rows([{"type": "assistant", "message": {"id": f"n{n}"}} for n in range(400)],
                  append=True)
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")
        self.land()
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")


class Bypasses(Fixture):
    """The review's probes (BS-IOS-BUG-581 lens): a held build cannot write or land
    through a command the parser reads as allowed."""

    def test_writes_through_reads_are_refused(self):
        for command in (f"{G} fetch -u . HEAD:main", f"{G} fetch . HEAD:main",
                        "cat a >| b", "echo x 1>|f", "cat <> f", f"{G} diff --output=f",
                        "sed -n -i 1p f", "sed -n 'w f' a", f"{G} -c core.pager=sh -p log",
                        "rg --pre sh x", "cat a > b"):
            self.assertEqual(self.hook(command), "deny", command)

    def test_landing_onto_local_main_does_not_end_the_hold(self):
        git(self.repo, "branch", "-f", "main", "HEAD")
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")

    def test_cd_carries_into_the_cleanup_check(self):
        tree = Path(self.tmp.name) / "wt"
        git(self.repo, "worktree", "add", "-q", "-b", "side", str(tree))
        (tree / "f").write_text("y")
        git(tree, "add", "f")
        git(tree, "commit", "-qm", "unlanded")
        self.assertEqual(self.hook(f"cd {self.tmp.name} && {G} worktree remove wt"), "deny")


class Ended(Fixture):
    """D1: once the build lands or its record moves on, nothing is held."""

    def test_landed_branch_lifts_the_hold(self):  # sighting 1, 3
        self.land()
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")

    def test_landed_with_dirt_left_still_holds(self):  # a chunk landed, work goes on
        self.land()
        (self.repo / "tool.py").write_text("x = 2\n")
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "deny")

    def test_record_moved_on_lifts_the_hold(self):
        self.write_record("DONE — Awaiting Verdict")
        self.assertEqual(self.hook("python3 tools/verify_app.py"), "allow")

    def test_cleanup_after_landing_passes_without_extend(self):  # Done when
        tree = Path(self.tmp.name) / "wt"
        git(self.repo, "worktree", "add", "-q", "-b", "side", str(tree), "main")
        # Even with the build still held, a landed clean worktree may go.
        self.assertEqual(self.hook(f"{G} worktree remove {tree}"), "allow")
        self.assertEqual(self.hook(f"{G} -C {self.repo} branch -d side"), "allow")
        self.assertEqual(self.hook("herdr-goal-done"), "allow")


if __name__ == "__main__":
    unittest.main()
