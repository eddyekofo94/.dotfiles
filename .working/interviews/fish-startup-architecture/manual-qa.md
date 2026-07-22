# Fish Startup Architecture Manual QA

Date: 2026-07-21

## Environment

- Fish 4.8.0 on macOS.
- Live symlinked configuration from `/Users/eddyekofo/.dotfiles/fish`.
- Real PTY sessions were used for prompt and key interaction checks. A
  `TERM=dumb` PTY was used for repeatable FZF interaction because the execution
  harness does not answer Fish's normal terminal background-color query.

## Results

- PASS — A normal interactive PTY rendered the Starship prompt once with the
  repository path, current branch, dirty-state counts, and tool versions.
- PASS — `fish_prompt` rendered valid Git and non-Git prompts after changing
  between the dotfiles repository and the home directory.
- PASS — the effective Fish command color remained Catppuccin Mocha `89b4fa`.
- PASS — `get_default_branch` returned `main`, and `get_current_branch`
  returned `prototype/herdr-migration-trial` only when invoked.
- PASS — Git abbreviation `ggp` remained available and expanded to
  `git push origin (get_current_branch)`.
- PASS — a second real PTY shell loaded vi-mode bindings and reported Ctrl-R as
  `_fzf_search_history`, Ctrl-G as `_fzf_search_git_status`, and Ctrl-P as
  `_fzf_search_directory` in insert mode.
- PASS — pressing Ctrl-R, Ctrl-G, and Ctrl-P opened the History, Git Status,
  and Directory FZF interfaces respectively; each returned to the prompt after
  cancellation.
- PASS — changing to `/tmp` and back to the repository updated `PWD`, while the
  on-demand Git helpers still returned the correct repository branches.
- PASS — no unexpected `fish -c` workers remained after the repeated-shell
  check in `fish/scripts/verify.sh`.

## Harness Note

The normal PTY harness pauses at Fish's terminal background-color query, so the
prompt session needed an interrupt to complete that handshake. This is the
existing harness limitation documented in prior terminal QA, not output from
the startup configuration. The repeatable interaction checks used `TERM=dumb`;
Starship intentionally disables itself for that terminal type, while the
separate normal PTY and direct `fish_prompt` checks covered prompt rendering.
