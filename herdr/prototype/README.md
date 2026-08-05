# PROTOTYPE — Herdr inside tmux

Question: can Herdr preserve the essential tmux + Neovim workflow while keeping
the screen simple enough for daily use? This prototype is isolated from the
normal Herdr config and does not change fish login startup or the production
Neovim tmux adapter.

## Reopened acceptance gate

The previous Herdr v0.7.4 rejection is reopened for one corrected trial. The
user approved golden-ratio focus and asked to retry the first near-working Alt
ownership model. Physical Alt is now left unbound in Herdr so the temporary
Neovim/Fish/fzf adapters receive it directly. The user approved the physical
navigation feel. A corrected `pane.graphics.set` request renders a raster
inside the fzf preview region, but the user rejected the live result as
glitchy/unpolished; tmux remains production.

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
the lower right for mouse checks. Press `Ctrl-a Shift-s` once to hide the stable
v0.7.4 sidebar.

The focused variant deliberately has no Herdr-level `Alt-h/j/k/l` bindings.
The launcher explicitly enables left Option-as-Alt for only the scratch
Ghostty process, then lets the chord reach the pane application unchanged.
`herdr_nav.lua` ports the four mappings from the production Neovim
`lua/plugin/tmux.lua`: Neovim moves locally first and invokes Herdr only at an
editor edge, including the existing fzf-lua `j/k` exception. `herdr_nav.fish`
handles an ordinary Fish prompt, and the scratch fzf command binds the same
chords to pane focus. None of this is installed into production configuration.

## Approved binding-policy prototype

The isolated config now follows the approved table: `Ctrl-a` remains the
prefix; lowercase `h/j/k/l` focuses, uppercase `H/J/K/L` swaps, `r` enters
native resize mode, `v` splits right, `a` adaptively splits right or down,
`s` enters copy mode (`?` then starts backward search on v0.7.4), `x`
smart-closes a pane, `o` confirms closing its sibling panes, `=` equalizes pane
areas without replacing panes, `X` closes the tab,
`c/n/p` create or select tabs,
`0..9` focus an existing numeric tab or create one labeled with that digit, `z`
toggles zoom, `S` toggles the sidebar, and `u` opens the newest HTTP(S) URL
visible in the focused pane. `b` inserts the newest labeled agent handoff and
`B` safely clears Codex or Claude context before inserting it.

`Prefix+Shift+f` opens the separate destructive object manager. It searches
panes, tabs, and workspaces with a metadata preview, selects exactly one target,
requires an explicit `y`/`yes`, and re-reads the object's identity and
descendant topology before closing it. Native `Prefix+f` remains the ordinary
non-destructive goto path.

`Prefix+Shift+r` lists URI, path, and hexadecimal-hash references extracted
from bounded recent unwrapped focused-pane readback. Enter copies the selected
reference; Ctrl-O opens a URI or a path resolved from the pane cwd and refuses
hashes. This popup is deliberately outside copy mode: it is not cursor-local,
selection-bounded, or a claim of copy-mode parity.

`Prefix+Shift+a` opens an on-demand overview of agents in every running local
named Herdr session. Rows show session, agent, status, and cwd. Enter focuses
the exact agent pane inside its owning session without attaching or raising the
other Ghostty window; Ctrl-R opens a bounded read-only recent-output view;
Ctrl-E opens an editable composer whose confirmed text is inserted through
bracketed paste without Return or submission; Ctrl-L refreshes the inventory.
Ghostty continues to own macOS Command shortcuts, including `Cmd-V` paste.
Every action refreshes and verifies the session-qualified agent identity before
dispatch, so a stopped session or replaced agent fails closed.

Run its deterministic safety gate with:

```sh
./herdr/prototype/validate_agent_overview.sh
```

The resulting `evidence/agent-overview-validation.jsonl` covers repeated
session-local pane IDs and agent labels, stale sessions and identities, bounded
readback, owning-session focus, exact multiline insertion without Enter, and
the unchanged native navigation and Command-key boundaries.

Run the focused safety and real-prefix gate with:

```sh
./herdr/prototype/validate_picker_reference.sh
```

The resulting `evidence/picker-reference-validation.jsonl` covers parser
ordering/deduplication, confirmation cancellation, successful pane/tab/workspace
deletion, stale descendant/identity rejection, copy/open dispatch, failure
paths, and real `Prefix+Shift+f` / `Prefix+Shift+r` popup transport.

