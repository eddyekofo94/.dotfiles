# What could replace `fif`?

**Date:** 2026-07-23

**Scope:** The interaction contract in `fish/functions/fif.fish`, with particular attention to [FFF](https://github.com/dmtrKovalenko/fff) and [ugrep's query UI](https://ugrep.com/).

**Decision:** Nothing reviewed is an exact replacement. Strongest experiential replacement: `fff.nvim`, when search may begin and end in Neovim. Strongest ready-made standalone alternative: `ugrep -Q`. FFF's core could do substantial backend work for a shell-independent successor, but it would still require a custom resident adapter and terminal UI.

## What “replace `fif`” actually means

The current command is more than fuzzy file selection. Its local implementation and tests establish this contract:

1. update a live content search while typing, but do not start ripgrep before two characters;
2. switch with `Ctrl-G` to a separate fuzzy filter over the current match rows, preserving both query buffers across repeated toggles;
3. keep `file:line:column` match identity and show a preview focused on the matching column;
4. support multi-select, select-and-advance, select-all, preview paging, OS-open, copy-path, and copy-content actions;
5. open the editor at the exact file, line, and column;
6. remain usable independently of one interactive shell and return terminal state cleanly.

The preserved **content query plus result-filter query** is the rarest capability. A tool that merely searches file contents quickly does not yet replace `fif`.

## Candidate fit

| Candidate | Live content query | Separate preserved fuzzy filter | Two-character gate | Match preview / position | Multi-select and actions | Shell-independent | Assessment |
|---|---|---|---|---|---|---|---|
| **fff.nvim** | Yes, through `live_grep()` and FFF's indexed content engine | No documented second retained filter buffer | Not equivalent to the current explicit gate | Strongest fit: structured line and column, editor-native preview and navigation | Multi-select, quickfix, split and tab workflows; exact shell copy/open bindings are not the same contract | No; Neovim is the frontend | **Best experiential replacement if Neovim-first** |
| **FFF core plus a new TUI** | Yes; the core can supply indexed search and bindings | Possible, but the adapter/TUI must own and preserve both states | Must be implemented by the adapter | Structured matches can carry line and column; preview geometry remains frontend work | Must be implemented | Potentially yes | **Useful backend, not a replacement application** |
| **`ugrep -Q`** | Yes; its query UI cancels and refreshes searches as input changes | No; its fuzzy facilities are not a retained filter over a separate content result set | No matching native contract; a wrapper would have to gate launch/search | Reports match positions and has a built-in viewer, but documented editor/viewer handoff is line-oriented rather than the current exact column workflow | Selection, select-all and paging exist; fewer programmable open/copy actions, and a new search resets selections | Yes | **Best standalone simplification** |
| **Television** | Not for this contract: the stock text channel runs a source command and fuzzy-filters its output | No | Could be approximated only with custom channel logic | Text results are line-aware, not an equivalent column-focused match model | Strong actions and selection | Yes | Good general picker, weak `fif` replacement |
| **Broot** | Has native content search | No | No equivalent established | Oriented around files/tree navigation; verbs expose a file and line, not the full match-row contract | Staging and custom file actions are strong | Yes | Wrong abstraction for a match-centric search UI |

## Could FFF do the heavy lifting?

Yes—on the expensive search side. FFF already provides the fast indexed content engine and structured match locations that make `fff.nvim` feel unusually immediate. Its current Neovim frontend also demonstrates that the engine can support previews, exact navigation, multiple selections, and useful result actions. That makes FFF a credible engine for a future `fif` successor.

It does **not** provide a standalone terminal picker equivalent to `fif`. The core is exposed as a library with language bindings; it does not own a persistent shell-facing interaction loop, the two independent query buffers, the two-character policy, preview geometry, clipboard/OS-open commands, or terminal cleanup. Reusing it outside Neovim therefore means building a small picker product around it—not substituting one command in `fif.fish`.

The practical FFF choices are:

- adopt `fff.nvim` as the primary workflow and accept that Neovim becomes the shell-independent *destination and frontend*; or
- build a resident FFF-backed service plus a terminal UI/adapter, retaining the current semantics explicitly.

The first is bounded and testable. The second could achieve close parity, but is custom software with ongoing maintenance.

## Why `ugrep -Q` deserves the first standalone trial

`ugrep -Q` already owns the live search loop, result list, viewer, navigation, paging, selection, and terminal UI. Unlike a generic fuzzy picker wired to repeated ripgrep processes, it is designed as an interactive content-search application. It can therefore replace much of the process orchestration currently split between Fish, ripgrep, FZF, and preview helpers.

The cost is deliberate simplification: it does not reproduce the independently preserved fuzzy-filter mode, the exact action vocabulary, or proven `file:line:column` editor handoff. If those are non-negotiable, `ugrep -Q` is an alternative search command, not a replacement. If speed, shell independence, and a coherent content-search TUI matter more, it is the strongest existing standalone candidate.

## Recommendation

Do not replace `fif` globally. Evaluate two parallel paths against the same fixtures:

1. **Experience path:** try `fff.nvim` for real search sessions and judge whether starting in Neovim eliminates the need for shell-level open/copy behavior.
2. **Standalone path:** try `ugrep -Q` and measure how often the missing preserved fuzzy filter and exact actions interrupt work.

FFF core should only become an implementation target if both ready-made experiences fail and the dual-query contract remains important enough to justify maintaining a custom frontend. Television and Broot can absorb other picker/navigation jobs, but neither should carry this particular function.

An acceptance comparison must cover the current two-character gate, repeated `Ctrl-G` query preservation, UTF-8 and long-line column positioning, multi-selection, every open/copy action, exact editor location, interruption cleanup, and launch from Fish and at least one other shell. Until a candidate passes those checks, `fif` remains the reference implementation.

## Evidence

Local behavior and regression coverage:

- [`fish/functions/fif.fish`](../../fish/functions/fif.fish)
- [`fish/functions/_fif_preview.fish`](../../fish/functions/_fif_preview.fish)
- [`fish/functions/_fif_edit_match.fish`](../../fish/functions/_fif_edit_match.fish)
- [`fish/functions/_fzf_file_picker_common_opts.fish`](../../fish/functions/_fzf_file_picker_common_opts.fish)
- [`fish/tests/fif_integration.sh`](../../fish/tests/fif_integration.sh)
- [`fish/tests/fif_real_fzf.sh`](../../fish/tests/fif_real_fzf.sh)

Primary upstream sources:

- FFF / fff.nvim: [official repository and README](https://github.com/dmtrKovalenko/fff)
- ugrep: [official site](https://ugrep.com/) and [official README](https://github.com/Genivia/ugrep/blob/master/README.md)
- Television: [official text channel](https://github.com/alexpasmantier/television/blob/main/cable/unix/text.toml), [actions](https://github.com/alexpasmantier/television/blob/main/docs/reference/02-actions.md), and [channels](https://github.com/alexpasmantier/television/blob/main/docs/user-guide/01-channels.md)
- Broot: [content navigation](https://dystroy.org/broot/navigation/), [verbs](https://dystroy.org/broot/conf_verbs/), and [staging](https://dystroy.org/broot/staging-area/)
