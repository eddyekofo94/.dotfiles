# tmux → Herdr binding coverage audit

Companion to [`tmux-to-herdr.md`](tmux-to-herdr.md). That document argues the
migration family by family; this one accounts for every individual `bind` line
in [`tmux/tmux.conf`](../../tmux/tmux.conf), so a key can no longer be missed
merely because its family was discussed.

Scope, as parsed on 2026-08-05: 211 `bind` lines — 75 root (`-n`), 68 prefix,
66 `copy-mode-vi`, 2 unbound-table entries. 143 distinct root+prefix keys. Of
those, 87 were named nowhere in the migration document. Each of the 87 is
classified below.

Sources checked for the Herdr side:

- `herdr/config.toml` — the 48 keys this machine configures.
- Herdr v0.7.5 defaults, read from `src/config/model.rs` (`prefix+h/j/k/l`,
  `prefix+v`, `prefix+minus`, `prefix+x`, `prefix+z`, `prefix+r`,
  `prefix+tab`, `prefix+shift+tab`, `prefix+[`, `prefix+1..9`, `prefix+c`,
  `prefix+p`, `prefix+n`, and the workspace/worktree set).
- The action list in `src/app/input/navigate.rs`, which bounds what any
  binding can be pointed at.

Status values: **COVERED** (a Herdr key or native surface does the same job),
**RETIRED** (deliberately dropped, with the decision recorded), **UNMAPPED**
(no Herdr equivalent exists today).

## COVERED

| tmux keys | tmux behavior | Herdr equivalent |
| --- | --- | --- |
| prefix `1` `3` `4` `5` `6` `8` `9`; root `M-1`…`M-9` | select or create numbered window | `prefix+0..9` custom commands (focus or create tab N) |
| prefix `j` `k` `l` | `select-pane -D/-U/-R` | native `prefix+j/k/l`, plus `alt+j/k/l` smart-nav |
| root `M-Up` `M-Down` `M-Left` `M-Right` | directional focus with Vim forwarding | `alt+h/j/k/l` smart-nav (arrow aliases retired) |
| prefix `C-n` | new window at cwd | `alt+ctrl+n` cwd-following tab; native `prefix+c` |
| prefix `C-s` `C-v` | stacked / side-by-side split | `alt+s`, `alt+v`; native `prefix+minus`, `prefix+v` |
| prefix `C-o` | `kill-pane -a` | `prefix+o` confirm close all sibling panes |
| prefix `C-x` | kill all other windows | `alt+ctrl+x` close other tabs |
| prefix `_`; root `M-^` | first window | `prefix+^` focus first tab |
| root `M-$` | last window | `prefix+$` focus last tab |
| root `M-w` `M-W` | `select-pane -t :.+/-` | native `prefix+tab` / `prefix+shift+tab` |
| root `M-p`; prefix `C-6` `C-^` | last pane / last client | `prefix+Tab` last-pane navigation |
| root `M-Tab` | last window | `alt+tab` focus previous tab, via the tab-history plugin; Herdr claims the chord globally, so it never reaches a pane app |
| root `M-r` `M-R` | `swap-pane -D/-U` | `prefix+shift+h/j/k/l` directional swap |
| prefix `+` `,` `.` `>`; root `M--` `M-+` `M-<` `M->` `M-,` | incremental resize chords | native `prefix+r` resize mode; `alt+=` / `prefix+=` equalize |
| prefix `J` | `join-pane` from another window | `prefix+shift+p` send or receive a pane |
| prefix `PageUp`; root `M-Escape` `C-M-Escape` | enter copy mode | native `prefix+[`, plus the configured aliases |
| prefix `Escape` `C-a` | send literal Escape / prefix | native double-prefix sends the literal key |
| root `MouseDrag1Pane` `WheelUpPane` `MouseDown1StatusRight` | mouse selection, scroll, status click | native Herdr mouse UI (user-confirmed) |
| all 66 `copy-mode-vi` binds | vi motions, search, selection, yank | native copy mode plus the private patch; see the copy-mode rows in the migration document |

## RETIRED

| tmux keys | tmux behavior | Decision |
| --- | --- | --- |
| root `M-C-h/j/k/l`, `M-C-n`, `M-C-o`, `M-C-p`, `M-C-q`, `M-C-s`, `M-C-v`, `M-C-z`, `M-C-c`, `M-C-x`, `M-C-f`, `M-C-6`, `M-C-^`, `M-C-Tab` | nested-tmux passthrough layer | Retired with the nesting model: Herdr runs unnested, so the second Ctrl-Alt tier has nothing to address |
| root `M-C-Up` `M-C-Down` | enter/exit passthrough mode | Retired; remote work uses native `herdr --remote` thin-client attach |
| root `M-t` | `select-pane -t 1` | Retired; absolute pane indices are not part of the Herdr model, which addresses panes by direction or navigator |

## UNMAPPED

| tmux keys | tmux behavior | Why nothing covers it |
| --- | --- | --- |
| prefix `:`; root `M-:` `C-M-:` | `command-prompt` | Herdr has no in-app command line. The socket API and `herdr` CLI are the equivalent surface, but they are not a keystroke away from the focused pane |
| prefix `}`, `C-S-PageUp`, `C-S-PageDown`; root `M-{` `M-}` `C-S-PageUp` `C-S-PageDown` | `swap-window` left/right | No tab-reordering action exists in the Herdr action list. Tabs can be created, renamed, closed, and selected, not moved |
| prefix `"` `C-r`; prefix `]` `p` | `choose-buffer`, paste from the buffer stack | Herdr copies to the system clipboard and keeps no paste-buffer stack, so there is nothing to choose from or cycle |
| prefix `)`; root `M-(` `M-)` | `switch-client -n/-p` between sessions | Herdr workspaces are not tmux sessions. Sessions are switched by `herdr session attach` from a shell, with no in-session keystroke |

`shrink-height` appears once in the parse as a binding target rather than a
key; it is a parser artifact of a multi-line `bind`, not a tmux key.

## Verdict

Nothing in the UNMAPPED set blocks daily use, and none of it was raised as a
loss during the trials. Tab reordering is the most defensible future request;
the other three are structural differences rather than gaps. Revisit if
upstream adds a tab-move action or an in-app command prompt.
