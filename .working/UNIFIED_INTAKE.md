# Unified Intake

## Active

None.
Source:
`.working/interviews/fish-vi-cursor-not-blinking/observations.md`.

## Ranked Next

1. `herdr-copy-mode-pending-commands`: highest readiness. Implemented and gated
   since 2026-08-01, but its fresh Standards/Fidelity review never ran, which
   is the only agent-owned step between it and closure. Eddy's physical
   acceptance in a new session remains separate and his.
2. `xcode-27-beta`: potentially useful for `pi-xcode`, but lower readiness;
   blocked by side-by-side-versus-replacement choice and Apple authentication.
3. `herdr-pane-input-lock`: low demonstrated need and still `Spec Needed`.

Not selectable now: `herdr-upstream-copy-mode-gaps` remains upstream-blocked;
`fish-fzf-image-visible-geometry-regression` remains intentionally deferred
after unreliable live rendering.

## Investigating

- `agent-closeout-length-violations`: OPEN, severity high (Eddy abandoned a
  session over it). Area: agent response contract. Found in: Claude Code,
  repeatedly; Codex complied after one instruction.

  Observed: responses exceed the `pi/AGENTS.md` budget of 15 body lines plus a
  one-line-per-section closeout. Five recorded instances; the 2026-08-03 nvim
  commit session produced a ~30-line report and Eddy left for Codex mid-task.
  Expected: same facts, inside the budget.

  Confirmed: the instruction is delivered every turn — `agent-config/claude/
  closeout.sh context` injects the Response Style section on
  `UserPromptSubmit`, and it is present in the offending transcripts. So this
  is not a missing-context bug. Provisional cause, not proven: the model
  treats a large task as license for a large report; the recorded triggers are
  multi-repo work, surfaced blockers, and multi-commit work (one bullet per
  commit).

  Correction applied 2026-08-03, required: `agent-config/claude/
  closeout_length.py`, wired as a `Stop` hook via `closeout.sh length`. It
  blocks a turn whose body exceeds 15 non-blank lines or whose closeout
  exceeds 12, returns the actual counts, and forces a re-send. `stop_hook_
  active` prevents a loop; unparseable input is a silent no-op. First observed
  firing live on 2026-08-13 in the gss image-preview session: it rejected a
  16-line and then a 14-line closeout, reported both counts, and the third send
  fit. The open validation step is satisfied; whether 15/12 are the right caps
  is still Eddy's call.

  Optional, not proven: no equivalent enforcement exists for Codex, which has
  not needed it. Whether the caps (15/12) are the right numbers is Eddy's
  call.

  `shares implementation seam with` `agent-skill-context-cleanup` (both govern
  what reaches the agent each turn). Remote mirror: pending — no hosted issue
  filed; the durable record is here.

- `fish-vi-cursor-not-blinking`: `resolved by`
  `terminal-cursor-blink-ownership`. Ghostty's effective config enables cursor
  blinking, but login Fish vi mode sets `fish_cursor_default=block`,
  `fish_cursor_insert=line`, `fish_cursor_replace_one=underscore`, and
  `fish_cursor_visual=block` without Fish's required `blink` suffix. Fish's
  mode-aware cursor escape therefore overrides the terminal default with a
  steady shape. The same ownership pattern affects Neovim modes whose
  `guicursor` entries omit blink timing. Source:
  `.working/interviews/fish-vi-cursor-not-blinking/observations.md`.

- `fish-ll-git-latency`: `symptom of` RubyandRiver Git metadata conflict
  artifacts and stale locking, not an eza-specific defect. The selected
  in-place index-lock repair resolves the reproduced latency without changing
  `ll`; broader conflict artifacts remain a recurrence risk, not authorized
  cleanup. Source:
  `.working/interviews/fish-ll-git-latency/observations.md`.

- `xcode-27-beta`: Eddy requested upgrading from Xcode 26.6 for `pi-xcode`.
  Apple currently publishes Xcode 27 only as beta 4; the Mac is already on the
  latest stable Xcode 26.6. A beta installation needs an explicit
  side-by-side-versus-replacement decision and Apple Developer download
  authentication. No toolchain change has been made.

