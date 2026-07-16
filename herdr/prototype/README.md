# PROTOTYPE — Herdr inside tmux

Question: can Herdr preserve the essential tmux + Neovim workflow while keeping
the screen simple enough for daily use? This prototype is isolated from the
normal Herdr config and does not change fish login startup or the production
Neovim tmux adapter.

Run it from the repository root:

```sh
./herdr/prototype/run.sh
```

Border rendering is a live visual choice. Herdr v0.7.4 has no configurable
border glyph or corner style, so the prototype exposes the three structures it
does support:

```sh
# Shared one-cell dividers: least space, but junctions can look pinched.
./herdr/prototype/run.sh --border compact

# Independent rectangular boxes: explicit corners, but uses more screen space.
./herdr/prototype/run.sh --border boxed

# No pane lines: quietest screen, with layout conveyed by content alone.
./herdr/prototype/run.sh --border borderless
```

Each style uses an isolated scratch session. The base tracked configuration is
still the requested compact/no-gap variant; the runner derives the other two
inside the ignored runtime.

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
./herdr/prototype/run.sh --border boxed cli server stop
./herdr/prototype/run.sh --border borderless cli server stop
rm -rf herdr/prototype/.runtime
```
