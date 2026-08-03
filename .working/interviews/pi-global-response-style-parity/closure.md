# Pi Global Response Style Parity — Closure

## Status

DONE on 2026-08-01.

## Delivered

- `pi/AGENTS.md` is the single canonical global rule source.
- Codex symlinks it directly; Claude imports it through a one-line adapter; Pi
  symlinks it at the exact isolated config path.
- Claude's per-turn hook extracts response/closeout sections from the canonical
  file rather than maintaining another rule copy.
- Reviewed predecessor files migrated to repository links with recoverable
  ignored backups; all targets preflight before mutation.
- Pi installer creates the exact link; launcher rejects missing, regular, or
  retargeted instruction state.
- Pi root, session, Herdr, and evidence state is unique per verification run;
  durable evidence publication is atomic.
- No-provider real-PTY startup proves Pi lists the global file under Context.
- Retained Herdr integration pin remains
  `256b38fbe0067fb51bde5c275def7eabe3ba2aa0c6e5070572f814c12d2f27ce`.

## Verification

- `./pi/verify.sh`: PASS.
- `./fish/scripts/verify.sh`: PASS; 26.571 ms median / 27.639 ms p95.
- Overlapping session validators: PASS with independent evidence roots.
- Agent installer migration/idempotency/preflight/drift checks: PASS.
- No-provider Pi context load: PASS twice focused and in the aggregate.
- Fresh review: Standards 0 / Fidelity 0.

## Manual Gates And Deferred Scope

- `herdr-alt-ctrl-n-new-tab` remains awaiting physical Ghostty chord acceptance.
- XcodeBuildMCP physical-device/tactile/performance gates remain open.
- MCP server/adapter/discovery, Xcode 27, default-agent promotion, and live Pi
  rollback remain deferred.
- No commit or push performed.
