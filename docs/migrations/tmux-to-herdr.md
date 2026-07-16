# tmux to Herdr migration tracker

This is the durable source of truth for evaluating and, only after explicit
approval, migrating from tmux to Herdr. The current tmux configuration remains
the production baseline. A Herdr item is checked only after the stated evidence
exists; visual feel and daily-workflow equivalence require user confirmation.

Primary research: [`../research/herdr-primary-sources.md`](../research/herdr-primary-sources.md)
Prototype: [`../../herdr/prototype/README.md`](../../herdr/prototype/README.md)

## Status legend

- [x] Verified in the prototype or explicitly approved by the user.
- [ ] Not yet verified.
- **PARTIAL**: usable only with a port or accepted behavior change.
- **BLOCKED**: no acceptable Herdr path is known.
- **AWAITING USER**: automation passed; subjective approval remains.

## Migration gate

Do not replace fish auto-start, remove tmux, or retire the tmux configuration
until every **Required** row is checked or the user explicitly accepts its
documented difference. Prototype evidence must include commands/readback;
appearance and interaction feel must include screenshots and user approval.

## Core behavior checklist

| Required | tmux behavior to preserve | Current implementation | Proposed Herdr path | Status / evidence |
| :---: | --- | --- | --- | --- |
| Yes | Detach and reattach without stopping processes | tmux server/client | Herdr named session | [x] Counter advanced while the client was detached; the same server PID and output survived reattach. |
| Yes | Multiple isolated sessions/projects | tmux sessions | Herdr sessions plus workspaces | [ ] |
| Yes | New panes/tabs follow current cwd | `-c '#{pane_current_path}'` | `terminal.new_cwd = "follow"` | [x] New right/down panes both reported the repository cwd. |
| Yes | Side-by-side and stacked splits | `prefix+v`, `prefix+n/s` | matching Herdr split bindings | [x] Right and down splits created the expected three-pane layout. |
| Yes | Directional pane navigation | `prefix+h/j/k/l`, guarded Alt bindings | Herdr focus actions plus Neovim adapter | [x] Prefix focus and CLI neighbor/focus readback passed. |
| Yes | Neovim split-to-outer-pane handoff | `lua/plugin/tmux.lua` and tmux TUI guards | prototype `smart_nav.sh` plus `herdr_nav.lua` | [ ] Direct smart binding passed: the same `Alt-l` moved between real Neovim windows and then handed the edge to Herdr in about 0.01s per invocation. **AWAITING USER physical feel** |
| Yes | Pane zoom | `prefix+O`, `Alt-z` | Herdr zoom binding/API | [x] CLI readback changed `false -> true -> false`. |
| Yes | Swap, resize, move, and close panes | tmux commands and smart-close policy | native API plus custom commands | [ ] **PARTIAL** |
| Yes | Tabs: create, next/previous, indexed, last, reorder, close | tmux window bindings | Herdr tabs and CLI | [ ] **PARTIAL for close-others/reorder aliases** |
| Yes | Searchable session/window/pane picker | custom `choose-tree`, fzf picker | Herdr navigator | [ ] The real Fish `fe` picker now runs in the direct trial; Herdr's own navigator remains a separate parity question. **AWAITING USER** |
| Yes | Vi copy mode, search, selection, clipboard | tmux copy-mode-vi | Herdr copy mode | [x] Searched `HERDR_COPY_SENTINEL`, selected with `v/e`, yanked, and `pbpaste` matched exactly. |
| Yes | Mouse focus, resize, scrolling, selection | `mouse on` and copy-mode routing | native Herdr mouse UI | [x] User confirmed all remaining direct-trial behavior worked after separately identifying navigation and image-preview failures. |
| Yes | Long scrollback | `history-limit 65536` | byte-based `advanced.scrollback_limit_bytes` | [x] 250 generated lines remained readable; byte-vs-line depth remains a migration difference. |
| Yes | Clean, simple Catppuccin screen | one top tmux status row | hidden collapsed sidebar, no gaps/toasts/sounds | [x] User confirmed the focused-only boxed direct layout works; focused border remains accented while inactive borders blend into `#1e1e2e`. |
| Yes | Ghostty key fidelity and true color | extkeys/RGB/undercurl settings | Herdr terminal renderer | [ ] |
| Yes | Kitty/chafa image previews | tmux DCS passthrough | experimental Herdr Kitty graphics | [ ] **BLOCKED:** real fzf preview was initially hidden; after revealing it the memory-transfer preview stayed blank, and forced Kitty stream transfer produced an invalid host-wide black placement in Ghostty. |
| Yes | Codex, Claude, OpenCode, AGY, Gemini visibility | native hooks plus tmux status engine | Herdr detection/integrations | [x] Codex detected and tracked `idle -> working -> idle`; other agents remain a later compatibility round. |
| Yes | Distinguish running, question, approval, finished, failure | custom semantic icons/colors | Herdr semantic state plus metadata | [ ] Working/idle passed for Codex. **PARTIAL:** approval/question collapse to blocked; no distinct failure state. |
| Yes | Ready-prompt paste and clear-then-paste | `ready_prompt.sh`, `prefix+b/B` | port to pane read/send/wait APIs | [ ] **PARTIAL: not in first prototype** |
| Yes | Fish login attach without nesting loops | `fish/config.fish` tmux block | guarded Herdr launcher | [ ] **deferred until approval** |
| No | Ordinary SSH and remote attach | remote tmux | remote Herdr/thin client | [ ] |
| No | Resurrect/Continuum-style recovery | TPM plugins | snapshot plus native agent resume | [ ] **PARTIAL for arbitrary processes** |
| No | Scratch shell and lazygit popups | `display-popup` | custom popup commands | [ ] |
| No | Golden-ratio pane focus | tmux focus hook | `pane.focused` plugin hook plus resize/layout API | [ ] **FEASIBLE, NOT PROTOTYPED:** v0.7.4 exposes the required focus event and directional fractional resize, but no built-in Focus.nvim-style policy. |
| No | URL search/open shortcuts | capture/copy scripts | pane-read custom commands | [ ] **PARTIAL** |
| No | Nested multiplexer passthrough | tmux key-table toggle | remote Herdr or experimental nesting | [ ] **PARTIAL** |

