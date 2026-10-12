# Pi Reasoning Level Footer

## Status

Parked after verified relocation on 2026-09-15. Do not implement concurrently with `pi-weekly-usage-live-refresh`; both modify the compact footer.

## Goal

Keep `openai-codex/gpt-5.6-sol` at medium reasoning and expose the current reasoning level in Pi's compact footer.

## Preserved Scope

- `pi/settings.json`: default model is `gpt-5.6-sol`; reasoning remains `medium`.
- `pi/extensions/eddy-compat.ts`: full-width `reasoning medium`, narrow-width `R:M`, semantic thinking-level colours, and `thinking_level_select` refresh.
- `pi/README.md`: footer behavior documentation.
- `pi/tests/mock_provider.ts`: reasoning-capable fixture.
- `pi/tests/session_display_pty_test.sh`: narrow `R:M` assertion.
- `pi/tests/session_display_test.mjs`: label, colour, and lifecycle coverage.

## Relocation Evidence

- Source: six unstaged files in `/Users/eddyekofo/.dotfiles` owned by Pi session `01a0a1f2-2173-7716-95dc-9617820275f8`.
- Destination: `/Users/eddyekofo/.dotfiles-sessions/pi-reasoning-level-footer` on `feature/pi-reasoning-level-footer`.
- Source and destination binary patch SHA-256 matched exactly: `6d6c9125a97c36dd8736ce63012645a11b40a43c7b35dc90ecd450cd8e453cc2`.
- The originating session reported `./pi/verify.sh`, compact-footer pseudo-terminal coverage, and focused display tests passing before relocation.
- No commit, merge, or push was performed.

## Integration Constraint

Integrate only after `pi-weekly-usage-live-refresh` closes or combine both diffs deliberately in one authorized integration pass. The shared seams are `pi/README.md`, `pi/extensions/eddy-compat.ts`, and `pi/tests/session_display_test.mjs`.