`adaptive_split.sh`, `smart_close.sh`, and `open_visible_url.sh` resolve the
focused pane through `HERDR_PANE_ID` or `pane current`, then use Herdr pane
layout, process, read, split, close, and zoom APIs. Smart close exits 75 and
leaves the pane alive on the first press when it is the last pane or owns a
non-shell foreground process; Herdr shows a notification and an identical
second press within five seconds confirms the API close. Ordinary Fish panes
own direct `Alt-v/n/q/X/z` plus confirmation-protected `Alt-Ctrl-x` through
`herdr_nav.fish`. Herdr itself does not bind
those Alt chords, so Neovim and fzf keep their existing application mappings.
In Neovim, `Alt-q` remains application-owned and closes the current visible
window/buffer through the existing mapping; `Alt-x` remains Neovim's window
exchange chord and has no shell-level Herdr action.
The Fish adapter registers both legacy `Esc+key` sequences and Herdr's observed
Kitty CSI-u Alt events; Fish 4.8 does not normalize the latter to named
`alt-*` bindings automatically.

Every prototype pane starts through `prototype_shell.sh`. Herdr keeps its
config under the isolated runtime `XDG_CONFIG_HOME`, while the wrapper restores
the user's real `~/.config` for Fish. It sets a temporary `TMUX` value only
while production Fish startup runs (preventing its tmux auto-attach), removes
that guard before the prompt, and then sources the prototype adapter. This
makes adaptive/fixed child panes recursively identical to the original shell
without changing production Fish configuration.

Run `validate_bindings.sh`; it resets only its disposable `trial-focused`
session before starting. It writes deterministic before/after evidence to
`evidence/binding-validation.jsonl`, including pane rectangles and split
ratios, moved pane/tab identities, sentinel PID liveness, zoom state, and
zero/one/multiple visible-URL fixtures. The same gate drives application-owned
`Alt-X` and `Alt-Ctrl-x` through Herdr's Kitty CSI-u transport into Fish,
including process termination and two-press close-others confirmation.

Run the real prefix URL gate independently with:

```sh
./herdr/prototype/validate_urls.sh
```

It drives `prefix+u` through a disposable PTY client and proves that zero URLs
open nothing, one URL is normalized and opened, and multiple visible URLs open
only the newest match. Evidence is replaced atomically only on success at
`evidence/url-validation.jsonl`; the opener is a log-only fixture and production
configuration remains unchanged.

## Remote attach gate

Run the isolated OpenSSH transport gate with:

```sh
./herdr/prototype/validate_remote.sh
```

The validator launches a disposable user-space `sshd` bound only to localhost,
uses temporary host/client keys and configuration, and exposes the existing
prototype v0.7.4 binary on the remote test path. A real `herdr --remote
ssh://... --session remote-audit` thin client starts a compatible named remote
server with a live pane, then detaches cleanly. A closed endpoint independently
proves fail-closed behavior before input or bootstrap. The gate does not enable
macOS Remote Login, install Herdr, or alter production configuration. Atomic,
hash-bound evidence is written to `evidence/remote-validation.jsonl`.

## Pane lifecycle gate

Run the pane-layout and destructive sibling-pane gate independently with:

```sh
./herdr/prototype/validate_panes.sh
```

Both `prefix+o` and Fish-owned `Alt-o` require an identical second press within
five seconds. The focused pane survives; only siblings in its tab are closed.
The live gate proves first-press process survival, second-press process exit,
and a safe no-op when the tab has no siblings. Neovim continues to own `<M-o>`
for its local “only window” behavior.

`prefix+=` and Fish-owned `Alt-=` use `layout.export` plus
`layout.set_split_ratio` to weight every BSP split by descendant pane count.
The same three pane IDs and sentinel processes survive while their areas become
equal; no pane, tab, or process is recreated.

## Tab lifecycle gate

Run the tab gate independently with:

```sh
./herdr/prototype/validate_tabs.sh
```

