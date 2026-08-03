# Pi Global Response Style Parity

## Goal

Make the shared global agent rules repository-owned and fail-closed across
Codex, Claude, and the isolated Pi pilot without duplicating canonical content.

## Exit Criteria

- One repository-owned canonical `AGENTS.md` supplies the global rules.
- Codex uses an exact symlink; Claude uses its supported import adapter; Pi uses
  its isolated `$PI_CODING_AGENT_DIR/AGENTS.md` symlink.
- Claude's closeout hook reads the same source instead of embedding another
  rule copy.
- Installers migrate only reviewed predecessors and reject unrelated targets.
- Pi install creates the link; Pi launch rejects missing or drifted state.
- Pi verification uses a private runtime per invocation and proves concurrency.
- `pi/verify.sh`, `fish/scripts/verify.sh`, no-provider Pi context load, and
  fresh Standards/Fidelity review pass.

## Scope / Non-goals

In scope: canonical rules and adapters, safe local installation, Pi installer/
launcher/verification, concurrency-safe Pi runtime, tests, and tracking.

Non-goals: rule-meaning changes, Herdr generation or re-pinning, physical-device
QA, Xcode/MCP/default-agent promotion, Herdr shortcut changes, commit, or push.

## Decisions

- Preserve Herdr integration SHA-256
  `256b38fbe0067fb51bde5c275def7eabe3ba2aa0c6e5070572f814c12d2f27ce`.
- Keep one canonical repository source; live files are adapters or symlinks.
- Preserve existing global rule behavior and Claude per-turn injection.
- Preserve `herdr-alt-ctrl-n-new-tab` awaiting physical Ghostty acceptance.

## Evidence / Findings

- Pi loads `~/.local/state/pi-pilot/config/AGENTS.md`, but its live link is not
  owned by the installer, launcher, or verification.
- Codex and Claude rules, Claude hook, and response memory are unbacked files.
- `pi/verify.sh` uses fixed `pi/.runtime/verify`; concurrent runs can race.
- Ambient Herdr 0.7.5 drift is accepted, not a re-pin trigger.

## Tradeoffs / Risks

- Replace live regular files only when reviewed predecessor hashes match.
- Claude needs a small `@AGENTS.md` adapter; Codex and Pi consume directly.
- No-provider startup proves discovery, not subjective response brevity.

## Validation Plan

- Focused migration, idempotency, drift, and predecessor-rejection tests.
- Pi install/launch red tests for missing, regular, and retargeted instructions.
- Parallel Pi verification smoke coverage with unique runtimes.
- Exact retained Herdr hash assertion.
- Full Pi/Fish gates, no-provider context listing, diff checks, fresh review.

## Ready To Act

Implemented and verified on 2026-08-01. Closure evidence:
`.working/interviews/pi-global-response-style-parity/closure.md`.

## Open Questions

None.
