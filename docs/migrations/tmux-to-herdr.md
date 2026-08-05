# tmux to Herdr migration tracker

This is the durable source of truth for the staged migration from tmux to
Herdr. Herdr is the local default; the current tmux installation and
configuration remain the immediate rollback baseline. A Herdr item is checked
only after the stated evidence exists; visual feel and daily-workflow
equivalence require user confirmation.

Primary research: [`../research/herdr-primary-sources.md`](../research/herdr-primary-sources.md)
Prototype: [`../../herdr/prototype/README.md`](../../herdr/prototype/README.md)

## Status legend

- [x] Verified in the prototype or explicitly approved by the user.
- [ ] Not yet verified.
- **PARTIAL**: usable only with a port or accepted behavior change.
- **BLOCKED**: no acceptable Herdr path is known.
- **VERIFIED DIFFERENCE**: the replacement or retirement is deterministic, but
  the legacy behavior is not reproduced.
- **ACCEPTED GAP**: important difference explicitly accepted as non-blocking.
- **AWAITING USER**: automation passed; subjective approval remains.

## Migration gate

Do not remove tmux or retire its configuration during the staged promotion.

**Exception, 2026-08-02:** Eddy explicitly lifted this for the handoff replay
path only — "move fully to herdr now, tmux on my path will confuse things."
`tmux/scripts/ready_prompt.sh` and the `prefix+b` / `prefix+B` binds are
deleted; the parser lives at `herdr/prototype/ready_prompt_parser.sh`. The rest
of tmux, including the Fish login fallback at `fish/config.fish:66-80`, is
untouched and still governed by the rule above.
Prototype and production evidence must include commands/readback; appearance
and interaction feel require screenshots and user approval.

**Current verdict (approved 2026-07-23, carried to the reviewed v0.7.5 source
build): STAGED DAILY-DRIVER PROMOTION ACTIVE.** The build in use is pinned by
`herdr/source-build/pins.env`; rows below still name v0.7.4 wherever their
evidence has not been re-recorded since, and those version labels are part of
the claim rather than decoration.
All required core rows have deterministic evidence or explicit user approval.
Golden-ratio focus, physical navigation, visual density, application-owned Alt
transport, and image rendering are approved. Tmux remains installed and
unchanged as an explicit non-nested fallback and persistent rollback target.
The unchecked rows in the chronological prototype rounds preserve superseded
observations and are not active gates.

## Core behavior checklist

