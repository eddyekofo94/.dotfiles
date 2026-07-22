# Unified Intake

## Active

None.

## Investigating

- `herdr-daily-driver-promotion`: Eddy wants Herdr to become the main driver and
  is settling a rollback-capable promotion boundary. Technical behavior gates
  are complete; current aggregate proof must be refreshed before promotion.

## Deferred

- `fish-fzf-image-visible-geometry-regression`: reopened on 2026-07-22 after
  Eddy's third live screenshot showed a much narrower central image strip in
  the long-lived Ghostty/tmux pane. The retained picker now refreshes its image
  preview when fzf receives a resize event; the same-client 118x20 -> 118x35
  loop changed the stale placeholder and restored the portrait from 139 to 262
  pixels wide. Automated verification and fresh review are clean. Closure is
  awaiting Eddy's visual retest in a fresh real pane because the final macOS
  raster capture returned an unusable all-black frame. Eddy's 15:29 retest
  rejected closure again: one frame can be correct while later frames remain
  intermittent. The same goal is back in implementation; upstream fzf guidance
  identifies stream transfer as required for redraw across resize/preview
  changes. The canonical renderer now uses stream; five same-client stress
  runs validated all 100 intermediate portrait frames and final resize geometry,
  full Fish verification passed, and fresh review is clean (Standards 0,
  Fidelity 0). Eddy's 16:03-16:04 fresh-pane retest rejected closure: three
  distinct PNGs render as narrow vertical slices, so the goal is `Ready To Act`
  again and the automated visual loop must first reproduce that exact
  multi-image state before another renderer change.
  Eddy then explicitly selected rollback after the experiment chain made image
  rendering worse. The renderer is restored to shared-memory transfer, the
  resize-refresh binding and unreliable Ghostty visual harness are removed,
  and the earlier Ctrl-T/PNG dispatcher fixes remain. Closure awaits one fresh
  Ghostty-window acceptance. Focused and full Fish verification pass, including
  direct PTY and isolated tmux consumers; fresh re-review is clean (Standards
  0, Fidelity 0). Eddy reports that live rendering is still not reliably
  working after rollback and chose to commit the recovery state and try again
  later. This remains unresolved and must not be presented as fixed.

## Human Interruptions

- 2026-07-18: the user replaced pre-selection Herdr intake review with the
  recurring Codex skills-context warning. Reason: the warning is frequent and
  directly degrades every new Codex session. No prior implementation goal had
  been activated, so no active goal was displaced.
- 2026-07-18: the user clarified that the catalog workflow must include Claude.
  Reason: `~/.claude/skills` exposes the same shared personal skill source, so a
  Codex-only cleanup would leave the cross-agent workflow inconsistent.

## Completed

- 2026-07-22 — superseded closure record for
  `fish-fzf-image-visible-geometry-regression`: the retained
  Ctrl-T fzf.fish picker now preserves fzf-owned preview geometry and renders
  the exact BibleStandard portrait at its source aspect ratio. Direct PTY,
  isolated tmux/Kitty transport, and a real Ghostty visual harness cover the
  binding, placeholder grid, and displayed raster. The visual harness uses
  bounded readiness polling and source-derived geometry; its final run passed
  at 0.471 versus source 0.460. Full Fish verification, fresh re-review
  (Standards 0, Fidelity 0), and Eddy's visual acceptance passed. The apparent
  mid-text bottom cutoff belongs to the source asset itself. Eddy's later live
  screenshot rejected this closure; the active record above governs. No commit
  or push.
- 2026-07-22 — `fish-regression-audit`: real-consumer review repaired Ctrl-T
  image dispatch, unrelated cache deletion, legacy-XDG maintenance output,
  false generator success, preview filename injection, incomplete Fisher retry
  poisoning, and PTY composed-state gaps. Exact BibleStandard PNG dispatch,
  failure fixtures, five consecutive PTY runs, full Fish verification (29.788
  ms median / 31.844 ms p95), and final Standards/Fidelity review passed with
  zero findings. No Herdr/tmux/Zsh behavior was changed.
- 2026-07-22 — `fish-ctrl-t-fzf-regression`: `Ctrl-T` now opens the retained
  `fzf.fish` directory picker in default and insert modes while `Ctrl-P` remains
  unchanged and generated native FZF ownership stays absent. Deterministic
  binding/preview coverage, full Fish verification, a physical-key live PTY,
  and fresh Standards/Fidelity review passed.
- 2026-07-21 — `zsh-local-env-warning`: agent-facing Zsh startup now preserves
  inherited terminal/XDG/editor values, guards optional local files, avoids
  duplicate setup, and bypasses interactive bootstrap in noninteractive and
  explicit agent/CI shells. Isolated missing/present override fixtures,
  interactive agent PTYs, syntax/security checks, and fresh
  Standards/Fidelity review passed.
- 2026-07-21 — `ready-prompt-replay-regression`: one ANSI-preserving readiness
  snapshot now distinguishes bare/dim Codex placeholders from inline or
  multiline typed text while queued, loading, and working states fail closed.
  Deterministic tmux coverage, disposable live Codex lowercase/uppercase
  replay, affected Herdr validation, live Claude safety, and fresh
  Standards/Fidelity review passed without submission.
- 2026-07-21 — `fish-startup-architecture`: startup now consumes prepared
  state; Git data is on-demand; theme and FZF binding ownership are singular;
  real-PTY QA, the full verifier, a 26.990 ms median / 27.748 ms p95 benchmark,
  and post-fix Standards/Fidelity review passed.
- 2026-07-21 — `fish-environment-correctness`: checked-in global Fish
  configuration now owns XDG/application values; Java and Vivid output are
  valid; stale universal PATH/environment state is removed; optional inputs are
  safe; the fresh-shell audit, full verifier, and post-fix Standards/Fidelity
  review passed.
- 2026-07-21 — `transport-security-baseline`: Git TLS verification is enabled;
  Homebrew and Fisher bootstrap content is pinned and SHA-256 verified; Fisher
  plugins pin exact commits; Rust uses Homebrew's `rustup`; deterministic audit,
  full Fish verification, and post-fix Standards/Fidelity review passed.
- 2026-07-19 — `ready-prompt-claude-clear-replay`: `Prefix+b` and `Prefix+B`
  now support Codex and Claude in tmux and the Herdr prototype. Deterministic
  tests, live Claude clear-ready-insert checks in both multiplexers, and fresh
  Standards/Fidelity review passed without automatic prompt submission.
- 2026-07-19 — `agent-skill-context-cleanup`: deterministic catalog checks and
  fresh Standards/Fidelity review passed, then the user confirmed fresh Codex
  and Claude sessions accepted the reduced catalogs.
