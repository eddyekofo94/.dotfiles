# tmux to Herdr parity audit

This document records the exhaustive feature comparison requested before final
daily-driver acceptance. It complements
[`tmux-to-herdr.md`](tmux-to-herdr.md), which remains the detailed validation
history.

## Baseline

- tmux baseline: the live `tmux/tmux.conf`, tmux 3.7b, TPM,
  tmux-resurrect, tmux-continuum, and Catppuccin.
- Herdr baseline: the installed and production-pinned Herdr v0.7.4,
  `herdr/config.toml`, the approved prototype helpers, and the golden-focus
  plugin.
- Herdr v0.7.5 was released on 2026-07-21. Its published changes improve agent
  automation, navigation, plugin persistence, and terminal behavior, but do
  not advertise the missing copy-mode primitives listed below. Upgrading is a
  separate compatibility slice, not an assumed parity fix.
- This audit changes no runtime configuration. Tmux remains the immediate
  fallback.

## Classification

| Class | Meaning |
| --- | --- |
| Implementable | The current Herdr CLI/API can support a bounded port. |
| Herdr-native replacement | Herdr already provides a simpler or stronger workflow; reproducing tmux literally would be worse. |
| Retirement | The binding is redundant or belongs to nested tmux and should remain absent. |
| Upstream-limited | Herdr v0.7.4/v0.7.5 exposes no faithful primitive. Do not fake parity with terminal-input emulation. |
| Decision required | A technically possible port has a security or workflow tradeoff that must be settled first. |

## Already covered

The production trial already covers the daily pane, tab, and agent surface:

- detach/reattach; named sessions; workspace navigation; last-pane navigation;
- split, adaptive split, focus, resize mode, swap, equalize, zoom, golden focus;
- smart pane close, close-other-panes, close tab, and close-other-tabs;
- numbered tab focus/create, previous/next tab, and tab reordering;
- searchable workspace/tab/pane navigation;
- scratch-shell and lazygit popups;
- ordinary copy selection, search, clipboard copy, and scrollback;
- newest-visible URL opening;
- ready-prompt replay and clear/replay;
- Fish/fzf/Neovim-owned `Alt-h/j/k/l`;
- agent status display and wait-capable structured Herdr APIs;
- remote thin-client attach;
- Catppuccin, focused-pane borders, sidebar, mouse behavior, and native image
  rendering.

The detailed evidence for these features is in
[`tmux-to-herdr.md`](tmux-to-herdr.md) and `herdr/prototype/evidence/`.

## Missing features that can be implemented