| Required | tmux behavior to preserve | Current implementation | Proposed Herdr path | Status / evidence |
| :---: | --- | --- | --- | --- |
| Yes | Detach and reattach without stopping processes | tmux server/client | Herdr named session | [x] Counter advanced while the client was detached; the same server PID and output survived reattach. |
| Yes | Multiple isolated sessions/projects | tmux sessions | Herdr sessions plus workspaces | [x] Scratch sessions `gate-alpha` and `gate-beta` ran concurrently on server PIDs `17770` and `19536`. Before and after `session attach`, each retained panes `w2:p1`/`w2:p2`, its own `/private/tmp/herdr-isolation.cn2tBx/project-{alpha,beta}` cwd, stable sentinel shell PIDs (`20641`/`20661` vs. `20651`/`20665`), and only matching `ALPHA_*` or `BETA_*` output. |
| Yes | Project-oriented sessionizer | `tmux/scripts/sessionizer.sh` | Git repository/worktree popup into current-session workspaces | [x] [`project-picker-validation.jsonl`](../../herdr/prototype/evidence/project-picker-validation.jsonl) proves configurable root discovery, generated-dependency pruning, linked worktrees outside the roots, duplicate-basename disambiguation, canonical cwd reuse, workspace creation/focus, restart re-adoption with pane history off, cancel/error no-ops, named-session isolation, and real `prefix+Shift+w` popup transport. Default discovery includes the dotfiles checkout and existing `~/Documents`, `~/Projects`, `~/projects`, `~/work`, and `~/code`; `HERDR_PROJECT_ROOTS` replaces that set. Native `prefix+w` remains the existing-workspace navigator. |
| Yes | New panes/tabs follow current cwd | `-c '#{pane_current_path}'` | `terminal.new_cwd = "follow"` | [x] New right/down panes both reported the repository cwd. |
| Yes | Side-by-side and stacked splits | `prefix+v`, `prefix+n/s` | matching Herdr split bindings | [x] Right and down splits created the expected three-pane layout. |
| Yes | Directional pane navigation | `prefix+h/j/k/l`, guarded Alt bindings | Herdr focus actions plus Neovim adapter | [x] Prefix focus and CLI neighbor/focus readback passed. |
| Yes | Neovim split-to-outer-pane handoff | `lua/plugin/tmux.lua` and tmux TUI guards | Alt unbound in Herdr; exact temporary Neovim port plus Fish/fzf adapters | [x] **APPROVED:** user confirms physical Alt-h/j/k/l movement works extremely well. |
| Yes | Pane zoom | `prefix+O`, `Alt-z` | Herdr zoom binding/API | [x] CLI readback changed `false -> true -> false`. |
| Yes | Swap, resize, move, and close panes | tmux commands and smart-close policy | native API plus custom commands | [x] `binding-validation.jsonl` records `w1:p1` swapping rectangles, root ratio `0.50 -> 0.60`, `w1:p3` moving `t1 -> t2 -> t1`, bare-shell close, and process-aware confirmation. Sentinel PID `10747` survived the first close press; the second confirmed press removed its pane. A sole pane survived with exit 75. |
| Yes | Tabs: create, next/previous, indexed, last, reorder, close | tmux window bindings | Herdr tabs and CLI | [x] `tab-lifecycle-validation.jsonl` records four sentinel-backed tabs; next/previous wrap; existing `prefix+2` focus; missing `prefix+7` creating exactly one cwd-following tab labeled `7`; exact last-tab history; reorder/restore with process survival; immediate close with process exit; and confirmation-protected close-others preserving only the selected tab/process. |
| Yes | Searchable session/window/pane picker | custom `choose-tree`, fzf picker | Herdr workspace navigation plus searchable navigator | [x] [`picker-validation.jsonl`](../../herdr/prototype/evidence/picker-validation.jsonl) records real `prefix+w` workspace navigation and prefix-only `prefix+f` searchable navigation; current-pane initial selection; case-insensitive multi-term workspace/tab/pane search; false-positive-resistant tree-row assertions for blocked/working/idle/done filters; exact workspace/tab/pane focus readback; safe search/outer Escape, no-match, and stale-target paths; four surviving sentinel PIDs; unchanged before/after runtime-object inventories; and strict isolation between explicitly attached sessions `pa`/`pb`. The PTY capture waits for semantic screen stability while ignoring animation-only spinner redraws. Evidence is replaced atomically only on success and records hashes of the config, PTY client, and validator; `Alt-Ctrl-f` is absent, every approved prototype binding is audited, and production config hashes stayed unchanged. |
| Yes | Vi copy mode, search, selection, clipboard | tmux copy-mode-vi | Herdr copy mode | [x] Searched `HERDR_COPY_SENTINEL`, selected with `v/e`, yanked, and `pbpaste` matched exactly. |
| Yes | Mouse focus, resize, scrolling, selection | `mouse on` and copy-mode routing | native Herdr mouse UI | [x] User confirmed all remaining direct-trial behavior worked after separately identifying navigation and image-preview failures. |
| Yes | Long scrollback | `history-limit 65536` | byte-based `advanced.scrollback_limit_bytes` | [x] 250 generated lines remained readable; byte-vs-line depth remains a migration difference. |
| Yes | Clean, simple Catppuccin screen | one top tmux status row | hidden collapsed sidebar, no gaps/toasts/sounds | [x] User confirmed the focused-only boxed direct layout works; focused border remains accented while inactive borders blend into `#1e1e2e`. |
| Yes | Ghostty key fidelity and true color | extkeys/RGB/undercurl settings | Herdr terminal renderer | [x] **APPROVED:** isolated direct Ghostty reported `TERM=xterm-256color`/`COLORTERM=truecolor`; pane readback preserved `48;2` RGB, `4:3` undercurl, and `58;2` underline colors. User screenshot visibly confirmed four distinct RGB swatches and curly underlines. Physical key capture produced exact Kitty events for `Alt-x` (`CSI 120;3u`), `Ctrl-Alt-x` (`CSI 120;7u`), `Shift-Tab` (`CSI 9;2u`), and `Ctrl-Shift-Enter` (`CSI 13;6u`), with no missing or duplicate events; user approved the gate. |
| Yes | Kitty/chafa image previews | tmux DCS passthrough | corrected `pane.graphics.set` fzf preview | [x] **ACCEPTED GAP:** raster transport works, but replacement/focus lifecycle is below the tmux visual bar. Important to revisit after an upstream fix; explicitly non-blocking for migration. |
| Yes | Codex, Claude, OpenCode, AGY, Gemini visibility | native hooks plus tmux status engine | Herdr detection/integrations | [x] [`multi-agent-compat-validation.jsonl`](../../herdr/prototype/evidence/multi-agent-compat-validation.jsonl) preserves the earlier Codex evidence and deterministically proves Claude, OpenCode, AGY (`antigravity`), and legacy Gemini (`node` plus start command) detection; Herdr-owned `working`/`blocked`/`done` lifecycle status; all five semantic metadata states for every named agent; distinct real `prefix+f` visibility; installed CLI/version readback without model calls; and unsupported-agent no-mutation behavior. The production path now adds current official Claude Code, Codex, and OpenCode integrations for native session recovery while retaining native manifest detection for every listed agent. |
| Yes | Distinguish running, question, approval, finished, failure | custom semantic icons/colors | Herdr semantic state plus metadata | [x] `agent-state-validation.jsonl` records five simultaneous Codex fixtures. Herdr keeps lifecycle authority (`working`, `blocked`, `done`) while guarded pane metadata renders distinct `running`, `question`, `approval`, `finished`, and `failure` labels in the real `prefix+f` navigator and `$semantic_state` sidebar row. The official Claude Code, Codex, and OpenCode integrations are now installed current beside the preserved tmux status hooks/plugins; `herdr/verify_integrations.sh` enforces that coexistence. |
| Yes | Ready-prompt paste and clear-then-paste | `ready_prompt.sh`, `prefix+b/B` | pane process/read/send APIs plus bracketed paste | [x] `ready-prompt-validation.jsonl` records 49 parser checks, exact multiline mock insertion without submission, consume-once and concurrency rejection, agent-aware Codex/Claude clear-and-replay, empty-composer and historical `/clear` handling, and unsupported-agent failure before input. Live tmux and disposable Herdr Claude gates proved `/clear`, stable ready detection, sentinel insertion, and no automatic submission. |
| Yes | Fish login attach without nesting loops | guarded default selector plus intact tmux block | named Herdr launcher with tmux fallback | [x] `login-attach-validation.jsonl` proves an isolated interactive login launches `--session main`, supports a validated custom session, and stays inert for non-login, non-interactive, existing Herdr, existing tmux, opt-out, unsafe-session, tmux-default, invalid-default, and missing-default cases. Production Fish now sources the fail-closed selector; tmux remains the unchanged fallback path. |
| No | Ordinary SSH and remote attach | remote tmux | remote Herdr/thin client | [x] [`remote-validation.jsonl`](../../herdr/prototype/evidence/remote-validation.jsonl) proves a real authenticated `herdr --remote ssh://... --session remote-audit` thin-client attach through a disposable localhost OpenSSH server. The exact v0.7.4 remote binary, compatible named server, and live pane inventory were read back before clean detach. A closed endpoint failed before input, bootstrap, or installation; macOS Remote Login stayed disabled and production hashes were unchanged. Ordinary SSH followed by remote Herdr is also the documented Herdr-native tmux-style path. |
| No | Resurrect/Continuum-style recovery | TPM plugins | snapshot plus native agent resume, with pane history off | [x] **HERDR-NATIVE DIFFERENCE:** `recovery-validation.jsonl` retains the isolated capability proof for topology/cwd restore and current Codex resume. The production privacy policy remains `pane_history = false`. `installation-validation.md` additionally proves a real Codex conversation reports native identity, loses its original process on a disposable server stop, returns through `codex resume <same-id>`, and completes a new turn without creating `session-history.json`. Arbitrary process state is not resurrected. |
| No | Scratch shell and lazygit popups | `display-popup` | custom popup commands | [x] `popup-validation.jsonl` records real `prefix+Enter` and `prefix+g` input opening distinct session-modal commands at 80% and 85%. Their inner PTYs measure 72×30 and 76×32 cells in the fixed client, inherit the focused pane cwd, dismiss on command exit, and leave the tiled pane/tab/workspace/layout inventories and sentinel PID unchanged. |
| No | Golden-ratio pane focus | tmux focus hook | prototype `pane.focused` plugin | [x] Focus produced exact 62/38 ratios, toggle restored exact 50/50, and the user approved the behavior as working very well. |
| No | URL search/open shortcuts | capture/copy scripts | pane-read custom commands | [x] [`url-validation.jsonl`](../../herdr/prototype/evidence/url-validation.jsonl) proves real `prefix+u` PTY input opens nothing for zero URLs, normalizes and opens the only URL, and opens only the newest of multiple visible URLs. Cursor-local copy-mode `O` is tracked separately as a verified unavailable v0.7.4 action. |
| No | Nested multiplexer passthrough | tmux key-table toggle | remote Herdr; keep experimental nesting disabled | [x] **HERDR-NATIVE DIFFERENCE:** `remote-validation.jsonl` proves the supported thin-client path while the v0.7.4 configuration readback proves `experimental.allow_nested = false` by default. The migration path avoids a second multiplexer instead of recreating tmux's outer/inner key-table toggle. No nested passthrough binding is installed. |

