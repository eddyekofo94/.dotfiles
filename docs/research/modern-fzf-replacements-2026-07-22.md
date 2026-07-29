# Modern FZF replacements for this Fish/Ghostty/tmux setup

**Research date:** 2026-07-22
**Environment assessed:** macOS, Fish, Ghostty 1.3.x, tmux 3.7
**Question:** Is there a modern, feature-rich picker that can replace FZF, including reliable high-quality image previews?

## Bottom line

There is no credible one-for-one replacement for the whole current FZF surface.

The best direction is a **hybrid**:

1. **Pilot Television (`tv`) as the general picker** for ordinary files, text, Fish history, environment/process lists, and Git channels. It is the closest modern alternative: native Fish `Ctrl-T`/`Ctrl-R`, multi-select, stdout return, custom sources/previews/actions, reloadable sources, and a maintained channel ecosystem.
2. **Use Yazi for image-heavy file browsing/selection.** It is a file manager/chooser, not a universal stream picker, but it explicitly owns image detection/rendering for Ghostty via Kitty Unicode placeholders and documents the required tmux passthrough setup. This is the strongest candidate for avoiding the current “picker launches an external image helper and hopes geometry stays synchronized” seam.
3. **Keep FZF during migration and for the advanced programmable workflows** (`reload`, `become`, transforms, query-driven grep, NUL-safe streams, arbitrary event bindings). Replace each function only after behavioral parity is proved. Do not replace FZF with Skim merely to solve images: Skim has the same external-preview ownership model and does not itself solve Ghostty/tmux graphics.

If the only objective is to repair image previews, replacing the fuzzy matcher is the wrong boundary. The decisive difference is **who owns the graphics lifecycle**. Yazi and Broot render images themselves; Television, Skim, and FZF run preview commands whose graphics must survive the picker/tmux/terminal interaction.

## Required coverage

The replacement baseline is broader than file search:

- Fish command-line insertion for `Ctrl-P`/`Ctrl-T`
- Fish history on `Ctrl-R`
- Git status on `Ctrl-G` with diff preview, plus log and reflog
- generic variables, environment, and process pickers
- multi-select, toggle, select all, deselect all
- custom actions: open, copy path, copy contents, grep handoff
- text, directory, Git diff, PNG, and JPEG previews
- preview paging
- query-driven source reload and process replacement (`become`-style handoff)
- NUL-delimited input/output and ANSI-aware display
- Fish-aware preview commands and stdout/return-file handoff
- acceptable startup/search performance and active maintenance
- stable resizing and high-quality images through Ghostty + tmux
- migration of `ff`, `fcd`, `fif`, `fstage`, `fpwd`, `gitog`, completion, and the existing specialized bindings

## Requirement matrix

Legend: **Yes** = first-party support; **Partial** = wrappers/custom configuration or narrower semantics; **No** = wrong tool class or no documented equivalent; **External** = delegates the feature to another command.

| Requirement | FZF 0.74.1 | Television 0.15.9 | Skim 5.4.0 | Yazi 26.5.6 | Broot 1.58.0 |
|---|---|---|---|---|---|
| Tool class | General picker/toolkit | General picker with channels | General picker, FZF-like | File manager/chooser | Tree navigator/file manager |
| Fish `Ctrl-T`, `Ctrl-R` | Yes | Yes | Yes | No; wrapper/keybind work | No; Fish `br` wrapper is for shell-state handoff |
| `Ctrl-P` command-line insertion | Partial: Fish binding wrapper | Partial: bind its Fish completion function | Partial: bind its Fish widget | Partial: chooser-file wrapper | Partial: print-path wrapper |
| Arbitrary stdin/stdout picker | Yes | Yes | Yes | No | Partial: path selector only |
| Multi-select | Yes | Yes | Yes | Yes, file selections | Yes, staging area |
| Select/deselect all | Yes | Not clearly documented as built-in; custom action/wrapper risk | Yes | Yes | Yes within staging/tree semantics |
| Custom sources | Yes | Yes, channels/ad-hoc source commands | Yes | File/search/plugin model, not arbitrary stream parity | Tree/search model, not arbitrary stream parity |
| Custom actions/open/copy | Yes, event actions | Yes, named actions with `execute`/`fork` modes | Yes, `--bind` execute actions | Yes, openers/keymaps/plugins | Yes, verbs and shortcuts |
| Live source reload | Yes | Yes, `reload_source` | Partial: interactive command mode; no demonstrated full FZF event parity | No general stream reload | No general stream reload |
| `become`/process handoff | Yes | Partial: `execute` action exits into a command, but parity must be tested | Execute actions; no demonstrated exact `become` parity | Open/shell actions, not general picker parity | `from_shell`/leave verbs, not general picker parity |
| Transform/event programming | Yes, event-driven transforms | Partial: channel templates/actions; much less general | Partial: bind actions; less complete than FZF | Plugins/keymaps, file-manager context | Verbs, file-manager context |
| ANSI input | Yes | Yes (`source.ansi`) | Yes | N/A for arbitrary streams | N/A for arbitrary streams |
| NUL input/output | Yes (`--read0`, `--print0`) | Not established in first-party docs; treat as a blocker until proved | FZF-like, but current public README does not establish the needed end-to-end NUL contract | Chooser file uses line-separated paths | Print-path/verbs; not a generic NUL-stream picker |
| Text/directory/diff preview | External preview command | External preview command | External preview command | Built-in previewer/plugin system | Built-in text/image preview and transformers |
| Preview paging | Yes | Yes | Yes | Yes | Yes, focused preview panel |
| High-quality PNG/JPEG | External helper | External helper; official images channel uses Chafa | External helper | **Yes, built in** | **Yes, built in via Kitty graphics** |
| Explicit Ghostty support | No; helper-dependent | No first-party graphics ownership | No; helper-dependent | **Yes: Kitty Unicode placeholders** | Not explicit; Kitty detection/config may need forcing |
| Explicit tmux image path | Helper-dependent | Helper-dependent | Helper-dependent | **Yes: passthrough and environment documented** | Yes: Unicode display mode works with tmux; nested-depth variable documented |
| Resize ownership | Picker layout + external helper | Picker layout + external helper | Picker layout + external helper | Owns preview sizing and terminal pixel bounds | Owns preview panel/graphics display |
| Fish shell return path | Yes | Yes, stdout | Yes, stdout | Yes, `--chooser-file`/`--cwd-file` wrappers | Yes, `:print_path`/`br` wrapper |
| Git/history/env/process coverage | Custom functions | Strong built-in/community channel fit | Custom commands/functions | File-oriented; plugins required | Git/file-oriented; not history/env/process picker |
| Current maintenance signal | 0.74.1, 2026-07-18 | 0.15.9, 2026-06-14 | 5.4.0, 2026-07-21 | 26.5.6, 2026-05-05 | 1.58.0, 2026-07-10 |
| Migration effort from this repo | Baseline | Medium-high | Medium | High if misused as total replacement; low as image chooser | High as total replacement; medium as file navigator |

