#!/usr/bin/env python3
"""Weekly launch-context token budget check.

Estimates the token cost of the static instruction/memory files Claude Code
loads at session start (AGENTS.md/CLAUDE.md imports + each project's
MEMORY.md) and flags any that drift over budget. This is a size guard, not a
live /context reading: the ratio below is calibrated once against a real
/context report (BibleStandard, 2026-08-11: AGENTS.md 20861 chars = 8.1k
tokens) and drifts with content mix, so treat output as "worth checking",
not exact. Nothing here can call /context itself — that only exists inside a
running Claude Code session.

Add a project to `PROJECTS` below (repo root path) to have it checked too.
The corresponding `~/.claude/projects/<mangled-path>/memory/MEMORY.md` is
found automatically from the repo root.

Each project's newest Claude transcript (its own checkout or a sibling
`<repo>-sessions/<slug>` worktree) is also read for what the session was
actually sent before the first turn: the skill listing, the deferred tool
names, the MCP server instructions and the instruction-file chain, in
characters (BibleStandard FS-285 D9.6). Those are measured, not estimated.
"""

import json
import sys
from pathlib import Path

CHARS_PER_TOKEN = 1 / 0.388  # calibrated ratio, see module docstring

GLOBAL_CLAUDE_MD = Path.home() / ".claude" / "CLAUDE.md"
GLOBAL_AGENTS_MD = Path.home() / ".dotfiles" / "agent-config" / "AGENTS.md"
CLAUDE_PROJECTS = Path.home() / ".claude" / "projects"

# Repo roots to check. Add one path per project you want covered.
PROJECTS = [
    Path.home() / "Programming/Projects/CanonFidei/BibleStandard",
    Path.home() / ".dotfiles",
]

BUDGETS_TOKENS = {
    "global AGENTS.md": 5000,
    "project AGENTS.md/CLAUDE.md": 5000,
    "project MEMORY.md": 3000,
    "project total (AGENTS+CLAUDE+MEMORY)": 10000,
}


# Characters per newest transcript, per attachment (BibleStandard FS-285 D9).
BUDGETS_CHARS = {
    "skill listing": 16000,
    "deferred tool names": 10000,
    "MCP instructions": 8000,
    "instructions": 12000,
}


def tokens(path: Path) -> int:
    if not path.exists():
        return 0
    return round(len(path.read_text(errors="replace")) / CHARS_PER_TOKEN)


def mangled_project_dir(repo_root: Path, projects: Path = CLAUDE_PROJECTS) -> Path:
    # Claude Code's project-dir mangling replaces "/", "_" and "." with "-".
    mangled = str(repo_root).replace("/", "-").replace("_", "-").replace(".", "-")
    return projects / mangled


def newest_transcript(repo_root: Path, projects: Path = CLAUDE_PROJECTS) -> Path | None:
    # A worktree session lives under `<mangled repo>-sessions-<slug>`, so the
    # mangled root is a prefix of every one of the project's directories.
    mangled = mangled_project_dir(repo_root, projects)
    candidates = [
        transcript
        for directory in mangled.parent.glob(mangled.name + "*")
        for transcript in directory.glob("*.jsonl")
    ]
    return max(candidates, key=lambda path: path.stat().st_mtime, default=None)


def transcript_sizes(transcript: Path) -> dict[str, int]:
    """Characters of each launch attachment the newest session state carries.

    Deltas add and remove by name, so the net set is what the model holds; the
    listing and instructions are taken from their latest attachment.
    """
    listing = ""
    instructions = 0
    tools: dict[str, str] = {}
    mcp: dict[str, str] = {}
    for line in transcript.read_text(errors="replace").splitlines():
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("type") != "attachment" or entry.get("isSidechain"):
            continue
        attachment = entry.get("attachment") or {}
        kind = attachment.get("type")
        if kind == "skill_listing":
            listing = attachment.get("content", "")
        elif kind == "instructions":
            instructions = sum(
                len(item.get("content", "")) for item in attachment.get("files", [])
            )
        elif kind == "deferred_tools_delta":
            for name in attachment.get("removedNames", []):
                tools.pop(name, None)
            names = attachment.get("addedNames", [])
            lines = attachment.get("addedLines", names)
            tools.update(zip(names, lines))
        elif kind == "mcp_instructions_delta":
            for name in attachment.get("removedNames", []):
                mcp.pop(name, None)
            mcp.update(zip(attachment.get("addedNames", []), attachment.get("addedBlocks", [])))
    return {
        "skill listing": len(listing),
        "deferred tool names": sum(len(line) for line in tools.values()),
        "MCP instructions": sum(len(block) for block in mcp.values()),
        "instructions": instructions,
    }


def project_agents_and_claude(repo_root: Path) -> int:
    total = 0
    for name in ("AGENTS.md", "CLAUDE.md"):
        total += tokens(repo_root / name)
    return total


def main() -> int:
    over_budget = []
    rows = []

    g = tokens(GLOBAL_CLAUDE_MD) + tokens(GLOBAL_AGENTS_MD)
    rows.append(("global AGENTS.md", g))
    if g > BUDGETS_TOKENS["global AGENTS.md"]:
        over_budget.append(f"global AGENTS.md: ~{g} tok > {BUDGETS_TOKENS['global AGENTS.md']}")

    for repo in PROJECTS:
        if not repo.exists():
            rows.append((f"{repo.name}: MISSING repo path", 0))
            continue
        ac = project_agents_and_claude(repo)
        mem_dir = mangled_project_dir(repo)
        mem = tokens(mem_dir / "memory" / "MEMORY.md")
        total = ac + mem
        rows.append((f"{repo.name}: AGENTS+CLAUDE.md", ac))
        rows.append((f"{repo.name}: MEMORY.md", mem))
        rows.append((f"{repo.name}: total", total))
        if ac > BUDGETS_TOKENS["project AGENTS.md/CLAUDE.md"]:
            over_budget.append(
                f"{repo.name} AGENTS+CLAUDE.md: ~{ac} tok > {BUDGETS_TOKENS['project AGENTS.md/CLAUDE.md']}"
            )
        if mem > BUDGETS_TOKENS["project MEMORY.md"]:
            over_budget.append(
                f"{repo.name} MEMORY.md: ~{mem} tok > {BUDGETS_TOKENS['project MEMORY.md']}"
            )
        if total > BUDGETS_TOKENS["project total (AGENTS+CLAUDE+MEMORY)"]:
            over_budget.append(
                f"{repo.name} total: ~{total} tok > {BUDGETS_TOKENS['project total (AGENTS+CLAUDE+MEMORY)']}"
            )
        transcript = newest_transcript(repo)
        if transcript is None:
            rows.append((f"{repo.name}: no transcript", 0))
            continue
        rows.append((f"{repo.name}: newest transcript {transcript.parent.name}/{transcript.name}", 0))
        for label, chars in transcript_sizes(transcript).items():
            rows.append((f"{repo.name}: {label}", f"{chars} chars"))
            if chars > BUDGETS_CHARS[label]:
                over_budget.append(f"{repo.name} {label}: {chars} chars > {BUDGETS_CHARS[label]}")

    print("Launch-context token budget check (estimated, see docstring)")
    for label, tok in rows:
        if isinstance(tok, str):
            print(f"  {label}: {tok}")
        else:
            print(f"  {label}: ~{tok} tok" if tok else f"  {label}")

    if over_budget:
        print("\nOVER BUDGET:")
        for line in over_budget:
            print(f"  - {line}")
        return 1

    print("\nAll within budget.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
