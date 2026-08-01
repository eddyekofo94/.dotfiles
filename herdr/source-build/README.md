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

## What the patch adds

Three narrow changes. There is no injected-input path.

- Vim muscle memory: `a` and `i` compose the existing `q` exit-without-copy
  operation; `Y` composes the existing `V` whole-line selection and `y`
  copy-and-exit operations.
- A bindable `copy_mode_search` action that enters copy mode with the backward
  search prompt already open, composing `enter_copy_mode` with the prompt that
  copy mode's own `?` key opens. Bound to `alt+s` in `herdr/config.toml`, it
  turns a scrollback search into one chord instead of two.
- Client-owned focus-cursor blinking. Herdr preserves the focused pane's cursor
  position and shape, exposes a hardware cursor when a TUI paints its own, and
  toggles visibility every 500 ms. Ghostty focus loss restores the application's
  steady/hidden state so background windows do not keep blinking.

`pane_history = false`, Herdr recovery, production configuration, and the tmux
fallback remain outside the patch.

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
