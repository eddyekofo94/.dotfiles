# Reviewed Herdr source build

This directory owns Eddy's narrow private Herdr build. It pins the exact
annotated tag object, peeled commit, Rust toolchain, Zig toolchain, patch
digest, patched-source digest, and arm64 macOS binary digest, and refuses any
unreviewed source difference or predecessor binary. Formatting, Clippy, the
complete copy-mode test family, and a locked release build run before the binary
can be installed.

`pins.env` is the single source of truth for Herdr's identity on this machine —
the tracked release, the version string, and the official release digest —
and `install.sh`, `herdr/verify.sh`, `verify_integrations.sh` and `build.sh` all
read it rather than hardcoding a version. An upgrade is one edit to that file,
which `upgrade.sh` makes for you.

`known-binaries.txt` records which binaries this machine produced or verified.
The install guard accepts any of them as a replaceable predecessor and refuses
anything else, so an upgrade replacing the previous reviewed build is normal
while an unrecognized binary in `~/.local/bin` is never silently overwritten.

## Everyday use

You do not normally run anything in this directory. `herdr` is wrapped by
`fish/functions/herdr.fish`:

- `herdr update` runs `herdr/update.sh --apply` instead of downloading the
  official release over the patched build.
- `herdr server reload-config` runs `herdr/reload.sh`, which checks the config
  symlink, the installed binary and the plugins before reloading. Also bound to
  `prefix+shift+c`.

Everything else passes through to the real binary untouched.

## What the patch series adds

`HERDR_PATCH_SERIES` in `pins.env` lists the reviewed patch files in apply
order. `HERDR_PATCH_SHA256` pins their concatenation, which detects a tampered
patch file; `HERDR_TREE_DIFF_SHA256` pins the patched tree independently, and
`build.sh` checks that every path the tree modifies is claimed by exactly one
patch. Apply order no longer has to reproduce `git diff` order byte for byte, so
a patch file may own any set of paths rather than a sorted-contiguous range —
which previously forced a change into a patch named for an unrelated feature.
Each file owns a disjoint set of source paths so it can be re-reviewed, rebased,
or dropped on its own at the next upstream tag.

Eight narrow changes across five patch files. There is no injected-input path.

Not everything private is a patch. The agent panel's active row used to need
one; v0.8.2 gave the palette an `active_row_bg` token, so the change is now a
`[theme.custom]` line in `herdr/config.toml` and owns no source. Config first,
patch only where upstream cannot express the behaviour.

`toast-triage-colours-status.patch` (`ui/status.rs`) and
`toast-triage-colours-mobile.patch` (`ui/mobile.rs`) — Toast triage colours in
both renderers: red is blocked on a human, green is done, blue is informational,
and the title carries the colour so the signal is not a single cell. Two files
because one patch owns one path, and the two renderers rebase independently.

`toast-triage-colours-status.patch` also carries the breathing Working dot.
Upstream picks the glyph (`StatusIndicatorStyle`, dots or symbols); this only
moves its colour, blending `panel_bg` → `yellow` on a cosine, 1440 ms per cycle,
never dimmer than 0.34 of the way up, and falling back to a DIM toggle on a
palette that is not truecolour. Same file, so the same patch.

`working-spinner-tick.patch` (`app/mod.rs`, `app/runtime.rs`,
`server/headless.rs`) — the redraw tick that lets that breath advance. The dot's
colour is a function of wall-clock time, so it moves only while something asks
for frames: a 120 ms deadline joins the same set upstream's
`next_tab_bar_status_deadline()` is in, armed by one helper that both the
attached-terminal loop and the headless server call. Arming it in `App` alone is
how the feature shipped dead once and was reverted, so `build.sh` runs
`cargo test --locked working_` to keep the headless test selected.

`agent-focus-keeps-agent-in-view.patch` (`app/agents.rs`, `app/api/agents.rs`)
— `herdr agent focus` scrolls the agent panel to the agent it focused, the way
the native `next_agent`/`previous_agent` actions already do. Without it a
scripted focus (`agent_cycle.py` on Ctrl+Alt+j/k, the agent overview) lands on
an agent past the panel's last row with nothing on screen saying so (2026-09-26,
BibleStandard FS-261). `build.sh` runs `cargo test --locked agent_focus_`.

`copy-mode-vim-muscle-memory.patch`:

- Vim muscle memory: `a` and `i` compose the existing `q` exit-without-copy
  operation; `Y` composes the existing `V` whole-line selection and `y`
  copy-and-exit operations.
