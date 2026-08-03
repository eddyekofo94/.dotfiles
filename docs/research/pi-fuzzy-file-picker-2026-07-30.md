# Pi fuzzy file picker research

**Research date:** 2026-07-30  
**Target:** the isolated, checksum-pinned Pi 0.82.1 pilot in `pi/`  
**Question:** what Pi does today, which extension/package seams are supported,
and what should replace its weak default file picker without breaking the
pilot's isolation or reviewed-code boundary.

> **Decision override (2026-07-30):** After reviewing the alternatives, Eddy
> explicitly selected the upstream `@ff-labs/pi-fff` Pi extension. The pilot
> therefore pins version 0.10.1 in `tools-and-ui` mode and isolates its package
> and databases. The repository-owned native-fzf recommendation below is
> retained as the research conclusion it superseded, not the active decision.

## Recommendation

Do **not** install a third-party Pi package into the pilot.

Build one small, repository-owned Pi extension that launches the already
installed native `fd` + `fzf` + `bat` stack, inserts the selected path as a
proper Pi `@file` reference, and has no package manager, arbitrary shell
configuration, background index, database, or agent-tool changes.

The desired interaction is:

1. `@` opens the real interactive `fzf` selector, not Pi's small autocomplete
   list.
2. `fd` supplies project files while respecting `.gitignore` and excluding
   `.git`.
3. `fzf` owns subsequence matching, ranking, scrolling, and multi-select.
4. `Ctrl-P` / `Ctrl-N` move up and down; Enter accepts; Escape returns to Pi
   unchanged.
5. A fixed `bat` preview shows the focused file.
6. One or more accepted paths are inserted without submission as `@path` or
   `@"path with spaces"`.
7. `/file` or `Ctrl-Shift-F` remains a fallback entry point if raw `@`
   interception proves unreliable in physical Ghostty testing.