## Effective keybinding migration

The source of truth is `tmux/tmux.conf`, not the older README table. The
effective tmux prefix entry is `Ctrl-a` (`prefix` itself is `None`, with
`Ctrl-a` switching to the prefix table).

| Current key | Current action | Herdr target | Status |
| --- | --- | --- | --- |
| `Ctrl-a` | Enter prefix table | `keys.prefix = "ctrl+a"` | [x] |
| `prefix+h/j/k/l` | Focus pane direction | same | [x] |
| `Alt-h/j/k/l` | Smart TUI/Neovim-or-pane navigation | leave Alt unbound in Herdr; temporary Neovim/Fish/fzf owners call Herdr only when needed | [x] Existing physical ownership path remains approved; the binding-policy pass did not add global Herdr Alt bindings. |
| `prefix+n`, `prefix+s` | Split down | approved `prefix+a` adaptive split; `prefix+s` copy/search | [x] A 27×24 focused pane deterministically split down into two 27×12 panes. |
| `prefix+v` | Split right | same | [x] One 54×24 pane became two 27×24 panes. |
| `Alt-n/s/v` | Split unless forwarded to Vim/TUI | application-owned `Alt-n/v`; retire `Alt-s` | [x] **APPROVED:** Round 9 proves Fish-owned `Alt-n` and nested-child `Alt-v` through both legacy and Kitty transports with configured child shells. Neovim and fzf retain ownership, Herdr has no global collision, and the retired `Alt-s` has no replacement. |
| `prefix+c`, `Alt-c/q` | Smart close pane | `prefix+x`; application-owned shell `Alt-q` | [x] Bare shell closed immediately; `sleep 300` and the last pane required an identical second press within five seconds. Neovim retains `Alt-q` for its visible window/buffer and `Alt-x` for window exchange. |
| `prefix+N`, `prefix+Ctrl-n`, `Alt-Ctrl-n` | New tab after current | approved native `prefix+c` | [x] Real `prefix+c` input created tabs `w1:t2`, `w1:t3`, and `w1:t4`, each with one pane and its own live sentinel PID; legacy aliases remain intentionally removed. |
| `prefix+t/T` | Next/previous tab | approved native `prefix+n/p` | [x] Real `prefix+n/p` input wrapped `w1:t4 -> w1:t1 -> w1:t4`; legacy aliases remain intentionally removed. |
| `Alt-0..9`, `prefix+0..9` | Select/create numbered tab | prefix digits focus a matching number/label or create one labeled digit | [x] Real `prefix+2` focused the existing second tab. Real `prefix+7` with four tabs created exactly one fifth tab labeled `7`, inherited the focused pane cwd, and was selected; no filler tabs were manufactured. Direct Alt digits are intentionally retired in favor of the prefix table. |
| `prefix+Tab` | Last tab | native cross-workspace `last_pane` | [x] **ACCEPTED DIFFERENCE:** `workspace-navigation-validation.jsonl` proves `prefix+Tab`/`Ctrl-^` toggles between `w1:p1` and `w2:p1` with both processes surviving. `tab-lifecycle-validation.jsonl` separately preserves exact last-tab history evidence, but the active `prefix+Tab` binding now means last pane. |
| `Alt-Tab` | Last tab | retire; use proven `prefix+Tab`/`Ctrl-^` last-pane navigation | [x] **VERIFIED DIFFERENCE:** [`capability-gap-validation.jsonl`](../../herdr/prototype/evidence/capability-gap-validation.jsonl) proves no global or Fish-owned `Alt-Tab` binding is installed. Exact last-tab history remains proven in the tab-lifecycle gate, while the active migration intentionally standardizes on cross-workspace last-pane navigation. |
| `prefix+{/}` | Reorder tabs | CLI/custom commands | [x] Real prefix input moved `w1:t3` right from `[w1:t1,w1:t2,w1:t3,w1:t4]` to `[w1:t1,w1:t2,w1:t4,w1:t3]`, then restored the original order while sentinel PID `30130` survived. |
| `prefix+O`, `Alt-z` | Toggle zoom | approved `prefix+z` and application-owned `Alt-z` | [x] **APPROVED:** native zoom and the Fish-owned Alt transport both passed `false -> true -> false`; Neovim retains `<M-z>` and Herdr has no global `Alt-z` collision. |
| `prefix+r/R`, `Alt-r/R` | Swap panes | approved directional `prefix+H/J/K/L` | [x] `w1:p1` moved from the full-height left rectangle to the upper-right rectangle while pane identity stayed stable. |
| `prefix+=`, `Alt-=` | Equal/tiled layout | topology-preserving `layout.set_split_ratio` action | [x] `pane-lifecycle-validation.jsonl` records a distorted three-pane BSP changing from root/nested ratios `0.70/0.65` to leaf-weighted `0.33333334/0.50` through both the real prefix path and Fish-owned Alt transport. Pane IDs, topology, and both sentinel PIDs survived; the rejected `layout.apply` replacement route is not used. |
| `prefix+Shift+p` | Send/join pane prompts | stale-safe fzf send/receive picker over native `pane move` | [x] `utility-parity-validation.jsonl` proves both send-focused and receive-beside-focused paths preserve the moved terminal ID, sentinel PID, cwd, target tab, and focus. Cancel, self, and a target closed after selection are inert. |
| `prefix+Shift+u` | `dump-history` | explicit-path focused-pane recent-text export | [x] `utility-parity-validation.jsonl` proves terminal text export to a mode-`0600` file, atomic no-clobber refusal, and replacement only after an explicit `y`. Production `pane_history = false` remains unchanged. |
| `prefix+^`, `prefix+$` | First/last window | ordered current-workspace tab-edge helpers | [x] First and last tab IDs are selected in `tab list` API order while `prefix+Tab` and `Ctrl+^` remain last-pane navigation; sentinel processes survive. |
| `prefix+<,>,comma,period,-,+` | Resize by two cells | approved native `prefix+r`, then `h/j/k/l` | [x] Direct API evidence changed the root split ratio `0.50 -> 0.60`; config check confirms native resize mode at `prefix+r`. |
| `prefix+o/Ctrl-o`, `Alt-o` | Close all other panes | confirmation-protected `prefix+o`; application-owned `Alt-o` | [x] `pane-lifecycle-validation.jsonl` proves the real prefix path and Fish-owned Alt transport both preserve the focused pane and two live sibling processes on the first press, then close only the siblings and terminate their processes on the identical second press. With no siblings the action is a no-op. Redundant `prefix+Ctrl-o` is retired. Neovim keeps its existing `<M-o>` “only window” mapping. |
| `prefix+X`, `Alt-X` | Close tab | native `prefix+X`; application-owned shell `Alt-X` | [x] `tab-lifecycle-validation.jsonl` proves real `prefix+X` input closes the tab and terminates its sentinel. `binding-validation.jsonl` independently drives `Alt-X` through Herdr's Kitty CSI-u transport into Fish, removes only the focused tab, and proves its shell PID dead. |
| `prefix+Ctrl-x`, `Alt-Ctrl-x` | Close all other tabs with confirmation | custom API command | [x] `tab-lifecycle-validation.jsonl` proves the prefix path, including fail-closed missing identity and session/socket-scoped confirmation. `binding-validation.jsonl` drives application-owned `Alt-Ctrl-x` through Fish: the first press preserves all four tabs, the second preserves only the selected tab, and both sibling sentinel PIDs terminate. |
| `prefix+w` | Session/window/pane tree | native `workspace_picker` for current-session workspace navigation | [x] Real prefix input opened ordinary workspace navigation with `Alpha Project` and `Beta Project`, without opening the search overlay; native Down+Enter focus readback changed to workspace `w2`. |
| `prefix+Shift+w` | Project sessionizer | session-modal Git repository/worktree picker | [x] Real prefix input selected a linked worktree, created and focused one workspace, then reused the same canonical target without duplication. Generated dependency trees are pruned; same-name repositories remain distinct by displayed path; named sessions remain isolation boundaries. |
| `prefix+f`, `Alt-Ctrl-f` | fzf window picker | native searchable `goto` on prefix-only `prefix+f`; retire direct `Alt-Ctrl-f` | [x] Real prefix input opened the searchable workspace/tab/pane overlay with the current pane selected; `Alt-Ctrl-f` is absent and all search, filter, selection, return, stale-target, process-safety, and named-session isolation assertions passed. |
| `prefix+Shift+f` | fzf destructive window operations | confirmed one-target pane/tab/workspace object manager | [x] `picker-reference-validation.jsonl` proves real popup transport, searchable type/ID/label/context rows, explicit confirmation, successful deletion for every object kind, inert cancellation/failure, and rejection when a pane identity or tab/workspace descendant topology changes after selection. Native `prefix+f` remains non-destructive goto. |
| `prefix+Shift+r` | broad URI/path/hash discovery | recent pane-read reference picker outside copy mode | [x] `picker-reference-validation.jsonl` proves URI/path/hash extraction, newest-first deduplication, punctuation trimming, copy and URI/path open dispatch, relative-path cwd resolution, hash-open refusal, and real popup/hash-copy transport. It does not claim cursor-local or selection-bounded copy-mode parity. |
| `prefix+Enter` | Scratch-shell popup | Herdr popup command | [x] Real prefix input opened an 80% session-modal fixture with a 72×30 inner PTY, inherited cwd, clean dismissal, and unchanged tiled layout/processes. |
| `prefix+g` | Lazygit popup | Herdr popup command | [x] Real prefix input opened an 85% session-modal fixture with a 76×32 inner PTY, inherited cwd, clean dismissal, and unchanged tiled layout/processes. |
| `prefix+[` / `PageUp` / `Alt-Escape` | Copy mode | Herdr copy mode aliases | [x] `prefix+[` and `Alt-Escape` configured; `PageUp` omitted to preserve shell/TUI behavior. |
| copy `v`, `Ctrl-v`, `y`, `Y` | select/rectangle/copy | reviewed v0.7.5 source build keeps native `v`/Space selection and `y`/Enter yank, adds `Y` by composing native `V` then `y`, and retires rectangle selection | [x] `copy-mode-validation.jsonl` proves actual shifted `Y` input copies the exact current line and exits. The pinned source patch has focused Rust coverage and installs no input emulation. Rectangle selection remains unavailable — see the non-goal below. |
| copy `Ctrl-v` rectangle | block/column selection | **DELIBERATE NON-GOAL** | [x] **WON'T DO:** upstream models a selection as `CopyModeSelection::Character` or `Linewise` only, and `Selection::contains(row, col)` tests a linear range, so a block variant would have to be threaded through hit-testing, rendering, and text extraction rather than added as a key. That code is carried in the private patch and rebased onto every Herdr upgrade, so the cost is paid at each upgrade, not once. Declined on 2026-08-05 as the least-used copy-mode key against the largest permanent patch. Revisit only if upstream adds a block selection kind. |
| copy counts, `V`, `g`/`G`, `0`/`^`/`$`, `{`/`}`, `zz` | vim motions and operators | native upstream behavior plus counted repeats from the private patch | [x] Native at v0.7.5: `V`, `g`, `G`, `0`, `$`, `^`, `?`, `{`, `}`, `w`/`b`/`e`, `/`, `n`/`N`, `v`/Space, `y`, `q`. The patch adds a pending-count buffer so those motions accept `3j`-style repeats, aliases `a`/`i` to exit-without-copy, adds `Y` and counted whole-line yank, and adds `zz` centering. |
| copy `u/d`, marks, prompt jumps | half pages, marks, OSC 133 prompts | native `Ctrl-u/d` and `PageUp/Down`; retire unavailable extras | [x] **VERIFIED DIFFERENCE:** `copy-mode-validation.jsonl` proves real `prefix+s`, `Ctrl-u/d`, and `PageUp/Down` input over 120 lines, including exact viewport movement and live-process survival. The capability audit proves marks and OSC 133 prompt jumps are absent from the v0.7.4 configurable surface and are not emulated. |
| `prefix+u`, copy `O` | Open URL | custom pane-read helper; retire cursor-local alias | [x] **VERIFIED DIFFERENCE:** `url-validation.jsonl` proves real `prefix+u` transport and exact zero/one/newest-of-many behavior with a non-launching opener fixture. The capability audit proves copy-mode cursor URL opening is absent from the v0.7.4 configurable surface and no input-emulation shim is installed. |
| `prefix+b/B` | Ready-prompt replay / clear replay | Herdr pane inspection/read plus bracketed `send-text`; uppercase waits after Codex or Claude `/clear` | [x] `prefix+b/B` are isolated shell commands. The validator proves exact extraction, pane-local consume-once state, no implicit Enter, live non-execution, stable-ready waiting, and fail-closed clear support for agents other than Codex and Claude. |
| `prefix+Space` | Layout menu | ratio-only, topology-compatible process-preserving palette | [x] `layout-menu-validation.jsonl` proves the real 54×20 palette retains equalize/zoom/split/cancel and adds tiled, main-horizontal, main-vertical, even-horizontal, and even-vertical. Every compatible preset preserves exact topology, pane/terminal IDs, sentinel PIDs, cwd, and focus; incompatible topology rejects before mutation. `layout.apply` is absent because it replaces pane terminals in v0.7.4. |
| `prefix+(`/`)`, `Ctrl-^` | Session navigation/last session | previous/next workspace plus native cross-workspace `last_pane` | [x] `workspace-navigation-validation.jsonl` proves real prefix input wraps `One -> Two -> Three -> One` and back to `Three`; the physical `Ctrl-^`/`Ctrl-6` byte toggles between panes in different workspaces; and all three sentinel processes survive. Named sessions remain isolation boundaries, while everyday project navigation follows Herdr's workspace model. |
| `Alt-Ctrl-Down/Up` | Nested tmux passthrough | retire; use native remote attach with nesting disabled | [x] **HERDR-NATIVE DIFFERENCE:** the disposable OpenSSH gate proves remote thin-client attach and the default-disabled nesting guard. These legacy passthrough chords are intentionally absent because there is no inner multiplexer to toggle. |

