#!/usr/bin/env python3
"""Fail closed when the shared Codex/Claude skill catalog drifts."""

from __future__ import annotations

import ast
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import tomllib


HOME = Path.home()
REPO_ROOT = Path(__file__).resolve().parent.parent
AGENT_SKILLS = Path(os.environ.get("AGENT_SKILLS_ROOT", HOME / ".agent-skills"))
CODEX_CONFIG = REPO_ROOT / "agent-config/codex/config.toml"
CLAUDE_SETTINGS = REPO_ROOT / "agent-config/claude/settings.json"
CODEX_HOOKS = REPO_ROOT / "tmux/hooks/codex.json"
MAX_CODEX_CATALOG_CHARS = 7_600

SYSTEM_VISIBLE = {"imagegen", "openai-docs", "skill-creator"}
SYSTEM_DISABLED = {"plugin-creator", "review-agent", "skill-installer"}
TRUSTED_SKILL_HOOK_HASH = (
    "sha256:a66d0b73fb99fe23f37f773e1a26624c26660d90604775053ea498a586196829"
)

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
    "sites@openai-bundled",
}

DISABLED_MCPS = {
    "XcodeBuildMCP",
    "apple-docs",
    "computer-use",
    "context7",
    "node_repl",
    "openaiDeveloperDocs",
}