Pi's first-party extension APIs support both required seams:
`ctx.ui.addAutocompleteProvider()` can wrap or replace `@` completion, and
`ctx.ui.custom()` can temporarily stop/restart the TUI while an interactive
terminal process owns the screen. Pi ships an official interactive-shell
example that demonstrates the latter lifecycle.
[Pi autocomplete-provider API](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/docs/extensions.md#autocomplete-providers)
[Pi interactive-shell example](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/examples/extensions/interactive-shell.ts)

This is preferable to vendoring a general picker package because it preserves
the pilot's exact scope: one human-facing file-reference picker, not a new
configuration language, shell execution surface, search-tool replacement, or
persistent indexing subsystem.

## What Pi 0.82.1 does now

Pi documents two separate editor behaviors:

- typing `@` searches project files;
- Tab completes a path-like token.

[Pi 0.82.1 usage](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/docs/usage.md)

The source shows why the `@` experience feels only partly fuzzy:

- Pi starts `fd` with the typed query as a regular-expression/path filter;
- the scan is capped at 100 results;
- Pi then gives only exact filename, filename-prefix, filename-substring, and
  full-path-substring scores;
- zero-score candidates are discarded;
- only the top 20 items reach the autocomplete list.

The query therefore must already survive `fd` and Pi's substring scoring.
Non-contiguous shorthand such as `inxts` does not behave like native fzf's
subsequence search for `index.ts`.
[Pi 0.82.1 `fd` walk](https://github.com/earendil-works/pi/blob/v0.82.1/packages/tui/src/autocomplete.ts#L123-L217)
[Pi 0.82.1 scoring and result caps](https://github.com/earendil-works/pi/blob/v0.82.1/packages/tui/src/autocomplete.ts#L695-L768)

Pi's ordinary non-`@` Tab completion is different again: it reads one
directory, keeps entries whose basename starts with the typed prefix, and sorts
directories before files. It is path completion, not a project-wide fuzzy
picker.
[Pi 0.82.1 path completion](https://github.com/earendil-works/pi/blob/v0.82.1/packages/tui/src/autocomplete.ts#L559-L693)

The installed pilot is exactly Pi 0.82.1. The tagged source inspected here is
commit `b4f293684bba718d59cc1157679bcf6157b3a7f5`, matching the repository's
version pin. The machine already has:

```text
fzf 0.74.0 (Homebrew)
fd 10.4.2
bat 0.26.1
ripgrep 15.2.0
```

No new system dependency is needed for the recommended picker.

## Supported extension and package seams

Pi supports four relevant resource routes:

- a local extension path in `settings.json`;
- a local package directory;
- a versioned npm package;
- a git package pinned to a tag or commit.

Local extension paths are loaded in place. Pi packages can bundle extensions,
skills, prompts, and themes; npm and git packages install dependencies. Pi's
docs explicitly warn that packages and extensions execute with the user's full
permissions.
[Pi package sources and installation](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/docs/packages.md#install-and-manage)
[Pi package dependencies](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/docs/packages.md#dependencies)

Project trust is only an input-loading gate, not a sandbox. Once loaded, a Pi
extension is an in-process TypeScript module with the same filesystem and
process authority as Pi itself.
[Pi 0.82.1 security model](https://github.com/earendil-works/pi/blob/v0.82.1/packages/coding-agent/docs/security.md)

The current pilot deliberately:

- pins Pi to 0.82.1;
- loads only repository-listed extensions and curated skills;
- rejects unreviewed global extension inventory;
- disables project trust by default;
- excludes third-party Pi packages from the settled pilot scope.

The compatible seam is therefore a new file under `pi/extensions/`, explicitly
listed in `pi/settings.json`, covered by the existing install/isolation checks,
and reviewed as local production code. `pi install ...` is not compatible with
the current boundary.

## Candidate assessment

### 1. `pi-fzfp` 2.5.0

This is the closest package to Pi's existing `@file` behavior. It wraps Pi's
autocomplete provider, uses `fd` for candidates, and calls external
`fzf --filter` for real subsequence ranking. Non-`@` completion delegates to
Pi. The current upstream source has 27 focused tests covering prefixes,
directories, deep files, caching, and real `fd`/`fzf` integration.
[Pi package registry entry](https://pi.dev/packages/pi-fzfp)
[Upstream source](https://github.com/burneikis/pi-fzfp)
[Provider implementation at inspected commit](https://github.com/burneikis/pi-fzfp/blob/00d0190e69544c5f0008178df38376f318eb2978/provider.ts)

Strengths:

- small source surface and no runtime npm dependencies;
- shell-free `spawnSync` argv calls in current upstream;
- external fzf supplies correct ranking;
- preserves Pi's normal completion behavior outside `@`.

Limits for this pilot:

- `fzf --filter` is **non-interactive**; Pi's original small autocomplete list
  remains the UI, with no native fzf scrolling or preview;
- the exact published 2.5.0 tarball imports the former
  `@mariozechner/pi-*` package names, while Pi 0.82.1's package-author guidance
  names `@earendil-works/pi-*`;
- the published source reads `~/.pi/agent/.fzfpignore` directly, outside this
  pilot's isolated `PI_CODING_AGENT_DIR`;
- upstream invokes synchronous scans/ranking on the editor path and can return
  every match;
- the package is third-party code, contrary to the current pilot decision.

Verdict: useful reference implementation for matching semantics, but it does
not provide the “proper picker” interaction being requested and should not be
installed as-is.

### 2. `pi-fzf` 0.9.0

This package provides a real Pi overlay selector with fuzzy filtering,
preview, multi-select, configurable list commands, actions, and shortcuts. Its
name is slightly misleading: the UI uses the JavaScript `fzf` library, not the
installed native `fzf` executable.
[Pi package registry entry](https://pi.dev/packages/pi-fzf)
[Upstream source](https://github.com/kaofelix/pi-fzf)
[Selector implementation at inspected commit](https://github.com/kaofelix/pi-fzf/blob/dd0ef2eed8725ed10aa45a5e87114a8719f69540/selector.ts)

Strengths:

- substantially better visual picker than Pi's autocomplete list;
- previews, scrolling, multi-select, and custom placement;
- its selector follows Pi's configured `tui.select.up/down` bindings, so the
  pilot's `Ctrl-P` / `Ctrl-N` bindings would work.

Reasons to reject it for this pilot:

- it reads arbitrary `.pi/fzf.json` files itself from each project, outside
  Pi's normal resource-loader trust decision;
- `list`, preview, and bash actions run through `bash -c`;
- `{{selected}}` is raw text replacement with no shell escaping, so hostile or
  merely unusual filenames can become command text in preview/bash templates;
- it adds an open-ended command/action language rather than one file picker;
- the exact package still imports the former `@mariozechner/pi-*` names;
- it adds a JavaScript fuzzy-ranking dependency even though the maintained
  native fzf binary is already installed.

The project-local config loading and raw shell templates are material trust
expansions, not stylistic objections.
[Config loading and raw template replacement](https://github.com/kaofelix/pi-fzf/blob/dd0ef2eed8725ed10aa45a5e87114a8719f69540/config.ts)
[Shell-backed list execution](https://github.com/kaofelix/pi-fzf/blob/dd0ef2eed8725ed10aa45a5e87114a8719f69540/index.ts#L51-L62)
[Shell-backed actions](https://github.com/kaofelix/pi-fzf/blob/dd0ef2eed8725ed10aa45a5e87114a8719f69540/actions.ts#L17-L54)

Verdict: good interaction ideas, unsuitable security and scope boundaries.

### 3. `@ff-labs/pi-fff` 0.10.1

This is the most actively maintained fuzzy-search option found in Pi's
official package gallery. It uses a Rust-native index, frecency, query history,
and git-aware ranking; its default mode adds three model-facing search tools
and replaces `@` autocomplete.
[Pi package registry entry](https://pi.dev/packages/%40ff-labs/pi-fff)
[Upstream repository](https://github.com/dmtrKovalenko/fff.nvim)

Strengths:

- current `@earendil-works` peer package names;
- very active upstream development;
- strong fuzzy, frecency, history, and git-aware ranking;
- no shell or network calls in the extension's stated design.

Limits for this pilot:

- it is an indexed search subsystem, not a previewing interactive file picker;
- the default mode also adds model-facing tools;
- it adds native Node/Bun dependencies and persistent search databases;
- its documented default state lives under normal Pi's `~/.pi/agent/fff`,
  outside the current pilot roots unless explicitly redirected;
- background indexing, history, tool behavior, native binaries, storage,
  rollback, and performance would all need separate review and validation.

Verdict: a future search-platform candidate, but disproportionate for fixing
the human `@file` picker.

## Why the local native-fzf extension is the best fit

The native fzf project explicitly supports:

- true fuzzy subsequence matching;
- interactive live ranking;
- previews with ANSI-aware tools such as `bat`;
- custom navigation bindings;
- multi-select;
- responsive preview layouts.

[fzf search syntax](https://junegunn.github.io/fzf/search-syntax/)
[fzf getting started](https://junegunn.github.io/fzf/getting-started/)
[fzf preview documentation](https://github.com/junegunn/fzf/blob/master/README.md#preview-window)

The implementation should keep the command surface fixed:

```text
fd --type f --hidden --exclude .git --print0
  -> fzf --read0 --print0 --multi
         --bind ctrl-p:up,ctrl-n:down
         --preview 'bat --color=always --style=numbers -- {}'
```

The exact argv can be refined during implementation, but these safety
properties should be non-negotiable:

- do not execute project-provided picker config;
- do not interpolate the selected path into an agent-owned `bash -c` template;
- use NUL-delimited input/output so spaces, quotes, and newlines are not
  confused with list boundaries;
- use a fixed preview command only;
- constrain candidates to the session cwd and reject any resolved selection
  that escapes it;
- insert into the editor without submission;
- restore Pi's TUI on success, cancellation, signal, or child failure;
- fail closed with a clear notice when `fd`, `fzf`, or `bat` is unavailable;
- retain native Tab path completion and a fallback picker command;
- add deterministic tests for quoting, multiple selections, cancellation,
  path containment, missing binaries, and TUI restoration;
- require physical Ghostty QA for `@`, Escape, `Ctrl-P` / `Ctrl-N`, preview,
  multi-select, and editor restoration.

## Install and security conclusion

All three third-party packages are executable Pi extensions. The official Pi
package gallery and Pi's own package documentation warn that such code has full
system access. “It is in the package gallery” is discovery metadata, not a
security approval.

For this isolated pilot:

- do not run `pi install`;
- do not add npm/git package entries;
- do not enable project-local picker configuration;
- do not replace Pi's model-facing `find`/`grep` tools;
- do not add persistent search state outside the pilot roots.

A small repository-owned extension is both the narrowest implementation and
the easiest one to pin, inspect, test, roll back, and include in
`pi/verify.sh`.

## Verification performed

- Inspected the installed Pi 0.82.1 docs, examples, and standalone layout.
- Inspected the exact Pi `v0.82.1` tagged source at
  `b4f293684bba718d59cc1157679bcf6157b3a7f5`.
- Inspected upstream source snapshots:
  - `pi-fzfp` at `00d0190e69544c5f0008178df38376f318eb2978`;
  - `pi-fzf` at `dd0ef2eed8725ed10aa45a5e87114a8719f69540`;
  - `fff.nvim` at `9033efb60f3fa5a39009244c6e9ba4e86e010005`.
- Downloaded and unpacked the exact npm tarballs for `pi-fzfp@2.5.0`,
  `pi-fzf@0.9.0`, and `@ff-labs/pi-fff@0.10.1` into a temporary research
  directory for source/manifest comparison. No package was installed.
- Ran current upstream `pi-fzfp` tests against the machine's real `fd` and
  `fzf`: **27 passed, 0 failed**.
- Confirmed installed `fzf`, `fd`, `bat`, and `rg` versions.

Not performed:

- no third-party package installation;
- no Pi configuration or production-code change;
- no live picker prototype;
- no physical Ghostty interaction test.
