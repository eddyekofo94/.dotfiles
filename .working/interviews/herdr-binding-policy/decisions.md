# Herdr Binding Policy

## Goal

Settle one conflict-free, QWERTY- and Vim-oriented prototype binding policy for Herdr, including exact pane-close safety behavior, so the isolated swap/resize/move/close validation gate can test intended behavior rather than provisional mappings.

## Exit Criteria

Decision-only and implementation-ready: every in-scope action has one approved primary chord (or an explicit decision to leave it unbound), all collisions are resolved, and close confirmation behavior is exact enough to validate deterministically.

## Scope / Non-goals

In scope: pane swaps, resize mode, horizontal/vertical or adaptive splits, pane/tab close, new/next/previous tab, zoom, sidebar visibility/toggle, copy/search entry, and smart-close/process safety. `Ctrl-a` and physical `Alt-h/j/k/l` navigation are settled constraints.

Non-goals: production configuration, Fish auto-attach, image-preview parity, migration execution or authorization, and unrelated bindings.

## Decisions

- Herdr should present with its sidebar hidden/collapsed by default, while retaining an explicit toggle binding.
- `prefix+b` and `prefix+B` remain reserved for ready-prompt replay and clear-then-replay; the sidebar toggle must not use either chord.
- For stable v0.7.4 trials, one manual sidebar toggle after a fresh start is acceptable. Do not add startup key injection; automatic hidden startup waits for an official release exposing the upstream startup-state option.
- Toggle the sidebar with `prefix+S`. This is mnemonic, free in Herdr's defaults, preserves ready-prompt `prefix+b/B`, and intentionally displaces tmux's prompt-based `prefix+S` send-pane chord.
- Swap panes spatially with `prefix+H/J/K/L`. Lowercase `h/j/k/l` moves focus; uppercase moves the focused pane in the same direction. This adopts Herdr's native mapping and replaces tmux's `r/R` next/previous swap model.
- Enter resize mode with `prefix+r`, then resize spatially with `h/j/k/l`. Use Herdr's native modal behavior and do not carry forward tmux's direct punctuation resize aliases.
- Use `prefix+v` for a fixed side-by-side Herdr split and `prefix+a` for an adaptive Herdr split that chooses right or down from the focused pane's shape using the `focus.split_nicely()` golden-ratio idea. `prefix+n` remains next-tab; shell `Alt-n` remains the fast adaptive split.
- Preserve application ownership for direct Alt splits. In ordinary shell panes, `Alt-v` requests a fixed right Herdr split and `Alt-n` requests the adaptive Herdr split. Neovim keeps its current mappings unchanged: `Alt-v` remains its vertical split, `Alt-n` remains its new horizontal window, and `leader+vv` remains the existing `focus.split_nicely()` action. fzf-lua retains its existing `Alt-v` actions.
- `prefix+s` is the chosen mnemonic for terminal copy/search entry, with backward search as the desired first action because terminal review normally looks into older output.
- For stable v0.7.4, accept `prefix+s` to enter copy mode followed by `?` to open backward search. Track true one-chord backward-search entry as an upstream usability request rather than adding key-sequence injection or a source patch.
- The upstream request was filed through Herdr's required Ideas discussion route as [Discussion #1503](https://github.com/ogulcancelik/herdr/discussions/1503), requesting a configurable action that enters copy mode directly in backward-search prompt state.
- Preserve tmux's `prefix+u` intent: from normal mode, find the newest URL visible in the focused pane and open it without entering copy mode. Implement later as a prototype-local Herdr pane-read helper; it is not native v0.7.4 behavior.
- Preserve exact `prefix+u` scope: inspect only the focused pane's visible content and open its newest well-formed HTTP(S) URL. Do not search older scrollback implicitly.
- Implement custom behavior in the Herdr-native style during the prototype phase: use focused-pane identity/read APIs and supported custom commands, fail closed with a clear no-URL result, and avoid tmux emulation, terminal key injection, or production configuration changes.
- Close a pane with `prefix+x` using the existing smart-close policy implemented through Herdr APIs: close immediately only when more than one pane exists and the focused pane is at a bare shell; confirm for a non-shell foreground process/TUI and for the last pane.
- Add application-aware lowercase `Alt-x`: Neovim retains its existing “exchange current window with next one” mapping; ordinary shell panes invoke the Herdr smart-close policy. Do not register `Alt-x` as a global Herdr binding that preempts pane applications.
- Close the active tab immediately with `prefix+X`, preserving tmux semantics even when the tab contains multiple panes or running processes. Application-aware uppercase `Alt-X` does the same from ordinary shell panes and passes through to Neovim/TUIs. The separately destructive “close all other tabs” action remains confirmation-protected and is outside this validation gate.
- Use Herdr's native tab model: `prefix+c` creates a new tab, `prefix+n` selects the next tab, and `prefix+p` selects the previous tab. Do not carry the old primary `prefix+N/t/T` model into the prototype binding table.
- Toggle Herdr zoom with `prefix+z`. Use application-aware `Alt-z`: Neovim retains its existing preview-window close mapping, while ordinary shell panes toggle Herdr zoom.
- Accept Herdr's native full accent outline around a zoomed pane as sufficient zoom-state feedback. Do not add a custom zoom badge or label.
- Keep `Ctrl-a` as the Herdr prefix. Do not adopt `Ctrl-Space`; preserve its one-press Neovim blink-cmp completion/documentation action and Fish `gss` fzf selection toggle.

