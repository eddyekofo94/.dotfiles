# Can a modern picker replace `fif`?

**Date:** 2026-07-23
**Scope:** Replace the exact interaction contract in `fish/functions/fif.fish`, not merely provide generic file search.
**Conclusion:** There is no zero-change drop-in. **Skim is the only credible shell-level parity prototype.** **fff.nvim** is the strongest experiential replacement if `fif` may become Neovim-native. **ugrep's `ug -Q`** is the best simpler standalone content-search alternative if the dual-query workflow and custom actions can be dropped.

## The contract that matters

`fif` currently combines behaviors that most candidates split apart:

- live ripgrep only after two query characters, with optional symlink following;
- `Ctrl-G` toggling between a ripgrep query and a fuzzy filename filter while preserving both queries;
- `file:line:column` results, a horizontally focused preview, and exact editor positioning;
- multi-select with select-and-advance, preview paging, open, copy-path, and copy-content actions;
- clean terminal replacement/return behavior and isolation from global FZF configuration.

The separate, preserved source and filter queries are the decisive requirement.

## Fit against `fif`

| Candidate | Live content search | Preserved source + filter queries | Match-level line/column | Selection/actions | Verdict |
|---|---|---|---|---|---|
| **Skim 5.4** | Yes: interactive `--cmd` can run ripgrep from `{q}` | **Yes:** first-party tests show command and normal queries surviving mode toggles | Can retain the existing ripgrep row schema; preview helper needs dimension adaptation | Multi-select, toggle-and-advance, select-all, preview paging, execute actions | **Prototype first** |
| **fff.nvim 0.10.1** | Yes, using FFF's indexed content engine | No: plain/regex/fuzzy are modes of one content query | **Yes:** structured line and column, editor-native opening | Preview, multi-select, quickfix, split/tab actions | Best if moving the experience into Neovim |
| **ugrep 7.8 `ug -Q`** | **Yes:** cancellable interactive search as the query changes | No; fuzzy matching is not a second filter over retained results | Reports line and column, but documented viewer handoff is line-oriented | Built-in viewer, paging, select/all; fewer arbitrary actions and selections reset on a new search | Best simplified standalone replacement |
| Television 0.15 | No for this purpose: its text channel runs static `rg .`, then fuzzy-filters the loaded output | No | Built-in text channel is line-aware, not column-aware | Strong custom actions and selection | Reject for `fif`; still useful as a general picker |
| Broot 1.58 | Native content search | No | File/tree-oriented; custom verbs expose file and line, not column | Staging and custom file actions | Wrong result abstraction |
| Yazi 26.5 | Can launch ripgrep search | No demonstrated equivalent | File results rather than individual match rows | Excellent file selection and preview | Wrong result abstraction |

## Why Skim is the narrow recommendation

Skim's interactive mode supports a command query (`-i -c 'rg ... {q}'`) and a normal fuzzy query. Its first-party `toggle_interactive_queries` test and snapshots demonstrate that the two query buffers remain distinct while toggling. That is the one unusual `fif` behavior the other candidates do not reproduce. Skim also exposes the familiar FZF-style action vocabulary needed for selection and preview navigation.

It is not a drop-in replacement:

- the two-character ripgrep gate must be retained explicitly and proved under real interaction;
- the existing preview helper reads FZF dimension variables, so Skim's preview geometry must be adapted and tested;
- Skim does not document FZF's `become` action, so exact line/column editor handoff needs a wrapper or execute-and-abort pattern;
- selection survival across reloads and mode toggles must be verified rather than assumed.

## Where FFF fits

The linked [FFF repository](https://github.com/dmtrKovalenko/fff) is especially compelling because `fff.nvim` has `live_grep()`, structured `line_number` and `col` results, integrated preview, multi-selection, quickfix export, and exact editor-native navigation. It is also current: release `v0.10.1` was published 2026-07-20.

FFF's core is presented as a library, not a standalone interactive shell picker. Building a new terminal UI on its Rust/C/Python/JavaScript bindings could recreate `fif`, but that is a new picker product rather than a bounded migration. The sensible FFF experiment is therefore an editor-native `:FffLiveGrep` workflow, not a transparent shell replacement.

## Recommended next experiment

Add a parallel, disposable `fif-sk` prototype; do not replace `fif` or its binding yet. It passes only if side-by-side automated and tmux/manual checks prove:

1. ripgrep never runs at zero or one character and starts at two;
2. `Ctrl-G` preserves independently edited ripgrep and fuzzy queries across repeated toggles;
3. selections, select-and-advance, select-all, and preview paging match current behavior;
4. long lines and UTF-8 matches point at the correct column within the actual preview width;
5. open reaches the exact line and column, copy actions parse selected rows correctly, and terminal state returns cleanly;
6. path validation, `--follow`, interruption cleanup, and slow-Fish-config isolation continue to pass.

If any gate fails, retain FZF for `fif`. Separately, fff.nvim is worth evaluating as an optional Neovim search path; `ug -Q` is worth trying only if a deliberately simpler workflow is acceptable.

## Primary sources

- Skim: [README](https://github.com/skim-rs/skim/blob/master/README.md), [manual](https://github.com/skim-rs/skim/blob/master/man/man1/sk.1), [binding tests](https://github.com/skim-rs/skim/blob/master/tests/binds.rs)
- FFF / fff.nvim: [official repository and README](https://github.com/dmtrKovalenko/fff), [v0.10.1 release](https://github.com/dmtrKovalenko/fff/releases/tag/v0.10.1)
- ugrep: [official site](https://ugrep.com/), [official README](https://github.com/Genivia/ugrep/blob/master/README.md), [v7.8.2 release](https://github.com/Genivia/ugrep/releases/tag/v7.8.2)
- Television: [text channel](https://github.com/alexpasmantier/television/blob/main/cable/unix/text.toml), [actions](https://github.com/alexpasmantier/television/blob/main/docs/reference/02-actions.md), [channels](https://github.com/alexpasmantier/television/blob/main/docs/user-guide/01-channels.md)
- Broot: [navigation and content search](https://dystroy.org/broot/navigation/), [verbs](https://dystroy.org/broot/conf_verbs/), [staging](https://dystroy.org/broot/staging-area/)
- Yazi: [quick start](https://yazi-rs.github.io/docs/quick-start/), [keymap actions](https://yazi-rs.github.io/docs/configuration/keymap/)