## Effective keybinding migration

The source of truth is `tmux/tmux.conf`, not the older README table. The
effective tmux prefix entry is `Ctrl-a` (`prefix` itself is `None`, with
`Ctrl-a` switching to the prefix table).

| Current key | Current action | Herdr target | Status |
| --- | --- | --- | --- |
| `Ctrl-a` | Enter prefix table | `keys.prefix = "ctrl+a"` | [x] |
| `prefix+h/j/k/l` | Focus pane direction | same | [x] |
| `Alt-h/j/k/l` | Smart TUI/Neovim-or-pane navigation | direct prototype shell binding inspects the foreground process, forwards to Neovim, or focuses Herdr | [ ] Objective path passed (`left Neovim window -> right Neovim window -> right Herdr pane`) at about 0.01s per helper call; physical feel awaits user approval. |
| `prefix+n`, `prefix+s` | Split down | same | [x] |
| `prefix+v` | Split right | same | [x] |
| `Alt-n/s/v` | Split unless forwarded to Vim/TUI | conditional command/plugin needed | [ ] **PARTIAL** |
| `prefix+c`, `Alt-c/q` | Smart close pane | `prefix+c`; process-sensitive helper later | [ ] **PARTIAL** |
| `prefix+N`, `prefix+Ctrl-n`, `Alt-Ctrl-n` | New tab after current | Herdr new-tab aliases | [x] Prefix aliases configured; direct Alt alias not carried over. |
| `prefix+t/T` | Next/previous tab | same | [x] |
| `Alt-0..9`, `prefix+0..9` | Select/create numbered tab | indexed tab jump; create-on-miss needs helper | [ ] **PARTIAL** |
| `prefix+Tab`, `Alt-Tab` | Last tab | Herdr last-pane/tab behavior needs validation | [ ] |
| `prefix+{/}` | Reorder tabs | CLI/custom commands | [ ] **PARTIAL** |
| `prefix+O`, `Alt-z` | Toggle zoom | Herdr zoom | [x] Prefix variants configured and zoom state verified; direct Alt alias deferred. |
| `prefix+r/R`, `Alt-r/R` | Swap panes | directional Herdr swap | [ ] **PARTIAL mapping** |
| `prefix+=`, `Alt-=` | Equal/tiled layout | layout apply/custom action | [ ] **PARTIAL** |
| `prefix+<,>,comma,period,-,+` | Resize by two cells | resize API/custom commands | [ ] **PARTIAL** |
| `prefix+o/Ctrl-o`, `Alt-o` | Close all other panes | custom API command | [ ] **PARTIAL** |
| `prefix+X`, `Alt-X` | Close tab | Herdr close tab | [ ] |
| `prefix+Ctrl-x`, `Alt-Ctrl-x` | Close all other tabs with confirmation | custom API command | [ ] **PARTIAL** |
| `prefix+w` | Session/window/pane tree | workspace/session navigator | [ ] **AWAITING USER** |
| `prefix+f`, `Alt-Ctrl-f` | fzf window picker | navigator or retained custom fzf | [ ] **AWAITING USER** |
| `prefix+Enter` | Scratch-shell popup | Herdr popup command | [x] Config accepted; interactive popup sizing remains visual QA. |
| `prefix+g` | Lazygit popup | Herdr popup command | [x] Config accepted; interactive popup sizing remains visual QA. |
| `prefix+[` / `PageUp` / `Alt-Escape` | Copy mode | Herdr copy mode aliases | [x] `prefix+[` and `Alt-Escape` configured; `PageUp` omitted to preserve shell/TUI behavior. |
| copy `v`, `Ctrl-v`, `y`, `Y` | select/rectangle/copy | Herdr copy mode; rectangle/Y parity unknown | [ ] **PARTIAL** |
| copy `u/d`, marks, prompt jumps | half pages, marks, OSC 133 prompts | native subset; marks/prompt jumps unverified | [ ] **PARTIAL** |
| `prefix+u`, copy `O` | Open URL | custom pane-read helper | [ ] **PARTIAL** |
| `prefix+b/B` | Ready-prompt replay / clear replay | reserved for port; move sidebar toggle elsewhere | [ ] **PARTIAL** |
| `prefix+Space` | Layout menu | custom popup/plugin action | [ ] **PARTIAL** |
| `prefix+(`/`)`, `Ctrl-^` | Session navigation/last session | workspace/session commands | [ ] **PARTIAL** |
| `Alt-Ctrl-Down/Up` | Nested tmux passthrough | avoid nesting or experimental equivalent | [ ] **PARTIAL** |