| Cluster | tmux feature | Bounded Herdr implementation | Dependency / stop condition |
| --- | --- | --- | --- |
| Recovery safety | tmux-resurrect structure/cwd restoration and Vim/Neovim strategies | Herdr already restores workspaces, tabs, panes, cwd, layout, and focus. The approved official Claude Code, Codex, and OpenCode integrations are installed current while `pane_history = false` remains active. | [x] `installation-validation.md` proves preservation-aware installation and a real Codex stop/restart/resume turn in a deleted disposable session. Full Herdr/Fish verification and fresh post-fix review pass (Standards 0 / Fidelity 0). |
| Project entry | `tmux/scripts/sessionizer.sh` | A Herdr workspace/worktree project picker that reuses an existing target or creates one in the selected directory. | [x] `Prefix+Shift+w` discovers configured Git roots plus linked worktrees, reuses canonical cwd metadata or safely re-adopts a tokenless restored pane cwd, and otherwise creates/focuses a basename-labeled workspace in the current `main` session. Strict failure rollback, focused validation, full Herdr/Fish verification, and fresh closure review pass (Standards 0 / Fidelity 0). Native `Prefix+w` remains existing-workspace navigation. |
| Pane transfer | `join-pane` / move-pane prompts | [x] `Prefix+Shift+p` opens a session-wide stale-safe fzf picker for send-focused and receive-beside-focused native pane moves. | `utility-parity-validation.jsonl` proves terminal ID, sentinel PID, cwd, target tab, and focus survive same- and cross-workspace moves. Same-workspace IDs persist; Herdr remaps cross-workspace pane IDs. Cancel/self/stale targets are inert. |
| History export | `dump-history` | [x] `Prefix+Shift+u` reads focused-pane recent terminal text and prompts for an explicit output path. | A 320-line fixture proves JSON-like text and trailing newlines survive. New files are atomically installed mode `0600`; existing paths are preserved unless the user explicitly answers `y`; `pane_history` stays off. |
| Tab edges | first-tab and last-tab shortcuts | [x] `Prefix+^` and `Prefix+$` focus API-order first/last tabs. | `Prefix+Tab` and `Ctrl+^` remain last-pane bindings; sentinel processes survive both tab-edge actions. |
| Layout presets | tiled, main-horizontal, main-vertical, even-horizontal, even-vertical | [x] The 54×20 palette exposes ratio-only presets when the existing BSP topology is compatible. | Every supported shape retains topology, pane/terminal IDs, processes, cwd, and focus. Incompatible presets reject before mutation; `layout.apply` remains unavailable because it replaces terminals. |
| Picker operations | tmux choose-tree/fzf delete, filtering, richer preview | [x] `Prefix+Shift+f` opens a one-target pane/tab/workspace delete popup with searchable labels and structured metadata preview. | Explicit confirmation, strict ownership/uniqueness checks, and fresh descendant terminal/topology fingerprints pass in fixture and real-prefix validation. Native `Prefix+f` remains the default navigation path. |
| Broad visible-reference search | URI/path/hash search over scrollback | [x] `Prefix+Shift+r` lists recent pane-read URI/path/hash matches; Enter copies and Ctrl-O opens URI/path matches. | Extraction/action/failure and real-prefix hash-copy evidence pass. This is explicitly outside copy mode and cannot provide cursor-local or selection-bounded semantics. |
| Outer terminal title | `set-titles-string '#S:#I #W'` | **Upstream-limited on v0.7.4.** Ghostty accepts a controlled direct OSC 2 title, but Herdr exposes no supported dynamic title-template configuration. Its literal `terminal title set/clear` API is not template parity and will not be wrapped in event emulation. | Reopen only when an authorized retained Herdr version documents a dynamic session/tab/pane title template; then require physical Ghostty readback across focus and rename transitions. |

## Decision-required or intentionally different

| tmux behavior | Herdr decision |
| --- | --- |
| tmux-resurrect pane contents are disabled (`@resurrect-capture-pane-contents off`) | Keep Herdr `pane_history = false`. This matches the current privacy posture and avoids writing prompts, tokens, and command output to `session-history.json`. |
| arbitrary process resurrection | Do not promise it. After a full server restart Herdr restores topology/cwd, not arbitrary processes. Normal detach keeps them alive; experimental live handoff is a separate future reliability slice. |
| shared tmux paste buffers and `choose-buffer` | **Durably deferred/upstream-limited on v0.7.4.** The system clipboard covers ordinary copy/paste, but Herdr has no supported multi-entry store or chooser. Do not add retention or emulation without a separately settled security product boundary. |
| pane input lock/unlock | Herdr has no established daily need or native equivalent. Treat as a separate requested-access-control feature, not migration parity by default. |
| `Prefix+Tab` last window | Herdr's approved `Prefix+Tab` means last pane, including across workspaces. First/last tab helpers may be added on different keys. |
| session cycling | Workspaces are the daily project-navigation unit; named Herdr sessions remain isolation boundaries. |
| top tmux status bar | Herdr's sidebar and tab bar provide richer workspace, tab, pane, and agent state. |

## Upstream-limited copy-mode features

Herdr v0.7.4 and the v0.7.5 published feature list do not expose configurable
faithful equivalents for:

- rectangle selection (`Ctrl-v`);
- marks and jump-to-mark;
- OSC 133 previous/next prompt jumps;
- selection-bounded forward/backward search;
- cursor-local URL opening (`O`);
- tmux's copy-mode-local broad URI/path/hash search.