## Evidence / Findings

- The prototype already sets `ui.sidebar_collapsed_mode = "hidden"`, which controls what the collapsed state looks like, and binds the toggle to `prefix+shift+b`.
- Stable Herdr v0.7.4 does not document a configuration key for initial collapsed state. The existing research records a post-v0.7.4 master change for configurable collapsed startup, so stable v0.7.4 cannot yet guarantee hidden-at-start through configuration alone.
- The migration tracker reserves `prefix+b/B` for the ready-prompt port and explicitly requires moving the sidebar toggle.
- Existing dirty migration/prototype/image-preview files predate this interview and are user-owned; this interview does not modify them.
- Current tmux binds `prefix+n/s` and guarded direct `Alt-n/s` to a stacked split, and `prefix+v` plus guarded direct `Alt-v` to a side-by-side split. Direct Alt chords are forwarded when Vim/Neovim or copy mode owns the pane.
- Neovim currently owns `Alt-v` as a vertical split and `Alt-n` as a new horizontal window. fzf-lua also owns `Alt-v` for opening selections in vertical splits.
- `focus.split_nicely()` chooses `vsplit` when the focused window is wider than a golden-ratio threshold and otherwise chooses a stacked `split`; it is an adaptive orientation policy, not merely an equal-sizing command.
- Herdr v0.7.4 exposes current-pane layout plus `pane split --direction right|down --ratio`, so a prototype-local adaptive split helper can reproduce the same basic orientation choice at the Herdr pane layer.
- Exit-criteria audit found and resolved a direct collision: adaptive split moved from `prefix+n` to mnemonic `prefix+a`, preserving `prefix+n/p` for next/previous tab.
- Stable v0.7.4 exposes one configurable `copy_mode` action. Inside copy mode, `?` opens backward search and `/` opens forward search. Its configuration parser accepts one action per binding, and the socket API exposes no copy-mode/search action, so `prefix+s` cannot enter copy mode and immediately open backward search through supported configuration or API.
- Herdr issue #1230 added `/` and `?` search inside copy mode, but no existing issue/discussion found in the checked search requests a configurable top-level action that enters copy mode directly in backward-search prompt state.
- The Herdr repository disables blank issues and explicitly routes feature requests, ideas, and behavior changes to GitHub Discussions.
- Current tmux `prefix+u` captures the visible pane, extracts the bottom-most well-formed HTTP(S) URL, opens it, and reports when none exists. Herdr provides `pane read --source visible`, so the same behavior is feasible without production tmux integration.
- In Herdr v0.7.4, zooming a tab that contains multiple panes renders only the focused pane across the full pane area and deliberately keeps `Borders::ALL`. Because the pane is focused, the border renderer uses the accent color. A single-pane tab has no pane border, and no separate built-in zoom badge or `ZOOM` label was found.
- Effective tmux does not currently bind lowercase `Alt-x` to pane close: guarded `Alt-c/q` smart-close panes, while guarded uppercase `Alt-X` closes a tab. Neovim owns lowercase `Alt-x` as “exchange current window with next one.”
- `Ctrl-Space` is available at the macOS/Ghostty transport layers on this Mac: macOS input-source hotkeys 60/61 are disabled, and Ghostty explicitly unbinds its own `ctrl+space` action so the chord reaches terminal applications. Herdr v0.7.4 parses `ctrl+space` as a valid prefix.
- `Ctrl-Space` is not unused inside applications. Neovim blink-cmp binds it (and its `Ctrl-@` encoding fallback) to show/hide completion and documentation. The Fish `gss` fzf workflow binds it to toggle selected files. Herdr owns its prefix before pane applications, so those actions would require the prefix-twice literal-send path or later remapping.

