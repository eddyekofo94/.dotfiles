# Unified Intake

## Active

None.

## Investigating

- `herdr-upstream-copy-mode-gaps`: rectangle selection, copy-line, marks,
  prompt jumps, selection-bounded search, and cursor-local URL opening are
  `blocked by` absent Herdr primitives in the installed v0.7.4 and are not
  advertised by v0.7.5. Do not emulate them through injected input.
- `herdr-pane-input-lock`: tmux pane disable/enable has no demonstrated Herdr
  need or native equivalent and remains `Spec Needed`.

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
- 2026-07-24: Eddy paused final Herdr daily-driver acceptance and requested an
  exhaustive implementation pass for every missing tmux feature. Reason: the
  prior core migration gate did not durably enumerate the lower-frequency
  tmux utilities and recovery limitations. The completed promotion becomes
  `blocked by` the ranked parity sequence rather than being discarded.

## Completed

- 2026-07-29 — `herdr-shared-buffer-history`: **durably deferred and
  upstream-limited** on the retained Herdr v0.7.4. The live tmux server's
  `choose-buffer` surface is a genuine 50-entry auto-named in-memory buffer
  ring; only names, sizes, and creation times were inspected. Herdr's installed
  help, complete generated config and API schema, exact tagged source, and
  official documentation expose only single-entry system clipboard writes,
  host paste handling, OSC 52 forwarding, and bounded remote image staging—no
  named-buffer store, chooser, list/read/delete lifecycle, or retention policy.
  Ordinary Herdr copy/paste is retained as the security-conscious replacement,
  but is not multi-entry parity. Clipboard persistence, `pbpaste` polling,
  plugin-state capture, pane-readback scraping, and picker emulation are
  rejected without a separately selected and settled security product
  boundary. Herdr remains v0.7.4 with `pane_history = false`; tmux remains
  available. `blocked by` upstream support for a documented native multi-entry
  facility or a future explicit product decision; `resolved by`
  `.working/interviews/herdr-shared-buffer-history/decisions.md`.
- 2026-07-29 — `herdr-outer-terminal-title-parity`: classified
  **upstream-limited** on the retained Herdr v0.7.4. A controlled direct OSC 2
  probe proved Ghostty 1.3.1 accepts and exposes application-provided titles.
  Herdr's one-shot `terminal title set/clear` API dispatched successfully in
  both the production `main` session and an isolated direct Ghostty session,
  but did not produce stable physical/readback title evidence. The complete
  v0.7.4 generated config, API schema, official changelog, and tagged source
  expose no supported dynamic title-template setting—only literal set/clear
  APIs intended for scripts/plugins. Custom event emulation and static-title
  substitution are rejected. No Herdr, Ghostty, Fish, or tmux production
  configuration changed. `affects` presentation, not recovery; `blocked by`
  upstream support for a documented dynamic session/tab/pane title template.
  `resolved by`
  `.working/interviews/herdr-outer-terminal-title-parity/decisions.md`.
- 2026-07-29 — `herdr-picker-reference-parity`: `Prefix+Shift+f` provides a
  searchable one-target pane/tab/workspace delete manager with explicit
  confirmation, strict inventory ownership/uniqueness checks, and fresh
  descendant terminal/topology fingerprints. `Prefix+Shift+r` provides
  newest-first URI/path/hash discovery over bounded recent pane readback;
  Enter copies and Ctrl-O opens URI/path references with relative/`~/` path
  resolution. Control bytes are stripped before display. Native `Prefix+f`
  remains goto, and no copy-mode parity is claimed or emulated. Focused fixture
  and real-prefix evidence, all refreshed Herdr gates, full Herdr/Fish
  verification, and post-fix fresh review pass at Standards 0 / Fidelity 0.
  Herdr remains v0.7.4 with `pane_history = false`; tmux remains available.
  `resolved by`
  `.working/interviews/herdr-picker-reference-parity/closure.md`. Final
  daily-driver acceptance remains `blocked by` explicitly upstream-limited
  title/copy-mode gaps and the remaining decision-required parity items.
- 2026-07-28 — `herdr-pane-tab-utility-parity`: `Prefix+Shift+p` provides
  session-wide stale-safe send/receive transfers with same- and cross-workspace
  process/cwd/focus preservation and tested rollback. `Prefix+Shift+u` exports
  exact decoded scrollback through a non-creating verified file open, including
  320 ordered lines and before/after-open path-swap rejection. `Prefix+^` /
  `Prefix+$` provide stable API-order tab edges. The five named layout presets
  are ratio-only, topology-compatible, real-binding tested, and fail closed on
  foreign concurrent ratios. Full Herdr and Fish verification passed; closure
  review finished at Standards 0 / Fidelity 0. Herdr remains v0.7.4 with
  `pane_history = false`; tmux remains available. `unblocks`
  `herdr-picker-reference-parity` while final daily-driver acceptance still
  depends on the remaining ranked parity sequence.
- 2026-07-27 — `herdr-project-sessionizer-workflow`: `Prefix+Shift+w` now opens
  a Herdr-native Git repository/worktree picker in the current session, reuses
  a canonical project workspace, safely re-adopts tokenless restored pane cwd,
  or creates a basename-labeled workspace. Strict API/live-state validation,
  atomic per-session locking, target-only transactional rollback, collision and
  failure fixtures, real fzf popup transport, and restart/isolation coverage
  pass. Full Herdr and Fish verification passed; closure review finished at
  Standards 0 / Fidelity 0. Herdr remains v0.7.4 with `pane_history = false`;
  tmux remains available. `unblocks` the ranked
  `herdr-pane-tab-utility-parity` candidate while final daily-driver acceptance
  still depends on the remaining parity sequence.
- 2026-07-24 — `herdr-recovery-safety-parity`: the exact approved official
  Claude Code, Codex, and OpenCode integrations are current on the retained
  Herdr v0.7.4 binary. Existing hooks/plugins are preserved with an external
  rollback snapshot and deterministic coexistence checks. A real disposable
  Codex conversation reported native identity, lost its original process on a
  controlled Herdr stop, resumed the same conversation, and completed a new
  turn without any pane-history file. Full Herdr and Fish verification passed;
  post-fix fresh review closed at Standards 0 / Fidelity 0. `resolved by`
  `herdr/verify_integrations.sh` and
  `.working/interviews/herdr-recovery-safety-parity/installation-validation.md`;
  `unblocks` the next ranked parity slice while final daily-driver acceptance
  remains dependent on the rest of the ranked parity sequence.
- 2026-07-23 — `herdr-trial-no-color-inheritance`: confirmed as a Codex trial
  launcher environment leak, not a Herdr/eza renderer defect. The isolated
  live Ghostty launcher now removes `NO_COLOR`; normal shell configuration is
  unchanged, and Eddy confirmed `ll` colors display normally.
- 2026-07-23 — `herdr-fzf-alt-j-focus-regression`: a manually started nested
  `fish` no longer drops the prototype's process-local `Alt-h/j/k/l` bindings.
  Exact nested-shell regression coverage, hash-bound binding/pane/capability
  evidence, aggregate Herdr verification, and fresh Standards/Fidelity review
  passed. A clean Ghostty trial physically exercised fzf `Alt-j`, nested-Fish
  `Alt-k`, fzf `Alt-h`, and Neovim edge `Alt-l`; production Fish, tmux, Ghostty,
  and Neovim configuration hashes stayed unchanged. Eddy confirmed the final
  physical behavior is working well.
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