## Prototype rounds

### Round 1 — isolated local trial

- [x] Official v0.7.4 macOS arm64 binary runs from the ignored prototype runtime.
- [x] Minimal configuration loads with `Ctrl-a` prefix and Catppuccin.
- [x] Expanded and collapsed screenshots are captured.
- [x] Split creation, cwd following, focus, zoom, and tab operations pass.
- [x] Detach/reattach preserves a sentinel process and output.
- [x] Copy/search/clipboard behavior passes automated readback where possible.
- [x] Neovim crosses an editor edge into a Herdr neighbor and back.
- [x] Codex is detected and transitions `idle -> working -> idle` around a prompt.
- [x] Kitty/chafa transport is observed; rendered pixels remain a live visual gate.
- [x] Representative CPU/RAM are recorded.

### Approval gate

- [ ] User approves the collapsed and expanded visual density.
- [ ] User approves navigation feel and accepted partial differences.
- [ ] User explicitly authorizes promoting Herdr from prototype to daily driver.

### Round 2 — live Ghostty visual and interaction QA

| Gate | Current result | Approval |
| --- | --- | --- |
| Collapsed/expanded density | Boxed geometry preferred over borderless/compact, but the desired result is a full outline only around the focused pane. | [ ] **PARTIAL** |
| Neovim `Alt-h/j/k/l` feel | Rejected in the nested trial: physical keys did not switch Herdr panes because the outer tmux intercepted them. Direct Ghostty behavior remains unknown. | [ ] **BLOCKED** |
| Mouse focus, resize, scroll, and selection | No approval or rejection was reported before closeout. | [ ] **UNVERIFIED** |
| Kitty/chafa pixels | No approval or rejection: the prototype lacked the normal fzf image-preview path, so the user could not perform a representative test. | [ ] **BLOCKED** |

### Round 3 — direct focused-only Ghostty trial

The active acceptance window was launched with
`./herdr/prototype/live_ghostty.sh`. It is not nested in tmux.

| Gate | Objective evidence | Approval |
| --- | --- | --- |
| Focused-border density | Focused variant generated with `pane_gaps = true` and inactive `overlay0 = "#1e1e2e"`; direct three-pane layout is running. | [ ] **AWAITING USER** |
| Neovim `Alt-h/j/k/l` | Real config loaded; prototype map survived lazy startup; readback moved Neovim window `1000 -> 1005`, kept Herdr on `w1:p1`, then moved Herdr to `w1:p2` at the editor edge. | [ ] **AWAITING USER physical feel** |
| Mouse focus, resize, scroll, and selection | Direct three-pane layout is available for clicks, border drags, scrolling, selection, and clipboard checks. | [ ] **AWAITING USER** |
| fzf/Kitty pixels | Real `fe png` process is running with `_fzf_preview {}`; visible pane readback contains the Kitty Unicode-placeholder grid for `expanded.png`/`collapsed.png`. | [ ] **AWAITING USER pixels** |