## Prototype rounds

The rounds below are a chronological evidence record, not the active checklist.
Later rounds supersede earlier `PARTIAL`, `BLOCKED`, and `AWAITING USER` results
without rewriting the historical observations that led to them.

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

- [x] User approves the focused-only boxed visual density; earlier compact and
  expanded candidates are superseded.
- [x] User approves physical navigation feel and the documented navigation and
  image-preview differences accepted by the active gate.
- [x] User explicitly authorized the reversible staged daily-driver promotion
  on 2026-07-23; tmux removal remains a separate future decision.

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

### Round 5 — final direct acceptance trial

The three subjective decisions are final: smart navigation and chafa were
rejected, while golden-ratio focus was approved. The live `trial-focused`
session was stopped during closeout.

| Gate | Objective evidence | Approval |
| --- | --- | --- |
| Smart `Alt-h/j/k/l` feel | Real Neovim moved window `1002 -> 1005` in 16.62 ms; the next identical chord handed focus `w1:p1 -> w1:p2` in 14.58 ms. A non-Neovim pane moved `w1:p2 -> w1:p3` in 14.86 ms. | [ ] **REJECTED:** physical Alt did not invoke this helper path and no longer worked inside Neovim. |
| Golden-ratio focus | The local `prototype.golden-focus` event hook changed the right/top focused layout to root `0.38` and nested `0.62`, then right/bottom to `0.38`/`0.38`. Toggle restored both splits to `0.50`, and a second toggle reapplied `0.38`/`0.62`. All observed plugin commands exited 0. | [x] **APPROVED:** user reports it works very well. |
| chafa fzf fallback | fzf process argv contains the explicit `chafa_preview.sh {}` preview. Pane readback contains symbol pixels, and [`chafa-final.png`](../../herdr/prototype/screenshots/chafa-final.png) captures the visible selected-PNG preview without Kitty transport. | [ ] **REJECTED:** working but too pixelated and blurry. |

