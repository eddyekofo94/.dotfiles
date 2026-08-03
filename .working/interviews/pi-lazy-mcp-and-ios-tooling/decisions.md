# Pi Lazy MCP And iOS Tooling

## Goal

Add one isolated, pinned XcodeBuildMCP CLI/skills slice to the completed opt-in
Pi pilot before considering any general MCP adapter.

## Exit Criteria

- Pin and review XcodeBuildMCP 2.7.0, its dependency lock, published integrity,
  official CLI skill, and exact upstream tag/commit.
- Install only inside marker-owned Pi pilot state with lifecycle scripts
  disabled and verified source/tree hashes.
- Expose the official `xcodebuildmcp-cli` skill plus the existing
  `swift-concurrency-expert`, `swiftui-liquid-glass`,
  `swiftui-performance-audit`, and `swiftui-view-refactor` skills exactly once.
- Keep MCP server mode, ambient MCP config discovery, self-upgrade/init, and
  package mutation unavailable through the pilot-owned route.
- Validate doctor, project discovery, build, test, build-and-run, Simulator
  screenshot, one UI interaction, daemon idle cleanup, and rollback against a
  disposable SwiftUI fixture.
- Preserve Pi isolation, FFF, Herdr, shared-skill ownership, Codex/Claude,
  Xcode 26.6, and unrelated dirty work.
- `pi/verify.sh`, `fish/scripts/verify.sh`, focused fixture validation, and
  fresh Standards/Fidelity review pass after the final change.
- Physical-device and subjective tactile behavior remain manual gates; no
  device claim is made from Simulator evidence.

## Scope / Non-goals

In scope after explicit installation promotion: repository-owned pin/manifest,
isolated installer/launcher changes, CLI-only wrapper/skill inventory, tests,
disposable SwiftUI validation, rollback, and durable evidence.

Non-goals: `pi-mcp-adapter`, any MCP server connection, importing Codex/Claude
MCP configs, Xcode 27 beta, `pi-xcode`, `pi-build-ios-apps`, Pi default-agent
promotion, production Bible Standard changes, commits, pushes, or publication.

## Decisions

- Keep Pi as the completed opt-in third harness; this slice does not replace
  Codex or Claude.
- Use XcodeBuildMCP CLI plus skills before general MCP.
- Pin current upstream `xcodebuildmcp@2.7.0`; never use `@latest` in the pilot.
- Reuse the four canonical Swift/SwiftUI skills from
  `/Users/eddyekofo/.agent-skills`; do not copy them.
- Preserve `defaultProjectTrust: never`, `--no-approve`, marker-owned roots,
  lifecycle-script-disabled installation, and tamper-evident package trees.
- Eddy explicitly promoted the isolated, pinned `xcodebuildmcp@2.7.0`
  installation on 2026-07-31.
- Keep `pi-mcp-adapter` deferred even if this CLI slice is promoted.

## Evidence / Findings

- `pi-isolated-pilot` closed DONE on 2026-07-30 with automated and physical QA.
  It remains pinned to Pi 0.82.1 and opt-in.
- Live pilot roots are `~/.local/share/pi-pilot` and
  `~/.local/state/pi-pilot`; `PI_CODING_AGENT_DIR` is the latter's `config`
  directory. Normal `~/.pi/agent` is intentionally outside pilot ownership.
- Current pilot exposes `skill-finish`, `herdr`, the exact official
  `xcodebuildmcp-cli` skill, and four canonical Swift/SwiftUI skills, plus the
  pinned FFF package. It rejects package mutation and unreviewed
  extensions/skills.
- On 2026-07-31, npm `latest` remains 2.7.0 with integrity
  `sha512-z/QISX3BBg5PluvkOlgSEpWQGOnDQ90jmEHyEFLYiqprSUC6x4b9WRN7DyRmp1OXqhLqv5+omy0LBZi8HzaBJQ==`.
- Official tag `v2.7.0` resolves to commit
  `c79f4eb9b7b96680d5a774acb0ae525416d254fb`.
- The package contains `skills/xcodebuildmcp-cli/SKILL.md`; its guidance is
  help-first and recommends the smallest direct CLI workflow.
- Local prerequisites: Xcode 26.6 (`17F113`), Node 26.5.0, npm 11.17.0, and
  available iOS 26.5 Simulators. The pinned wrapper is on `PATH` only inside
  the isolated pilot and is also available as `./pi/xcodebuildmcp`.
- XcodeBuildMCP includes CLI and MCP modes in one package and uses runtime
  Sentry telemetry by default. The reviewed wrapper rejects MCP/init/setup/
  upgrade and socket/MCP-output overrides, disables telemetry, isolates daemon
  state, and verifies the complete package tree before every invocation.
- Governing research:
  `docs/research/pi-mcp-ios-development-2026-07-30.md`.

## Tradeoffs / Risks

- The same package contains desired CLI workflows and deferred MCP mode; the
  pilot-owned wrapper enforces the boundary.
- `--no-ignore-scripts` is unacceptable; source installation must retain the
  pilot's `--ignore-scripts` and exact-lock/hash model.
- Simulator automation proves repeatable UI mechanics, not physical tactile or
  performance acceptance.
- Adding five skills increases Pi prompt catalog surface; verification proves
  exact single discovery and no harness-incompatible invocation.

## Validation Plan

- Review published npm tarball, lock, licenses, lifecycle scripts, telemetry,
  CLI command surface, daemon behavior, and official CLI skill.
- Add red-capable installer/isolation tests before activation.
- Use a disposable SwiftUI fixture; do not modify Bible Standard.
- Run focused doctor/build/test/run/screenshot/UI/cleanup/rollback checks.
- Run `pi/verify.sh`, `fish/scripts/verify.sh`, scoped `git diff --check`, and
  fresh Standards/Fidelity review; fix and re-review until clean.

## Ready To Act

Implemented and verified on 2026-07-31. Eddy promoted the isolated, pinned
`xcodebuildmcp@2.7.0` installation. Closure evidence:
`.working/interviews/pi-lazy-mcp-and-ios-tooling/closure.md`.

## Open Questions

None.
