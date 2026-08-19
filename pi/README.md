# Isolated Pi Pilot

This is a pinned evaluation harness, not the default `pi` installation.

```sh
./pi/install.sh
./pi/pilot.sh
```

The launcher isolates Pi configuration, credentials, extensions, and sessions
under `~/.local/state/pi-pilot` by default. The checksum-verified 0.82.1
standalone distribution lives under `~/.local/share/pi-pilot`.

Pi's package installer does not modify Codex or Claude. Pi loads only the
explicitly listed canonical skills in `pi/settings.json`; `$herdr` and
`$skill-finish` are accepted aliases for Pi's native `/skill:...` commands.

Global response and closeout rules have one repository source at
`agent-config/AGENTS.md`; `pi/AGENTS.md` is a compat symlink to it that this
pilot's own scripts read. `pi/install.sh` owns its exact isolated-config
symlink and `pi/pilot.sh` rejects missing, regular, or retargeted instruction
state. Codex and Claude adapters are managed separately by
`agent-config/install.sh` and point at `agent-config/AGENTS.md` directly.

The pilot is intentionally not available as a plain `pi` command and it does
not read or write `~/.pi`. Start named work explicitly:

```sh
./pi/pilot.sh --name project-review
```

The pilot uses Emacs-style history and list navigation:

- `Ctrl-P` or Up selects the previous prompt/item.
- `Ctrl-N` or Down selects the next prompt/item.
- `Ctrl-Shift-M` opens the model picker; direct model cycling is intentionally
  unbound.
- `Ctrl-L` clears and redraws the viewport without deleting the persisted
  conversation or starting a new session. The `❯` editor and footer details
  remain visible after the redraw.
- The editor removes Pi's reverse-video painted cursor and exposes one hardware
  cursor. It requests Ghostty's blinking bar while the prompt owns focus and a
  blinking block outside the prompt; Ghostty supplies its normal outline when
  the terminal surface is unfocused.
- In the session picker, `Ctrl-Shift-P` toggles paths and `Ctrl-Shift-N`
  toggles the named-session filter.

Prompt recall is scoped to the current persisted branch and is reconstructed
after `/reload`, `/resume`, and `/tree`. Use `/resume` (or start with
`./pi/pilot.sh -r`) to select an older session. Noninteractive benchmark and
RPC runs do not have an editor history.

Slash-command suggestions learn from commands submitted inside this isolated
pilot. The most recently used matching command is first; the remaining used
commands are ordered by frequency and then recency. For example, after
submitting `/reload`, typing `/re` selects `/reload` ahead of `/resume`.

The interactive editor uses Catppuccin Mocha and an accent-colored `❯`. Its
`@` mention list is powered by the pinned FFF extension, so project paths use
FFF's fuzzy, frecency-ranked, and git-aware index rather than Pi's native
substring matcher. Type `@` and a query, move with `Ctrl-P`/`Ctrl-N` or the
arrow keys, and press Enter to insert the selected path. `/fff-health` shows
index status and `/fff-rescan` forces a refresh.

FFF runs in `tools-and-ui` mode: it adds `fffind` and `ffgrep` while retaining
Pi's native tool names. Its package, native dependencies, frecency database,
and query-history database remain inside the isolated pilot roots. Installation
uses the repository-reviewed npm lock before dependency resolution, disables
package lifecycle scripts, verifies the complete installed tree, and applies a
small reviewed patch that prevents sessions or `/fff-mode` from changing the
pilot's fixed mode.

The pilot also exposes a pinned XcodeBuildMCP 2.7.0 CLI through
`xcodebuildmcp` and the exact official `xcodebuildmcp-cli` skill. Four
canonical shared skills cover Swift concurrency, Liquid Glass, SwiftUI
performance, and SwiftUI view refactoring without repository copies. The CLI
package and complete dependency tree are lockfile- and hash-verified before
every launch; install lifecycle scripts and telemetry are disabled. Runtime
state, daemon sockets, logs, screenshots, and DerivedData defaults use the
marker-owned pilot state root.

Use help-first CLI workflows:

```sh
./pi/xcodebuildmcp doctor
./pi/xcodebuildmcp tools
./pi/xcodebuildmcp simulator --help
```

The pilot wrapper rejects `mcp`, `init`, `setup`, `upgrade`, socket overrides,
and MCP bootstrap output. No ambient Codex/Claude MCP configuration is read.
`pi-mcp-adapter`, MCP server mode, Xcode 27, and default-agent promotion remain
deferred.

`Prefix+b` inserts the latest handoff in the current Pi editor without
submission. `Prefix+B` uses a private request file plus the extension's
`Ctrl+Shift+Y` endpoint to verify that Pi is idle and its editor is empty,
create a new persisted session, and prefill the handoff without submission.

Preview rollback:

```sh
./pi/rollback.sh
```

Apply rollback:

```sh
./pi/rollback.sh --apply
```

Rollback refuses any root without the pilot marker and moves managed data to
Trash rather than deleting it.

## Evidence gates

After the one-time checksum-verified install, run the automated gates without
provider calls:

```sh
./pi/verify.sh
./fish/scripts/verify.sh
./herdr/prototype/validate_ready_prompt.sh
```

`pi/verify.sh` uses a unique disposable runtime per invocation and proves the
pinned artifact, isolated configuration, canonical global instructions, curated
skills, named/resumable sessions, manual and forced-threshold compaction,
Herdr's managed Pi integration, both replay keys, cross-session inventory,
runtime measurements, marker-owned rollback, and a disposable SwiftUI
doctor/discovery/build/test/run/screenshot/gesture/daemon-cleanup loop.

The broader `./herdr/verify.sh` currently stops at a pre-existing aggregate
fixture that expects 31 custom bindings while the current configuration has 43;
that unrelated mismatch is not used as Pi evidence.

Provider quality and cost require an authenticated model and are deliberately
not faked by the offline fixture. Authenticate inside the isolated pilot:

```text
./pi/pilot.sh
/login
```

Then run the same no-tool task through Pi and native Codex:

```sh
./pi/benchmark_provider.py --run
```

The benchmark is dry-run by default so verification never spends provider
tokens unexpectedly. It records raw native JSON streams plus a scored
comparison under `pi/evidence/`; Pi's reported monetary cost is retained while
Codex is marked as not exposing monetary cost when its native stream provides
tokens only.

Finish the provider and physical two-window acceptance checklist in
`pi/MANUAL_QA.md`. Pi must remain opt-in until every applicable item is
confirmed.