### Round 4 — direct smart-navigation and renderer diagnosis

| Gate | Objective evidence | Approval |
| --- | --- | --- |
| Focused-border density | User reported that everything other than the named navigation and preview issues worked. | [x] **APPROVED** |
| Mouse focus, resize, scroll, and selection | Same direct-trial confirmation; no mouse exception was reported. | [x] **APPROVED** |
| Seamless `Alt-h/j/k/l` | Focused config binds direct Alt chords to `smart_nav.sh`. Foreground Neovim receives the chord through `pane send-keys`; other panes use `pane focus`. Automated `Alt-l` readback moved `1000 -> 1005 -> w1:p2`, with 0.01s helper samples. | [ ] **AWAITING USER physical feel** |
| fzf/Kitty pixels | `?` revealed the fzf preview region, proving it was initially toggled hidden. Memory transfer stayed blank. A controlled stream-transfer probe then produced a host-wide black placement instead of the selected image. | [ ] **BLOCKED / REJECTED FOR v0.7.4** |
| Golden-ratio focus | Official API exposes `pane.focused`, `pane resize --amount`, and layout snapshots. A small plugin can reapply a target ratio on focus, but nested BSP layouts need a defined restore policy. | [ ] **FEASIBLE; USER POLICY + PROTOTYPE REQUIRED** |
| Smooth scrolling | Neovim keeps its existing `neoscroll` behavior unchanged. Herdr v0.7.4 scrollback accepts an integer `mouse_scroll_lines` value and applies line-step scroll actions; no animated/pixel-eased scrollback setting exists. | [ ] **NO HERDR-LAYER EQUIVALENT** |

## Decisions and evidence log

Add dated entries here. Never replace an unverified item with a checkmark based
only on documentation or assumed API parity.

- 2026-07-16: the first isolated launch used a long session/config path and
  failed closed with `local socket name length exceeds capacity of sun_path of
  sockaddr_un`. The scratch session/config path was shortened before retrying.
- 2026-07-16: v0.7.4 `config check` returned `config: ok`. The production
  tmux config, fish auto-start, and Neovim tmux adapter were not changed.
- 2026-07-16: the working layout contained two tabs and four panes: Neovim with
  two editor windows, Codex, and two shells. Directional split/focus, cwd
  following, zoom, copy/search/clipboard, 250-line scrollback, and
  detach/reattach all passed using CLI or terminal readback.
- 2026-07-16: the temporary Neovim adapter kept `Alt-h` inside the editor when
  an editor neighbor existed, then handed edge `Alt-l` to Herdr. Outer
  `Ctrl-a h` returned to the editor pane.
- 2026-07-16: Codex state changed from `idle` to `working` and back to `idle`
  while answering `HERDR_AGENT_OK`. Detection briefly remained stale after an
  updater process exited, so terminal title/process cleanup is a compatibility
  risk worth retesting with other agents.
- 2026-07-16: `chafa -f kitty --passthrough=auto --polite=on` exited 0 with
  experimental Kitty graphics enabled. Nested tmux capture showed the reserved
  20x10 cells but cannot preserve the pixels, so Ghostty image quality is still
  awaiting live user approval.
- 2026-07-16: five representative samples with two tabs/four panes measured the
  Herdr server at 21,792 KiB RSS and 0.0-0.3% CPU, and the client at 10,976 KiB
  RSS and 0.0% CPU (about 32 MiB combined). These are point samples on this Mac,
  not a tmux benchmark or a scaling claim.
- 2026-07-16: screenshots:
  [`expanded`](../../herdr/prototype/screenshots/expanded.png) and
  [`collapsed`](../../herdr/prototype/screenshots/collapsed.png).
- 2026-07-16: the user rejected the compact border junction appearance as
  visually ugly. The Neovim `colorful-winsep.lua` implementation and Herdr
  v0.7.4 source both use square box-drawing junctions (`┌ ┐ └ ┘` and the
  corresponding T/cross glyphs). Herdr does not expose glyph/corner styling;
  it exposes only borders on/off and shared (`pane_gaps = false`) versus
  independent boxed (`pane_gaps = true`) borders. The prototype runner now
  offers `compact`, `boxed`, and `borderless` sessions for live comparison.