## Candidate findings

### 1. Television (`tv`): best modern general-picker candidate

Television describes itself as a fast, portable fuzzy finder over files, text, Git repositories, environment variables, and arbitrary piped data. Its quickstart documents multi-select, clipboard copy, preview paging, stdout selection, ad-hoc source and preview commands, and native Fish initialization with `Ctrl-T` smart completion and `Ctrl-R` history search. [Official quickstart](https://alexpasmantier.github.io/television/getting-started/quickstart/)

Its channel model is a good conceptual match for this dotfiles setup: each picker can own a source, display/output transformation, preview, bindings, and named actions. The official community channel catalog includes Fish history, environment variables, Git files/diffs, processes and many command-oriented examples; it also demonstrates action chaining with `reload_source`. [Official Unix channel catalog](https://alexpasmantier.github.io/television/community/channels-unix/)

The main limitation is image ownership. The official image channel calls `chafa`; Television does not claim to own Kitty graphics placement, image deletion, or resize. Therefore a Television migration may improve configuration ergonomics but does **not** by itself solve the Ghostty/tmux image regression. [Official images channel](https://alexpasmantier.github.io/television/community/channels-unix/#images)

Television also has less demonstrated low-level stream/event coverage than FZF. In particular, first-party documentation found for this report does not establish NUL-safe input/output or exact equivalents for FZF's query/event transforms and `become`. Those are migration gates, not details to assume.

Health: latest release **0.15.9**, published 2026-06-14. [Official release](https://github.com/alexpasmantier/television/releases/tag/0.15.9)

**Assessment:** Best candidate for a controlled general-picker pilot; not yet a full replacement and not an image fix.

### 2. Skim (`sk`): closest CLI shape, weakest reason to migrate

Skim is a Rust fuzzy finder with Fish/Bash/Zsh shell bindings. Its official README documents Fish `Ctrl-T` file selection, `Ctrl-R` history, Alt-C directory selection, multi-select, ANSI, preview windows, dynamic command mode, and programmable binds such as select-all/deselect-all and external execution. [Official README](https://github.com/skim-rs/skim#readme)

That makes Skim the lowest-conceptual-change substitute. It also means it inherits the relevant architectural weakness: image previews are external preview commands, not a first-party graphics subsystem. Moving from `fzf + image helper` to `sk + image helper` changes the fuzzy picker but leaves the failure-prone terminal graphics boundary intact.

Its modern 5.x series is active, but compatibility should not be inferred from borrowed FZF syntax. The current advanced Fish functions rely on FZF-specific reload/become/transform behavior and must be ported and tested individually.

Health: latest release **5.4.0**, published 2026-07-21. [Official release](https://github.com/skim-rs/skim/releases/tag/v5.4.0)

**Assessment:** Viable fallback general picker, but not a compelling migration and not a solution to images.

### 3. Yazi: strongest image owner, not a universal picker

Yazi is a file manager with selection, visual selection, select-all/invert, copy-path actions, openers, shell commands, name/content search, tabs, and a `--chooser-file` return path suitable for shell/editor wrappers. [Official quickstart](https://yazi-rs.github.io/docs/quick-start/) [Official chooser example](https://yazi-rs.github.io/docs/tips/#file-tree-picker-in-helix) [Official keymap/action reference](https://yazi-rs.github.io/docs/configuration/keymap/)

For this incident, Yazi has the strongest first-party evidence. Its image documentation explicitly lists **Ghostty -> Kitty Unicode placeholders -> built-in support**, documents the three tmux settings (`allow-passthrough`, `update-environment TERM`, `update-environment TERM_PROGRAM`), explains resize bounds, and exposes `yazi --debug` to report the selected adapter. [Official image-preview documentation](https://yazi-rs.github.io/docs/image-preview/)

Yazi cannot replace arbitrary history/env/process/Git-log stream pickers. It is also revealing that its own quick subtree navigation integrates FZF, and its installation docs list FZF as an optional dependency for that feature. [Official built-in FZF plugin](https://yazi-rs.github.io/docs/plugins/builtins/#fzflua) [Official dependencies](https://yazi-rs.github.io/docs/installation/)

Health: latest release **26.5.6**, published 2026-05-05. [Official release](https://github.com/sxyazi/yazi/releases/tag/v26.5.6)

**Assessment:** Recommended image/file-browser companion and chooser; explicitly not the general FZF replacement.

### 4. Broot: capable tree navigator with its own graphics

Broot offers fuzzy/regex/content search, Git status filtering, synchronized previews, custom verbs, stdout path selection, a Fish-compatible `br` wrapper, multi-file staging, and built-in high-resolution Kitty graphics. [Official overview](https://dystroy.org/broot-master/) [Official launch/return-path docs](https://dystroy.org/broot/launch/) [Official verbs](https://dystroy.org/broot/conf_verbs/)

Unlike FZF/Skim/Television, Broot owns image display. Its configuration exposes Kitty transfer media and a `unicode` display method described as the flexible method that works with tmux; it also documents nested tmux depth. [Official preview configuration](https://dystroy.org/broot/conf_file/#preview) [Official launch environment](https://dystroy.org/broot/launch/#environment-variables)

However, first-party compatibility text names Kitty and WezTerm rather than Ghostty, so the exact Ghostty detection path must be proved rather than assumed. More importantly, Broot is a tree/file navigator, not an arbitrary stream picker for Fish history, variables, processes, log/reflog, or query-driven grep handoffs.

Health: latest release **1.58.0**, published 2026-07-10. [Official release](https://github.com/Canop/broot/releases/tag/v1.58.0)

**Assessment:** Worth comparing with Yazi for file-tree navigation, but Yazi has much stronger explicit Ghostty evidence.

### 5. FZF remains the programmability baseline

FZF's current documentation calls it a general-purpose fuzzy finder and interactive terminal toolkit, with an event-driven architecture, Fish integration, arbitrary stdin/stdout, NUL-safe output, multi-select, `become`, reload, transform actions, preview commands, and tmux popup support. Those capabilities closely match why the local configuration accumulated so many specialized functions. [Official README](https://github.com/junegunn/fzf#readme)

Its weakness here is not matching or maintenance; it is that high-quality image preview is delegated to an external command. FZF's own image-preview examples likewise route through helpers. That separation makes geometry, clearing, transfer mode, resize, tmux passthrough, and terminal detection a multi-owner protocol.

Health: latest release **0.74.1**, published 2026-07-18. [Official release](https://github.com/junegunn/fzf/releases/tag/v0.74.1)

## Recommended migration experiment

Do not attempt a big-bang replacement. Run one bounded, reversible comparison:

1. Keep all current FZF functions available.
2. Add an isolated Television pilot for only:
   - file insertion,
   - Fish history,
   - Git status with diff preview.
3. Add an isolated Yazi chooser for file/image browsing, using `--chooser-file`, and validate it in the exact Ghostty 1.3.x + tmux 3.7 environment.
4. Test Yazi's adapter report, resizing, rapid image traversal, PNG/JPEG aspect ratio, selection return, cancellation, and stale-image cleanup.
5. Compare Television against the current FZF behavior for quoting, multi-select, ANSI, command-line cursor insertion, output with spaces/newlines, and Git actions.
6. Keep `fif`/query-reload, process/environment utilities, reflog/log, and NUL-sensitive flows on FZF until explicit parity tests exist.

### Decision rule

- If Yazi is stable through tmux while the generic Television workflows pass: adopt the **Television + Yazi + residual FZF** hybrid and migrate incrementally.
- If Television cannot meet output/event semantics: keep FZF as the general picker and add only Yazi for images.
- If Yazi also exhibits the same visible-geometry corruption in the exact environment: the remaining fault is below the picker abstraction (Ghostty/tmux/protocol/environment), and changing fuzzy finders should stop.

## Answer to the original question

Yes, modern alternatives exist, but none replaces everything:

- **Television** is the best modern general-picker candidate.
- **Yazi** is the best fit for robust high-quality Ghostty/tmux image browsing.
- **Broot** is another strong graphical tree navigator.
- **Skim** is the closest FZF-shaped alternative but offers no image-architecture advantage.
- **FZF** should remain installed until the advanced local workflows have proven replacements.

The recommended answer is therefore **hybrid, not direct replacement**.
