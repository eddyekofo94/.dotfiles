# Fish Ctrl-T FZF Regression

## Goal

Restore `Ctrl-T` file picking through the retained `fzf.fish` directory picker
after the Fish startup ownership cleanup removed fzf's generated native binding.

## Exit Criteria

- `Ctrl-T` invokes `_fzf_search_directory` in Fish default and insert modes.
- Existing `Ctrl-P` directory search remains unchanged.
- `fish_user_key_bindings.fish` remains the sole FZF binding owner; native
  `fzf-file-widget` bindings are not reintroduced.
- Deterministic binding/preview coverage, full Fish verification, and a real
  interactive PTY validation pass.
- Fresh Standards and Fidelity review passes after the final change.

## Scope / Non-goals

In scope: the FZF binding declaration, directly impacted deterministic coverage,
live PTY validation, full Fish verification, and durable workflow records.

Non-goals: changing `Ctrl-P`, restoring all generated `fzf --fish` key bindings,
changing picker behavior or preview UX, Fish startup architecture, Herdr/tmux,
Zsh, unrelated dirty files, commits, pushes, or publication.

## Decisions

- Keep `fzf.fish` as the sole FZF binding implementation.
- Preserve `Ctrl-P` and add `Ctrl-T` as an alias to the same
  `_fzf_search_directory` function in default and insert modes.
- Do not source generated native fzf bindings or restore `fzf-file-widget`.
- Add the regression assertion to the existing FZF preview integration seam so
  the key-to-picker-to-preview contract cannot silently regress again.

## Evidence / Findings

- Before the fix, directly applying the repository's user-binding function and
  reading back default/insert maps finds no `Ctrl-T` FZF binding.
- `fzf --fish` would normally bind `Ctrl-T` to `fzf-file-widget`.
- The completed startup cleanup intentionally stopped sourcing generated native
  bindings, while `fzf_configure_bindings --directory=\\cp` preserved only
  `Ctrl-P` through the richer `fzf.fish` picker.
- `_fzf_search_directory` already consumes `_fzf_file_picker_opts`, the shared
  preview/binding path used by the repository's FZF integration coverage.
- The current worktree is broadly dirty. Only this goal's explicit allowlist may
  change; all unrelated Fish, Herdr, tmux, Zsh, and workflow work is preserved.

## Tradeoffs / Risks

- Two chords intentionally invoke one directory picker, but there remains only
  one implementation owner.
- Testing only function presence would miss this regression; coverage must
  assert the actual bindings in both active Fish modes.
- Terminal rendering and key delivery need PTY evidence in addition to static
  binding readback.

## Validation Plan

- Run the focused FZF preview/binding integration test.
- Run `fish/scripts/verify.sh`.
- In a real interactive Fish PTY, read back both `Ctrl-T` bindings, send the
  physical control byte, and observe the directory picker prompt without
  relying on generated `fzf-file-widget`.
- Run `git diff --check` and audit the goal allowlist.
- Run fresh Standards and Fidelity review against this record, the startup
  ownership decision, Fish workflow/QA standards, and the actual scoped diff;
  fix and re-review until clean.

## Ready To Act

Implemented and closed on 2026-07-22. The user selected this bounded regression
through `feature-plan` and authorized local implementation, validation, review,
and fixes.

## Open Questions

None.

## Closure Evidence

- `fish/tests/fzf_preview_integration.sh` first exited 1 against the missing
  binding, then passed after the fix. It now asserts exact default/insert
  `Ctrl-T` and preserved `Ctrl-P` mappings to `_fzf_search_directory` and rejects
  native `fzf-file-widget` ownership.
- `fish/scripts/verify.sh` passed transport security, environment/startup
  ownership, Fish syntax, FZF integrations, worker leakage, the startup
  benchmark, and Fish-scoped diff checks. The 30-run benchmark measured
  27.781 ms median and 28.853 ms p95.
- A real 40x120 interactive Fish PTY received physical `Ctrl-T`, rendered the
  `Directory>` picker, loaded 1,150 entries, canceled cleanly, and returned to
  the prompt.
- Fresh post-fix review reported 0 Standards findings and 0 Fidelity findings.
  The reviewer independently reran the focused integration, Fish/POSIX syntax,
  and scoped `git diff --check` checks.
- No generated native FZF binding owner was restored. No unrelated Fish,
  Herdr/tmux, Zsh, commit, push, hosted-ticket, or publication work was
  performed.
