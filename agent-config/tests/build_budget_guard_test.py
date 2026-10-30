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
WORK = "python3 tools/write_code.py"  # work a held build may not start


def stamp(seconds_ago):
    return datetime.fromtimestamp(time.time() - seconds_ago, timezone.utc).isoformat().replace(
        "+00:00", "Z")


def build_row(seconds_ago, handed_off=False):
    note = " — handed off (build budget): read the plan file's Progress, then go on" * handed_off
    return {"type": "user", "timestamp": stamp(seconds_ago), "origin": {"kind": "human"},
            "message": {"content": f"<command-name>/build</command-name>\n"
                                   f"<command-args>{GOAL}{note}</command-args>"}}


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

    def denied(self, command=WORK):
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

    def run_hook(self, command, tool="Bash", cwd=None):
        payload = {"transcript_path": str(self.transcript), "cwd": str(cwd or self.repo),
                   "tool_name": tool, "tool_input": {"command": command}}
        env = {k: v for k, v in os.environ.items() if k != "BUILD_BUDGET_EXTEND"}
        return subprocess.run([sys.executable, "-I", str(HOOK)], input=json.dumps(payload),
                              capture_output=True, text=True, env=env).stdout

    def hook(self, command, tool="Bash", cwd=None):
        return "deny" if '"deny"' in self.run_hook(command, tool, cwd) else "allow"

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
        self.assertEqual(self.hook(WORK), "deny")
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
        self.hook(WORK)
        self.assertFalse((self.repo / ".working").exists())
        (self.repo / ".working" / SLUG).mkdir(parents=True)
        (self.repo / ".working" / SLUG / "budget-extend").touch()
        self.assertEqual(self.hook(WORK), "deny")

    def test_reason_asks_for_a_reply_never_a_command(self):  # BS-IOS-BUG-670 D2, D4
        self.rows([build_row(3 * 3600, handed_off=True), *work(3 * 3600, 0)])
        reason = json.loads(self.run_hook(WORK))[
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
        self.assertEqual(self.hook(WORK), "allow")

    def test_two_hours_of_work_across_a_night_is_held(self):
        self.rows([build_row(30 * 3600), *work(30 * 3600, 29 * 3600),
                   *work(5 * 3600, 3 * 3600 + 1200, tag="x")])  # 1 h + idle + 1 h 40
        self.assertEqual(self.hook(WORK), "deny")

    def test_an_eleven_hour_gap_passes_and_two_hours_five_is_held(self):  # BS-IOS-BUG-660 D1
        self.rows([build_row(12 * 3600), *work(12 * 3600, 11 * 3600), typed(0)])  # 1 h, 11 h idle
        self.assertEqual(self.hook(WORK), "allow")
        self.rows([build_row(7500), *work(7500, 0)])  # 2 h 5 min of calls, 5 min apart
        self.assertEqual(self.hook(WORK), "deny")

    def test_a_waiting_that_never_woke_holds_nothing(self):  # BS-IOS-TASK-614's night
        self.rows([build_row(40 * 3600), *work(40 * 3600, 39 * 3600)])
        self.assertEqual(self.hook(WORK), "allow")


class Reply(Fixture):
    """BS-IOS-BUG-670 D2: Eddy's message typed after a denial opens a new 2 h window."""

    def test_a_reply_after_the_denial_lifts_the_hold(self):
        self.denied()
        self.rows([typed(0, "keep going")], append=True)
        self.assertEqual(self.hook(WORK), "allow")

    def test_a_message_before_any_denial_lifts_nothing(self):
        self.rows([typed(0, "what are you waiting for?")], append=True)
        self.assertEqual(self.hook(WORK), "deny")

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
        self.assertEqual(self.hook(WORK), "deny")

    def test_the_new_window_runs_out_too(self):
        denial = {"type": "user", "timestamp": stamp(3 * 3600), "message": {"content": [
            {"type": "tool_result", "content": "PreToolUse:Bash hook error: Build budget guard: "
                                               "build past 2 h of working time (build.md §2)"}]}}
        self.rows([build_row(6 * 3600), *work(6 * 3600, 3 * 3600), denial,
                   typed(3 * 3600 - 60), *work(3 * 3600 - 60, 0, tag="y")])
        self.assertEqual(self.hook(WORK), "deny")
        self.rows([typed(0)], append=True)
        self.assertEqual(self.hook(WORK), "deny")  # no denial since
        self.denied()
        self.rows([typed(0)], append=True)
        self.assertEqual(self.hook(WORK), "allow")

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
        self.assertEqual(self.hook(WORK), "allow")
        plan.write_text(plan.read_text() + "  missed its proof\n  missed its proof\n")
        self.assertEqual(self.hook(WORK), "deny")  # step two now


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
        self.assertEqual(self.hook(WORK), "allow")
        self.begin(2)
        self.assertEqual(self.hook(WORK), "deny")

    def test_parking_calls_pass_at_two(self):
        self.begin(2)
        self.assertEqual(self.hook(f"{G} status --short"), "allow")
        self.assertEqual(self.hook("x", tool="Read"), "allow")

    def test_not_counted_sidechain_or_before_the_build(self):
        self.begin(2, sidechain=True, before=3)
        self.assertEqual(self.hook(WORK), "allow")

    def test_a_reply_and_the_record_moving_on_lift_it(self):
        self.begin(3)
        self.denied()
        self.rows([typed(0)], append=True)
        self.assertEqual(self.hook(WORK), "allow")
        self.rows([{"type": "system", "subtype": "compact_boundary"}] * 2, append=True)
        self.assertEqual(self.hook(WORK), "deny")
        self.write_record("DONE")
        self.assertEqual(self.hook(WORK), "allow")


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
        self.assertEqual(self.hook(WORK), "allow")
        self.begin(400)
        self.assertEqual(self.hook(WORK), "deny")

    def test_reason_names_the_turns(self):
        self.begin(400)
        payload = {"transcript_path": str(self.transcript), "cwd": str(self.repo),
                   "tool_name": "Bash", "tool_input": {"command": WORK}}
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
        self.assertEqual(self.hook(WORK), "allow")

    def test_a_reply_and_landing_lift_it(self):
        self.begin(400)
        self.denied()
        self.rows([typed(0)], append=True)
        self.assertEqual(self.hook(WORK), "allow")
        self.rows([{"type": "assistant", "message": {"id": f"n{n}"}} for n in range(400)],
                  append=True)
        self.assertEqual(self.hook(WORK), "deny")
        self.land()
        self.assertEqual(self.hook(WORK), "allow")


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
        self.assertEqual(self.hook(WORK), "deny")

    def test_cd_carries_into_the_cleanup_check(self):
        tree = Path(self.tmp.name) / "wt"
        git(self.repo, "worktree", "add", "-q", "-b", "side", str(tree))
        (tree / "f").write_text("y")
        git(tree, "add", "f")
        git(tree, "commit", "-qm", "unlanded")
        self.assertEqual(self.hook(f"cd {self.tmp.name} && {G} worktree remove wt"), "deny")


class Park(Fixture):
    """BS-IOS-BUG-660 D2, BS-IOS-BUG-845: a held build can do every park step its refusal names."""

    def setUp(self):
        super().setUp()
        backup = tempfile.TemporaryDirectory(dir="/tmp")
        self.addCleanup(backup.cleanup)
        self.backup = Path(backup.name)  # the repo sits in $TMPDIR, never under /tmp

    def edit(self, path, tool="Write"):
        payload = {"transcript_path": str(self.transcript), "cwd": str(self.repo),
                   "tool_name": tool, "tool_input": {"file_path": str(path), "content": "x"}}
        out = subprocess.run([sys.executable, "-I", str(HOOK)], input=json.dumps(payload),
                             capture_output=True, text=True).stdout
        return "deny" if '"deny"' in out else "allow"

    def test_backups_into_tmp_pass(self):  # the 638 park's refusals
        for command in (f"{G} diff > {self.backup}/build.diff",
                        f"{G} diff --cached >> {self.backup}/build.diff 2>/dev/null",
                        f"{G} diff --output={self.backup}/build.diff",
                        f"{G} diff --output {self.backup}/build.diff",
                        f"cp tool.py {self.backup}/", f"{G} ls-tree -r --name-only HEAD",
                        "sort a.txt | head -3", "python3 tools/features_index.py --help"):
            self.assertEqual(self.hook(command), "allow", command)

    def test_writes_outside_tmp_are_refused(self):
        for command in (f"{G} diff > build.diff", f"{G} diff > {self.repo}/build.diff",
                        f"{G} diff --output=build.diff", f"{G} diff > /tmp/../{self.repo}/x",
                        f"cd {self.backup} && {G} diff > x.diff", "sort -o a.txt a.txt",
                        "sort --compress-program=sh a.txt", "sort -ro a.txt a.txt"):
            self.assertEqual(self.hook(command), "deny", command)

    def test_a_link_out_of_tmp_is_refused(self):
        (self.backup / "out").symlink_to(self.repo / "tool.py")
        self.assertEqual(self.hook(f"echo x > {self.backup}/out"), "deny")

    def test_write_into_tmp_passes_and_code_is_refused(self):
        self.assertEqual(self.edit(self.backup / "land-message.txt"), "allow")
        self.assertEqual(self.edit(self.repo / "Sources" / "App" / "View.swift", "Edit"), "deny")
        self.assertEqual(self.edit(self.repo / "Tests" / "ViewTests.swift"), "deny")
        self.assertEqual(self.edit(self.repo / "tool.py", "Edit"), "deny")

    def test_checkout_and_rm_pass_once_the_copy_is_in_tmp(self):
        (self.repo / "tool.py").write_text("x = 2\n")  # tracked dirt
        (self.repo / "Split.swift").write_text("struct Split {}\n")  # an untracked split file
        self.assertEqual(self.hook(f"{G} checkout -- tool.py"), "deny")
        self.assertEqual(self.hook("rm Split.swift"), "deny")
        (self.backup / "tool.py").write_text("x = 1\n")  # not the same bytes
        self.assertEqual(self.hook(f"{G} checkout -- tool.py"), "deny")
        nested = self.backup / "park" / "src"
        nested.mkdir(parents=True)
        (nested / "tool.py").write_text("x = 2\n")
        (nested / "Split.swift").write_text("struct Split {}\n")
        self.assertEqual(self.hook(f"{G} checkout -- tool.py"), "allow")
        self.assertEqual(self.hook(f"{G} -C {self.repo} checkout -q -- tool.py"), "allow")
        self.assertEqual(self.hook("rm Split.swift"), "allow")
        self.assertEqual(self.hook(f"rm -f -- {self.repo}/Split.swift"), "allow")
        self.assertEqual(self.hook(f"{G} checkout -- tool.py && rm Split.swift"), "allow")

    def test_clearing_beyond_the_copies_is_refused(self):
        (self.repo / "Split.swift").write_text("struct Split {}\n")
        (self.backup / "Split.swift").write_text("struct Split {}\n")
        (self.repo / "Other.swift").write_text("struct Other {}\n")
        for command in ("rm Split.swift Other.swift", "rm -rf Split.swift", "rm *.swift",
                        "rm -r .", f"{G} checkout -- .", f"{G} checkout main -- Split.swift",
                        f"{G} checkout -f -- Split.swift", f"{G} checkout -- ':(glob)*.swift'",
                        f"rm {self.backup}/Split.swift", "rm $HOME/Split.swift"):
            self.assertEqual(self.hook(command), "deny", command)

    def test_a_shared_folder_plan_file_passes(self):  # BS-IOS-BUG-845
        folder = self.repo / ".working" / "interviews" / "track"
        folder.mkdir(parents=True)
        self.assertEqual(self.edit(folder / "plan-808.md", "Edit"), "deny")  # no decisions.md
        (folder / "decisions.md").write_text("# decisions\n")
        self.assertEqual(self.edit(folder / "plan-808.md", "Edit"), "allow")
        (folder / "plan-808.md").write_text("- [ ] 1. a step\n")
        self.assertEqual(self.hook(f"{G} add .working/interviews/track/plan-808.md"), "allow")
        self.assertEqual(self.edit(self.repo / "plan-808.md"), "deny")

    def test_a_shared_folder_plan_file_counts_its_tries(self):  # BS-IOS-BUG-845
        folder = self.repo / ".working" / "track"
        folder.mkdir(parents=True)
        plan = folder / "plan-808.md"
        plan.write_text("- [ ] 2. the step\n  missed its proof\n  missed its proof\n")
        self.rows([build_row(600), *work(600, 0),
                   {"type": "assistant", "timestamp": stamp(0), "message": {"id": "p", "content": [
                       {"type": "tool_use", "name": "Edit", "input": {"file_path": str(plan)}}]}}])
        self.assertIn("missed its proof twice", self.run_hook(WORK))

    def test_reason_names_the_park_steps(self):  # D3
        self.rows([build_row(3 * 3600, handed_off=True), *work(3 * 3600, 0)])
        reason = json.loads(self.run_hook(WORK))[
            "hookSpecificOutput"]["permissionDecisionReason"]
        for step in ("/tmp", "--output=", f"{G} checkout -- <file>", "rm <file>", "plan file",
                     "tools/land.py", "reply to give it 2 more hours"):
            self.assertIn(step, reason)
        self.assertNotIn("budget-extend", reason)


class Handoff(Fixture):
    """Eddy, 2026-10-30: time, compactions and turns hand the build to a fresh tab on the
    same checkout; two missed tries, and a second hand-off in a row, still park and split."""

    def reason(self):
        return json.loads(self.run_hook(WORK))[
            "hookSpecificOutput"]["permissionDecisionReason"]

    def test_time_hands_off(self):
        reason = self.reason()
        for step in ("plan file", "## Progress", f"herdr-goal-done --handoff {GOAL}",
                     f"/build {GOAL}", "never ask him"):
            self.assertIn(step, reason)
        self.assertNotIn("reply to give it 2 more hours", reason)
        self.assertNotIn("tools/land.py", reason)

    def test_compactions_and_turns_hand_off(self):
        compacted = {"type": "system", "subtype": "compact_boundary"}
        self.rows([build_row(600), compacted, compacted])
        self.assertIn("compactions: hand off", self.reason())
        self.rows([build_row(600), *work(600, 0, every=1)])
        self.assertIn("turns: hand off", self.reason())

    def test_the_handoff_runs_while_held(self):
        self.assertEqual(self.hook(f"herdr-goal-done --handoff {GOAL}"), "allow")
        self.assertEqual(self.hook(f"herdr-goal-done --handoff {GOAL}; {G} commit -am x"),
                         "deny")

    def test_a_second_handoff_in_a_row_parks(self):
        self.rows([build_row(3 * 3600, handed_off=True), *work(3 * 3600, 0)])
        reason = self.reason()
        self.assertIn("a second time in a row", reason)
        self.assertIn("reply to give it 2 more hours", reason)
        self.assertNotIn("--handoff", reason)

    def test_a_handed_off_tab_inside_its_budget_works(self):
        self.rows([build_row(600, handed_off=True), *work(600, 0)])
        self.assertEqual(self.hook(WORK), "allow")

    def test_missed_tries_still_park(self):
        plan = self.repo / "plan.md"
        plan.write_text("- [ ] 2. the step\n  missed its proof\n  missed its proof\n")
        self.rows([build_row(600), *work(600, 0),
                   {"type": "assistant", "timestamp": stamp(0), "message": {"id": "p", "content": [
                       {"type": "tool_use", "name": "Edit", "input": {"file_path": str(plan)}}]}}])
        reason = self.reason()
        self.assertIn("missed its proof twice", reason)
        self.assertIn("reply to give it 2 more hours", reason)
        self.assertNotIn("--handoff", reason)

    def test_goal_done_opens_the_fresh_tab_and_closes_this_one(self):
        script = HOOK.parents[2] / "herdr" / "goal_done.sh"
        tree = Path(self.tmp.name) / "bs-ios-bug-9001"
        git(self.repo, "worktree", "add", "-q", "-b", "side", str(tree), "main")
        (tree / "dirt.txt").write_text("unfinished\n")  # the dirt stays for the fresh tab
        env = {**os.environ, "HERDR_TAB_ID": "t1", "HERDR_GOAL_DONE_AGENT": "claude"}
        out = subprocess.run(["bash", str(script), "--dry-run", "--handoff", GOAL], cwd=tree,
                             capture_output=True, text=True, env=env)
        self.assertEqual(out.returncode, 0, out.stderr)
        lines = out.stdout.splitlines()
        self.assertIn(f"--cwd {tree.resolve()} --label", lines[0])
        self.assertIn(f'"/build {GOAL} — handed off (build budget)', lines[1])
        self.assertEqual(lines[-1], "would run: herdr tab close t1")
        self.assertNotIn("session_worktree", out.stdout)
        out = subprocess.run(["bash", str(script), "--dry-run", "--handoff", GOAL], cwd=self.repo,
                             capture_output=True, text=True, env=env)
        self.assertNotEqual(out.returncode, 0)
        self.assertIn("not the shared checkout", out.stderr)


class Finish(Fixture):
    """BS-IOS-BUG-1073: a held build at its landable point runs the gate and lands;
    source edits stay refused, and a worktree's park leaves its dirt in place."""

    def edit(self, path):
        payload = {"transcript_path": str(self.transcript), "cwd": str(self.repo),
                   "tool_name": "Edit", "tool_input": {"file_path": str(path)}}
        out = subprocess.run([sys.executable, "-I", str(HOOK)], input=json.dumps(payload),
                             capture_output=True, text=True).stdout
        return "deny" if '"deny"' in out else "allow"

    def reason(self, cwd=None):
        self.rows([build_row(3 * 3600, handed_off=True), *work(3 * 3600, 0)])
        return json.loads(self.run_hook(WORK, cwd=cwd))[
            "hookSpecificOutput"]["permissionDecisionReason"]

    def test_the_gate_runs(self):  # D1
        for command in ("python3 tools/verify_app.py", "python3 tools/verify_app.py --fast",
                        "timeout 3600 python3 tools/verify_app.py --fast",
                        "python3 tools/run_until_red.py --log /tmp/gate.log -- "
                        "python3 tools/verify_app.py --fast",
                        "timeout 3600 python3 tools/run_until_red.py --log /tmp/g.log -- "
                        "python3 tools/verify_app.py --fast 2>&1 | tail -40"):
            self.assertEqual(self.hook(command), "allow", command)

    def test_the_wrappers_run_nothing_else(self):  # D1
        for command in ("timeout 60 " + WORK,
                        "python3 tools/run_until_red.py --log /tmp/g.log -- " + WORK,
                        "python3 tools/run_until_red.py --log log.txt -- "
                        "python3 tools/verify_app.py",
                        "timeout python3 tools/verify_app.py"):
            self.assertEqual(self.hook(command), "deny", command)

    def test_a_code_branch_lands(self):  # D1
        self.assertEqual(self.hook("python3 tools/land.py feature/bug-9001 -F /tmp/m"), "allow")

    def test_source_is_added_and_committed(self):  # D1
        self.assertEqual(self.hook(f"{G} add Sources/x.swift tool.py"), "allow")
        self.assertEqual(self.hook(f"{G} commit -m done -- Sources/x.swift"), "allow")
        self.assertEqual(self.hook(f"{G} commit -F /tmp/m"), "allow")

    def test_source_edits_and_commit_all_stay_refused(self):  # D1
        self.assertEqual(self.edit(self.repo / "Sources" / "x.swift"), "deny")
        self.assertEqual(self.hook(f"{G} commit -a -m done"), "deny")
        self.assertEqual(self.hook(f"{G} commit --all -m done"), "deny")

    def test_reason_leads_with_the_gate_and_the_land(self):  # D3
        reason = self.reason()
        self.assertIn("if only the gate and the land are left, run them now", reason)
        self.assertLess(reason.index("run them now"), reason.index("1. Back up"))
        self.assertIn("reply to give it 2 more hours", reason)

    def test_a_worktree_park_keeps_its_dirt(self):  # D2
        tree = Path(self.tmp.name) / "ios-sessions" / "bs-ios-bug-9001"
        tree.parent.mkdir()
        git(self.repo, "worktree", "add", "-q", "-b", "side", str(tree), "main")
        reason = self.reason(cwd=tree)
        self.assertIn("leave the dirt in place", reason)
        self.assertNotIn(f"{G} checkout -- <file>", reason)
        self.assertIn(f"{G} checkout -- <file>", self.reason())  # the shared checkout clears


class Ended(Fixture):
    """D1: once the build lands or its record moves on, nothing is held."""

    def test_landed_branch_lifts_the_hold(self):  # sighting 1, 3
        self.land()
        self.assertEqual(self.hook(WORK), "allow")

    def test_landed_with_dirt_left_still_holds(self):  # a chunk landed, work goes on
        self.land()
        (self.repo / "tool.py").write_text("x = 2\n")
        self.assertEqual(self.hook(WORK), "deny")

    def test_record_moved_on_lifts_the_hold(self):
        self.write_record("DONE — Awaiting Verdict")
        self.assertEqual(self.hook(WORK), "allow")

    def test_cleanup_after_landing_passes_without_extend(self):  # Done when
        tree = Path(self.tmp.name) / "wt"
        git(self.repo, "worktree", "add", "-q", "-b", "side", str(tree), "main")
        # Even with the build still held, a landed clean worktree may go.
        self.assertEqual(self.hook(f"{G} worktree remove {tree}"), "allow")
        self.assertEqual(self.hook(f"{G} -C {self.repo} branch -d side"), "allow")
        self.assertEqual(self.hook("herdr-goal-done"), "allow")


if __name__ == "__main__":
    unittest.main()
