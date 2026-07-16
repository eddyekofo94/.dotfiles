# Herdr as a tmux replacement: primary-source research

Research date: 2026-07-16
Current stable release checked: [v0.7.4, released 2026-07-15](https://github.com/ogulcancelik/herdr/releases/tag/v0.7.4)
Product identity: [Herdr](https://herdr.dev/) by `ogulcancelik`, an open-source, terminal-native agent multiplexer—not the similarly named third-party add-ons.

## Scope and confidence

This note covers Herdr itself, not the local tmux or Neovim configuration. It uses only sources controlled by the project: the official documentation, the official repository, release notes, and source/config reference at v0.7.4. Claims about tmux parity are intentionally conservative.

Legend:

- **Yes** — first-party documentation explicitly supports it.
- **Partial** — supported with an important limitation or different model.
- **No** — first-party documentation explicitly says it is unavailable.
- **Unknown** — no first-party support statement was found; do not assume parity.

## Bottom line

Herdr is credible for a trial if the desired center of gravity is persistent terminal panes plus visibility into several coding agents. It preserves the familiar `ctrl+b` prefix model, offers workspaces/tabs/panes, can be made visually compact, works over ordinary SSH, and exposes much richer agent-aware automation than stock tmux. Its official [concept model](https://herdr.dev/docs/concepts/) and [keyboard guide](https://herdr.dev/docs/keyboard/) are deliberately familiar to tmux users.

It is not yet safe to treat as a drop-in replacement for every mature tmux behavior. The project is pre-1.0 and young, a server restart kills arbitrary pane processes, native Windows is beta, third-party plugins are unsandboxed, and several sophisticated tmux workflows have no documented equivalent. Most importantly for a Neovim-centered setup, Herdr documents pane-direction bindings but does **not** document a smart Neovim/Herdr edge-handoff integration comparable to a Vim-aware tmux navigator.

## Personalized recommendation

**Give Herdr a side-by-side trial; do not replace tmux yet.** The fit is better than it first appears because Herdr's CLI exposes the exact low-level primitives needed for a new Neovim adapter: current pane identity, edge/neighbor inspection, directional focus, resize, split, swap, read, and send. Herdr also replaces a large amount of custom agent-status work with a first-class agent model.

The migration is nevertheless a small porting project, not a config translation. The present setup depends on tmux-specific pane formats/options, hook-driven status rendering, conditional forwarding when Neovim is foreground, capture/send APIs, TPM plugins, and fish login auto-attach. Herdr does not read `tmux.conf`, run TPM plugins, or provide a documented process-conditional keybinding layer. Keep tmux available until the Neovim boundary handoff, ready-prompt replay, agent state fidelity, and image rendering have passed a real trial.

## Local functionality inventory and Herdr fit

Local sources inspected on 2026-07-16:

- [`tmux/tmux.conf`](../../tmux/tmux.conf), [`tmux/README.md`](../../tmux/README.md), helper scripts, hooks, tests, and manual QA.
- [`fish/config.fish`](../../fish/config.fish) and [`fish/conf.d/env.fish`](../../fish/conf.d/env.fish) for login auto-attach and Kitty image passthrough.
- `~/.config/nvim/lua/plugin/tmux.lua`, `lua/core/keymaps.lua`, `lua/core/options.lua`, and the Focus/window configuration for editor-to-multiplexer behavior.
- Runtime versions: tmux 3.7b, Neovim 0.13.0-dev, and Ghostty 1.3.1. Herdr is not installed, so no live Herdr behavior was assumed.

Legend: **✓** built in or directly configurable; **△** achievable with changed behavior or a port; **✗** documented absence/incompatibility; **?** not established by first-party docs and needs a trial.

| Current local functionality | Herdr | What carries over, changes, or blocks |
| --- | :---: | --- |
| Persistent PTY processes across detach/reattach | ✓ | Native background server behavior. |
| Multiple named sessions | ✓ | Named sessions exist, with workspaces above tabs/panes. |
| Restore after server/reboot | △ | Shape and cwd restore; arbitrary processes do not. Supported agents can resume via current integrations. This broadly replaces Resurrect/Continuum for agents, not arbitrary programs. |
| Fish login automatically creates/attaches sessions | △ | Rewrite the login block to launch/attach `herdr`, guarded by `HERDR_ENV`/pane state. The current block must not auto-enter tmux inside Herdr because Herdr then sees `tmux`, not the agent. |
| Project-oriented sessionizer | △ | Workspaces and `workspace create/focus` cover the model, but `tmux/scripts/sessionizer.sh` must be rewritten. |
| Windows/tabs with numbers, next/previous/last, rename, close | ✓ | Tabs and indexed jumps are native; last-pane exists but is unset by default. Exact aliases need config. |
| Session/window/pane searchable tree | ✓ | Session navigator and workspace navigation are searchable and can filter agent state. Exact tmux chooser formatting is not portable. |
| fzf window picker | △ | Herdr's navigator may replace it; keeping the exact fzf UI would require a custom command/API script. |
| Splits inherit the current pane cwd | ✓ | `terminal.new_cwd = "follow"` is the default. |
| Directional pane focus | ✓ | Prefix bindings and CLI directional focus are native. |
| Prefix-free `Alt-h/j/k/l` outside Neovim | △ | Direct chords are configurable, but Herdr documents no foreground-process condition. A global direct bind would steal the chord from TUIs instead of tmux's current smart forwarding. |
| Neovim `Alt-h/j/k/l`: move through editor windows, then outer pane | △ | Feasible through `herdr pane edges/neighbor/focus --current`; the current Lua calls tmux directly and must be adapted. No official ready-made Neovim integration was found. |
| Neovim/TUI-aware forwarding of Alt navigation and management keys | △ | No documented equivalent to the current `running_vim`, `fwd`, and `fwd_strict` guards. The safest trial is prefix-first Herdr keys plus a Neovim-owned Herdr adapter. |
| Neovim-aware close, only-window, rotate, previous-pane, equalize | △ | Herdr has close/swap/last-pane/layout primitives, but every current fallback calls tmux commands and must be ported/tested. |
| Neovim-aware pane resizing by two cells | △ | Herdr exposes directional resize with an amount; adapter work is required and its float amount differs from tmux cell arithmetic. |
| Swap, move, or join panes; move pane to another tab | ✓ | Native CLI/API move and swap operations are stronger than the current prompt-based join workflow. Exact shortcuts need mapping. |
| Pane zoom | ✓ | Native toggle. |
| Equal/tiled and named layout menu | △ | Layout export/apply and split ratios exist, but tmux's named built-in preset catalogue was not documented. |
| Optional golden-ratio focus at 62% | △ | Could be a plugin/event or custom command using focus and split-ratio APIs; there is no documented built-in auto-resize-on-focus equivalent. |
| Floating scratch shell and lazygit popup | ✓ | Custom popup commands reproduce both without changing the tiled layout. |
| Smart close: immediate for spare shell, confirmation for TUI/last pane | △ | General confirmation exists, but the current process-sensitive close policy needs a script/plugin using process info. |
| Mouse pane/tab focus, drag resize, scroll, context menus | ✓ | First-class Herdr behavior. |
| Vi-style keyboard copy mode | ✓ | Motions, selection, yank, search, and repeat are native. |
| 65,536-line scrollback | △ | Herdr uses a byte limit (10 MB default), not a line count; tune after measuring comparable history. |
| Mouse copy and macOS/system clipboard | ✓ | Copy-on-select is built in; remote thin-client mode also bridges image paste. Clipboard parity still needs live QA. |
| Cross-platform clipboard shell fallbacks | △ | Herdr owns common clipboard behavior, but the exact Linux/WSL/Termux/macOS fallback script does not port automatically. |
| Named/shared paste buffers and buffer chooser | ? | No tmux-like shared named-buffer surface was found. |
| Search within a selected copy-mode region | ? | Herdr has copy-mode search, but selection-bounded search was not documented. |
| Previous/next OSC 133 shell prompt navigation | ? | No first-party equivalent was found. |
| URL search/open under cursor and open newest visible URL | △ | Ctrl-click is native when the terminal forwards it; the keyboard URL workflows need custom read/output scripts. |
| Visible copy-mode indication and smart Escape behavior | △ | Herdr has explicit modes; exact bare-shell/TUI-sensitive Escape policy is not documented. |
| Terminal true color, undercurl, extended keys, title propagation | △ | General terminal rendering/key support is expected and recent focus-event forwarding is documented, but exact Ghostty + Neovim escape fidelity needs live QA. |
| Kitty inline images through tmux passthrough | ? | Herdr's local Kitty graphics support is experimental and off by default. Do not assume the current `chafa --passthrough=auto` workflow survives. |
| Nested remote tmux passthrough toggle | △ | Herdr has ordinary SSH, a thin remote client, and experimental Herdr nesting, but not the same outer/inner tmux key-table workflow. Remote Herdr may remove the need. |
| Catppuccin appearance | ✓ | Built-in Catppuccin and terminal-palette themes. |
| One simple top status row | △ | Herdr uses a sidebar plus tab row rather than the current top tmux status line. It can be collapsed/hidden and simplified, but exact quietness needs screenshots. |
| Hide clutter: no toasts, no sounds, reduced borders/gaps | ✓ | Toasts default off; sounds, sidebar mode, pane borders/gaps, and single-tab bar are configurable. Sounds should be explicitly disabled for this setup. |
| Per-agent state for Codex, Claude, OpenCode, AGY, Gemini | △ | All are detected to varying confidence; current integrations are strongest for Codex/Claude/OpenCode. Gemini is not fully tested in the official support table. Rich state should be verified agent by agent. |
| Distinct running, question, approval, finished, and failed icons | △ | Herdr's semantic model is working/blocked/done/idle/unknown. Question and approval collapse into blocked, and no separate failed state is documented. Custom status/metadata can add display detail but not new semantic states. |
| Multiple agents summarized inside each tab label | △ | Herdr rolls state into pane/tab/workspace and lists agents in the sidebar. It does not reproduce the exact single-line `codex:project · claude:project` tmux tab format. |
| 12 FPS cached agent spinner | △ | Herdr owns its status rendering, eliminating the custom animator; exact motion, glyph size, and colors require visual approval. |
| Existing native agent commands remain unchanged | ✓ | Integrations install hooks/plugins behind ordinary agent commands, matching the current philosophy. Audit hook merging before enabling them. |
| Ready-prompt replay (`prefix+b`) | △ | Port `ready_prompt.sh` to `pane read`, `send-text`, and `send-keys`, then bind it as a custom command. The current script is tmux-specific. |
| Clear-then-replay (`prefix+B`) with readiness polling | △ | The API can read, send, and wait, so the workflow is implementable; none of the tested fail-closed semantics come for free. |
| TPM/Catppuccin/Resurrect/Continuum plugin ecosystem | ✗ | tmux plugins do not run in Herdr. Replace capabilities individually with Herdr built-ins or its newer, unsandboxed plugin system. |
| Custom hooks, scripts, JSON CLI, and socket automation | ✓ | This is a Herdr strength; structured APIs are broader and less format-string-dependent than tmux scripting. |
| Git worktree creation and grouping | ✓ | Native workspace/worktree workflow is an advantage over the current tmux layer. |
| Ordinary SSH use and phone-friendly attach | ✓ | Native local-on-server and thin-client paths are supported. |
| Current no-clutter behavior with one or two tabs | △ | `hidden` collapsed mode and single-tab-bar hiding can be configured, but startup collapse behavior in stable v0.7.4 and the real visual result need a live trial. |

### Neovim interaction analysis

The editor currently owns a two-layer window system:

1. Neovim uses right/below splits, stable cursor-preserving split behavior, many `Alt` window operations, and Focus.nvim for optional active-window resizing.
2. `lua/plugin/tmux.lua` activates only when `$TMUX` exists, reads `$TMUX_PANE`, asks tmux whether the pane is zoomed or at an outer edge, and calls `select-pane` only when Neovim cannot move farther.
3. The tmux side conditionally forwards the same `Alt` keys when a live Vim/Neovim/SSH process owns the pane; otherwise those keys operate on tmux. This is why the navigation feels seamless rather than merely sharing similar shortcuts.

Herdr supplies enough CLI structure to recreate step 2, and its panes export `HERDR_PANE_ID`. The missing piece is step 3: no documented Herdr binding condition switches behavior based on the foreground process. For the first prototype, keep Herdr's outer actions prefix-based, leave `Alt-h/j/k/l` unbound in Herdr, and let a small Neovim adapter call `herdr pane focus --direction ... --current` only at an editor edge. That preserves editor muscle memory without globally stealing Alt chords from Codex, Claude, fzf, lazygit, or other TUIs.

## Migration capability matrix

| Capability relevant to a tmux migration | Herdr | First-party evidence and caveat |
| --- | --- | --- |
| Run inside the existing terminal emulator | **Yes** | Herdr is a terminal TUI, not a replacement terminal app; the [official comparison](https://herdr.dev/compare/) says it runs inside the existing terminal. |
| Persistent local panes after client detach/terminal close | **Yes** | The background server owns PTYs; detach with `prefix+q`, and reattach with `herdr`. Processes remain live during ordinary detach. [Session state](https://herdr.dev/docs/session-state/#live-persistence) |
| Persistence across a Herdr server restart | **Partial** | Layout, cwd, and focus return, but original shells, servers, tests, and arbitrary processes are gone. Supported agents may resume via native integrations. [Snapshot restore](https://herdr.dev/docs/session-state/#snapshot-restore) |
| Multiple independent sessions | **Yes** | Named sessions have separate panes, workspaces, tabs, sockets, and runtime state, while sharing global config. [Named sessions](https://herdr.dev/docs/persistence-remote/#named-sessions) |
| Projects grouped above tabs/windows | **Yes** | A workspace is a project-level container; tabs hold layouts; panes are real terminals. [Concepts](https://herdr.dev/docs/concepts/) |
| Tabs/windows | **Yes** | Create, rename, close, cycle, or jump to tabs 1–9. Tabs are also addressable through CLI/socket APIs. [Keyboard](https://herdr.dev/docs/keyboard/#the-rest-by-task) |
| Split panes horizontally and vertically | **Yes** | `prefix+v` splits right and `prefix+minus` splits down; mouse menus also split. [Keyboard](https://herdr.dev/docs/keyboard/#learn-these-five-first) |
| Directional pane focus | **Yes** | Default `prefix+h/j/k/l`; direct chords can be added. [Keyboard](https://herdr.dev/docs/keyboard/) |
| Seamless Neovim-to-multiplexer edge navigation | **Unknown** | Herdr forwards terminal focus events to Neovim as of v0.7.4, restoring file autoreload, but official docs do not describe editor-aware boundary handoff or a Vim navigator integration. [v0.7.4 release notes](https://github.com/ogulcancelik/herdr/releases/tag/v0.7.4) |
| Pane swap/move and resize | **Yes** | Shifted `h/j/k/l` swaps panes and `prefix+r` enters resize mode. APIs also expose move, swap, resize, and split-ratio operations. [Keyboard](https://herdr.dev/docs/keyboard/#the-rest-by-task), [Socket API](https://herdr.dev/docs/socket-api/) |
| Pane zoom/fullscreen | **Yes** | `prefix+z` toggles zoom. [Keyboard](https://herdr.dev/docs/keyboard/#the-rest-by-task) |
| Saved or programmable layouts | **Yes** | The CLI/socket API supports layout export, apply, and split ratios; plugins can automate layout bootstrapping. [CLI reference](https://herdr.dev/docs/cli-reference/), [Plugins](https://herdr.dev/docs/plugins/) |
| tmux-style named layout presets such as `even-horizontal` | **Unknown** | The general layout API is documented, but no first-party named preset catalogue equivalent to tmux's built-ins was found. |
| Floating popup/scratch terminal | **Yes** | v0.7.4 added session-modal popup panes for custom commands and plugins without changing the tiled layout. [v0.7.4 release notes](https://github.com/ogulcancelik/herdr/releases/tag/v0.7.4), [Configuration](https://herdr.dev/docs/configuration/#custom-command-keybindings) |
| Mouse focus, resizing, menus, selection | **Yes** | Click panes/tabs/workspaces, drag borders, use right-click menus, and drag-select to copy; mouse capture can be disabled. [Quick start](https://herdr.dev/docs/quick-start/), [Concepts](https://herdr.dev/docs/concepts/#mouse-ui) |
| Scrollback | **Yes** | Per-pane scrollback defaults to a 10 MB byte limit and is configurable; `prefix+e` opens scrollback in `$EDITOR`. [Config reference](https://herdr.dev/docs/config-reference/) |
| Keyboard copy mode | **Yes** | Vim/tmux-style movement, selection, yank, literal forward/backward smart-case search, and repeat search are documented. Pane output continues while browsing history. [Keyboard copy mode](https://herdr.dev/docs/keyboard/#copy-mode) |
| Shared tmux-style paste-buffer management | **Unknown** | Clipboard copy/paste paths exist, but no documented tmux-like named/shared buffer command set was found. |
| Searchable command/key help | **Yes** | `prefix+?` shows all active bindings. [Keyboard](https://herdr.dev/docs/keyboard/) |
| Fully configurable prefix and keys | **Yes** | Prefix, prefix bindings, direct modifier chords, multiple bindings per action, indexed jumps, and custom command bindings are configurable. [Configuration](https://herdr.dev/docs/configuration/#keybindings) |
| Prefix-free navigation | **Yes** | Direct chords are supported; Herdr recommends `ctrl+alt` families while documenting OS/terminal conflicts. [Going prefix-free](https://herdr.dev/docs/keyboard/#going-prefix-free) |
| Shell/CWD inheritance | **Yes** | Shell executable/mode and new-pane cwd policy are configurable; `follow` inherits the focused pane/workspace directory. [Terminal defaults](https://herdr.dev/docs/configuration/#terminal-defaults) |
| Minimal status UI | **Partial** | Sidebar collapse is bound to `prefix+b`; collapsed mode, row contents/gaps, pane borders/gaps, notifications, sounds, and single-tab-bar hiding are configurable. However, no documented setting removes every Herdr-owned UI element at once. [UI and sidebar](https://herdr.dev/docs/configuration/#ui-and-sidebar), [Config reference](https://herdr.dev/docs/config-reference/) |
| Theme follows the outer terminal | **Yes** | The built-in `terminal` theme follows the host ANSI palette, and individual tokens can be overridden. [Theme](https://herdr.dev/docs/configuration/#theme) |
| No pop-up clutter | **Yes** | Toast delivery defaults to `off`; sounds are independently configurable; active-tab notifications are suppressed. [Notifications](https://herdr.dev/docs/configuration/#notifications), [Config reference](https://herdr.dev/docs/config-reference/) |
| Agent-state dashboard | **Yes** | Herdr detects agents and distinguishes blocked, working, done, idle, and unknown; official integrations improve semantic accuracy and enable native session restore. [Agents](https://herdr.dev/docs/agents/), [Integrations](https://herdr.dev/docs/integrations/) |
| Git worktree workflow | **Yes** | Herdr can create/open/group/remove worktree checkouts from workspace rows with dirty-tree safeguards. [Worktrees](https://herdr.dev/docs/configuration/#worktrees) |
| Ordinary remote use over SSH | **Yes** | SSH to a host and run Herdr there, exactly like the common tmux path. [How to work](https://herdr.dev/docs/how-to-work/#remote-work-through-normal-ssh) |
| Local thin client attached to remote Herdr | **Yes** | `herdr --remote host` uses SSH, can preserve local keybindings, and bridges local image clipboard paste. Remote hosts are Linux/macOS x86_64 or aarch64. [Remote attach](https://herdr.dev/docs/persistence-remote/#remote-attach-over-ssh) |
| Multi-client attach | **Partial** | The server supports attached clients and read-only terminal observers; one writable direct-attach controller owns input/resize for a terminal at a time. [Direct terminal attach](https://herdr.dev/docs/persistence-remote/#direct-terminal-attach) |
| tmux-style collaborative shared-session semantics | **Unknown** | Multiple client paths exist, but first-party docs do not promise tmux-equivalent simultaneous collaborative control, per-client view policies, or multi-user socket permission workflows. |
| CLI scripting and structured API | **Yes** | CLI commands generally return JSON and use the same local socket API available to agents and integrations. [CLI reference](https://herdr.dev/docs/cli-reference/), [Socket API](https://herdr.dev/docs/socket-api/) |
| Custom commands bound to keys | **Yes** | Commands can open a popup, a pane, or run detached, with active workspace/tab/pane/cwd context in environment variables. [Custom command bindings](https://herdr.dev/docs/configuration/#custom-command-keybindings) |
| Plugins and event hooks | **Yes** | Plugin v1 supports manifest-declared actions, event hooks, panes, and link handlers; any executable language may be used. [Plugins](https://herdr.dev/docs/plugins/) |
| Native plugin-rendered non-terminal UI and dynamic action registration | **No** | Explicitly not part of plugin v1; plugin surfaces are manifest-declared. [Plugins](https://herdr.dev/docs/plugins/) |
| Synchronized input/broadcast to several panes | **Unknown** | No first-party user-facing equivalent to tmux `synchronize-panes` was found. |
| Link/mirror one tab into several workspaces/sessions | **Unknown** | No first-party equivalent to tmux linked windows was found. |
| Run Herdr nested | **Partial** | Nested launch is an experimental, disabled-by-default option; ordinary nesting is not the default design. [Config reference](https://herdr.dev/docs/config-reference/) |

## A plausible low-clutter Herdr posture

Herdr does not require an always-expanded dashboard. The documented controls can produce a substantially quieter screen:

```toml
[theme]
name = "catppuccin"

[ui]
sidebar_collapsed_mode = "hidden"
pane_borders = true
pane_gaps = false
hide_tab_bar_when_single_tab = true

[ui.toast]
delivery = "off"

[ui.sound]
enabled = false
```

Use `prefix+b` to collapse the sidebar. The current `master` branch has a post-v0.7.4 change for configuring collapsed-sidebar startup state, but that was **not** part of the stable v0.7.4 config checked here, so it should not be assumed until released. The stable, searchable source of defaults is the [v0.7.4 config reference](https://herdr.dev/docs/config-reference/).

Two reservations remain:

1. `hidden` applies to the collapsed presentation; stable v0.7.4 does not document a start-collapsed setting, so a manual `prefix+b` toggle may still be needed after attach.
2. The final visual result depends on terminal width, the number of tabs, borders, and the user's exact workspace/agent layout; it requires a live screenshot/manual trial.

## Advantages over a conventional tmux setup

1. **Agent state is a first-class model.** Workspaces roll up blocked/working/done/idle state, and integrations can report semantic lifecycle and resume native agent sessions. This is the main product difference, not merely a theme or status-script change. [Agents](https://herdr.dev/docs/agents/)
2. **Higher-level organization.** Workspaces sit above tabs and panes and are designed around repos/tasks, including grouped Git worktrees. [Concepts](https://herdr.dev/docs/concepts/), [Worktrees](https://herdr.dev/docs/configuration/#worktrees)
3. **Mouse and keyboard are both first class.** It retains tmux-like prefix behavior but adds direct clicking, border dragging, menus, and selection. [Quick start](https://herdr.dev/docs/quick-start/)
4. **Structured automation.** JSON CLI/socket APIs expose tabs, panes, workspaces, layouts, agents, notifications, and terminal attach; plugins build on that same surface. [CLI reference](https://herdr.dev/docs/cli-reference/), [Socket API](https://herdr.dev/docs/socket-api/)
5. **Remote thin-client path.** In addition to ordinary SSH, Herdr can attach from a local client while retaining local bindings and bridging image clipboard paste. [Remote attach](https://herdr.dev/docs/persistence-remote/#remote-attach-over-ssh)
6. **Modern transient panes.** Popup terminal commands can run without disturbing the tiled layout. [v0.7.4 release notes](https://github.com/ogulcancelik/herdr/releases/tag/v0.7.4)
7. **Easy trial and rollback.** It is one terminal program, supports macOS/Linux binaries plus Homebrew/mise/Nix, and can even run inside tmux while evaluating it. [Install](https://herdr.dev/docs/install/), [official README](https://github.com/ogulcancelik/herdr#lives-in-your-terminal)

## Drawbacks and migration risks

1. **Pre-1.0 and fast moving.** Stable is only v0.7.4, and the release notes show frequent behavioral fixes around keys, mouse input, attach, agent detection, Windows, and process handling. That is healthy activity but also evidence of a young compatibility surface. [Releases](https://github.com/ogulcancelik/herdr/releases)
2. **Server restart is not tmux-style live continuity.** A stopped/restarted Herdr server loses arbitrary processes; snapshot restore recreates shells and layout. Experimental live handoff is opt-in and best effort. [Session state](https://herdr.dev/docs/session-state/)
3. **Screen-history persistence has a security trade-off.** It is off by default because persisted pane contents may contain secrets, tokens, prompts, and command output. [Pane screen history](https://herdr.dev/docs/session-state/#pane-screen-history-replay)
4. **Agent restore is selective.** Only supported agents with current official integrations and valid native session references resume conversations; everything else restores as a shell. [Native agent restore](https://herdr.dev/docs/session-state/#native-agent-session-restore)
5. **Plugin trust is broad.** Plugins run as the user with the user's environment and full CLI access. Herdr validates manifests but does not review or sandbox plugin code. [Plugin trust and security](https://herdr.dev/docs/plugins/#trust-and-security)
6. **Plugin v1 has explicit gaps.** No runtime action registration, native non-terminal plugin UI, managed plugin storage API, or dedicated plugin update command exists. [Plugins](https://herdr.dev/docs/plugins/)
7. **Windows is not production-equivalent.** Native Windows is preview-only beta, and native `herdr --remote` is not included there. Stable binaries target Linux and macOS. [Install requirements](https://herdr.dev/docs/install/#requirements), [Windows beta](https://herdr.dev/docs/windows-beta/)
8. **Keyboard fidelity depends on the outer terminal.** Direct chords can be consumed by macOS/Linux/terminal defaults, and older terminals have known duplicate key-event problems. [Keyboard](https://herdr.dev/docs/keyboard/#going-prefix-free), [Troubleshooting](https://herdr.dev/docs/troubleshooting/)
9. **No performance conclusion is justified yet.** The project calls itself a lightweight single Rust binary, but no official tmux-vs-Herdr benchmark, steady-state RAM/CPU budget, or large-session scaling limit was found. Treat “lighter/faster than tmux” as **unverified**, not an advantage. [Official README](https://github.com/ogulcancelik/herdr)
10. **Licensing differs from tmux.** Herdr is AGPL-3.0-or-later with commercial licensing available, rather than tmux's permissive ISC license. Organizations distributing modifications or providing it as a network service should review obligations. [Herdr license](https://github.com/ogulcancelik/herdr/blob/v0.7.4/LICENSE), [README licensing statement](https://github.com/ogulcancelik/herdr#license)
11. **Privacy is local-first but not fully documented.** The product says there is no account or hosted control plane, and remote access uses OpenSSH. However, no explicit first-party telemetry/privacy policy was found, so “zero telemetry” is **unverified**. Update checks and remote bootstrap can contact Herdr's release endpoints. [Official comparison](https://herdr.dev/compare/), [Install/update](https://herdr.dev/docs/install/#update), [Remote attach](https://herdr.dev/docs/persistence-remote/#remote-attach-over-ssh)

## Security and privacy posture

- Core local operation has no documented login/account requirement or hosted dashboard. [How to work](https://herdr.dev/docs/how-to-work/)
- Remote attach uses normal OpenSSH authentication and can use the user's SSH config; it may create a private temporary SSH config and per-attach control socket unless disabled. [Remote attach](https://herdr.dev/docs/persistence-remote/#remote-attach-over-ssh)
- Remote bootstrap may offer to install Herdr into `~/.local/bin`; non-interactive runs fail instead of modifying the host. [Remote attach](https://herdr.dev/docs/persistence-remote/#remote-attach-over-ssh)
- Session shape is stored, and experimental pane-history persistence stores terminal content separately. The config/session directory should be treated like shell history. [Session state](https://herdr.dev/docs/session-state/)
- Local socket APIs and plugins are powerful control surfaces. The official docs emphasize plugin vetting and lack of sandboxing. [Plugin trust](https://herdr.dev/docs/plugins/#trust-and-security)

## Current status and platform/install facts

- Latest stable checked: [v0.7.4](https://github.com/ogulcancelik/herdr/releases/tag/v0.7.4), published 2026-07-15.
- Stable targets: Linux and macOS on x86_64/aarch64; Windows is preview beta. [Install](https://herdr.dev/docs/install/)
- Install paths: official shell installer, Homebrew, mise, Nix, or release binary. Package-manager installs must be updated through their package manager. [Install](https://herdr.dev/docs/install/)
- Source license: `AGPL-3.0-or-later`; commercial licensing is offered. [Cargo manifest](https://github.com/ogulcancelik/herdr/blob/v0.7.4/Cargo.toml), [README](https://github.com/ogulcancelik/herdr#license)
- The project is active and unarchived, but version `0.x` means interface/config churn remains a practical risk.

## Unknowns that a local trial must answer

These should be treated as acceptance tests, not assumptions:

1. Can the existing Neovim pane-navigation mappings cross a Neovim edge into a Herdr pane and return without a prefix or manual mode switch?
2. Can the stable release start with the sidebar in the exact desired collapsed state, or is one `prefix+b` toggle needed per attach?
3. Does compact mode remain visually quiet with the user's real set of workspaces and agents?
4. Do Ghostty/macOS key encodings preserve every current direct navigation chord?
5. Are copy mode, mouse selection, system clipboard, and long scrollback behavior equivalent enough for daily use?
6. Are any current tmux features dependent on unsupported/undocumented functions such as synchronized input, linked windows, shared paste buffers, custom format strings, or multi-user session sharing?
7. What are measured Herdr server/client RAM and idle CPU under the user's representative pane/agent count?

## Recommended trial boundary

Run Herdr **inside the existing tmux setup first**, in one non-critical project. Do not migrate session startup or remove tmux config yet. The trial should stop only after:

- the existing tmux and Neovim feature inventory is mapped against the matrix above;
- a minimal Herdr config reproduces pane/tab navigation and acceptable visual simplicity;
- detach/reattach and one ordinary SSH workflow pass;
- clipboard/copy/search/scrollback pass;
- resource usage is measured with a representative number of panes;
- every `Unknown` needed by the user's daily workflow is either demonstrated or kept as a documented blocker.

## Primary sources consulted

- [Official Herdr documentation](https://herdr.dev/docs/)
- [Official Herdr repository and README](https://github.com/ogulcancelik/herdr)
- [v0.7.4 release notes](https://github.com/ogulcancelik/herdr/releases/tag/v0.7.4)
- [Concepts](https://herdr.dev/docs/concepts/)
- [Keyboard and copy mode](https://herdr.dev/docs/keyboard/)
- [Configuration and config reference](https://herdr.dev/docs/configuration/)
- [Session state and restore](https://herdr.dev/docs/session-state/)
- [Persistence and remote access](https://herdr.dev/docs/persistence-remote/)
- [CLI reference](https://herdr.dev/docs/cli-reference/)
- [Socket API](https://herdr.dev/docs/socket-api/)
- [Plugins](https://herdr.dev/docs/plugins/)
- [Integrations](https://herdr.dev/docs/integrations/)
- [Install and platform requirements](https://herdr.dev/docs/install/)
- [Troubleshooting](https://herdr.dev/docs/troubleshooting/)