- Vim's pending-command buffer: a typed count repeats the next motion (`2j`,
  `10l`, `3w`, `2n`) and makes `V`, `Y`, and a selection-less `y` linewise over
  that many lines (`2Y` is Vim's `2yy`). `z` opens a two-key sequence whose only
  member is `zz`, which scrolls the cursor's line to the middle of the viewport
  by composing the existing scroll-offset operations. Esc discards a half-typed
  count or `z` without touching the selection or the search; the overlay echoes
  the pending keys the way Vim's `showcmd` does. A leading `0` stays the
  line-start motion, and counts are capped at 9999.
- A bindable `copy_mode_search` action that enters copy mode with the backward
  search prompt already open, composing `enter_copy_mode` with the prompt that
  copy mode's own `?` key opens. Bound to `alt+b` in `herdr/config.toml`, it
  turns a scrollback search into one chord instead of two.
- Client-owned focus-cursor blinking. Herdr preserves the focused pane's cursor
  position and shape, exposes a hardware cursor when a TUI paints its own, and
  toggles visibility every 500 ms. Ghostty focus loss restores the application's
  steady/hidden state so background windows do not keep blinking.

`pane_history = false`, Herdr recovery, production configuration, and the tmux
fallback remain outside the series.

## Everyday commands

Build and run the source tests:

```sh
./herdr/source-build/build.sh
```

Build, verify, and atomically install the reviewed binary without restarting any
running Herdr server:

```sh
./herdr/source-build/build.sh --install
```

Existing servers keep their current executable image. A newly created named
session uses the installed patched binary, which allows physical acceptance
without stopping retained sessions.

## Following upstream releases

`upgrade.sh` does the bookkeeping an upstream release forces: finding the new
tag, rebasing the patch, and recording new digests. It does not replace
judgement — it stops and explains whenever a human needs to look.

```sh
./herdr/source-build/upgrade.sh                       # newer release? changes nothing
./herdr/source-build/upgrade.sh --apply               # migrate, build, re-pin; binary staged
./herdr/source-build/upgrade.sh --apply --install     # ... and install it
./herdr/source-build/upgrade.sh --tag v0.8.0 --apply  # target a specific tag
```

What it does, in order:

1. Reads the newest `vMAJOR.MINOR.PATCH` tag from the upstream repository.
   Non-release tags are ignored so a release candidate cannot be selected.
2. Fetches that tag into a scratch checkout, leaving the current build alone.
3. **Checks whether upstream has adopted the patch.** Each marker is text the
   patch introduces that the pinned base does not contain, matched as a fixed
   string and scoped to the narrowest path that could carry the feature. A loose
   marker such as a bare `copy_mode_search` matches Herdr's own long-standing
   internals like `handle_copy_mode_search_prompt_key`, which would block every
   future upgrade — keep new markers precise. If a marker hits, the upgrade
   stops so the patch can shrink or retire instead of duplicating upstream.
4. Applies the patch with a three-way merge. Conflicts stop the upgrade and are
   reported per file; the patch then needs a human rebase.
5. Regenerates the patch file from the merged result. A three-way merge rebases
   the patch, so its recorded form has to be rewritten, and the diffstat is
   printed so the change is still recognizable. (`git apply --3way` implies
   `--index`, so the merge is unstaged first to match what `build.sh` reads.)
6. Runs the same gates `build.sh` always runs, then records the new digests.
7. Restores the previous pins, patch, and source tree if any of that fails.

## Re-pinning

The three digests record a reviewed result; they do not authorize one. After
deliberately changing the patch, `--repin` rewrites them from what the run
actually produced instead of refusing to build:

```sh
./herdr/source-build/build.sh --repin
```

Every other gate still runs. `upgrade.sh` uses this internally.

## Things that will bite

- **A binary older than the patch ignores `copy_mode_search` silently.** The key
  is accepted and does nothing, so `alt+s` stays inert until the reviewed build
  is installed. `herdr/reload.sh` checks for this and says so.
- **An upgrade does not restart running servers.** That is deliberate — it means
  a session's panes survive an update — but the session keeps running the old
  binary until its server is stopped, and `reload-config` reports a protocol
  mismatch rather than reloading. New named sessions use the new binary.
- **A new release usually ships newer agent integrations.** The old plugin keeps
  running and reports stale agent state; only `herdr integration status` shows
  it. `update.sh` refreshes them; `reload.sh` warns.
- **Bare `herdr update` outside fish still replaces the patched binary.** The
  wrapper is a fish function, so `sh -c 'herdr update'` or a script calling
  `~/.local/bin/herdr update` bypasses it. `herdr/verify.sh` catches the result
  afterwards through the binary digest pin.
