# Fish Startup Ownership And Performance

## Goal

Make fresh interactive Fish startup consume configuration without performing
installation, cache generation, symlink creation, repository inspection, or
maintenance, while preserving the current environment, theme, prompt, and key
binding behavior.

## Exit Criteria

- A 30-run fresh interactive shell benchmark reaches median <=40 ms and p95
  <=55 ms.
- `fish/scripts/verify.sh` passes, including the environment and startup audits.
- Manual interaction QA is recorded for prompt, Git/non-Git transitions,
  abbreviations, vi bindings, FZF bindings, and a second interactive shell.
- Fresh Standards and Fidelity review passes after the final implementation
  change.

## Scope / Non-goals

In scope: Fish startup ownership in `conf.d/__init__.fish`, `conf.d/git.fish`,
`conf.d/theme.fish`, `config.fish`, `fish_user_key_bindings.fish`, and
`_fzf_envs.fish`; off-startup maintenance and generated caches; verification,
benchmarking, manual QA, and local workflow records.

Non-goals: fonts, dead-code cleanup, repository-size cleanup, Herdr/tmux work,
commits, pushes, hosted tickets, or publication.

## Decisions

- Startup consumes prepared cache files but never generates or expires them.
- `fish/scripts/refresh_startup.fish` owns directory creation, stale-cache
  expiry, Homebrew/Zoxide/Starship/environment cache generation, configuration
  symlinks, missing Fisher installation, and the global Git log alias.
- Valid inherited `JAVA_HOME` remains authoritative. The prepared cache supplies
  the platform fallback, and SDKMAN remains a cheap final fallback.
- Git branch information is evaluated by functions only when a Git command or
  abbreviation uses it. Fish startup does not query the current repository or
  write global Git configuration.
- `fish/conf.d/theme.fish` is the only Fish color/theme owner and preserves the
  effective Catppuccin Mocha colors that previously won at the end of startup.
- `fish/functions/fish_user_key_bindings.fish` is the only FZF binding owner.
  It retains Ctrl-R history, Ctrl-G Git status, and Ctrl-P directory behavior
  after vi bindings are installed. FZF's generated shell completion remains
  available from a completion-only prepared cache.
- Missing prepared state fails closed: the shell still starts, while the
  maintenance command restores optional integrations.

## Evidence / Findings

- The pre-change 30-run benchmark measured 92.060 ms median and 171.673 ms p95.
- Startup profiling showed eager Git branch queries, global Git configuration,
  Java and Vivid generation, theme application, and cache expiry among the
  largest avoidable startup operations.
- FZF bindings were configured in `config.fish`, the login/WSL branch, the
  generated native FZF initialization, and `fish_user_key_bindings.fish`; the
  last owner determined the intended effective mappings.
- The existing environment-correctness goal explicitly deferred this work and
  remains the source contract for XDG, Java, Vivid, PATH, and optional inputs.

## Tradeoffs / Risks

- Tool upgrades that change generated initialization require rerunning
  `fish/scripts/refresh_startup.fish`; verification reports stale or missing
  prepared state instead of repairing it during startup.
- Removing native FZF key initialization intentionally leaves the fzf.fish
  plugin as the binding implementation. Existing project integration tests and
  manual binding checks guard the intended behavior.
- Subjective prompt rendering and perceived responsiveness require an
  interactive terminal QA record; deterministic checks cannot fully prove them.

## Validation Plan

- Run `fish/scripts/refresh_startup.fish` once to prepare local state.
- Run Fish syntax checks and the startup-ownership audit.
- Run the 30-run fresh-shell benchmark and enforce median/p95 thresholds.
- Run `fish/scripts/verify.sh` and scoped `git diff --check`.
- Exercise a real interactive Fish PTY and record prompt, Git/non-Git,
  abbreviation, vi/FZF binding, and second-shell results.
- Review Standards and Fidelity separately against this record, the environment
  decision record, project workflow rules, and the actual scoped diff; fix and
  re-review until both pass.

## Ready To Act

Implemented and closed on 2026-07-21. The user selected this exact bounded goal
through `feature-plan` and provided its scope, stop condition, validation, and
non-goals.

## Open Questions

None.

## Closure Evidence

- `fish/scripts/refresh_startup.fish` completed successfully and prepared the
  Homebrew, FZF completion, Zoxide, Starship, Java, and Vivid state.
- `fish/scripts/verify.sh` passed transport security, environment correctness,
  complete startup-ownership scanning, Fish syntax, FZF integrations, worker
  leakage, the startup benchmark, and Fish-scoped diff checks.
- The final 30-run fresh interactive shell benchmark measured 26.990 ms median
  and 27.748 ms p95 against limits of 40 ms and 55 ms.
- Real-PTY manual interaction QA passed and is recorded in `manual-qa.md`.
- Initial review found an eager Homebrew fallback, incomplete audit coverage,
  and duplicate `_fzf_envs.fish` loading. Those findings were fixed, all
  affected validation was rerun, and fresh post-fix review passed with 0
  Standards findings and 0 Fidelity findings.
- No fonts, dead-code, repository-size, Herdr/tmux, commit, push, hosted-ticket,
  or publication work was performed.
