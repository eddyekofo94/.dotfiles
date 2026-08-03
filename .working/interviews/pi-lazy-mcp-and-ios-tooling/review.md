# Pi Lazy MCP And iOS Tooling — Fresh Review

## Fixed Point

- Repository HEAD: `1bb26bfce2108e3d877e03aa53a1f66f4c20dbe3`.
- Decisions:
  `.working/interviews/pi-lazy-mcp-and-ios-tooling/decisions.md`.
- Standards: global/project instructions, agentic loop standard,
  `pi/AGENTS.md`, and existing Pi isolation patterns.
- Scope: current goal files, including relevant untracked Pi pilot files.

## Standards

Initial finding:

1. Direct wrapper use could follow symlinked runtime, home, temp, run, or
   workspace-socket directories outside marker-owned state. Fixed with
   fail-closed checks and a red disposable regression.
2. Unified intake described the pilot `AGENTS.md` as absent despite its
   repository source and live symlink. Corrected while retaining the unproven
   installer-ownership gap as investigating scope.

Fresh post-fix findings: **0**.

## Fidelity

Initial findings:

1. The same runtime symlink gap violated the marker-owned isolation boundary.
2. An inherited daemon idle-timeout variable could disable automatic cleanup,
   while the first fixture proved only explicit stop. Fixed by removing the
   ambient override, allowing only a bounded fixture timeout, and proving
   automatic process exit, stopped status, and socket cleanup.
3. The manual-QA checklist left the successfully executed live rollback
   preview unchecked. Corrected without marking rollback application complete.

Fresh post-fix findings: **0**.

## Verification

- `./pi/verify.sh`: PASS after fixes.
- Disposable SwiftUI fixture: PASS for doctor, project discovery, build, two
  tests, build-and-run, two screenshots, scroll gesture, automatic daemon idle
  shutdown, socket cleanup, and rollback coverage.
- `./fish/scripts/verify.sh`: PASS after fixes; final rerun startup benchmark
  25.311 ms median / 38.063 ms p95. Prior run's transient 123.058 ms p95 failed
  only the timing threshold; unchanged rerun passed.
- Live install: XcodeBuildMCP 2.7.0, doctor telemetry-disabled, and exact
  seven-skill RPC inventory PASS.
- npm registry integrity/gitHead/license, upstream tag commit, registry-only
  dependency lock, shell syntax, scoped hashes, and `git diff --check`: PASS.

## Summary

Standards findings: **0**. Fidelity findings: **0**. No unresolved automated
finding. Physical-device, tactile, and subjective performance checks remain
manual gates.