PROFILE_ENABLES = {
    "browser": ({"node_repl"}, {"browser@openai-bundled", "chrome@openai-bundled"}),
    "computer-use": ({"node_repl", "computer-use"}, {"computer-use@openai-bundled"}),
    "design": (set(), {"figma@openai-curated", "visualize@openai-bundled"}),
    "docs": ({"context7", "openaiDeveloperDocs"}, set()),
    "ios": ({"XcodeBuildMCP", "apple-docs"}, set()),
    "office": (set(), {
        "documents@openai-primary-runtime",
        "pdf@openai-primary-runtime",
        "presentations@openai-primary-runtime",
        "spreadsheets@openai-primary-runtime",
    }),
    "sites": (set(), {"sites@openai-bundled"}),
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


def canonical_inventory() -> tuple[set[str], set[str]]:
    module = REPO_ROOT / "pi/extensions/compat-core.mjs"
    script = """
import { pathToFileURL } from "node:url";
const [modulePath, root] = process.argv.slice(1);
const { enabledSkills, startupSkills } = await import(pathToFileURL(modulePath));
process.stdout.write(JSON.stringify({
  enabled: enabledSkills(root),
  startup: startupSkills(root),
}));
"""
    result = subprocess.run(
        ["node", "--input-type=module", "-e", script, str(module), str(AGENT_SKILLS)],
        check=True,
        capture_output=True,
        text=True,
        timeout=10,
    )
    inventory = json.loads(result.stdout)
    return set(inventory["enabled"]), set(inventory["startup"])


def model_visible_skills() -> set[str]:
    codex_bin = os.environ.get("CODEX_BIN", "codex")
    with tempfile.TemporaryDirectory(prefix="codex-catalog-") as temporary:
        codex_home = Path(temporary) / "codex"
        codex_home.mkdir()
        shutil.copy2(CODEX_CONFIG, codex_home / "config.toml")
        os.symlink(AGENT_SKILLS, codex_home / "skills")
        environment = {**os.environ, "CODEX_HOME": str(codex_home)}
        result = subprocess.run(
            [codex_bin, "debug", "prompt-input"],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=REPO_ROOT,
            env=environment,
        )
        prompt_items = json.loads(result.stdout)
    skill_contexts = [
        content.get("text", "")
        for item in prompt_items
        for content in item.get("content", [])
        if content.get("text", "").startswith("<skills_instructions>")
    ]
    if len(skill_contexts) != 1:
        fail("Codex did not emit exactly one model-visible skill catalog")
    return set(re.findall(r"^- ([a-z0-9]+(?:-[a-z0-9]+)*):", skill_contexts[0], re.M))


def main() -> None:
    codex = tomllib.loads(CODEX_CONFIG.read_text(encoding="utf-8"))
    claude = json.loads(CLAUDE_SETTINGS.read_text(encoding="utf-8"))

    plugins = codex.get("plugins", {})
    if set(plugins) != DISABLED_PLUGINS:
        fail(f"Codex plugin set drifted: {set(plugins) ^ DISABLED_PLUGINS}")
    if any(config.get("enabled") is not False for config in plugins.values()):
        fail("every optional Codex plugin must be disabled by default")

    personal_dirs, core_personal = canonical_inventory()
    on_demand = personal_dirs - core_personal
    archive_paths = set(AGENT_SKILLS.glob("_archive/*/SKILL.md"))
    archive_names = {path.parent.name for path in archive_paths}

    configured: dict[Path, list[dict[str, object]]] = {}
    for item in codex.get("skills", {}).get("config", []):
        configured.setdefault(Path(str(item["path"])), []).append(item)
    expected_configured = {
        *(AGENT_SKILLS / name / "SKILL.md" for name in on_demand),
        *archive_paths,
        *(AGENT_SKILLS / ".system" / name / "SKILL.md" for name in SYSTEM_DISABLED),
    }
    if set(configured) != expected_configured:
        fail(f"Codex disabled skill set drifted: {set(configured) ^ expected_configured}")
    for skill_path, entries in configured.items():
        if len(entries) != 1 or entries[0].get("enabled") is not False:
            fail(f"Codex skill must have one disabled entry: {skill_path}")
        if not skill_path.is_file():
            fail(f"disabled skill source missing: {skill_path}")

    overrides = claude.get("skillOverrides", {})
    expected_overrides = {
        **{name: "user-invocable-only" for name in on_demand},
        **{name: "off" for name in archive_names},
    }
    if overrides != expected_overrides:
        fail("Claude skillOverrides drifted")
    if (HOME / ".claude/skills").resolve() != AGENT_SKILLS:
        fail("Claude shared-skill symlink drifted")

    visible_paths = [AGENT_SKILLS / name / "SKILL.md" for name in core_personal]
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
    expected_visible = core_personal | SYSTEM_VISIBLE
    visible = model_visible_skills()
    if visible != expected_visible:
        fail(f"Codex model-visible skill catalog drifted: {visible ^ expected_visible}")

    print("PASS: Codex TOML and Claude JSON parsed")
    print(f"PASS: {len(DISABLED_PLUGINS)} optional Codex plugins disabled")
    mcps = codex.get("mcp_servers", {})
    if set(mcps) != DISABLED_MCPS:
        fail(f"Codex MCP set drifted: {set(mcps) ^ DISABLED_MCPS}")
    if any(config.get("enabled") is not False for config in mcps.values()):
        fail("every optional Codex MCP must be disabled by default")

    for profile, (expected_mcps, expected_plugins) in PROFILE_ENABLES.items():
        profile_path = REPO_ROOT / f"agent-config/codex/{profile}.config.toml"
        profile_config = tomllib.loads(profile_path.read_text(encoding="utf-8"))
        enabled_mcps = {
            name for name, value in profile_config.get("mcp_servers", {}).items()
            if value.get("enabled") is True
        }
        enabled_plugins = {
            name for name, value in profile_config.get("plugins", {}).items()
            if value.get("enabled") is True
        }
        if enabled_mcps != expected_mcps or enabled_plugins != expected_plugins:
            fail(f"Codex {profile} profile activation set drifted")

    hooks = json.loads(CODEX_HOOKS.read_text(encoding="utf-8"))
    prompt_hooks = hooks.get("hooks", {}).get("UserPromptSubmit", [])
    skill_handlers = [
        handler
        for group in prompt_hooks
        for handler in group.get("hooks", [])
        if "on-demand-skill.mjs" in handler.get("command", "")
    ]
    if len(skill_handlers) != 1 or skill_handlers[0].get("additionalContextLimit") != 0:
        fail("Codex on-demand skill hook is not registered exactly once without truncation")
    trusted_hook = codex.get("hooks", {}).get("state", {}).get(
        "/Users/eddyekofo/.codex/hooks.json:user_prompt_submit:1:0", {}
    )
    if trusted_hook.get("trusted_hash") != TRUSTED_SKILL_HOOK_HASH:
        fail("Codex on-demand skill hook hash is not trusted")

    print(f"PASS: {len(on_demand)} personal skills available only on demand")
    print(f"PASS: {len(core_personal)} personal workflow skills visible")
    print(f"PASS: exact {len(visible)}-skill Codex model-visible catalog")
    print(f"PASS: {len(DISABLED_MCPS)} optional Codex MCPs disabled")
    print(f"PASS: {len(PROFILE_ENABLES)} explicit capability profiles")
    print(f"PASS: Codex catalog estimate {catalog_chars}/{MAX_CODEX_CATALOG_CHARS}")


if __name__ == "__main__":
    main()