- `herdr-upstream-copy-mode-gaps`: rectangle selection, marks, prompt jumps,
  selection-bounded search, and cursor-local URL opening remain `blocked by`
  absent Herdr primitives in v0.7.4 and are not advertised by v0.7.5. Distinct
  copy-line `Y` is `resolved by` the completed reviewed source-build goal, and
  counts plus `zz` are `resolved by` `herdr-copy-mode-pending-commands`. Do
  not emulate the remaining gaps through injected input.
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

- 2026-08-13 — `fish-gss-image-preview`: **DONE**. `gss` previewed a changed
  image through delta and bat, so a PNG came up as "Binary files differ" plus a
  bat binary-content warning. The kitten/chafa painter and the extension test
  moved out of `_fzf_preview` into `_fzf_preview_image` and
  `_fzf_preview_is_image`; `__gss_preview` now calls both, offset by the two
  rows its status header owns. Deleted images still fall through to the diff
  path. Regression coverage asserts the placement and the absent text
  fallback; full `fish/scripts/verify.sh` passed and Eddy accepted the physical
  render. Committed and pushed as `4579aa7d`.

- 2026-08-03 — `closeout-beside-the-prompt-editor`: **DONE, implemented in
  `~/.config/nvim`**, which is why this repository's record previously and
  wrongly read "no implementation". `Ctrl+g` opens the agent's prompt file in
  Neovim with the captured closeout beside it in a read-only `nofile`
  `split = "right"` buffer — the preferred shape, not the appended-with-dashes
  fallback. The three open questions are settled by that implementation: the
  split is the only behavior, the capture is the whole closeout, and the editor
  is Neovim specifically.

  `~/.config/nvim` commits: `a1fc4fe2` (`lua/plugin/agent-prompt.lua`,
  `tools/agent_prompt_editor.sh`, specs and fixtures) and `172d3942`
  (detection widened past Claude Code to Pi, Codex, and OpenCode via the
  `AI_AGENT` convention, per-runtime markers, and `$TMPDIR` versus `/tmp`
  roots). Dotfiles owns only the entry point: `fish/user_variables.fish` routes
  `VISUAL` through the shim and stays a pass-through outside an agent pane, so
  `git commit` is unaffected (`b35c1199`).

  `Ctrl+Shift+g` was never needed — the shim captures during the existing
  `Ctrl+g`, so the CSI-u chord-distinguishability risk recorded here is moot.
  Verified 2026-08-03: 16/16 shim tests and `~/.config/nvim/tools/verify.sh`
  green at 0 warnings / 0 errors. `shares implementation seam with`
  `herdr-ready-prompt-handoff` (`prefix+b` / `prefix+Shift+b`), which still
  owns replay into the pane.

- 2026-08-03 — `herdr-alt-ctrl-n-new-tab`: **DONE**. Ghostty
  `Left Option+Control+n` creates exactly one focused cwd-following tab in the
  current workspace; `Prefix+c` stays native and `Alt-t` stays unbound in Herdr.
  Focused CSI-u transport coverage, `validate_tabs.sh`, full Herdr/Fish gates,
  and fresh review at Standards 0 / Fidelity 0 passed. Eddy accepted the
  physical chord on 2026-08-03. `resolved by`
  `.working/interviews/herdr-alt-ctrl-n-new-tab/decisions.md`.

- 2026-08-01 — `terminal-cursor-blink-ownership`: **DONE**. Herdr now owns a
  500 ms blink phase for the focused Ghostty surface, including default,
  steady, and hidden TUI cursors such as Codex. Focus loss restores the source
  steady/hidden state so background panes/windows do not blink; position and
  shape remain intact. Focused tests, full Herdr/Fish gates, and fresh final
  review passed at Standards 0 / Fidelity 0. Eddy accepted physical
  multi-window behavior. No push. `resolved by`
  `.working/interviews/fish-vi-cursor-not-blinking/closure.md`.

