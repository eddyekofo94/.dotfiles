# Pi 0.82.1: MCP and iOS development

**Date:** 2026-07-30  
**Scope:** Pi 0.82.1, the isolated `pi-pilot`, maintained Pi packages, and native iOS/Xcode development. “iOS” below means Apple’s operating system, not ISO standards.

## Executive answer

- **Pi 0.82.1 has no native MCP client.** This is deliberate: upstream says “No MCP” and directs users toward CLI tools plus skills or an extension that adds MCP support. It also omits native subagents and other workflow features by design. ([Pi 0.82.1 README](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/README.md#philosophy))
- **MCP can be added, but not safely by simply copying the orchestrator-wide configuration into the pilot.** Third-party extensions execute with the Pi process’s full user permissions. ([Pi security model](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/docs/security.md#no-built-in-sandbox))
- **Best MCP candidate:** `pi-mcp-adapter@2.15.0`, after source review and with a pilot-specific wrapper/config. It gives one `mcp` proxy tool, tool search/describe, cached metadata, lazy connections by default, per-server lifecycle and disablement, and optional selected direct tools. ([package record](https://pi.dev/packages/pi-mcp-adapter), [source README](https://github.com/nicobailon/pi-mcp-adapter#pi-mcp-adapter))
- **Best immediate iOS path:** use the maintained `xcodebuildmcp` **CLI and CLI skill**, not its MCP server mode. Pi already has `bash`, and the CLI exposes the same build, test, Simulator, device, debugging, and UI-automation implementations without adding a general MCP bridge. ([XcodeBuildMCP CLI](https://www.xcodebuildmcp.com/docs/cli))
- **Do not make `pi-build-ios-apps` the default for Bible Standard.** It does expose useful Xcode/Simulator tools, but its stated product direction is React Native-first and it currently pins XcodeBuildMCP 2.6.2 while upstream is at 2.7.0. ([package record and README](https://pi.dev/packages/pi-build-ios-apps))
- **`@ttiimmaahh/pi-xcode` is not usable on this Mac’s current Xcode 26.6.** It is a standalone Xcode Intelligence ACP agent requiring Xcode 27+, currently beta-only, rather than a normal terminal-Pi extension. ([package record and requirements](https://pi.dev/packages/%40ttiimmaahh/pi-xcode))

No package was installed and no Pi runtime configuration was changed during this research.

## What Pi itself provides

Pi’s built-in development surface is intentionally small: `read`, `write`, `edit`, and `bash` are enabled by default, with `grep`, `find`, and `ls` available as built-in tools. Extensions can add arbitrary tools and integrations. ([Pi 0.82.1 quick start and tool reference](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/README.md#quick-start))

Pi does natively support Agent Skills. It puts only skill names and descriptions in the prompt, then loads a matching `SKILL.md` on demand. Global skills, explicitly configured skills, package skills, and trusted project skills are supported. ([Pi 0.82.1 skills documentation](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/docs/skills.md#how-skills-work))

Pi package scope and MCP server-config scope are separate:

- `pi install <package>` records a global package.
- `pi install -l <package>` records a project package in `.pi/settings.json`.
- Project packages and `.pi` resources load only after Pi trusts the project. ([Pi package management](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/docs/packages.md#install-and-manage))
- An MCP extension may independently read `.mcp.json` or another file in the working directory. Pi project trust must not be assumed to guard a third-party extension’s own file reads.

## The isolated pilot’s current boundary

The repository-owned pilot currently:

- pins Pi 0.82.1 and sets `defaultProjectTrust` to `never`;
- launches Pi with `--no-approve`;
- rejects `--approve`, `--no-approve`, `--extension`, `--skill`, and other isolation-bypassing flags;
- allows only the reviewed package pin `npm:@ff-labs/pi-fff@0.10.1`;
- rejects package mutation commands and verifies the installed package tree before launch;
- exposes only `skill-finish` and `herdr` from the shared skill catalog.

Local evidence: [`pi/settings.json`](../../pi/settings.json), [`pi/pilot.sh`](../../pi/pilot.sh), and [`pi/install.sh`](../../pi/install.sh).

Therefore a normal project-local `pi install -l ...` or `.pi/settings.json` entry is **not currently an activation path in this pilot**. That is intentional. A new MCP or iOS package needs the same reviewed-pin, lifecycle-script-disabled, hashed-tree installation path already used for FFF.

## Maintained MCP options

The package catalog is fast-moving. The versions and publication activity below were checked on 2026-07-30.

| Package | Connection behavior | Tool surface | Scope and server control | Main limitation for this pilot |
|---|---|---|---|---|
| [`pi-mcp-adapter@2.15.0`](https://pi.dev/packages/pi-mcp-adapter) | **Lazy on first tool call by default**; optional `eager`, `keep-alive`, or `lazy-keep-alive`; idle disconnect supported | One `mcp` proxy by default with `search`, `describe`, and call; cached metadata allows discovery without a live connection; selected/all direct tools are optional | Global and project MCP files; `disabled`; `/mcp enable/disable`; `includeTools`/`excludeTools`; host-specific Codex/Claude discovery is off by default | Its default export automatically reads shared `.mcp.json` paths and project `.mcp.json`/`.pi/mcp.json`. That file discovery is separate from Pi’s project-trust loader. Use an isolated programmatic config or a reviewed trust-aware wrapper. |
| [`@qianhuan-lxs/pi-mcp-bridge@0.5.6`](https://pi.dev/packages/%40qianhuan-lxs/pi-mcp-bridge?name=MCP) | Lazy on call with idle disconnect | Three generic tools (`CallMcpTool`, `FetchMcpResource`, `ListMcpResources`) plus a filesystem registry; large registries load schemas on demand | Servers are explicitly added/synced into its registry | Tool metadata must first be synced and is injected as a compact registry block; it is not the same searchable proxy surface as `pi-mcp-adapter`. |
| [`@spences10/pi-mcp@0.0.57`](https://pi.dev/packages/%40spences10/pi-mcp) | No startup connection by default; manual `/mcp connect`; optional eager environment flag; idle disconnect | Registers every discovered tool directly after a server connects | Global and project `mcp.json`; per-server enable/disable; its own project-config trust prompt and `MY_PI_MCP_PROJECT_CONFIG=skip` fail-closed option | No proxy tool search; connecting a large server adds all of its tool schemas to the model surface. |
| [`pi-mcp-extension@1.5.0`](https://pi.dev/packages/pi-mcp-extension) | `lazy` is the default, but means **manual** `/mcp:start`; `eager` starts on session start | Registers each discovered MCP tool directly | Global and `.pi/mcp.json`; start/stop commands | No tool search/proxy and no documented persistent per-server disable flag; inactive tools are unavailable until the user starts the server. |

Other recent MCP packages exist, including `@pi-unipi/mcp`, but “recently published” is not the same as reviewed or appropriate for an isolated pilot. Pi’s own documentation warns that packages run with full system access and must be reviewed before installation. ([Pi package security warning](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/docs/packages.md#install-and-manage))

### Recommended MCP design

Use `pi-mcp-adapter`, but **do not load its ambient default export unchanged**.

The reviewed pilot integration should:

1. Pin the exact package version and dependency lock, disable lifecycle scripts, patch only if required, and hash the installed tree.
2. Load `createMcpAdapter({ config: ... })` through a small repository-owned wrapper. The package documents that an in-memory `config` is a complete isolated snapshot and does not merge global, imported, command-line, or project configuration. ([adapter SDK configuration](https://github.com/nicobailon/pi-mcp-adapter#sdk-configuration))
3. Keep every server at `lifecycle: "lazy"`.
4. Keep `directTools: false` by default so Pi receives one searchable proxy tool rather than every MCP schema.
5. Put only reviewed servers in that snapshot and use explicit `includeTools`/`excludeTools` where a server is broad.
6. If server availability must differ by repository, let the trusted wrapper compare the canonical working directory with a repository-owned allowlist outside the project. Do not let an arbitrary checkout activate commands through its own `.mcp.json`.
7. Do not enable host-config discovery or import Codex, Claude, Cursor, or other orchestrator configs.

This avoids orchestrator-wide automatic connections: Pi sees only the curated server catalog, and no server process or HTTP session starts until the agent actually calls a tool.

There are currently no shared standard MCP files at `~/.config/mcp/mcp.json`, `~/.agents/mcp.json`, or `~/.agents/mcp/mcp.json` on this Mac. That lowers today’s accidental-import risk, but the wrapper should still fail closed if one appears later.

## Pi-native iOS development

### Recommended baseline: CLI plus skill

Use Pi’s built-in file tools and `bash` with XcodeBuildMCP’s CLI:

1. Load a reviewed XcodeBuildMCP **CLI skill** so the model learns the command surface on demand.
2. Run `xcodebuildmcp doctor` before the first build in a workspace.
3. Establish project/workspace, scheme, and Simulator defaults in `.xcodebuildmcp/config.yaml` only in a trusted app repository.
4. Use `xcodebuildmcp simulator build`, `test`, or `build-and-run`.
5. Use `xcodebuildmcp ui-automation ...` and screenshots for Simulator interaction proof.
6. Use the project’s own verification command as the engineering gate, then leave physical-device and subjective tactile acceptance open until performed.

XcodeBuildMCP 2.7.0 exposes direct terminal commands for Simulator build/install/launch/test/logging, devices, macOS, Swift packages, LLDB debugging, and UI automation. Stateful operations start a per-workspace daemon only on first use and shut it down after ten idle minutes. CLI and MCP modes share the same tool implementations. ([official CLI reference](https://www.xcodebuildmcp.com/docs/cli))

This route is closer to Pi’s own recommended philosophy—CLI tools documented by skills—and does not require any MCP connection at Pi startup.

Current local facts:

- Xcode: **26.6** (`17F113`)
- `sourcekit-lsp`: available at `/usr/bin/sourcekit-lsp`
- `xcodebuildmcp`: not currently on `PATH`
- `xcrun simctl`: available

### Useful packages and skills

| Capability | Candidate | Recommendation and limitation |
|---|---|---|
| Xcode/Simulator/build/test/UI automation | [`xcodebuildmcp@2.7.0`](https://github.com/getsentry/XcodeBuildMCP) CLI plus its CLI skill | **Recommended first.** Maintained, broad native-Apple workflow, no Pi MCP adapter required. It is not installed yet and its package/skill must be pinned and reviewed for the pilot. |
| Swift diagnostics and source actions | [`@narumitw/pi-lsp`](https://pi.dev/packages/%40narumitw/pi-lsp) | **Optional second.** Supports `sourcekit-lsp`, starts language servers only for tool calls, and provides `lsp_diagnostics`/`lsp_fix`. It does not build, test, launch, or automate Simulator UI. Its project config is used only for Pi-trusted projects, which matches upstream security expectations but means the current `--no-approve` pilot would use global/built-in config. |
| Turn Pi into an Xcode Intelligence agent | [`@ttiimmaahh/pi-xcode@0.2.4`](https://pi.dev/packages/%40ttiimmaahh/pi-xcode) | **Defer.** Requires Xcode 27+ beta; current Xcode is 26.6. It is a standalone ACP executable launched by Xcode, not the normal terminal-Pi migration path. |
| All-in-one Pi mobile toolkit | [`pi-build-ios-apps@0.4.0`](https://pi.dev/packages/pi-build-ios-apps) | **Do not use as the SwiftUI default.** Useful tools exist, but the package is explicitly React Native-first, adds eleven tools and multiple runtime surfaces, and pins an older XcodeBuildMCP than current upstream. Review only if a React Native project needs its browser-first loop. |
| Swift/SwiftUI domain guidance | Existing shared skills: `swift-concurrency-expert`, `swiftui-liquid-glass`, `swiftui-performance-audit`, `swiftui-view-refactor` | **Reuse after review.** These already exist under `~/.agent-skills`; Pi supports explicit shared skill paths. The pilot currently exposes none of them, so adding them is a separate reviewed settings change. They guide code decisions but do not replace build/runtime proof. |

## Bounded migration recommendation

The next implementation slice should be **iOS CLI support before general MCP**:

1. Review and pin `xcodebuildmcp@2.7.0`.
2. Add only its CLI skill plus the four existing Swift/SwiftUI skills to the pilot’s reviewed skill inventory.
3. Extend installer verification to cover the new package and skill hashes.
4. Validate on a disposable SwiftUI fixture: doctor, build, test, build-and-run, Simulator screenshot, one UI interaction, and cleanup.
5. Only after that is stable, review `pi-mcp-adapter@2.15.0` behind an isolated programmatic-config wrapper and start with exactly one non-destructive server.

This sequencing gives Pi a complete iOS development loop without first expanding it into an orchestrator-wide MCP client.
