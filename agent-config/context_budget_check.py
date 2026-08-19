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
"""

import sys
from pathlib import Path

CHARS_PER_TOKEN = 1 / 0.388  # calibrated ratio, see module docstring

GLOBAL_CLAUDE_MD = Path.home() / ".claude" / "CLAUDE.md"
GLOBAL_AGENTS_MD = Path.home() / ".dotfiles" / "agent-config" / "AGENTS.md"

# Repo roots to check. Add one path per project you want covered.
PROJECTS = [
    Path.home()
    / "Documents/Theology/epub_conversion/books/mobile_apps/ios/BibleStandard",
    Path.home() / ".dotfiles",
]

BUDGETS_TOKENS = {
    "global AGENTS.md": 5000,
    "project AGENTS.md/CLAUDE.md": 5000,
    "project MEMORY.md": 3000,
    "project total (AGENTS+CLAUDE+MEMORY)": 10000,
}


def tokens(path: Path) -> int:
    if not path.exists():
        return 0
    return round(len(path.read_text(errors="replace")) / CHARS_PER_TOKEN)


def mangled_project_dir(repo_root: Path) -> Path:
    # Claude Code's project-dir mangling replaces both "/" and "_" with "-".
    mangled = str(repo_root).replace("/", "-").replace("_", "-")
    return Path.home() / ".claude" / "projects" / mangled


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

    print("Launch-context token budget check (estimated, see docstring)")
    for label, tok in rows:
        print(f"  {label}: ~{tok} tok" if isinstance(tok, int) and tok else f"  {label}")

    if over_budget:
        print("\nOVER BUDGET:")
        for line in over_budget:
            print(f"  - {line}")
        return 1

    print("\nAll within budget.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