- 2026-08-01 — `fish-prompt-return-latency`: **DONE**. RubyandRiver remains at
  its exact path. A stale zero-byte Git index lock was quarantined recoverably,
  reducing repeated Git status from 0.85 seconds to 0.01-0.02 seconds and
  unchanged `ll --git` to 0.02-0.06 seconds. Starship Git status is restored.
  Both Git-bearing prompt gates pass near 31 ms p95, full Fish verification
  passes, Eddy accepted physical Ghostty behavior, and fresh final review
  passed at Standards 0 / Fidelity 0. Remaining File Provider conflict
  artifacts are recorded recurrence risk. No push. `resolved by`
  `.working/interviews/fish-prompt-return-latency/closure.md`.

- 2026-08-01 — `pi-global-response-style-parity`: **DONE**. One canonical
  repository rule source now serves Codex directly, Claude through its import
  adapter and source-reading hook, and Pi through its exact isolated-config
  symlink. Safe all-target migration preflight, fail-closed Pi launch checks,
  private concurrent verification state/evidence, overlapping validator
  coverage, full Pi/Fish gates, real no-provider context discovery, and fresh
  final review passed at Standards 0 / Fidelity 0. The reviewed Herdr pin,
  physical/device gates, deferred scope, and no-commit/no-push boundary remain
  intact. `resolved by`
  `.working/interviews/pi-global-response-style-parity/closure.md`.

- 2026-07-31 — `pi-lazy-mcp-and-ios-tooling`: **DONE**. The opt-in Pi pilot
  owns a lifecycle-script-disabled, lockfile- and hash-verified
  `xcodebuildmcp@2.7.0` installation, telemetry-disabled CLI-only wrapper,
  exact official CLI skill, and four canonical shared Swift/SwiftUI skills.
  MCP/init/setup/upgrade/socket/MCP-output paths fail closed. Disposable
  SwiftUI doctor/discovery/build/test/build-and-run/screenshot/gesture,
  automatic daemon idle cleanup, marker-owned rollback, full Pi/Fish gates,
  live install checks, and fresh review passed at Standards 0 / Fidelity 0.
  Physical-device/tactile gates remain manual. MCP adapter/server mode,
  ambient MCP discovery, Xcode 27, and default-agent promotion remain deferred.
  No commit or push. `resolved by`
  `.working/interviews/pi-lazy-mcp-and-ios-tooling/closure.md`.
- 2026-07-31 — `fish-fcat-selected-path`: **DONE**. `fcat` prints only the
  selected file's copyable home-relative path in subtle `brblack`, followed by
  one blank line and unchanged contents; outside-home paths remain canonical
  absolute paths. The physical RubyandRiver failure was a `symptom of` VCS
  ignore handling: scoped `--no-ignore-vcs` now exposes ignored local files
  while `.git` remains explicitly excluded. Query-derived producer coverage,
  `.git` guards, focused/full Fish verification, the exact real-fzf PTY route,
  and fresh final review passed at Standards 0 / Fidelity 0. Eddy reloaded
  `fcat` and accepted physical colour/copy behavior on 2026-07-31. No commit or
  push. `resolved by`
  `.working/interviews/fish-fcat-selected-path/closure.md`.
- 2026-08-01 — `herdr-copy-mode-pending-commands`: **AWAITING CONFIRMATION**.
  Copy mode gained Vim's pending-command buffer: a typed count repeats the next
  motion and makes `V`, `Y`, and a selection-less `y` linewise over that many
  lines; `zz` centres the cursor's line; Esc discards a half-typed count or `z`
  without clearing the selection or search. `copy_mode` is now `prefix+s` plus
  `alt+/`, `copy_mode_search` moved to `alt+b`, and `alt+s` became a second
  split-down chord and `alt+d` was unbound. Eight new focused Rust tests, extended PTY
  clipboard/viewport evidence, the reviewed rebuild and re-pin, and full
  Herdr/Fish gates passed; fresh Standards/Fidelity review did not run. No
  commit or push. Physical acceptance in a newly created session is still
  Eddy's. Source:
  `.working/interviews/herdr-copy-mode-pending-commands/closure.md`.
