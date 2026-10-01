#!/usr/bin/env python3
"""Cover the transcript measure the weekly budget check reads.

The listing, deferred tools and MCP instructions arrive as attachments and
deltas; a measure that double-counts a re-added tool or misses a removal
reports a budget that is not the one the model paid (BibleStandard FS-285).
"""

import json
import os
import runpy
import tempfile
import time
from pathlib import Path

CHECK = runpy.run_path(
    str(Path(__file__).resolve().parents[1] / "context_budget_check.py")
)


def attachment(payload: dict, sidechain: bool = False) -> str:
    return json.dumps({"type": "attachment", "isSidechain": sidechain, "attachment": payload})


def write_transcript(path: Path) -> None:
    lines = [
        json.dumps({"type": "mode", "mode": "auto"}),
        "not json",
        attachment({"type": "skill_listing", "content": "old listing", "isInitial": True}),
        attachment({"type": "skill_listing", "content": "- a: b\n- c: d", "isInitial": True}),
        attachment({"type": "instructions", "files": [{"content": "abc"}, {"content": "de"}]}),
        attachment({"type": "deferred_tools_delta", "addedNames": ["One", "Two"], "addedLines": ["One", "Two"], "removedNames": []}),
        attachment({"type": "deferred_tools_delta", "addedNames": ["Three", "One"], "addedLines": ["Three", "One"], "removedNames": ["Two"]}),
        attachment({"type": "mcp_instructions_delta", "addedNames": ["srv"], "addedBlocks": ["12345"], "removedNames": []}),
        # A subagent's own attachments are not the main session's cost.
        attachment({"type": "skill_listing", "content": "x" * 999}, sidechain=True),
    ]
    path.write_text("\n".join(lines) + "\n")


def test_transcript_sizes_net_the_deltas() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        transcript = Path(temporary) / "s.jsonl"
        write_transcript(transcript)
        sizes = CHECK["transcript_sizes"](transcript)
    assert sizes == {
        "skill listing": len("- a: b\n- c: d"),
        "deferred tool names": len("One") + len("Three"),
        "MCP instructions": 5,
        "instructions": 5,
    }, sizes


def test_newest_transcript_includes_session_worktrees() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        home = Path(temporary)
        repo = home / "Projects" / "My_App"
        projects = home / ".claude" / "projects"
        own = projects / "-tmp-x"  # unrelated project, newest of all
        main = CHECK["mangled_project_dir"](repo, projects)
        worktree = main.with_name(main.name + "-sessions-fs1")
        for directory in (own, main, worktree):
            directory.mkdir(parents=True)
        (main / "a.jsonl").write_text("")
        (worktree / "b.jsonl").write_text("")
        (own / "c.jsonl").write_text("")
        now = time.time()
        os.utime(main / "a.jsonl", (now - 20, now - 20))
        os.utime(worktree / "b.jsonl", (now - 10, now - 10))
        found = CHECK["newest_transcript"](repo, projects)
    assert found == worktree / "b.jsonl", found


def test_mangling_matches_claude_code() -> None:
    mangled = CHECK["mangled_project_dir"](Path("/Users/me/.dotfiles_x"))
    assert mangled.name == "-Users-me--dotfiles-x", mangled.name


if __name__ == "__main__":
    for name, function in list(globals().items()):
        if name.startswith("test_"):
            function()
    print("context_budget_check_test: PASS")
