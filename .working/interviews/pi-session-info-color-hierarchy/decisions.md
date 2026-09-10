# Pi Session Information Colour Hierarchy

## Goal

Make Pi's session details scannable and expose context pressure continuously.

## Exit Criteria

- Pi starts quietly without the Context, Skills, Extensions, and Themes
  inventory.
- One footer row shows model, repository, branch/worktree, context tokens/percentage,
  weekly Codex allowance left when available, and current directory.
- Context pressure and a critical weekly allowance are the only
  state-dependent warning colours; model names use stable identity colours.
- Context is green below 70%, amber from 70% through 84%, and red at 85%+.
- The indicator refreshes after session start, tree navigation, model changes,
  completed agent runs, and compaction.
- Focused tests and `./pi/verify.sh` pass.
- Fresh Standards and Fidelity reviews have no blocking findings.
- Physical Ghostty appearance remains explicitly awaiting Eddy.

## Scope / Non-goals

- Preserve Pi's native footer data sources, custom editor, reload behavior,
  isolation, and compaction configuration while replacing the footer layout.
- Do not add or configure subagent packages.
- Do not alter the prior active goal's uncommitted implementation.

## Decisions

- Replace Pi's native multi-line footer with one extension-owned footer row.
- Read weekly allowance through the installed Codex app-server's supported
  `account/rateLimits/read` method at interactive launch; omit it when the
  value is unavailable.
- Preserve Pi's native `/session` command because built-in commands run before
  extension input hooks and cannot be replaced safely.
- Keep token usage visible from startup. Mark the initial system-prompt estimate
  with `~`, then use Pi's provider-backed context usage after the first response.
- Use the existing `success`, `warning`, `error`, and supporting semantic theme
  roles instead of hard-coded terminal colours.
- Give model families stable, restrained identity colours: Astra, flagship,
  and Opus use yellow; the default Sol model uses pink; Terra uses blue; Luna
  uses peach; Sonnet uses mauve; Haiku uses green; unknown models use mauve.
- Keep weekly allowance neutral above 10%; render 10% or less in Catppuccin
  Mocha maroon.
- Follow Eddy's Claude reference structurally: one aligned footer row, mostly
  neutral metadata, quiet startup, a compact repository plus branch/worktree
  identity, and one meaningful context colour.

## Validation Plan

- Exercise boundary classification and session accounting in
  `session_display_test.mjs`.
- Assert the production extension wiring in `theme_ui_test.sh`.
- Run `./pi/verify.sh` from the isolated worktree.
- Review the final diff independently for Standards and Fidelity.
- Leave the physical Ghostty colour and layout check unchecked for Eddy.

## Open Questions

- Physical colour contrast and wrapping at Eddy's terminal width require the
  manual Ghostty check.

## Verification Evidence

- `session_display_test.mjs`, `ui_core_test.mjs`, `theme_ui_test.sh`, and
  `compat_core_test.mjs`: PASS.
- `session_display_pty_test.sh`: PASS against the worktree extension; it proves
  themed ANSI output, one-line context status, quiet startup, and replacement
  of the native multi-line footer.
- `validate_sessions.sh`: PASS against the worktree extension with disposable
  state and evidence.
- `pi/verify.sh`: PASS after rebasing onto `b944f031`; the named worktree used a
  short disposable alias so macOS Herdr and XcodeBuildMCP sockets remained
  within `sockaddr_un` path limits. Provider comparison stayed in dry-run mode.
- Fresh post-rebase review after verification repairs: Standards 0 findings;
  Fidelity 0 findings.
- 2026-09-10 compact-layout `pi/verify.sh`: PASS. The revised five-row PTY
  panel, compact `● ?%` status, `/reload`, context load, session validation,
  Herdr integration, XcodeBuildMCP validation, and runtime benchmark passed;
  provider comparison stayed in dry-run mode.
- Physical Ghostty first compact-layout attempt: FAIL. Eddy's screenshot showed
  startup inventory, Pi's two-line native footer, and a separate context row.
  Eddy requested one Claude-like footer row with model/worktree/branch/context
  on the left and weekly allowance/current directory on the right.
