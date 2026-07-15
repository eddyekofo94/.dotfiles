# Tmux Keymaps

This document contains the keybindings for managing windows (tabs) in tmux.

## Agent Status Tabs

Catppuccin window tabs show each interactive coding agent in that window:

```text
1 codex:.dotfiles ⠋ · claude:BibleStandard 
```

Supported commands are `codex`, `claude`, `opencode`, `agy`, and legacy
`gemini`. Blue spinners mean running, orange `` means a question needs an
answer, red `` means permission or approval is required, green `` means ready
or finished, and red `` means failed. Selecting a window does not clear its
state.

Agent hook files call `tmux/scripts/agent_status.py`. Codex requires reviewing
and trusting the hook once through `/hooks`. Run `tmux/scripts/verify.sh` after
changing the renderer, adapters, or tmux configuration.

## Default Prefix

The default prefix is `C-Space` (Ctrl + Space).

---

## Windows (Tabs)

| Keybinding | Action |
|------------|--------|
| `c` | Create new window (with confirmation if not shell) |
| `N` | Create new window after current |
| `C-n` | Create new window after current |
| `M-C-n` | Create new window after current (no prefix) |
| `t` | Go to next window |
| `T` | Go to previous window |
| `0-9` | Go to window by number |
| `M-0` to `M-9` | Go to/create window 0-9 (no prefix) |
| `Tab` | Go to last used window |
| `M-Tab` | Go to last used window (no prefix) |
| `^` / `_` | Go to first window |
| `$` | Go to last window |
| `M-^` | Go to first window (no prefix) |
| `M-$` | Go to last window (no prefix) |
| `{` | Swap current window with previous |
| `}` | Swap current window with next |
| `M-{` | Swap current window with previous (no prefix) |
| `M-}` | Swap current window with next (no prefix) |
| `w` | Open window tree with fzf |
| `f` | Find window with fzf |

---

## Panes (Splits)

| Keybinding | Action |
|------------|--------|
| `n` / `s` | Split vertically |
| `v` | Split horizontally |
| `C-s` | Split vertically |
| `C-v` | Split horizontally |
| `M-n` / `M-s` | Split vertically (no prefix) |
| `M-v` | Split horizontally (no prefix) |
| `M-C-n` | Split vertically (no prefix) |
| `M-C-v` | Split horizontally (no prefix) |

### Pane Navigation

| Keybinding | Action |
|------------|--------|
| `h` | Go to pane left |
| `j` | Go to pane down |
| `k` | Go to pane up |
| `l` | Go to pane right |
| `M-h` | Go to pane left (no prefix) |
| `M-j` | Go to pane down (no prefix) |
| `M-k` | Go to pane up (no prefix) |
| `M-l` | Go to pane right (no prefix) |
| `M-p` | Go to last pane |
| `M-t` | Go to first pane |

### Pane Management

| Keybinding | Action |
|------------|--------|
| `o` / `C-o` | Kill all panes except current |
| `M-o` | Kill all panes except current (no prefix) |
| `M-q` | Close pane (no prefix) |
| `z` | Toggle pane zoom |
| `O` | Toggle pane zoom |
| `M-z` | Toggle pane zoom (no prefix) |
| `=` | Tile all panes |
| `M-=` | Tile all panes (no prefix) |
| `r` | Swap with next pane |
| `R` | Swap with previous pane |

---

## Copy Mode

| Keybinding | Action |
|------------|--------|
| `[` | Enter copy mode |
| `M-Escape` | Enter copy mode (no prefix) |
| `PageUp` | Enter copy mode and scroll up |

### Within Copy Mode

| Keybinding | Action |
|------------|--------|
| `v` | Begin selection |
| `C-v` | Begin rectangle selection |
| `y` | Copy selection |
| `M-t` | Go to first pane |
| `M-w` | Go to next pane |
| `M-W` | Go to previous pane |
| `M-n` | Split vertically |
| `M-v` | Split horizontally |
| `M-p` | Go to last pane |
| `M-z` | Toggle zoom |
| `M-{` | Swap with previous window |
| `M-}` | Swap with next window |

---

## Sessions

| Keybinding | Action |
|------------|--------|
| `)` | Switch to next session |
| `(` | Switch to previous session |
| `M-)` | Switch to next session (no prefix) |
| `M-(` | Switch to previous session (no prefix) |
| `C-^` / `C-6` | Switch to last session |
| `x` | Attach another session and kill current |
| `w` | Open window tree menu |

---

## Other Useful Bindings

| Keybinding | Action |
|------------|--------|
| `C-r` | Choose buffer |
| `Space` | Display layout menu |
| `:` | Command prompt |
| `M-:` | Command prompt (no prefix) |
