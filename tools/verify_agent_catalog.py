#!/usr/bin/env python3
"""Fail closed when the shared Codex/Claude skill catalog drifts."""

from __future__ import annotations

import ast
import json
from pathlib import Path
import tomllib


HOME = Path.home()
AGENT_SKILLS = HOME / ".agent-skills"
CODEX_CONFIG = HOME / ".codex/config.toml"
CLAUDE_SETTINGS = HOME / ".claude/settings.json"
MAX_CODEX_CATALOG_CHARS = 7_600

CORE_PERSONAL = {
    "bug",
    "code-review",
    "diagnosing-bugs",
    "doctor",
    "feature-plan",
    "grill-me",
    "heal",
    "herdr",
    "loop",
    "research",
    "skill-finish",
    "spec-ticket",
    "todo",
}

CLAUDE_OFF = {
    "ask-eddy",
    "claude-handoff",
    "codex-first",
    "grill-with-docs",
    "grilling",
    "handoff",
    "implement",
    "improve-codebase-architecture",
    "loop-me",
    "setup-matt-pocock-skills",
    "teach",
    "to-spec",
    "to-tickets",
    "triage",
    "wayfinder",
    "writing-great-skills",
}

CLAUDE_MANUAL = {
    "app-store-changelog",
    "codebase-design",
    "domain-modeling",
    "git-guardrails-claude-code",
    "ios-debugger-agent",
    "mattpocock-skill-sync",
    "migrate-to-shoehorn",
    "project-skill-audit",
    "prototype",
    "refactor",
    "resolving-merge-conflicts",
    "scaffold-exercises",
    "setup-pre-commit",
    "setup-ts-deep-modules",
    "single-dev-server",
    "swift-concurrency-expert",
    "swiftui-liquid-glass",
    "swiftui-performance-audit",
    "swiftui-ui-patterns",
    "swiftui-view-refactor",
    "tdd",
    "wizard",
    "writing-beats",
    "writing-fragments",
    "writing-shape",
}

SYSTEM_VISIBLE = {"imagegen", "openai-docs", "skill-creator"}
SYSTEM_DISABLED = {"plugin-creator", "skill-installer"}

DISABLED_PLUGINS = {
    "anthropic-skills@claude-cowork",
    "browser@openai-bundled",
    "chrome@openai-bundled",
    "computer-use@openai-bundled",
    "documents@openai-primary-runtime",
    "figma@openai-curated",
    "github@openai-curated",
    "gmail@openai-curated-remote",
    "pdf@openai-primary-runtime",
    "presentations@openai-primary-runtime",
    "spreadsheets@openai-primary-runtime",
    "template-creator@openai-primary-runtime",
    "visualize@openai-bundled",
}


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def frontmatter_value(path: Path, key: str) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        fail(f"missing frontmatter: {path}")
    for line in lines[1:]:
        if line == "---":
            break
        prefix = f"{key}:"
        if line.startswith(prefix):
            value = line[len(prefix) :].strip()
            if value[:1] in {'"', "'"}:
                try:
                    return str(ast.literal_eval(value))
                except (SyntaxError, ValueError):
                    fail(f"invalid {key} scalar: {path}")
            return value
    fail(f"missing {key}: {path}")


def skill_cost(path: Path) -> int:
    return len(str(path)) + len(frontmatter_value(path, "name")) + len(
        frontmatter_value(path, "description")
    )


def main() -> None:
    codex = tomllib.loads(CODEX_CONFIG.read_text(encoding="utf-8"))
    claude = json.loads(CLAUDE_SETTINGS.read_text(encoding="utf-8"))

    plugins = codex.get("plugins", {})
    if set(plugins) != DISABLED_PLUGINS:
        fail(f"Codex plugin set drifted: {set(plugins) ^ DISABLED_PLUGINS}")
    if any(config.get("enabled") is not False for config in plugins.values()):
        fail("every optional Codex plugin must be disabled by default")

    personal_dirs = {
        path.parent.name for path in AGENT_SKILLS.glob("*/SKILL.md")
    }
    expected_disabled = CLAUDE_OFF | CLAUDE_MANUAL
    if personal_dirs != CORE_PERSONAL | expected_disabled:
        drift = personal_dirs ^ (CORE_PERSONAL | expected_disabled)
        fail(f"personal skill inventory drifted: {drift}")

    configured: dict[str, list[dict[str, object]]] = {}
    for item in codex.get("skills", {}).get("config", []):
        name = Path(str(item["path"])).parent.name
        configured.setdefault(name, []).append(item)
    expected_configured = expected_disabled | SYSTEM_DISABLED
    if set(configured) != expected_configured:
        fail(f"Codex disabled skill set drifted: {set(configured) ^ expected_configured}")
    for name, entries in configured.items():
        if len(entries) != 1 or entries[0].get("enabled") is not False:
            fail(f"Codex skill must have one disabled entry: {name}")
        if not Path(str(entries[0]["path"])).is_file():
            fail(f"disabled skill source missing: {name}")

    overrides = claude.get("skillOverrides", {})
    expected_overrides = {
        **{name: "off" for name in CLAUDE_OFF},
        **{name: "user-invocable-only" for name in CLAUDE_MANUAL},
    }
    if overrides != expected_overrides:
        fail("Claude skillOverrides drifted")
    if (HOME / ".claude/skills").resolve() != AGENT_SKILLS:
        fail("Claude shared-skill symlink drifted")

    visible_paths = [AGENT_SKILLS / name / "SKILL.md" for name in CORE_PERSONAL]
    visible_paths += [
        AGENT_SKILLS / ".system" / name / "SKILL.md" for name in SYSTEM_VISIBLE
    ]
    for path in visible_paths:
        if not path.is_file():
            fail(f"visible skill source missing: {path}")
    catalog_chars = sum(skill_cost(path) for path in visible_paths)
    if catalog_chars > MAX_CODEX_CATALOG_CHARS:
        fail(
            f"Codex catalog estimate {catalog_chars} exceeds "
            f"{MAX_CODEX_CATALOG_CHARS}"
        )

    print("PASS: Codex TOML and Claude JSON parsed")
    print(f"PASS: {len(DISABLED_PLUGINS)} optional Codex plugins disabled")
    print(f"PASS: {len(expected_disabled)} personal skills hidden")
    print(f"PASS: {len(CORE_PERSONAL)} personal workflow skills visible")
    print(f"PASS: Codex catalog estimate {catalog_chars}/{MAX_CODEX_CATALOG_CHARS}")


if __name__ == "__main__":
    main()