- 2026-07-31 — `herdr-copy-mode-vim-muscle-memory`: **DONE**. The reviewed
  exact-v0.7.4 source build adds copy-mode `a` and `i` as exit-without-copy
  aliases for `q`, and `Y` as composed whole-line selection plus
  copy-and-exit. Exact tag, commit, toolchain, patch, patched-source, and binary
  hashes are pinned; the installer is atomic and fail-closed. Focused Rust and
  disposable PTY tests, full Herdr/Fish gates, and fresh Standards/Fidelity
  review passed. Eddy accepted physical `Prefix+s` then `a`, `i`, and `Y` in a
  newly created session on 2026-07-31. `pane_history = false`, recovery,
  tmux fallback, and the no-input-emulation boundary remain intact. No commit
  or push. `resolved by`
  `.working/interviews/herdr-copy-mode-vim-muscle-memory/closure.md`.
- 2026-07-30 — `pi-isolated-pilot`: **DONE**. The pinned, isolated,
  reversible Pi 0.82.1 pilot now has Catppuccin Mocha, a `❯` prompt,
  branch-local prompt history, Ctrl-P/Ctrl-N list and history navigation,
  Ctrl-Shift-M model selection, resilient Ctrl-L clear/redraw, mode-aware
  hardware cursor behavior, recency-ranked slash suggestions, pinned FFF
  `@` completion, and retained Herdr handoff/session integration. Automated
  Pi/Fish/ready-prompt gates and fresh Standards/Fidelity reviews passed.
  Eddy confirmed every applicable physical item, including `Prefix+b` and
  `Prefix+B`. Pi remains opt-in; no MCP/iOS packages, promotion, commit, or
  push occurred. `resolved by`
  `.working/interviews/pi-isolated-pilot/closure.md`.
- 2026-07-29 — `herdr-cross-session-agent-overview`: **DONE**. Every physical
  Ghostty window remains attached to its independent named Herdr session, while
  `Prefix+A` discovers agents across all running local sessions and shows
  session, agent, status, and cwd. Bounded Read returns cleanly on bare and
  Kitty CSI-u Escape; Focus targets the exact pane inside its owning session
  without reattaching or raising a window; Message supports physical multiline
  `Cmd-V` and inserts exact text without Return, submission, or focus change.
  Stale targets fail closed. Full Herdr/Fish verification, physical two-window
  QA, and fresh final review passed at Standards 0 / Fidelity 0.
  `pane_history = false`, recovery, independent-window allocation, and tmux
  fallback remain intact. No commit or push. `resolved by`
  `.working/interviews/herdr-cross-session-agent-overview/closure.md`.
- 2026-07-29 — `herdr-independent-ghostty-windows`: **DONE**. Native Ghostty
  `Command-N` now creates independent named Herdr sessions instead of mirroring
  `main`. A no-client launch restores the last retained automatic session;
  while a client is active, New Window creates a never-before-used monotonic
  `window-N` session from `$HOME`. HUP-resistant PID-plus-start-identity leases,
  private locked runtime state, recovery, explicit overrides, nesting guards,
  `pane_history = false`, and tmux fallback are preserved. Deterministic gates,
  full Herdr/Fish verification, and fresh Standards/Fidelity review passed.
  Final physical close-all/reopen restored `window-7`, then a concurrent second
  window created `window-9`; the windows remained independently navigable and
  writable. No commit or push. `resolved by`
  `.working/interviews/herdr-independent-ghostty-windows/closure.md`.
- 2026-07-29 — `herdr-independent-ghostty-windows`: **superseded closure**;
  the independent-window and cwd behavior passed, but Eddy then clarified the
  restore-versus-create lifecycle. The earlier record: native Ghostty `Command-N`
  gives each ordinary top-level window the lowest inactive
  persistent named Herdr session (`main`, then `window-N`) instead of mirroring
  an occupied session. Meaningful Ghostty cwd inheritance is retained; a root
  `/` launch falls back to `$HOME` before allocation. Eddy's pictured retained
  `window-3` was repaired to `~`, and fresh physical `window-4` started at
  `$HOME`. Explicit named-session overrides, recovery, all guards, and tmux
  fallback remain intact. Focused regressions cover cwd success/failure and
  guard inertness as well as concurrency, reuse, safety, and `window-10`. Full
  Herdr/Fish verification and physical QA passed; final review closed at
  Standards 0 / Fidelity 0. No commit or push.
  `resolved by`
  `.working/interviews/herdr-independent-ghostty-windows/closure.md`.
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