- 2026-07-16: Mac UI automation is not permitted to control Ghostty in this
  environment. Density, mouse feel, navigation feel, and Kitty pixels therefore
  remain human approval gates even when CLI/source checks pass.
- 2026-07-16: live comparison windows were prepared in the existing `main`
  tmux session without changing tmux configuration: window 2 `herdr-boxed` and
  window 3 `herdr-borderless`. Both start collapsed with the same three-pane
  layout; Neovim plus the temporary Herdr adapter is in the left pane, the
  Kitty/chafa image probe is in the upper-right pane, and a shell is in the
  lower-right pane for mouse focus/resize/selection checks.
- 2026-07-16: the user preferred independent boxed pane geometry because the
  complete right-angle outline gives useful focus while preserving a quiet
  screen. The next visual candidate is "focused box only": retain boxed layout,
  keep the focused border on the Catppuccin accent, and set the inactive-border
  `theme.custom.overlay0` token to the pane background. Herdr's renderer supports
  that color distinction, but the result has not been rendered or approved and
  still reserves border cells around inactive panes.
- 2026-07-16: physical `Alt-h/j/k/l` failed during the live nested trial. The
  outer tmux binds those chords globally and forwards them only when its own
  foreground-process check sees Vim/Neovim/SSH. It sees `herdr`, so it consumes
  the chord before Neovim's temporary Herdr adapter can receive it. Earlier
  direct key injection proved the adapter logic but did not prove real nested
  keyboard delivery. A direct Herdr-in-Ghostty trial is required.
- 2026-07-16: the live trial did not include the user's normal fzf image-preview
  workflow. Kitty transport remains unapproved despite the standalone `chafa`
  command exiting successfully. Mouse behavior also received no explicit
  approval or rejection before the requested closeout.
- 2026-07-16: closeout removed the temporary `herdr-boxed` and
  `herdr-borderless` tmux windows and stopped the compact, boxed, and borderless
  Herdr servers. The production `main:1` tmux window remained active.
- 2026-07-16: the focused-only variant derives an isolated config with
  independent pane boxes and sets `theme.custom.overlay0` to Ghostty's verified
  Catppuccin Mocha background `#1e1e2e`. Focused borders retain Herdr's accent;
  inactive border cells remain reserved but should blend into the background.
- 2026-07-16: the first direct harness attempt exposed two prototype-only
  environment mistakes. Isolated `XDG_CONFIG_HOME` leaked into pane processes,
  hiding the real Neovim/Fish configs; then a login Fish used for `fe` triggered
  production tmux auto-attach. The harness now passes the normal config home to
  Neovim explicitly and runs the checked-in `fe`/`_fzf_preview` functions under
  `fish --no-config`, avoiding login startup without changing Fish itself.
- 2026-07-16: final direct readback reported `HERDR_DIRECT_GHOSTTY=1`, real
  Neovim with two normal split windows, the temporary Herdr map after lazy
  startup, and real fzf with `--query=png --preview '_fzf_preview {}'`. Adapter
  injection moved within Neovim first and then focused the right Herdr pane.
  Computer Use is not permitted to inspect Ghostty, so density, physical key
  feel, mouse behavior, and rendered Kitty pixels remain user-only approvals.
- 2026-07-16: the user approved the focused-only density and the remaining
  interaction set by confirming that everything except Alt navigation and the
  image preview worked. Those visual and mouse gates are now checked.
- 2026-07-16: direct Alt bindings now invoke the prototype-only
  `smart_nav.sh`. It inspects Herdr foreground-process JSON, injects the chord
  into Neovim when appropriate, and otherwise focuses the neighboring Herdr
  pane. Automated samples completed in 0.01s and proved local-window then
  outer-pane handoff; subjective key feel remains unapproved.
- 2026-07-16: fzf's preview was initially toggled hidden. Sending `?` exposed
  the right preview region, but `kitten icat --transfer-mode=memory` remained
  blank. A controlled stream-transfer probe rendered a host-wide black frame
  instead of the selected red Bible Standard app icon. Kitty image preview is
  therefore a stable-v0.7.4 migration blocker, not an approved capability.
- 2026-07-16: golden-ratio autoresize is implementable through a
  `pane.focused` plugin hook and fractional pane resize/layout APIs, but is not
  built in and needs a restore policy before prototyping. Herdr scrollback is
  integer-line stepped; the existing Neovim neoscroll animation remains valid
  inside Neovim, but Herdr adds no equivalent animated terminal scrollback.