The reviewed private v0.7.4 source build now supplies distinct
copy-current-line (`Y`) by composing the existing `V` and `y` operations.
Ordinary selection, yank, search, half-page/page movement, scrollback, and the
newest-visible URL helper are already covered. The remaining primitives should
be tracked upstream or revisited after a release that explicitly adds them. Input
emulation would be brittle and is not an acceptable implementation.

## Upstream-limited outer-title parity

Ghostty 1.3.1 accepted a controlled direct OSC 2 title and exposed the exact
value through macOS accessibility readback. The host terminal is therefore not
the missing configuration surface.

Herdr v0.7.4 exposes literal `client.window_title.set/clear` and
`herdr terminal title set/clear` operations, but its complete generated config
and tagged source expose no dynamic outer-title template. Both production-main
and isolated direct-Ghostty calls reported successful dispatch without stable
physical/readback presentation. A plugin, poller, or shell hook that rebuilds
`#S:#I #W` after every state change would be unsupported emulation and is
rejected. See
`.working/interviews/herdr-outer-terminal-title-parity/decisions.md`.

## Deferred shared-buffer parity

The live tmux server currently holds its configured limit of 50 auto-named
paste buffers. Only buffer names, byte sizes, and creation times were inspected;
contents were not read. `@resurrect-capture-pane-contents` remains off, so this
is live server memory rather than an approved durable clipboard archive.

Herdr v0.7.4's installed CLI help, complete generated config and socket API
schema, exact tagged source, official changelog, and version-matched
documentation expose no named-buffer store, chooser, list/read/delete
lifecycle, or retention policy. Its supported path writes copy-mode and mouse
selections to the current system clipboard and accepts normal host paste. That
is the retained security-conscious ordinary workflow, but it is not
multi-entry parity.

A popup over plugin state, `pbpaste` polling, intercepted writes, or pane
readback would create a new sensitive-data retention product and emulate the
missing primitive. It is rejected without separately settled capture, scope,
local/remote access, memory/disk storage, limits/TTL, restart, deletion, content
type, and secret-warning decisions. See
`.working/interviews/herdr-shared-buffer-history/decisions.md`.

## Accepted retirements and stronger Herdr features

- Direct redundant Alt aliases stay retired where Prefix or
  application-owned navigation already covers the action.
- Nested-tmux passthrough stays retired; Herdr remote attach avoids an inner
  multiplexer.
- Herdr workspaces/worktrees, structured JSON APIs, native agent views and
  waits, remote thin clients, spatial swap/resize, and modal popups are
  retained as improvements rather than reshaped into tmux vocabulary.

## Ranked implementation sequence

1. [x] `herdr-recovery-safety-parity`: official agent integrations and
   isolated restart/resume proof, while pane history remains off.
2. [x] `herdr-project-sessionizer-workflow`: project entry is ported as a
   current-session workspace/worktree popup with canonical reuse.
3. [x] `herdr-pane-tab-utility-parity`: pane transfer, history export, tab edges,
   and only process-safe layout presets.
4. [x] `herdr-picker-reference-parity`: richer destructive picker operations and
   visible-reference search.
5. [~] `herdr-outer-terminal-title-parity`: upstream-limited until Herdr
   documents a supported dynamic session/tab/pane title template.
6. [~] `herdr-shared-buffer-history`: ordinary system clipboard use is retained;
   multi-entry parity is deferred/upstream-limited until Herdr documents a
   native facility or Eddy explicitly selects and settles a separate
   security-sensitive product.
7. `herdr-pane-input-lock`: decision required; establish a real daily need and
   supported access-control primitive before considering implementation.
8. `herdr-upstream-copy-mode-gaps`: monitor upstream; implement only after
   supported primitives exist.

Exactly one sequence item may be the active implementation goal. Final
daily-driver acceptance is blocked until Eddy either accepts or explicitly
defers every item above.
