# Herdr staged-promotion validation

Date: 2026-07-23

## Installed state

- `~/.local/bin/herdr --version`: `herdr 0.7.4`
- `~/.config/herdr/config.toml` resolves to tracked `herdr/config.toml`.
- `~/.config/herdr/default-multiplexer` is mode `0600` and contains `herdr`.
- A clean top-level Ghostty login created and attached to the running named
  `main` session.
- `prototype.golden-focus` is linked and enabled in that session; subsequent
  logins provision it through `herdr/ensure_plugins.sh`.

## Live fallback and rollback matrix

Two temporary, separately identified Ghostty instances were used and closed by
their exact PIDs after validation:

1. `herdr/tmux_fallback.sh` opened a third working tmux client in a fresh
   top-level Ghostty while the caller carried tmux state. The launcher removed
   `TMUX`, `HERDR_ENV`, and `HERDR_PANE_ID`, set `HERDR_NO_AUTO_ATTACH=1`, and
   did not nest or loop.
2. `herdr/set_default.sh tmux` followed by a normal clean Ghostty login opened
   a working tmux client. `herdr/set_default.sh herdr` restored Herdr as the
   persistent default.
3. The temporary client count returned from three to the original two, the
   running Herdr `main` session survived, and its normalized session/plugin
   state plus all production configuration hashes were unchanged.

Observed test PIDs: fallback Ghostty `40520`; rollback Ghostty `40583`.

## Preservation hashes before and after

| Artifact | SHA-256 |
| --- | --- |
| `tmux/tmux.conf` | `e46f1474f61ed3a3a937f9c17b0cb2bc27335abf238a659dbf1f6ff298610cc3` |
| `fish/config.fish` | `e134618c29b40f7e3703fb420191c40ddf53ac838e2c2c63b533a906ffaebfea` |
| `herdr/config.toml` | `8386ef3d392f9c7d4c67d951ca8b303cf946eafebe04604d7c6d7176e5af6ef6` |
| normalized `main/session.json` | `7359803bb1d002280dddade02c605e6f613f75a458a0ca6c7dfe2146f74a7f65` |
| normalized `main/plugins.json` | `d0271cb1eba62d1649b610b4de29bcec997b0bb3b30ba440cf376c0f1e368f14` |

The repeatable non-GUI gate is `herdr/verify.sh`; the live matrix above is the
one-time promotion proof. Final subjective daily-driver acceptance is the only
remaining manual gate.