- Physical Ghostty green `<70%`, amber `70–84%`, and red `>=85%` contrast:
  NOT RUN. Automated boundary classification passed at `69.9`, `70`, `84.9`,
  and `85` percent.
- Physical Ghostty `/reload`, `/tree`, model-change refresh, custom-editor
  preservation, and native-footer preservation: NOT RUN on the revised build.
- 2026-09-10 visual feedback rejected the nine-row, multi-colour direction as
  bloated. The implementation now targets five grouped rows and reserves colour
  for context pressure; revised physical Ghostty acceptance is NOT RUN.
- Fresh compact-layout review: Standards 0 findings; Fidelity 0 findings.
- 2026-09-10 Claude-like footer focused checks: `session_display_test.mjs`,
  `codex_weekly_usage_test.mjs`, `theme_ui_test.sh`, and
  `session_display_pty_test.sh`: PASS. The PTY fixture proves the worktree
  extension loads, startup inventory stays hidden, and Pi's native multi-line
  footer is absent. Physical Ghostty acceptance remains NOT RUN.
- 2026-09-10 worktree-local `pi/verify.sh`: the managed sandbox passed through
  the compact-footer PTY gate, then denied FFF's frecency database with
  `Operation not permitted`; no product code changed for that environment error.
- 2026-09-10 explicitly approved isolated `pi/verify.sh`: PASS end to end via
  temporary `/tmp/piw-compact`. Agent-config, display, weekly usage, keybindings,
  theme/editor, isolation, concurrency, PTY, FFF reload, context loading,
  XcodeBuildMCP, sessions, Herdr, benchmarks, and diff checks passed. Provider
  comparison remained in documented dry-run mode. The alias was removed; all
  mutable verifier data stayed under ignored `pi/.runtime`.
- Fresh post-verification review against `b944f031`: Standards 0 findings;
  Fidelity 0 findings. Physical Ghostty appearance remains unconfirmed.
- Physical Ghostty revised-footer checkpoint, exact Eddy confirmation:
  `Quiet startup: PASS`; `One-row footer: PASS`; `Left-side fields: PASS`;
  `Right-side weekly and cwd: PASS`; `Native two-line footer absent: PASS`;
  `Colour restraint: PASS`.
- 2026-09-10 final palette and startup-usage `pi/verify.sh`: PASS through the
  approved isolated `/tmp/piw-compact` route. Startup usage now shows an honest
  `~` system-prompt estimate until provider usage exists; fixture-only context,
  weekly, and model states make the remaining physical checks token-free.
- Fresh final review against `b944f031`: Standards 0 findings; Fidelity 0
  findings. The remaining revised-colour and interaction checks are physical.
- Final integration exposed a nondeterministic PTY assertion when the live
  weekly allowance consumed the right side of an 80-column footer. The test
  now fixes weekly allowance at 72% and proves the intended long-branch
  truncation plus protected weekly and cwd fields. Full `pi/verify.sh`: PASS
  through logical short path `/tmp/pi-finish.bIk2rl/w`; the short path avoids
  the documented macOS Unix-socket length limit.
- Eddy explicitly ended the evaluation gate and approved daily use on
  2026-09-10. Long-path wrapping, context 69/70/84/85 colour contrast, weekly
  10% maroon, and the revised `/reload`/`/tree`/model interaction matrix remain
  `NOT RUN`; none is recorded as a physical pass.
- Final integration review after the deterministic PTY repair: Fidelity 0
  findings. Standards found three tracking-only lifecycle defects: premature
  closure, a pre-repair 0/0 claim, and the resulting intake relationship
  inconsistency. Product code and the PTY repair had no Standards findings;
  the lifecycle records were corrected before re-review.
- Final post-fix review after adding the tracked physical-QA launcher and the
  reproducible long-worktree procedure: Standards 0 findings; Fidelity 0
  findings.
