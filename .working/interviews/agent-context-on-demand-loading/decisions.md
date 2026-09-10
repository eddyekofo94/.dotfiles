# Agent Context On-Demand Loading

Status: Idea

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

## Relationships

- **refines** `codex-skill-context-cleanup`: that goal reduced plugin and skill
  catalog context but explicitly excluded MCP servers.
- **blocked by** `pi-session-info-color-hierarchy`: it is the repository's one
  active implementation goal; this entry is intake only.

## Validation Needed

- Parse the managed TOML with `codex --strict-config`.
- Compare `codex mcp list`, plugin status, fresh-session visible capabilities,
  startup token estimate, and spawned MCP processes before and after.
- Run `agent-config/verify.sh`, the catalog verifier, and fresh Standards and
  Fidelity review.

## Unresolved

- Decide whether rare MCPs should use named Codex profiles, project-local
  configuration, or explicit temporary enablement.
- Determine whether Figma's current-session visibility is stale app-server
  state or a Codex plugin-state defect despite `enabled = false`.
