# Herdr Recovery Safety Parity — Installation Validation

Date: 2026-07-24

## Approved integration set

- Claude Code: current v7
- Codex: current v6
- OpenCode: current v8

All versions above are the integrations bundled by the retained Herdr v0.7.4
binary. Herdr itself remained
`24992e1625dbdcb18354a59e299e4b263c312400b31396cdc07cd46ed57f24a7`.

## Preservation and rollback

The pre-install snapshot is outside the repository at:

`~/.config/herdr/integration-backups/20260724T142238Z`

It contains the pre-existing Claude settings/hooks, the Codex config plus both
the `hooks.json` symlink and its dotfiles target, and the OpenCode config,
package metadata, and existing plugin.

Installation was run one integration at a time. After each write:

- Claude retained all seven pre-existing hook event families, the closeout
  hook, permissions, skill overrides, notifications, and the enabled Swift LSP
  plugin. Only the official Herdr `SessionStart` hook and managed script were
  added.
- Codex retained the symlink from `~/.codex/hooks.json` to
  `tmux/hooks/codex.json` and every pre-existing agent-status hook. The
  installer added one `SessionStart` entry, the managed hook script, and the
  documented `features.hooks = true` gate. The real restart test reviewed and
  trusted that exact new hook, producing the expected Codex hook trust record.
- OpenCode retained byte-identical `opencode.json`, `package.json`, and
  `tmux-agent-status.js`. The official Herdr plugin was added beside the
  existing plugin.

`herdr/verify_integrations.sh` now checks this coexistence, the exact approved
integration set, the pinned Herdr version, Herdr pane-history privacy, and the
matching tmux-resurrect privacy setting. It also binds Codex's exact official
`SessionStart[1]` hook object to the corresponding trusted hook-state hash, so
a changed or untrusted recovery hook fails verification.

## Real isolated restart/resume

Disposable session: `recovery-safety-20260724` (deleted after validation).

1. A real Codex 0.145.0 conversation replied `HERDR_RECOVERY_READY`.
2. Herdr reported native session identity
   `019f9484-b848-7c10-a7eb-e88a643ef49d`.
3. Stopping only the disposable Herdr server killed the original Codex process.
4. No `session-history.json` existed before or after the stop.
5. Reattaching restarted the pane as
   `codex resume 019f9484-b848-7c10-a7eb-e88a643ef49d`.
6. The original exchange loaded from Codex's native conversation store, and a
   new turn replied `HERDR_RECOVERY_RESUMED`.
7. The disposable session was stopped and deleted. The `default` and `main`
   Herdr servers remained running.

The production Herdr config, installed binary, tmux config, and explicit tmux
fallback hashes matched their pre-test values. `pane_history = false` remained
active throughout.

## Verification

- `./herdr/verify_integrations.sh`: PASS
- `./herdr/verify.sh`: PASS, including integration, login-attach, prototype,
  configuration, installer-refusal, fallback/default, and production checks
- `./fish/scripts/verify.sh`: PASS, including transport security, environment,
  startup ownership, fzf/fif, PTY, tmux, and startup performance
  (29.646 ms median / 31.622 ms p95 over 30 runs)
- Fresh Standards/Fidelity review: PASS after two in-scope fixes
  - added exact Codex hook/trust-state verification;
  - restored the tracked Codex hook catalog's trailing newline.
- Final post-fix review: Standards 0 / Fidelity 0
