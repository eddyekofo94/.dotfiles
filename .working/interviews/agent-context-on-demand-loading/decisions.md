# Agent Context On-Demand Loading

Status: Implemented — locally verified, not pushed

## Want

New Codex sessions should start with only routinely useful tools and skills.
Rare Figma, Apple documentation, library-documentation, Xcode, and browser
capabilities should not consume startup context merely because they are
installed.

Source, Eddy, 2026-09-10:

> for new codex sessions, I see figma/apple docs mcps being loaded on startup,
> I haven't used figma in 3 months, that's token bloat, can we refine the
> sessions and startup token usage?

## Existing Seam

- `agent-config/codex/config.toml` owns enabled plugins, skills, and Model
  Context Protocol (MCP) servers and is symlinked to `~/.codex/config.toml`.
- `.working/interviews/codex-skill-context-cleanup/decisions.md` already made
  optional plugins, including Figma, disabled by default and reduced the
  always-visible personal-skill catalog.
- Live inspection on 2026-09-10 reports Figma `installed, disabled`, while
  `apple-docs`, `context7`, `XcodeBuildMCP`, `openaiDeveloperDocs`, and
  `node_repl` remain globally enabled.

Disposition: **finetune** the managed Codex config and its existing catalog
verifier. Do not add a second configuration owner or delete installed plugins.

## Outcome Contract

- Default sessions expose only cross-project capabilities used routinely.
- Rare capabilities remain installed and can be enabled deliberately for a
  matching task or project.
- Fresh-session startup context and MCP process count are measured before and
  after the change.
- Figma must remain disabled by default; its unexpected visibility must be
  traced to the actual runtime/plugin owner rather than guessed from cache
  paths.
- Existing sandbox, Auto-review, hooks, memory, and core workflow skills must
  not regress.

## Decisions

- Use one six-skill startup allowlist across Pi, Codex, and Claude: `bug`,
  `feature`, `feature-plan`, `goals`, `skill-finish`, and `todo`.
- Keep every other validated top-level shared skill installed. Pi and Codex
  resolve `$name`, `/name`, and `/skill:name` against that inventory and load
  only the selected `SKILL.md`; Claude uses `user-invocable-only`.
- Reuse Pi's validated inventory and token-boundary parser in Codex's
  `UserPromptSubmit` hook. Unknown `$name` and `/skill:name`, multiple skills,
  malformed sources, and unavailable sources fail closed. Paths, URLs, quoted
  examples, code spans, and unrelated slash commands remain prompt text.
- Disable every optional Codex Model Context Protocol (MCP) server and plugin
  in the base configuration. Preserve their definitions and installed source.
- Use official named Codex profiles for capabilities that must be selected
  before a session starts: `browser`, `computer-use`, `design`, `docs`, `ios`,
  `office`, and `sites`.
- Preserve the live Codex marketplace, desktop, and trusted-browser metadata
  updates and the Pi `gpt-5.5` default while merging the settings.

## Relationships

- **refines** `codex-skill-context-cleanup`: that goal reduced plugin and skill
  catalog context but explicitly excluded MCP servers.
- **follows** `pi-session-info-color-hierarchy`, which closed on 2026-09-10;
  this entry remains intake until selected through `feature-plan`.

## Validation Needed

- Parse the managed TOML with `codex --strict-config`.
- Compare `codex mcp list`, plugin status, fresh-session visible capabilities,
  startup token estimate, and spawned MCP processes before and after.
- Run `agent-config/verify.sh`, the catalog verifier, and fresh Standards and
  Fidelity review.

## Platform Boundary

- Codex can add skill instructions to the current prompt through a hook, but a
  disabled MCP server cannot be started and registered halfway through an
  existing session. Profiles are therefore the supported deliberate activation
  boundary: start `codex --profile <name>` for that capability.
- Figma and every other optional plugin are disabled in the base config and
  enabled only by a matching profile.

## Implementation Evidence

- Before the change, each observed Codex process started `node_repl`,
  `apple-doc-mcp`, `context7-mcp`, and `xcodebuildmcp` immediately.
- The managed catalog verifier reports six visible personal workflow skills,
  twenty-nine on-demand personal skills, fourteen disabled optional plugins,
  six disabled MCP servers, and seven explicit profiles.
- Focused hook tests cover all three invocation forms, core-skill native
  delegation, quoted/path/code false positives, unknown skills, multiple
  skills, invalid payloads, and disappearing sources.
- A fresh disposable base Codex app-server thread started with no child MCP
  processes; all six configured MCP servers reported disabled.
- The `ios` profile reported only `apple-docs` and `XcodeBuildMCP` enabled;
  the remaining MCP servers stayed disabled. A post-install authenticated
  fresh-session process check remains part of the final shared-checkout gate.
- Fresh Standards and Fidelity re-reviews returned zero findings after the
  archive-visibility, hook-trust, and evidence fixes.