## Tradeoffs / Risks

- On stable v0.7.4, `hidden` is a collapsed presentation mode, not a proven start-collapsed setting. The accepted temporary cost is one manual toggle per fresh session.
- The tmux prompt-based send-pane action loses its `prefix+S` chord. Pane movement should use Herdr's navigator/API rather than compete with the sidebar mnemonic.
- Binding `Alt-v/n` directly in Herdr would consume those chords before Neovim/fzf. Preserving current ownership requires the same application-first adapter principle as settled `Alt-h/j/k/l`: Neovim/fzf retain their mappings, while ordinary shell panes invoke Herdr split behavior.
- A true one-chord backward-search entry would require an upstream Herdr action or a Herdr source patch. Terminal/Ghostty key-sequence injection would be brittle and violates the production-config boundary.
- A direct global Herdr `Alt-x` binding would preempt Neovim's existing window-exchange mapping. If adopted, it should use application-first ownership: Neovim keeps `Alt-x`; ordinary shell panes invoke Herdr smart-close.

- Changing the prefix to `Ctrl-Space` improves reach but trades away one-press Neovim completion and `gss` selection toggling. Remapping those production application bindings is outside this interview's non-goals.

## Validation Plan

- Validate proposed keys against Herdr v0.7.4 defaults and the isolated prototype configuration.
- Audit collisions against effective tmux mappings, ready-prompt `b/B`, Neovim/Vim, Fish, fzf, Ghostty, and macOS ownership.
- Run `./herdr/prototype/verify.sh` after any later prototype-only implementation.
- In an isolated scratch Herdr session, capture deterministic before/after layout, pane identity, dimensions, and sentinel-process liveness for swap, resize, move, and close.
- Verify `prefix+u` against visible-pane fixtures containing zero, one, and multiple HTTP(S) URLs; prove it opens only the newest visible match and fails closed when none exists.
- Verify application-aware Alt chords in both ordinary shell panes and real Neovim/fzf ownership paths without editing production Neovim, Fish, Ghostty, or tmux configuration.
- Keep subjective feel awaiting explicit user confirmation.

## Ready To Act

The binding policy is conflict-free and implementation-ready for an isolated prototype pass. Implement only under `herdr/prototype/`, then run the validation plan and update the migration tracker with evidence actually produced.

### Approved Prototype Binding Table

| Action | Approved binding / behavior |
| --- | --- |
| Prefix | `Ctrl-a` |
| Focus panes | application-aware `Alt-h/j/k/l`; `prefix+h/j/k/l` |
| Swap panes | `prefix+H/J/K/L` |
| Resize panes | `prefix+r`, then `h/j/k/l` |
| Fixed right split | `prefix+v`; application-aware `Alt-v` |
| Adaptive split | `prefix+a`; application-aware shell `Alt-n`; Neovim remains unchanged |
| Copy/search mode | `prefix+s`; then `?` for backward search on v0.7.4 |
| Close pane | smart-close `prefix+x`; application-aware `Alt-x` |
| Close tab | immediate `prefix+X`; application-aware `Alt-X` |
| New / next / previous tab | `prefix+c` / `prefix+n` / `prefix+p` |
| Zoom | `prefix+z`; application-aware `Alt-z`; native accent outline is sufficient |
| Sidebar | `prefix+S`; one manual collapse after fresh v0.7.4 start is accepted |
| Ready prompt replay | reserve `prefix+b/B` |
| Open newest visible URL | `prefix+u`, using Herdr focused-pane/read APIs |

## Open Questions

None for this binding-policy scope.
