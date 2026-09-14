# Local Integration and Installation

## Status

Done by verified implementation and owner acceptance. `/reload` loads live
refresh; live values and every settled colour boundary were physically
confirmed. Eddy accepted the working feature without forcing a physical
failed-read fixture; deterministic coverage proves retention. `push everything`
authorized publication. The reasoning-footer branch remains separate.

## Integration

- Rebased `feature/pi-weekly-usage-live-refresh` onto clean local main `01b4a36c`.
- Implementation commit: `fde7dd6a` (`Refresh Pi weekly usage live and preserve it across reloads`).
- Fast-forward merged locally into main before installation.
- Ran `./pi/install.sh` from `~/.dotfiles`: PASS.
- `./pi/pilot.sh --version`: `0.82.1`.
- Installed settings symlink: `~/.local/state/pi-pilot/config/settings.json` -> `/Users/eddyekofo/.dotfiles/pi/settings.json`.
- Configured extension: `/Users/eddyekofo/.dotfiles/pi/extensions/eddy-compat.ts`.
- Installed/main source matches the verified feature source byte-for-byte.
- Extension SHA-256: `b084d94a374cf578c6d165f93b84b80d2c92d417c3682c91c59d5716d420df2d`.

## Verification

- `node pi/tests/session_display_test.mjs`: PASS in feature and merged main.
- `node pi/tests/codex_weekly_usage_test.mjs`: PASS in feature and merged main.
- `sh pi/tests/theme_ui_test.sh`: PASS in feature and merged main.
- Final post-fix `./pi/verify.sh`: PASS, exit 0. Used isolated
  `AGENT_CONFIG_HOME=.../pi/.runtime/weekly-integration-agent-home`, disposable
  pilot state, and the existing prepared Herdr binary. Parent directories for
  the isolated agent home were created after an initial preflight refusal;
  no live agent configuration was retargeted.
- Full verification includes isolated install, terminal/reload fixtures,
  sessions, Herdr replay, disposable SwiftUI validation, and runtime benchmarks.
- Independent fresh Standards and Fidelity re-review: PASS; see `review.md`.
- Installed fixture-mode RPC `get_commands` with `--no-session`: PASS; the
  `eddy-pilot` command proves the configured extension loaded without errors.
- Live `node pi/codex_weekly_usage.mjs`: returned `14` at the installation check.
  This proves source availability, not physical footer acceptance.
- `git diff --check`: PASS.
- Generated benchmark/session evidence was restored rather than committing
  disposable paths. Local logs are retained under
  `pi/.runtime/weekly-integration-evidence/` in the feature worktree.
- Paid provider comparison and physical Ghostty acceptance: NOT RUN.

## Parked Work Preservation

`~/.dotfiles-sessions/pi-reasoning-level-footer` remains separate. During this
run another session committed its parked changes as `751a91c9`. This integration
did not edit, rebase, merge, install, or remove that branch.

Its six modified Pi files' initial binary diff and committed diff against
`01b4a36c` have the identical SHA-256:
`6d6c9125a97c36dd8736ce63012645a11b40a43c7b35dc90ecd450cd8e453cc2`.
The reasoning-footer worktree is clean and its commit is not in main.

## Physical Confirmation

- 2026-09-15: PASS — after `/reload`, the footer began at the stale 20% launch
  snapshot, then changed to 14% after one completed Codex response and to 13%
  after the next. Direct upstream reads were 14% and 13%, respectively. Eddy
  physically confirmed the footer showed 13%. Live refresh without restart is
  therefore accepted.
- 2026-09-15: PASS — Eddy physically confirmed the live 13% weekly value appears amber.
- 2026-09-15: PASS — Eddy physically confirmed the 10% fixture appears dark maroon.
- 2026-09-15: PASS — Eddy physically confirmed the 20% fixture appears amber.
- 2026-09-15: PASS — Eddy physically confirmed the 21% fixture appears neutral.
- 2026-09-15: PASS — Eddy physically confirmed the 11% fixture appears amber.
- All settled colour fixtures pass.
- 2026-09-15: OWNER ACCEPTANCE — Eddy confirmed the feature works and requested
  commit/publication rather than forcing a physical read failure. Automated
  event-level tests remain the evidence for failed-read and reload retention.

## Closure

No manual check remains. Push main under Eddy's explicit `push everything`
authorization. Do not merge the separately parked reasoning-footer branch as
part of this goal.