### Round 6 — exact muscle-memory repair and native-image audit

| Gate | Evidence | Approval |
| --- | --- | --- |
| Physical `Alt-h/j/k/l` | Server logs contain no helper API activity for either set of rejected physical Alt presses. The revised scratch-only Ctrl-Alt CSI-u translation still left Alt unread inside Neovim and required prefix navigation. | [ ] **REJECTED / BLOCKED IN v0.7.4** |
| High-quality fzf image | A direct `pane.graphics.set` PNG request returned `ok` and produced crisp pixels, but placement/clear escaped the pane and blacked the entire Ghostty client, repeating the Kitty stream failure. | [ ] **BLOCKED IN v0.7.4** |

### Round 7 — pass-through ownership and corrected native placement

| Gate | Evidence | Approval |
| --- | --- | --- |
| Physical `Alt-h/j/k/l` | Herdr has no direct Alt binding; isolated Ghostty explicitly uses left Option as Alt. The temporary Neovim adapter mirrors the real `lua/plugin/tmux.lua` local-first mappings and `FzfLuaFocus` exception. API injection moved `1048 -> 1003 -> 1048 -> 1005`, then handed focus out of Neovim; the Fish adapter moved `w1:p3 -> w1:p1`. | [x] **APPROVED:** user reports the movement works extremely well. |
| Native fzf image | `pane.graphics.set` accepted an actual 1800×890 PNG and confined it to `w1:p2`; repeated set, focus resize, and clear returned `ok`. | [ ] **REJECTED:** user reports the live preview is glitchy and not as polished as tmux. |

### Round 8 — image-only lifecycle retry

The approved `Alt-h/j/k/l` adapter was left byte-for-byte unchanged. This pass
used only clean standalone PNG fixtures and isolated prototype files.

| Gate | Evidence | Approval |
| --- | --- | --- |
| Crisp standalone PNG | The prototype pre-fits each 1600×1000 fixture to the Ghostty cell box before `pane.graphics.set`. [`native-preview-clean`](../../herdr/prototype/screenshots/native-preview-clean.png) shows the full, centered green fixture without recursive terminal pixels. | [ ] **VISUALLY CLEAN, NOT SUFFICIENT** |
| Selection replacement | Pane-scoped `lockf` serialization and latest-token checks prevented older API workers from completing after newer workers. All logged set requests returned `ok`, but [`native-preview-cycle-amber`](../../herdr/prototype/screenshots/native-preview-cycle-amber.png) shows amber selected with the prior green raster, and [`native-preview-cycle-blue`](../../herdr/prototype/screenshots/native-preview-cycle-blue.png) shows blue selected with the prior amber raster plus a transient host-wide black region. | [ ] **IMPORTANT GAP:** visible replacement lag/stale raster remains; accepted as non-blocking pending upstream work. |
| Resize and focus lifecycle | fzf now binds `resize:refresh-preview`; repeated focus changes produced successful replacement responses at both 20- and 36-column preview widths. [`native-preview-focus-right`](../../herdr/prototype/screenshots/native-preview-focus-right.png) nevertheless captured a focus redraw with most non-preview terminal content black before later recovery. | [ ] **IMPORTANT GAP:** focus redraw is not tmux-quality; accepted as non-blocking pending upstream work. |
| Explicit clear | Escape exited fzf, the serialized `pane.graphics.clear` returned `ok`, no fzf/native preview process remained, and [`native-preview-cleared`](../../herdr/prototype/screenshots/native-preview-cleared.png) shows the pane restored with no raster residue. | [x] **PASS** |
| Selection replacement on v0.7.5 | Retry run on the hash-verified v0.7.5 prototype runtime. A live `trial-focused` session drove the fzf selection blue → amber → green at a 29×14-cell preview; all three `pane.graphics.set` requests returned `ok` under the same `lockf` and latest-token serialization ([`graphics-v075-retry.log`](../../herdr/prototype/evidence/graphics-v075-retry.log)). The agent could not screenshot the trial window — it opened on a space `screencapture` does not reach — so **no visual comparison was captured** and the stale-raster question is unresolved either way. | [ ] **AWAITING USER:** API half re-run clean on v0.7.5; visual replacement still needs Eddy's eyes on the live window. |

