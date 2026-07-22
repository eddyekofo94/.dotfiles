# Transport Security Baseline

## Goal

Make active dotfiles bootstrap paths fail closed instead of disabling TLS or
executing mutable remote content without integrity verification.

## Exit Criteria

- Git HTTPS certificate verification is explicitly enabled.
- Active Homebrew bootstrap call sites execute one pinned, SHA-256-verified
  official installer.
- Fisher bootstrap executes one pinned, SHA-256-verified official release.
- Fisher's installed plugin manifest pins every GitHub dependency to an exact
  commit.
- Rust installation uses Homebrew's `rustup` formula rather than `curl | sh`.
- A deterministic audit and fixture-backed verifier prevent regression.
- `fish/scripts/verify.sh` and fresh Standards/Fidelity review pass.

## Scope / Non-goals

In scope: `git/.gitconfig`, `install_all.zsh`, the live `zsh/.zprofile`,
`fish/functions/init_fisher.fish`, `fish/fish_plugins`, `fisher/deps.fish`, `rust/setup/setup`,
`homebrew/setup/install/install`, shared verified-download helpers, and the
transport-security audit.

Non-goals: archival OMF examples, commented historical snippets, Fish startup
refactoring, cache cleanup, font removal, Herdr/tmux changes, Git history,
commits, pushes, or externally visible lifecycle changes.

## Decisions

- Pin official Homebrew and Fisher source URLs to immutable Git commits and
  verify exact SHA-256 digests before parsing or execution.
- Pin every Fisher-managed plugin to an immutable Git commit so the verified
  manager cannot silently replace shell code from mutable default branches.
- Centralize download, checksum, and installer behavior so active call sites do
  not duplicate trust logic.
- Use Homebrew's cross-platform `rustup` formula for Rust bootstrap. Let rustup
  retain responsibility for verified toolchain installation.
- Treat only live startup files and named bootstrap entry points as active for
  this bounded audit. Record archival remote-execution examples separately
  instead of expanding this security baseline into legacy cleanup.
- Preserve the existing noninteractive Homebrew behavior while replacing the
  mutable `master` installer URL and `curl` command substitution.

## Evidence / Findings

- `git/.gitconfig` currently sets `http.sslVerify = false` and is symlinked into
  the live user configuration.
- Homebrew installation runs from mutable `master` in `install_all.zsh`,
  `zsh/.zprofile`, and `homebrew/setup/install/install`.
- Fisher's live fallback and dependency bootstrap source mutable `main` over a
  pipe.
- Rust bootstrap in `install_all.zsh` and `rust/setup/setup` pipes the current
  network response directly to `sh`.
- Homebrew officially supports macOS and Linux installation through its Bash
  installer and provides a bottled `rustup` formula on both platforms.

## Tradeoffs / Risks

- Pinned installer revisions intentionally stop auto-following upstream. A
  future update must review the diff and replace both commit and checksum.
- A Homebrew-first Rust path makes the standalone Rust helper depend on
  Homebrew; that is intentional for one auditable package-manager owner.
- Archival OMF scripts still contain historical remote-execution examples but
  are neither sourced nor executable in the current configuration.

## Validation Plan

- Run `tools/audit_transport_security.sh`.
- Run fixture-backed success and checksum-mismatch cases for the verified
  downloader without network access.
- Run `zsh -n install_all.zsh zsh/.zprofile` and `sh -n` on changed POSIX
  scripts.
- Run Fish syntax and formatting checks on changed Fish files.
- Run `fish/scripts/verify.sh`.
- Run `git diff --check` on the scoped files.
- Review Standards and Fidelity separately against this record and the actual
  diff, then fix and re-review any actionable findings.

## Ready To Act

Ready. The user's cleared-session request explicitly selected and authorized
the prior ready-to-paste prompt for implementation.

## Open Questions

None.

## Review Evidence

- Initial Fidelity review found one medium regression-test gap: the audit did
  not require each active bootstrap entry point to delegate to its verified
  helper. The fix added explicit per-callsite contracts and `wget` rejection.
- Initial Standards review found that pathname-only contracts could be
  satisfied by comments or non-executing text. The fix anchored every contract
  to the exact executable Zsh, POSIX shell, or Fish command form.
- Post-fix fresh review passed with 0 Standards findings and 0 Fidelity
  findings. `tools/audit_transport_security.sh`, `fish/scripts/verify.sh`, Fish
  formatting, scoped syntax checks, live pinned-download checksum checks, and
  scoped `git diff --check` all passed before closure.
