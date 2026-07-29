# Codex And Claude Skill Context Cleanup

## Goal

Reduce the always-visible Codex and Claude skill catalogs enough that normal
sessions no longer shorten skill descriptions to fit their initial-context
budgets.

## Exit Criteria

- `~/.codex/config.toml` parses as TOML.
- `~/.claude/settings.json` parses as JSON.
- Selected redundant and low-frequency plugins are explicitly disabled.
- Superseded and low-frequency personal skills are hidden from model context in
  both agents.
- Skill and plugin source files remain installed for rollback.
- Fresh Codex and Claude sessions are used to test whether catalog warnings
  disappear.

## Scope / Non-goals

Scope is the local Codex and Claude catalog configuration and durable rationale.
Non-goals are deleting plugin caches or personal skill sources, editing skill
contents, changing MCP servers, or removing engineering, EPUB, SwiftUI/iOS,
GitHub, Figma, browser, computer-use, PDF, and spreadsheet capabilities from
disk. Specialist capabilities may be hidden by default and re-enabled when a
task needs them.

## Decisions

- Prefer the documented reversible `enabled = false` mechanism over deletion.
- Disable the `anthropic-skills` plugin because its artifact skills duplicate
  OpenAI document, PDF, presentation, and spreadsheet capabilities.
- Disable every optional Codex plugin by default. Plugin bundles can be
  re-enabled for a task that specifically needs them; keeping Figma and GitHub
  always visible would exceed the catalog budget even though they have real
  project history.
- Disable personal skills superseded by the unified workflow:
  `ask-eddy`, `claude-handoff`, `codex-first`, `grill-with-docs`, `grilling`,
  `handoff`, `implement`, `improve-codebase-architecture`, `loop-me`,
  `setup-matt-pocock-skills`, `teach`, `to-spec`, `to-tickets`, `triage`,
  `wayfinder`, and `writing-great-skills`.
- Keep these rare specialists manually invocable in Claude and disabled by
  default in Codex: `app-store-changelog`, `codebase-design`,
  `domain-modeling`, `git-guardrails-claude-code`, `ios-debugger-agent`,
  `mattpocock-skill-sync`, `migrate-to-shoehorn`, `project-skill-audit`,
  `prototype`, `refactor`, `resolving-merge-conflicts`, `scaffold-exercises`,
  `setup-pre-commit`, `setup-ts-deep-modules`, `single-dev-server`,
  `swift-concurrency-expert`, `swiftui-liquid-glass`,
  `swiftui-performance-audit`, `swiftui-ui-patterns`,
  `swiftui-view-refactor`, `tdd`, `wizard`, `writing-beats`,
  `writing-fragments`, and `writing-shape`.
- Keep only the cross-project core always visible: `code-review`,
  `diagnosing-bugs`, `doctor`, `feature-plan`, `grill-me`, `heal`, `herdr`,
  `loop`, `research`, `skill-finish`, `spec-ticket`, and `todo`, plus the
  system `imagegen`, `openai-docs`, and `skill-creator` skills.
- Preserve all disabled source folders so any capability can be restored by
  changing one flag and restarting Codex.
- Keep Claude's unified workflow skills model-visible. Use `skillOverrides` to
  mark superseded personal skills `off` and rare but potentially useful skills
  `user-invocable-only`; both states remove their descriptions from model
  context, while the latter preserves explicit manual invocation.
- Retain Claude's sole installed plugin, `swift-lsp`; it supports recurring iOS
  work and is not responsible for the shared personal-skill catalog size.

## Evidence / Findings

- The Codex manual states that the initial skills list uses at most 2% of the
  context window or 8,000 characters when the context window is unknown, and
  that descriptions are shortened before skills are omitted.
- Before this change, 12 plugin entries were enabled in the local config, in
  addition to the shared personal skill catalog and system skills.
- All 13 configured optional Codex plugins are disabled by default.
- Forty-one personal skills are hidden from Claude model context and disabled
  in Codex: sixteen superseded skills plus twenty-five low-frequency manual
  tools.
- Claude's official documentation states that `skillOverrides` can hide a skill
  from model context without editing shared `SKILL.md` files; the
  `user-invocable-only` state keeps the skill in the slash menu.

## Tradeoffs / Risks

- Disabled capabilities will not be available implicitly until re-enabled.
- The active sessions cannot prove the post-restart catalog or warning state.
- Plugin IDs and cached versions can change in later Codex releases; the stable
  control surface is the plugin key in `~/.codex/config.toml`, not cache paths.

## Validation Plan

- Parse `~/.codex/config.toml` with Python's standard-library `tomllib`.
- Parse `~/.claude/settings.json` with `jq`.
- Assert every selected plugin key has `enabled = false`.
- Assert every selected personal skill path has exactly one disabled config
  entry and still exists on disk.
- Assert Claude has 41 matching `skillOverrides`, that retained unified
  workflow skills have no override, and that all source directories still
  exist through the shared symlink.
- Run `python3 tools/verify_agent_catalog.py`; it checks the exact plugin and
  skill sets, shared-source existence, retained workflow visibility, and a
  conservative 7,000-character Codex catalog ceiling.
- Run `git diff --check` for the durable repository records.
- In fresh Codex and Claude sessions, verify catalog warnings are absent and
  retained unified workflow skills remain available.

## Ready To Act

Ready. The user explicitly requested disabling or deleting excess skills; the
reversible disabling policy resolves that request without destructive removal.

## Open Questions

- None. On 2026-07-19 the user confirmed that fresh Codex and Claude sessions
  accept the catalog cleanup.

## Review Evidence

- The initial fresh review found one Standards issue and three Fidelity issues:
  no durable verifier, a still-oversized 23.7K catalog estimate, incomplete
  personal-skill classification, and a Codex-only exit-criterion phrase.
- Automatic fixes added `tools/verify_agent_catalog.py`, reduced the default
  Codex catalog to 6,876/7,000 estimated characters, documented all 41 hidden
  personal skills, and aligned the exit criteria across Codex and Claude.
- Post-fix fresh review passed with 0 Standards findings and 0 Fidelity
  findings. Automated implementation and review are complete; the active goal
  was closed after the user's fresh-session confirmation on 2026-07-19.
