# Fish Environment Correctness

## Goal

Make every fresh Fish shell derive valid environment values and PATH entries
from checked-in configuration instead of stale machine-specific universal
variables.

## Exit Criteria

- `JAVA_HOME` is either a valid directory selected from an explicit valid
  override or the platform Java resolver, or is absent when Java is unavailable.
- `LS_COLORS` contains generated Vivid data when Vivid and the checked-in theme
  are available; it never contains literal command text.
- Deterministic application environment variables are global/exported and are
  absent from universal scope.
- `fish_user_paths` contains no persisted configuration-owned PATH state.
- A fresh Fish shell built from a controlled base PATH has no duplicate or
  nonexistent configuration-owned entries and preserves terminal-provided
  `TERM`.
- Optional Cargo and UV inputs fail closed when absent.
- The environment audit, `fish/scripts/verify.sh`, and fresh
  Standards/Fidelity review pass.

## Scope / Non-goals

In scope: `fish/conf.d/__init__.fish`, `fish/conf.d/env.fish`,
`fish/conf.d/brew.fish`, `fish/conf.d/uv.env.fish`, the environment-owned tail
of `fish/config.fish`, `fish/fish_variables`, Fish verification, and durable
workflow records.

Non-goals: theme, Git, FZF, or plugin ownership refactors; startup-performance
work; fonts or cache cleanup; Zsh's separate XDG configuration; Herdr/tmux
work; commits; pushes; or externally visible lifecycle changes.

## Decisions

- Checked-in Fish configuration is the source of truth. Universal variables
  remain only for Fish/plugin/user state that genuinely needs cross-process
  persistence, not machine-derived application environment.
- `__init__.fish` owns foundational XDG locations and startup paths because it
  runs first. `env.fish` owns application environment values. Both use global
  scope; neither persists machine-derived universals.
- Fish uses XDG defaults rooted at `$HOME` (`.config`, `.local/share`,
  `.local/state`, and `.cache`) even when an inherited Zsh environment contains
  the known incorrect `.config/.local` or `.config/.cache` paths.
- Preserve a valid externally supplied `JAVA_HOME`. Otherwise use macOS
  `/usr/libexec/java_home`, then an existing SDKMAN `current` path. Do not
  synthesize a path from an unset `SDKMAN_DIR`.
- Generate `LS_COLORS` by executing Vivid only when both the binary and theme
  exist. Leave it unset when generation is unavailable.
- Preserve terminal ownership of `TERM`; Fish must not force a universal
  terminal type.
- Use global `fish_add_path` with existing, canonical directories. Remove the
  redundant generated UV PATH source because `$HOME/.local/bin` is already
  owned canonically by `__init__.fish`.
- Guard optional Cargo and tracked helper sources with readability checks.

## Evidence / Findings

- Live and tracked universal state contains `JAVA_HOME=/candidates/java/current`
  because `$SDKMAN_DIR` was unset when the value was persisted.
- `LS_COLORS` is the literal text `(vivid generate ...yml)` rather than Vivid's
  generated data.
- `fish_user_paths` persists seven entries, including a nonexistent Codex app
  path. Manual Bun PATH prepending duplicates `$HOME/.bun/bin` in fresh shells.
- Fish inherits `XDG_DATA_HOME=$HOME/.config/.local/share` and
  `XDG_CACHE_HOME=$HOME/.config/.cache` from Zsh, shadowing the correct
  universal values and producing a misplaced cache directory.
- macOS `/usr/libexec/java_home` resolves to an existing Java 17 home. Vivid,
  the checked-in Catppuccin theme, Cargo's optional environment file, and the
  canonical `$HOME/.local/bin` directory are present on this Mac.
- `uv.env.fish` adds `$HOME/.local/share/../bin`, a noncanonical spelling of
  the already-owned `$HOME/.local/bin` path.

## Tradeoffs / Risks

- Fish intentionally corrects inherited XDG values; Zsh's separate incorrect
  owner remains deferred by scope.
- The ignored live `fish_variables` store was cleaned of the named stale
  environment values. Fresh shells are the proof target; existing shells may
  need to be restarted to discard inherited global values.
- When optional tools are absent, their variables or PATH entries are absent
  rather than pointing at speculative locations.
- Fish's internal read-only `__fish_cache_dir` is computed before `conf.d` from
  the inherited Zsh XDG cache value. Cache consumers remain unchanged because
  cache/startup refactoring is an explicit non-goal; the separate Zsh XDG owner
  remains deferred.

## Validation Plan

- Add and run `fish/scripts/audit_environment.sh` with controlled fresh-shell
  environment, universal-scope, XDG, Java, Vivid, optional-source, PATH
  uniqueness, existence, and `TERM` assertions.
- Run Fish syntax and formatting checks on every changed Fish file.
- Run `fish/scripts/verify.sh`.
- Run scoped `git diff --check`.
- Review Standards and Fidelity separately against this record and the actual
  diff, fix actionable findings, rerun verification, and re-review.

## Ready To Act

Ready. The user explicitly selected this bounded goal and supplied its scope,
stop condition, and validation requirements through `feature-plan`.

## Open Questions

None.

## Review Evidence

- Initial Standards review found two medium verification defects: the new audit
  lacked executable mode, and its controlled PATH duplicated `/usr/bin` or
  `/bin` when Fish is installed there. The fixes set mode `100755` and
  conditionally prepend Fish's binary directory only when absent.
- Initial Fidelity review found three issues: Java did not continue to SDKMAN
  after an empty macOS resolver result, exportedness was not asserted, and a
  cache/FZF consumer rewire crossed explicit non-goals. The fixes added an
  ordered, unit-exercised existing-directory resolver; changed audit queries to
  require global/exported scope; and fully reverted cache/FZF rewiring.
- Post-fix fresh review passed with 0 Standards findings and 0 Fidelity
  findings. Direct environment audit, Fish formatting, scoped diff checks, the
  transport audit, FZF integration suites, worker-leak check, and full
  `fish/scripts/verify.sh` passed before closure.

## Follow-on Relationship

- `fish-startup-architecture` subsequently resolved this goal's deferred cache
  ownership boundary by replacing Fish's inherited internal cache path with
  `DOTFILES_FISH_CACHE` and prepared startup state. Reconciliation removed the
  obsolete audit exemption for `set -U __fish_cache_dir`; post-change review
  and full Fish verification passed without reopening either completed goal.
