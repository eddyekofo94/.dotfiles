# PROTOTYPE — Herdr inside tmux

Question: can Herdr preserve the essential tmux + Neovim workflow while keeping
the screen simple enough for daily use? This prototype is isolated from the
normal Herdr config and does not change fish login startup or the production
Neovim tmux adapter.

Run it from the repository root:

```sh
./herdr/prototype/run.sh
```

The first run downloads the official Herdr v0.7.4 macOS arm64 release into
`.runtime/`, verifies its expected byte size, and starts the named scratch
session `trial`. The short scratch name keeps the macOS Unix socket below its
path-length limit. Remove `.runtime/` to wipe everything.

To launch the normal Neovim configuration with the temporary Herdr navigation
override from a Herdr pane:

```sh
nvim -c 'luafile ~/.dotfiles/herdr/prototype/herdr_nav.lua'
```

All validated outcomes belong in
[`docs/migrations/tmux-to-herdr.md`](../../docs/migrations/tmux-to-herdr.md).
The runtime itself is throwaway and ignored by Git.

## Verification and evidence

Run the repeatable static checks with:

```sh
./herdr/prototype/verify.sh
```

The trial screenshots are
[`expanded`](screenshots/expanded.png) and
[`collapsed`](screenshots/collapsed.png). They are ANSI renders captured from
the actual nested session. Final density, mouse feel, and Kitty image pixels
must still be judged in the live Ghostty session.

To stop and wipe the scratch runtime without touching normal tmux:

```sh
./herdr/prototype/run.sh cli server stop
rm -rf herdr/prototype/.runtime
```