### Upstream graphics review after Round 8

Primary-source review on 2026-07-17 found no qualifying release to retest:

- [`v0.7.4` remains the latest stable release](https://github.com/ogulcancelik/herdr/releases/tag/v0.7.4).
  The latest official prerelease is
  [`preview-2026-07-16-e907e6a36646`](https://github.com/ogulcancelik/herdr/releases/tag/preview-2026-07-16-e907e6a36646).
- The preview includes
  [`e9cbcf2f`, a `pane.graphics.stream` disconnect-race fix](https://github.com/ogulcancelik/herdr/commit/e9cbcf2f6f8654dd41b10826ef6aecd526f6b0b0),
  but that change does not modify standalone `pane.graphics.set`, image
  replacement, or focus/resize composition.
- At checked master `99760f77`, the `pane.graphics.set` handler has the same Git
  blob as v0.7.4. The only Herdr compositor change,
  [`8dcb75a5`](https://github.com/ogulcancelik/herdr/commit/8dcb75a5c08b4dd1f225ea531a27824a9f41ae4a),
  extracts active-tab surface rendering without changing replacement, cache,
  focus, or resize behavior.
- The official [socket API](https://herdr.dev/docs/socket-api/#experimental-pane-graphics)
  continues to mark pane graphics experimental and treats repeated-frame
  `stream` separately from `set`/`clear`.

**Decision:** do not reopen the image prototype against the current stable,
preview, or untagged master. Preserve the failure captures and retry only after
an official release or preview explicitly changes `pane.graphics.set`
replacement or focus/resize composition. This is deferred polish, not a
migration gate.

### v0.7.5 retry decision (2026-08-05)

**Trigger fired, for one gap only.** The 2026-07-17 retry condition is met on the
replacement/cache half: vendored `libghostty-vt` adds process-global generation
stamps and `src/ghostty/mod.rs` keys texture-cache staleness on them, upstream
documenting that a same-ID retransmission with identical dimensions, format, and
data length previously escaped size-heuristic cache keys. Round 8's symptom —
a new selection painting the *prior* fixture — is that failure exactly, and
`herdr/prototype/native_preview.sh` pre-fits every fixture to the cell box, so
its replacements do present near-identical dimensions. Nothing in v0.7.5 touches
focus or resize composition: the `pane.graphics.set` handler blob is unchanged
and the compositor edits are the `8dcb75a5` tab-surface extraction plus its
v0.7.5 continuation (`render_stream.rs` deletions are code moved into
`crate::ui` helpers, not behavior).

**Decision: retry, scoped to the replacement gap.** Cost is low — this machine
already runs the reviewed v0.7.5 build (`herdr --version` → 0.7.5), and the
Round 8 harness, fixtures, and screenshot procedure are intact, so no rebuild
and no new prototype code are required. The black focus redraw is observed and
recorded in the same run but is **not** retested as a fix candidate; it has no
upstream change behind it and stays deferred regardless of outcome.

**Validation plan:**

1. Confirm the running binary matches `pins.env` before capturing anything.
2. Run the Round 8 image round unchanged under `./herdr/prototype/live_ghostty.sh`
   with the same fixtures, cycling selection green → amber → blue.
3. Capture replacement screenshots at the same points as
   [`native-preview-cycle-amber`](../../herdr/prototype/screenshots/native-preview-cycle-amber.png)
   and [`native-preview-cycle-blue`](../../herdr/prototype/screenshots/native-preview-cycle-blue.png),
   plus a focus-change capture for the observation-only row.
4. Log every request/response to prototype evidence as in Round 8.

**Stop condition:** each captured raster matches its selected fixture with no
prior-frame residue, or the stale raster reproduces on v0.7.5. Either way the
gap row is updated with the new captures.

**Acceptance is the user's.** Replacement smoothness is visual and subjective;
the row stays `AWAITING USER` until Eddy confirms the captures. A pass promotes
the replacement gap only — the focus-redraw gap remains an accepted,
non-blocking deferral, and pane graphics remain experimental upstream.

### Round 9 — approved binding policy implementation

The isolated prototype implements the approved table without changing tmux,
Ghostty, Neovim, or Fish production configuration. The repeatable evidence is
[`binding-validation.jsonl`](../../herdr/prototype/evidence/binding-validation.jsonl).

| Gate | Evidence | Approval |
| --- | --- | --- |
| Config collisions | All four generated configs returned `config: ok`; `verify.sh` found no duplicate custom keys and no global Herdr `Alt-v/n/x/z/X` binding. | [x] **PASS** |
| Split, swap, resize, move | Fixed split changed 54×24 into two 27×24 panes; adaptive split chose down for 27×24; `w1:p1` swapped rectangles; resize changed root ratio 0.50→0.60; `w1:p3` moved `t1→t2→t1` without changing terminal identity. | [x] **PASS** |
| Smart close | `sleep 300` PID 10747 survived the first close request (exit 75), then its pane disappeared on the identical confirming request. A bare shell closed immediately, while a sole pane remained alive after its first request. | [x] **PASS** |
| Zoom | Layout readback changed `false→true→false`. | [x] **PASS** |
| Newest visible URL | Zero URLs exited 4 and opened nothing; one opened `http://a`; multiple opened only the newest visible match, `http://b`. | [x] **PASS** |
| Application-owned Alt chords | The first physical trial failed because Fish named `alt-*` bindings did not match Herdr's Kitty CSI-u events. The next trial exposed child panes inheriting Herdr's scratch config instead of the real Fish config. The adapter now binds both transports, and `prototype_shell.sh` restores real Fish config plus the adapter for every generation while suppressing tmux auto-attach only during startup. Regression evidence records `Alt-n` 2→3 panes, nested child `Alt-v` 3→4, configured Fish processes in both generations, and `Alt-z` false→true→false. Final ownership validation: Fish `Alt-q` removed configured pane `w1:pA` (4→3 panes); Neovim `Alt-x` kept two sentinel windows and exchanged current window `1000→1002`; Neovim `Alt-q` reduced windows 2→1 and left the other sentinel. | [x] **APPROVED** |

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
- 2026-07-16: the final direct acceptance harness links the isolated
  `prototype.golden-focus` plugin. Its `pane.focused` hook applies the tmux-like
  62% target on each applicable split axis. The `Ctrl-a Shift-g` plugin action
  disables the hook and restores 50/50, then re-enables and reapplies 62%.
- 2026-07-16: final navigation samples measured 16.62 ms inside Neovim,
  14.58 ms for Neovim-edge-to-Herdr handoff, and 14.86 ms between ordinary
  Herdr panes. These are single direct samples on this Mac, not latency bounds.
- 2026-07-16: the final fzf probe bypasses the rejected Kitty path and invokes
  `chafa_preview.sh` explicitly. Both pane readback and the direct Ghostty
  screenshot show symbol-rendered preview content. Computer Use was denied
  access to Ghostty by its safety allowlist, so the subjective gates remain
  user-owned despite command/readback and screenshot evidence.
- 2026-07-17: the user approved golden ratio, rejected the physical smart-nav
  path because Alt stopped working inside Neovim, and rejected chafa because
  its symbol rendering is too pixelated and blurry for the required standard.
- 2026-07-17: server logs confirmed physical Alt never entered the helper/API
  path. The revised scratch-only launcher translates physical `Alt-h/j/k/l`
  into unambiguous Ctrl-Alt CSI-u chords; Herdr then forwards the original Alt
  chord to Neovim/Vim/SSH or focuses an outer pane, mirroring the tmux guard.
- 2026-07-17: Herdr's native `pane.graphics.set` accepted a full PNG and
  rendered crisp pixels, but its placement escaped the target pane and a later
  set/clear blacked the full Ghostty client. Together with the Kitty failures,
  this leaves no high-quality v0.7.4 preview suitable for migration.
- 2026-07-17: the final physical-key retest rejected the revised isolated
  Ghostty remap. The user still had to use prefix navigation, `Alt-h/j/k/l`
  was not read inside Neovim, and the server log contained focus/resize events
  but no smart-navigation focus call from those physical Alt presses.
- 2026-07-17: the final screenshot confirmed that the safe chafa-symbol
  fallback is fully pixelated and does not meet the existing high-quality
  preview standard. Golden-ratio focus remains approved, but the two required
  failures make the v0.7.4 migration verdict **REJECTED**. Production tmux,
  Fish, Neovim, and Ghostty configuration remain unchanged.
- 2026-07-17: primary-source review localized the Alt regression to ownership:
  Herdr consumes matching direct bindings before pane forwarding. The reopened
  prototype removes Herdr/Ghostty chord remaps, explicitly enables left
  Option-as-Alt in only the scratch Ghostty process, and ports the production
  Neovim helper's local-first and fzf-lua behavior. Fish and fzf receive
  separate prototype-only adapters for the non-Neovim half of tmux's guard.
- 2026-07-17: corrected `pane.graphics.set` placement uses the fzf preview's
  pane-relative column and grid dimensions, falling back to pane rows when fzf
  reports its `-200` row sentinel. Set, replacement, focus resize, and clear
  returned `ok`; the captured raster is crisp and confined. The previous
  host-wide frame was a placement error, not a stable v0.7.4 blocker.
- 2026-07-17: the user approved the reopened physical Alt navigation as working
  extremely well and rejected the native fzf image preview as glitchy and less
  polished than tmux.
- 2026-07-17: the Herdr Fish pane inherited `NO_COLOR=1`. The `ll` function
  delegates to eza without `--color=always`, so eza suppresses color; this is
  an environment/flag issue, not a Herdr renderer failure.
- 2026-07-17: the image-only retry replaced recursive terminal screenshots with
  three clean 1600×1000 PNG fixtures. The prototype serializes updates per pane,
  discards superseded workers, pre-fits native pixels to the preview cell box,
  refreshes on fzf resize, and clears on picker exit. Crisp placement and clear
  both passed, but 150 ms selection captures still showed the prior raster and
  focus/resize captures intermittently blacked most of the Ghostty client before
  recovering. Herdr v0.7.4 native preview therefore remains an important
  upstream feature gap, but the user explicitly accepts it as non-blocking for
  migration while a fix is unavailable; the approved Alt adapter was not
  modified.
- 2026-07-17: the user reclassified polished image-preview parity as important
  but optional for migration. Static crisp PNG rendering remains available;
  stale replacement and focus-redraw defects stay tracked for a future upstream
  retest and do not authorize changing production configuration by themselves.
- 2026-07-17: official releases, the newest preview, and the 20 post-v0.7.4
  master commits were reviewed. The only direct graphics fix is stream-specific;
  `pane.graphics.set` is unchanged and no release qualifies for another live
  retry. Image parity remains accepted deferred polish.
- 2026-07-17: the approved binding table was implemented only in the isolated
  prototype. `verify.sh` and `validate_bindings.sh` passed. Layout, pane, tab,
  process, zoom, and URL readbacks are recorded under `herdr/prototype/evidence`.
  A direct Ghostty trial was launched with real Neovim/fzf/Fish ownership and no
  global Herdr Alt collision; physical feel remains awaiting user confirmation.
- 2026-07-17: the user reported that none of the new application-aware Alt
  commands worked. Live diagnosis proved the helpers and environment were valid
  but Herdr's Kitty CSI-u events did not match Fish's legacy named Alt bindings.
  Prototype-only CSI-u aliases fixed `Alt-n/v/z/x` in the exact pane-send path.
  The regression also found that smart-close briefly saw its own `herdr pane
  process-info` probe as foreground work; it now ignores only that observer.
  `validate_bindings.sh` records the passing transport transitions.
- 2026-07-17: the user confirmed the transport fix but rejected the child pane
  environment: `Alt-n/v` opened bare Fish panes without the real prompt/config,
  and those panes lacked recursive Alt actions. The isolated prototype now uses
  `prototype_shell.sh` for every pane. Live readback proved `XDG_CONFIG_HOME`
  restored to `~/.config`, `TMUX` removed before the prompt, and both an
  `Alt-n` child and its nested `Alt-v` child running configured Fish with the
  adapter. No production Fish or tmux file changed.
- 2026-07-17: direct smart-close ownership moved from shell `Alt-x` to
  shell `Alt-q`. This matches the existing Neovim close-window mapping while
  keeping Neovim's `Alt-x` window exchange intact. Both legacy and Kitty CSI-u
  Fish bindings were updated; the exact transport regression removed its
  disposable pane with `Alt-q`, and no global Herdr Alt binding was added.
- 2026-07-17: final ownership validation passed in the open isolated Ghostty
  session. Fish `Alt-q` closed configured child pane `w1:pA` and changed pane
  count 4→3. With distinct `ALT_X_LEFT`/`ALT_X_RIGHT` Neovim sentinels,
  `Alt-x` retained two windows and exchanged the current window `1000→1002`;
  `Alt-q` then reduced the window count 2→1, leaving `ALT_X_LEFT`. These
  application-aware chords are approved; migration remains unauthorized.
- 2026-07-17: the searchable-picker review hardened its proof harness. PTY
  snapshots now wait for semantic stability without treating Herdr's animated
  Braille spinner as content churn; navigator checks distinguish result-tree
  rows from query text and exclude every wrong state; workspace, tab, and pane
  search are each covered; successful selections prove terminal return; and
  runtime-object IDs are identical before and after picker paths. Failed runs
  retain the last complete evidence file, cleanup preserves signal status and
  terminates disposable clients/servers, and successful evidence is bound to
  the exact config/client/validator hashes. Production configuration remains
  untouched, and migration remains unauthorized.
- 2026-07-18: the active tracker was reconciled with the final evidence. Visual
  density, physical navigation, and the application-owned `Alt-n/v/z` transports
  are approved. `prefix+Tab` now records the proven cross-workspace `last_pane`
  behavior while exact last-tab history remains preserved in the tab-lifecycle
  evidence. Only Codex has multi-agent compatibility evidence, so the other named
  agents remain a required partial row. Image lifecycle polish stays an accepted
  deferred gap, and migration remains unauthorized.
- 2026-07-18: the bounded multi-agent compatibility gate passed for Claude,
  OpenCode, AGY, and Gemini. Separate atomic evidence records deterministic
  detection, Herdr lifecycle ownership, all semantic states, real navigator
  visibility, installed version readback, and safe unsupported-agent behavior.
  The prior Codex evidence and production configuration remained unchanged;
  no integration was installed and migration remains unauthorized.
- 2026-07-18: real `prefix+u` PTY validation passed for zero, one, and multiple
  visible URLs, including punctuation normalization and newest-match selection.
  Application-owned `Alt-X` and `Alt-Ctrl-x` also passed through Herdr's Kitty
  CSI-u transport into Fish, with exact tab survival and process-death readback.
  Binding evidence is now atomic and hash-bound. Copy-mode `O` remains an
  upstream difference; production configuration and migration status did not
  change.
- 2026-07-18: remote attach passed through a disposable localhost OpenSSH
  server with temporary keys and isolated local/remote Herdr configuration. A
  real thin client started a compatible named v0.7.4 remote server with a live
  pane, detached cleanly, and failed closed against a closed endpoint without
  bootstrap or installation. This settles remote work and nested passthrough as
  a Herdr-native difference: use remote attach and keep experimental nesting
  disabled. macOS Remote Login, production configuration, and migration status
  did not change.
- 2026-07-18: the remaining optional legacy-key differences were converted
  from indirect partial claims into a hash-bound v0.7.4 capability audit.
  Rectangle selection, copy-line `Y`, marks, OSC 133 prompt jumps, cursor-local
  copy-mode `O`, and direct `Alt-Tab` were deterministically unavailable or
  retired in the official binary, with supported
  selection/paging/URL/last-pane replacements recorded and no input-emulation
  shims installed. The 2026-07-30 reviewed source build later resolved only
  copy-line `Y`; the other gaps remain.
- 2026-07-23: a live fzf-to-lower-pane handoff exposed that manually running
  `fish` inside a prototype pane dropped all `Alt-h/j/k/l` navigation because
  Fish bindings and functions are process-local. The prototype adapter now
  wraps nested Fish launches so they source the same application-aware
  bindings. The binding gate reproduces `fish` followed by `Alt-j`; a clean
  Ghostty trial physically exercised fzf `Alt-j`, nested-Fish `Alt-k`, fzf
  `Alt-h`, and Neovim edge `Alt-l`. Production Fish, tmux, Ghostty, and Neovim
  remain unchanged. Eddy confirmed the resulting physical navigation works
  well.
- 2026-07-23: staged daily-driver promotion is locally active. The pinned
  Herdr v0.7.4 binary is installed at `~/.local/bin/herdr`, the tracked
  `herdr/config.toml` is linked into `~/.config/herdr/config.toml`, and clean
  top-level Fish logins attach to the named `main` Herdr session. Tmux remains
  installed and unchanged. Use `herdr/tmux_fallback.sh` for a one-off,
  non-nested tmux window; use `herdr/set_default.sh tmux` for persistent
  rollback and `herdr/set_default.sh herdr` to restore Herdr. Run
  `herdr/verify.sh` and `fish/scripts/verify.sh` after startup changes.
- 2026-07-30: a reviewed private source build remains pinned to the exact
  annotated v0.7.4 tag object and peeled commit. Copy mode now aliases `a` and
  `i` to native `q` exit-without-copy and composes `Y` from native `V` whole-line
  selection plus `y` copy-and-exit. The source patch, patched file, Rust/Zig
  toolchains, and arm64 macOS binary are hash-verified; no input emulation,
  pane-history change, recovery change, tmux removal, or version upgrade is
  involved.
- 2026-07-27: project-oriented entry is complete. `Prefix+Shift+w` opens the
  Git repository/worktree picker inside the current Herdr session while native
  `Prefix+w` remains existing-workspace navigation. The implementation uses
  strict structured API and live-state readback, tokenless restart re-adoption,
  atomic session locking, and target-only verified rollback. Focused validation,
  full Herdr/Fish verification, and fresh closure review pass (Standards 0 /
  Fidelity 0). Herdr remains v0.7.4 with `pane_history = false`; tmux remains
  installed and available.
- 2026-08-05: v0.7.5 leaves the `pane.graphics.set` handler byte-identical but
  does reopen the deferred image prototype elsewhere. At the pinned tag object
  `99df3ac3` and commit `ef4c23f5` recorded in
  [`pins.env`](../../herdr/source-build/pins.env), `src/app/api/pane_graphics.rs`
  — which holds `handle_pane_graphics_set`, `set_pane_graphics_layer`, and
  `handle_pane_graphics_clear` — has the same Git blob
  `7851f69a8f55c948d68b8baefbd5c3b5c645f59f` as v0.7.4. That is a handler-blob
  claim only, not whole-subsystem parity, and the rest of the graphics path did
  move. `src/kitty_graphics.rs`, `src/server/headless/pane_graphics.rs`, and
  `src/server/render_stream.rs` now thread a `TabSurfaceView` argument instead of
  reading `app.view.pane_infos` directly; `TabSurfaceView` borrows that same
  `pane_infos` slice, so those three are the mechanical continuation of the
  `8dcb75a5` tab-surface extraction already reviewed on 2026-07-17.
  `src/api/server/pane_graphics_stream.rs` separately gained a peer-disconnect
  (EINVAL) race fix. The material change is elsewhere: vendored
  `libghostty-vt` kitty graphics storage adds process-global **generation
  stamps** (`graphics_storage.zig`, +299 lines), and `src/ghostty/mod.rs`
  (+390/-140) consumes them as texture-cache staleness keys. Upstream documents
  the image stamp as changing on retransmission of the same image ID, so
  "texture caches must key staleness on this value rather than on size
  heuristics" — which is exactly the Round 8 stale-raster-on-replacement seam.
  The 2026-07-17 retry trigger (an upstream change that explicitly touches
  `pane.graphics.set` replacement or focus/resize composition) is therefore
  **met** for the replacement/cache half. The Round 8 gaps remain unretested and
  the black focus redraw is untouched by this release. The retry decision is
  settled in [v0.7.5 retry decision](#v075-retry-decision-2026-08-05): retry the
  replacement gap on the existing harness, keep the focus-redraw gap deferred.
