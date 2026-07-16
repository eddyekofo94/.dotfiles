# PROTOTYPE — Herdr inside tmux

Question: can Herdr preserve the essential tmux + Neovim workflow while keeping
the screen simple enough for daily use? This prototype is isolated from the
normal Herdr config and does not change fish login startup or the production
Neovim tmux adapter.

## Reopened acceptance gate

The previous Herdr v0.7.4 rejection is reopened for one corrected trial. The
user approved golden-ratio focus and asked to retry the first near-working Alt
ownership model. Physical Alt is now left unbound in Herdr so the temporary
Neovim/Fish/fzf adapters receive it directly. A corrected `pane.graphics.set`
request now renders a crisp raster inside the fzf preview region. Both results
still require physical/visual user approval; tmux remains production.

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

# Independent boxes with inactive borders hidden into the Ghostty background.
./herdr/prototype/run.sh --border focused

# No pane lines: quietest screen, with layout conveyed by content alone.
./herdr/prototype/run.sh --border borderless
```

Each style uses an isolated scratch session. The base tracked configuration is
still the requested compact/no-gap variant; the runner derives the other three
inside the ignored runtime.

For the direct Ghostty acceptance trial, use one command:

```sh
./herdr/prototype/launch_live_ghostty.sh
```

This launches a new Ghostty window without tmux variables, starts the
focused-only Herdr session, then prepares three panes: the real Neovim config
with two editor windows and the temporary Herdr edge adapter on the left, the
real fzf picker over the prototype PNGs on the upper right, and a shell on
the lower right for mouse checks. Press `Ctrl-a Shift-b` once to hide the stable
v0.7.4 sidebar.

The focused variant deliberately has no Herdr-level `Alt-h/j/k/l` bindings.
The launcher explicitly enables left Option-as-Alt for only the scratch
Ghostty process, then lets the chord reach the pane application unchanged.
`herdr_nav.lua` ports the four mappings from the production Neovim
`lua/plugin/tmux.lua`: Neovim moves locally first and invokes Herdr only at an
editor edge, including the existing fzf-lua `j/k` exception. `herdr_nav.fish`
handles an ordinary Fish prompt, and the scratch fzf command binds the same
chords to pane focus. None of this is installed into production configuration.

High-quality image preview now uses Herdr's experimental pane-owned raster
layer. `native_preview.sh` reads the real fzf preview geometry, rejects fzf's
observed negative row sentinel, and sends a pane-relative PNG placement. Set,
repeated selection, focus resize, and clear all returned `ok`; screenshots show
the raster confined to the fzf region without a black host frame. Chafa symbols
remain only the failure fallback because their quality was rejected.

The scratch `prototype.golden-focus` plugin listens for `pane.focused` and
targets the same 62% width/height used by the tmux focus hook. Press
`Ctrl-a Shift-g` to disable it and restore the focused layout axes to 50/50;
press again to re-enable and apply 62%. The plugin source exists only on this
throwaway branch; its registration and mutable state stay inside the ignored
prototype runtime.

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
[`collapsed`](screenshots/collapsed.png). The final direct Ghostty chafa
fallback is captured in [`chafa-final`](screenshots/chafa-final.png). The user
approved golden-focus behavior and rejected the earlier smart-navigation and
chafa paths. The corrected raster evidence is captured in
[`native-preview-retry`](screenshots/native-preview-retry.png) and
[`native-preview-acceptance`](screenshots/native-preview-acceptance.png); its
quality and the restored physical Alt feel are awaiting user approval.

To stop and wipe the scratch runtime without touching normal tmux:

```sh
./herdr/prototype/run.sh cli server stop
./herdr/prototype/run.sh --border boxed cli server stop
./herdr/prototype/run.sh --border focused cli server stop
./herdr/prototype/run.sh --border borderless cli server stop
rm -rf herdr/prototype/.runtime
```