The validator derives a gate-only configuration with `/bin/sh` as its isolated
sentinel shell, starts the disposable `gate-tabs` server and a fixed-size PTY
client, and drives the real prefix-key path. It verifies create, next/previous,
indexed selection, exact last-tab history, reorder/restore, immediate close,
and confirmation-protected close-others with tab-ID readback and
sentinel-process liveness. Reorder uses the supported `tab.move` socket method
because v0.7.4 does not expose it in the CLI wrapper. The session is stopped and
deleted on success or failure; evidence is published atomically to
`evidence/tab-lifecycle-validation.jsonl` only after a pass. Nothing is
installed into production Herdr, tmux, Fish, Ghostty, or Neovim configuration,
and a pass does not authorize migration.

Close-others confirmation state is namespaced by Herdr session and socket and
fails closed when either identity is unavailable. The gate proves that a
foreign session and a same-named session on a distinct socket each preserve
every tab on their first press and cannot consume or confirm the original
server's pending close.

Numeric creation follows Herdr's contiguous tab model: a missing digit creates
one cwd-following tab labeled with that digit instead of manufacturing filler
tabs to imitate tmux's sparse indices.

## Popup gate

Run the session-modal popup gate independently with:

```sh
./herdr/prototype/validate_popups.sh
```

Real `prefix+Enter` and `prefix+g` input opens disposable scratch and lazygit
fixtures at the configured 80% and 85% sizes. The fixed 120×40 client reports
inner popup PTYs of 72×30 and 76×32 cells after borders and the collapsed
sidebar are accounted for. Both popups inherit the active pane's cwd, dismiss
when their command exits, and leave the tiled pane, tab, workspace, layout, and
sentinel process unchanged. The gate does not launch a production shell or
lazygit instance and does not authorize migration.

The `lazygit` fixture kind names the popup slot, not the tool. Production
`prefix+g` now launches `tuicr --working-tree`; the prototype config keeps the
`lazygit` payload deliberately. The gate sed-substitutes `popup_fixture.sh` for
that command before the server starts, so it never runs either tool, and what it
proves — 85%×85% geometry, a 76×32 inner PTY, inherited cwd, dismissal on
process exit, tiled objects unchanged — is identical for any full-screen git TUI.
`prototype/config.toml` is sha256-pinned by sixteen gates, so retitling the
payload would force sixteen live re-validations that prove nothing new. Swapping
the production git TUI is not a prototype change; only a change to the popup
contract itself (binding, type, or geometry) re-opens this gate.

## Layout palette gate

Run the process-preserving layout palette gate with:

```sh
./herdr/prototype/validate_layout_menu.sh
```

