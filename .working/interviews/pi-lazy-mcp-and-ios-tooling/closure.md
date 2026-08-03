# Pi Lazy MCP And iOS Tooling — Closure

## Status

DONE on 2026-07-31.

## Delivered

- Isolated `xcodebuildmcp@2.7.0` installation under marker-owned Pi state.
- Exact npm integrity, upstream tag/commit, dependency lock, package source,
  dependency tree, official skill, and license hashes.
- Lifecycle-script-disabled installation and telemetry-disabled execution.
- CLI-only wrapper with fail-closed package/runtime checks and isolated
  HOME, temp, daemon socket, logs, build state, and screenshots.
- MCP, init, setup, upgrade, socket overrides, and MCP bootstrap output rejected.
- Exact official `xcodebuildmcp-cli` skill plus four canonical shared
  Swift/SwiftUI skills, each discovered once.
- Repository-pinned Herdr Pi integration retained despite ambient Herdr 0.7.5
  generator drift.
- Disposable SwiftUI validation and marker-owned rollback coverage.

## Verification

- `./pi/verify.sh`: PASS after final fixes.
- `./fish/scripts/verify.sh`: PASS after final fixes.
- Live `./pi/install.sh`, `./pi/xcodebuildmcp --version`, telemetry-disabled
  doctor, exact seven-skill RPC inventory, and rollback preview: PASS.
- Fresh final review: Standards 0 / Fidelity 0.
- Reviewed hashes:

  ```text
  bea15ca0cff4ca1101b22690178279617e3969d2baad49b99e537d114899a927  pi/xcodebuildmcp
  49739c194ff5ab7dcb880542d3c6a82b496d0fba6f726ee938672cb667a65d87  pi/install.sh
  70f7f6907eed2fc69e3077bb6f57aa98c49e1c6dd92a5b853c0a6867b13f3255  pi/pilot_paths.sh
  da5ac0dac31cd9d71b6632d0b6befef9f8d28b3f7b0d61141b0946d271a96a01  pi/tests/xcodebuildmcp_fixture.sh
  16a1c121c740a6d837acd03b453fbb838b75282a61c578631eeb6533247aee43  pi/packages/xcodebuildmcp/package-lock.json
  afeaf4d088fd79760bb6c80ccf9b5e23e1587587d0c8a135d4b4427fc869a0b1  pi/skills/xcodebuildmcp-cli/SKILL.md
  ```

## Manual Gates

- Physical-device trust/signing/build/install/launch remains unchecked.
- Physical tactile behavior and subjective performance remain unchecked.
- Simulator evidence does not satisfy either gate.

## Deferred Scope

- `pi-mcp-adapter`, MCP server mode, ambient MCP discovery, Xcode 27,
  `pi-xcode`, `pi-build-ios-apps`, and default-agent promotion.
- Production Bible Standard changes.
- No commit, push, hosted ticket, or publication performed.

## Workflow Result

Active goal cleared. Remaining intake re-ranked; `xcode-27-beta` is next by
current dependency/leverage ordering but still requires its settled
side-by-side-versus-replacement and authentication decisions.