`prefix+Space` opens a 54×20 session-modal palette. It retains `e` equalize,
`z` zoom, `a` adaptive split, `v` split right, and `q` cancel, and adds the
tmux-menu symbols `+` tiled/equalize, `_` main-horizontal, `|` main-vertical,
`\` even-horizontal, and `-` even-vertical.

Every preset is ratio-only. Tiled/equalize keeps the current BSP topology.
Even-horizontal and even-vertical require an already all-right or all-down
tree. Main-horizontal requires a top main leaf above an all-right remainder;
main-vertical requires a left main leaf beside an all-down remainder. The main
ratio is 62%. An incompatible preset exits before mutation. The live gate
proves all compatible shapes retain exact pane/terminal IDs, sentinel PIDs,
cwd, topology, and focus; it also proves incompatible rejection is inert.
`layout.apply` is deliberately absent because a v0.7.4 probe showed it replaces
the referenced pane terminals.

## Pane and tab utility parity gate

Run the focused utility gate with:

```sh
./herdr/prototype/validate_utilities.sh
```

`prefix+Shift+p` opens a real fzf popup containing both send-focused and
receive-beside-focused pane-transfer choices. The helper revalidates both pane
IDs after selection and uses native `pane move`; cancel, self, and stale
targets are inert. Candidates span the session. Same-workspace moves retain the
pane ID; cross-workspace moves use Herdr's destination-workspace pane ID while
retaining the terminal, process, cwd, and focus. `prefix+Shift+u` prompts for an
explicit scrollback-export
path, creates new files without clobbering, and requires `y` before replacing
an existing path. Exports preserve API-decoded text bytes, including JSON-like
leading text and trailing newlines, in mode `0600` files and do not enable pane
history.

`prefix+^` focuses the first tab and `prefix+$` the last tab in current
workspace API order. They do not change `prefix+Tab` or `Ctrl+^`, which remain
the approved last-pane bindings. The gate proves both transfer directions,
including a cross-workspace move, preserve terminal ID, sentinel PID, cwd, and
focus; a 320-line history export, no-clobber and confirmed overwrite; tab-edge
order; both real popup transports; and unchanged tmux, Fish, Ghostty, and
Neovim scope hashes.

## Copy-mode paging gate

Run the native scroll-navigation gate with:

```sh
./herdr/prototype/validate_copy_mode.sh
```

The fixed 120×40 client enters copy mode through real `prefix+s` input over a
120-line live pane. Native `Ctrl-u` moves the visible range from lines 82–120 to
62–100 and `Ctrl-d` returns it to 82–120; `PageUp` moves to 44–82 and
`PageDown` returns to the live bottom. The pane's sentinel process survives the
entire browse. This intentionally adopts Herdr's documented modifier chords
instead of injecting tmux's plain `u/d`. The reviewed source build additionally
proves `a`/`i` exit without copying and `Y` copies the current line and exits.
Rectangle selection, marks, and OSC 133 prompt jumps remain explicit upstream
capability gaps in v0.7.4 rather than emulated key sequences.

Run `validate_capability_gaps.sh` to bind those unavailable actions to the
exact v0.7.4 default-configuration hash and the reviewed source-patch hash. The
same audit proves that legacy `Alt-Tab` and cursor-local copy-mode `O` remain
retired without input-emulation shims. It records the supported replacements
and writes atomic evidence to `evidence/capability-gap-validation.jsonl`.

## Recovery gate

Run the full server-restart gate with:

```sh
./herdr/prototype/validate_recovery.sh
```

The gate enables pane history only in its isolated config, builds one named
workspace with two tabs and three labeled panes, and stops the server while
three sentinel processes are live. After restart, workspace/tab/pane IDs,
labels, cwd, focus, and the 62/38 split return byte-for-byte. Two ordinary shell
panes replay exact saved scrollback. The third pane uses a version-6 Codex hook
installed into a disposable `CODEX_HOME`; Herdr invokes the runtime-only fixture
as `codex resume recovery-codex-session`. The three original PIDs are proven
dead and replaced. This is the Herdr recovery model: snapshot plus opt-in screen
history plus native agent resume, not arbitrary live-process resurrection.

## Workspace-navigation gate

Run the tmux-session-to-Herdr-workspace navigation gate with:

```sh
./herdr/prototype/validate_workspace_navigation.sh
```

Named Herdr sessions remain isolated server namespaces; ordinary project
navigation uses first-class workspaces inside one session. Real `prefix+(`/`)`
input cycles three workspaces in both directions with wrapping. `Ctrl-^`
(the same terminal byte as `Ctrl-6`) invokes native `last_pane` and toggles
between panes in different workspaces. All three sentinel processes survive.
`prefix+Tab` remains an additional last-pane binding outside the tab-history
gate.

## Ready-prompt replay gate

Run the replay gate independently with:

```sh
./herdr/prototype/validate_ready_prompt.sh
```

After changing agent-specific clear or ready-composer behavior, run the optional
live Claude gate. It uses a disposable session and does not make a model request:

```sh
./herdr/prototype/validate_ready_prompt_live_claude.sh
```

`ready_prompt.sh` uses Herdr process inspection and recent-unwrapped pane reads,
then applies the established fail-closed handoff parser. It sends the extracted
text through a bracketed-paste envelope over `pane send-text`, so multiline
content is inserted without submission. Consume-once state is scoped to the
pane. `prefix+B` submits `/clear` for Codex or Claude, waits for two stable
agent-specific ready screens, then inserts the handoff; other agents fail
before capture or input.
The validator covers parser compatibility, mocked error/clear paths, and a live
Herdr/Fish transport trial whose pasted `touch` command must remain visible but
unexecuted.

## Semantic agent-state gate

Run the semantic-state gate independently with:

```sh
./herdr/prototype/validate_agent_states.sh
```

Herdr retains lifecycle authority and its native `working`, `blocked`, and
`done` rollups. `semantic_agent_state.py` reuses the established agent-event
classifier and reports display-only metadata: running work remains `working`,
questions and approvals remain `blocked`, and finished and failed outcomes
remain `done`, while state labels and the `$semantic_state` sidebar token make
all five outcomes visually distinct. The adapter is inert outside a Herdr pane,
and no Codex, Claude, OpenCode, AGY, or Gemini hook is installed by this gate.

Run the bounded multi-agent compatibility gate independently with:

```sh
./herdr/prototype/validate_multi_agent_compat.sh
```

This separate atomic gate preserves `agent-state-validation.jsonl` and records
Claude, OpenCode, AGY, and Gemini CLI availability plus deterministic detection,
all five lifecycle/semantic transitions, real `prefix+f` navigator visibility,
and an unsupported-agent no-mutation control. It makes no model calls, installs
no integrations, changes no production configuration, and does not authorize
migration. Successful evidence is written to
`evidence/multi-agent-compat-validation.jsonl`.

## Fish login-attach gate

Run the isolated login gate with:

```sh
./herdr/prototype/validate_login_attach.sh
```

For an ordinary interactive top-level login, `herdr_login_attach.fish`
uses a persistent most-recent automatic-session pointer. Allocation seeds the
pointer as a crash fallback. An event-driven, PID-plus-start-identity supervisor
waits for the Herdr client without polling, survives terminal HUP, refreshes the
pointer when that exact automatic client exits, and removes its matching runtime
lease, so the final session to close is restored later. When no Herdr client is
open, the next window restores that session.
When any Herdr client is open, the next window creates a never-before-allocated
session: `main`, then monotonically increasing `window-N` names. Closing a
client does not stop or delete its server. An explicit safe
`HERDR_LOGIN_SESSION` still overrides the automatic policy.

Automatic launches change to the user's valid `$HOME` before allocation. A
restored Herdr session retains its own persisted pane cwd. The adapter remains
inert inside Herdr (`HERDR_ENV` or `HERDR_PANE_ID`), inside production tmux, in
non-login or non-interactive Fish, when `HERDR_NO_AUTO_ATTACH` is set, or when a
custom session name is unsafe. The isolated gate proves concurrent monotonic
creation, no-client restoration, migration from existing automatic sessions,
the `window-10` boundary, PID-reuse/symlink/interruption safety, event-driven
exit recording with no-polling and preserved-client-stdin assertions,
persistent-state safety, and every retained guard without installing
or changing production Fish, tmux, Ghostty, or Herdr configuration.

High-quality image preview uses Herdr's experimental pane-owned raster layer.
`native_preview.sh` reads the real fzf geometry, rejects its negative row
sentinel, pre-fits PNG pixels to the Ghostty cell box, serializes updates per
pane, and discards superseded workers. The retry uses only the clean fixtures in
`fixtures/`; terminal screenshots are no longer preview inputs. Crisp placement
and explicit clear pass, but fast selection captures still show the previous
raster and focus/resize can transiently black most of the client. The native
route therefore remains rejected as less polished than tmux. Chafa symbols
remain only the failure fallback because their quality was also rejected.

The scratch `prototype.golden-focus` plugin listens for `pane.focused` and
targets the same 62% width/height used by the tmux focus hook. Press
`Ctrl-a Shift-g` to disable it and restore the focused layout axes to 50/50;
press again to re-enable and apply 62%. The plugin source exists only on this
throwaway branch; its registration and mutable state stay inside the ignored
prototype runtime.

The first run uses the hash-verified reviewed v0.7.4 source build when
`../source-build/.work/bin/herdr` exists; otherwise it downloads the official
v0.7.4 macOS arm64 release into `.runtime/` and verifies its expected byte
size. It starts the named scratch session `trial`. The short scratch name keeps
the macOS Unix socket below its path-length limit. Remove `.runtime/` to wipe
only the throwaway trial state; the reviewed source-build cache is separate.

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
chafa paths. The latest clean raster and clear evidence is captured in
[`native-preview-clean`](screenshots/native-preview-clean.png) and
[`native-preview-cleared`](screenshots/native-preview-cleared.png). The stale
selection and focus-redraw failures are captured in
[`native-preview-cycle-amber`](screenshots/native-preview-cycle-amber.png),
[`native-preview-cycle-blue`](screenshots/native-preview-cycle-blue.png), and
[`native-preview-focus-right`](screenshots/native-preview-focus-right.png).
The user already approved the physical Alt feel; this image-only retry did not
modify that adapter.

To stop and wipe the scratch runtime without touching normal tmux:

```sh
./herdr/prototype/run.sh cli server stop
./herdr/prototype/run.sh --border boxed cli server stop
./herdr/prototype/run.sh --border focused cli server stop
./herdr/prototype/run.sh --border borderless cli server stop
rm -rf herdr/prototype/.runtime
```
