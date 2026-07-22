# Fish Regression Audit

## Goal

Thoroughly audit and repair user-visible regressions introduced by the current
uncommitted Fish environment, startup-ownership, security, and FZF changes,
rather than waiting for Eddy to discover them one at a time.

## Exit Criteria

- Every behavior changed or promised by the transport-security,
  environment-correctness, startup-architecture, Ctrl-T binding, and Ctrl-T
  image-preview records has an explicit deterministic or live consumer check.
- Confirmed regressions are reproduced through their real call paths, fixed at
  the owning seam, and protected by red/green regression coverage.
- The exact BibleStandard PNG uses the canonical image previewer through
  `Ctrl-T` without a bat warning.
- Full Fish verification, startup benchmarks, live PTY interaction matrix,
  scoped diff/audit checks, and fresh Standards/Fidelity review pass after the
  final fix.
- The tracker accurately records every linked report and no unrelated dirty
  work is changed.

## Scope / Non-goals

In scope: all current uncommitted behavior changes and verification seams from
the completed `transport-security-baseline`, `fish-environment-correctness`,
`fish-startup-architecture`, and `fish-ctrl-t-fzf-regression` goals; the
diagnosed `fish-ctrl-t-image-preview-regression`; Fish runtime consumers,
prepared-state fallbacks, interactive bindings/plugins/prompts, Git and non-Git
paths, FZF file/text/directory/image behavior, login/nesting guards, performance,
worker cleanup, tests, and durable workflow records.

Non-goals: Herdr promotion or prototype behavior, tmux automation changes,
Zsh behavior, fonts/dead-code/repository-size cleanup, redesigning established
Fish UX, commits, pushes, hosted tickets, or publication. Read-only checks may
cross into bootstrap/security files already changed by the cited goals; edits
outside Fish require direct evidence that this audit's regression originates
there.

## Decisions

- Treat this as one bounded QA goal with confirmed regressions as linked
  subfindings, not as an unbounded cleanup batch.
- The fixed baseline is commit
  `3a06efbdcc07ebffe6066ea5f51b04a349cb5d1a`; audit the relevant staged,
  unstaged, and untracked current work against the cited decision records.
- Build the matrix from real consumers first. Static owner/hash assertions are
  supporting evidence, not proof that an interaction works.
- Preserve the intended one-owner architecture: checked-in Fish configuration
  owns environment and bindings; startup consumes prepared state; maintenance
  scripts generate it; `fish_user_key_bindings.fish` solely owns FZF mappings;
  canonical `_fzf_preview` owns image rendering.
- Fix every confirmed in-scope regression automatically, add prevention at the
  real seam, rerun affected checks, then perform fresh two-axis review.
- User-visible terminal pixel quality remains a manual acceptance item only when
  deterministic payload and live PTY evidence cannot prove it objectively.

## Evidence / Findings

- Eddy found two sequential regressions after the startup cleanup: missing
  `Ctrl-T`, followed by PNGs reaching `bat` after `Ctrl-T` was restored.
- The Ctrl-T binding regression is fixed and covered, but its initial validation
  verified key delivery and canonical preview independently rather than the
  combined dispatcher path.
- The image regression is deterministically reproduced against
  BibleStandard's `Sources/App/Resources/app_icon_87.png`. The retained
  `_fzf_search_directory` calls legacy `_fzf_preview_file`; with no
  `fzf_preview_file_cmd`, it sends regular files to `bat`.
- Temporarily setting `fzf_preview_file_cmd=_fzf_preview` repairs that exact
  path without restoring generated FZF ownership.
- `fish/scripts/verify.sh` has passed repeatedly, proving that its previous
  coverage was insufficient to detect at least these real-path regressions.
  The audit must therefore test composed consumer flows, not only component
  outputs.
- The maintenance command used a broad `find ~/.cache/fish -name '*.fish'
  -mmin +1200 -delete` before regenerating its named caches. An isolated fixture
  proved that it deletes an unrelated consumer's old Fish cache. This is a
  confirmed startup-ownership regression; maintenance must overwrite only its
  explicitly named outputs and preserve unowned files.
- The worktree contains extensive unrelated Herdr/tmux/Zsh work and prior
  reviewed Fish work. Preserve it; use explicit path and hunk discipline.

## Audit Matrix

- Environment: inherited and fallback `JAVA_HOME`; XDG/application variables;
  Vivid output; optional Cargo/UV sources; canonical, existing, nonduplicated
  PATH; clean universal state.
- Prepared startup: present, missing, and refreshed cache paths; no generation,
  expiry, symlink, Git-config, or installation mutation during startup.
- Interactive shell: prompt/right prompt, theme ownership, abbreviations,
  autopair, magic-enter, vi mode, custom bindings, fifc Tab, fzf completion, and
  second-shell availability.
- Git behavior: repository and non-repository prompt/abbreviation paths without
  eager startup Git work or global mutation.
- FZF: exact default/insert mappings for Ctrl-R/G/P/T; sole owner; Ctrl-T/Ctrl-P
  file insertion; text/directory/image preview dispatch; PNG transport; Ctrl-U,
  Ctrl-F/B, open/copy/grep bindings; `fe`, `fif`, and git-status consumers.
- Login/process safety: noninteractive and non-login paths; tmux/nesting guard
  remains unchanged; repeated shells leave no workers; startup benchmark stays
  within the settled median/p95 limits.
- Security/bootstrap: existing deterministic success/mismatch audits and syntax
  checks remain green; no runtime Fish regression is hidden by prepared state.

## Validation Plan

- Extend focused tests only where a real consumer-path gap is demonstrated;
  watch each new assertion fail before its fix and pass afterward.
- Run the exact BibleStandard PNG reproduction and the complete FZF integration
  suite for image, text, directory, bindings, and related consumers.
- Run environment, startup-ownership, transport-security, syntax, worker-leak,
  and 30-run startup benchmark checks through `fish/scripts/verify.sh`.
- Run a scripted live interactive PTY matrix that sends real control bytes and
  exercises prompt, bindings, picker entry/cancel/return, and representative
  Git/non-Git paths. Use fixed terminal geometry and terminal-query responses.
- Audit all relevant changed paths against the fixed baseline and run scoped
  `git diff --check`.
- Give a fresh reviewer the source decisions, audit matrix, actual diff, failure
  evidence, and final validation. Require separate Standards and Fidelity
  findings; fix and re-review until both are zero or a real blocker remains.

## Ready To Act

Ready. On 2026-07-22 Eddy explicitly selected a thorough regression audit and
authorized fixing confirmed regressions. No implementation-changing questions
remain.

## Open Questions

None.

## Implementation And Validation Evidence

- Restored the supported fzf.fish regular-file adapter by setting
  `fzf_preview_file_cmd` to the canonical `_fzf_preview`; no generated/native
  `fzf-file-widget` ownership was reintroduced.
- Changed FZF integration coverage to call the real `_fzf_preview_file`
  dispatcher for image, text, and directory fixtures, and expanded exact
  default/insert binding coverage across Ctrl-R/G/P/T and retained picker
  actions.
- Removed the broad stale-cache deletion from
  `fish/scripts/refresh_startup.fish`. Maintenance now overwrites only its
  explicitly named generated files; an isolated old unrelated cache survives.
- Added `fish/tests/startup_consumer_integration.sh` for refresh ownership,
  missing-cache startup, interactive plugin/abbreviation availability, and Git
  versus non-Git consumers.
- Added `fish/tests/interactive_consumer_pty.sh` with fixed PTY geometry and
  terminal-query replies. It physically exercises reader initialization,
  autopair, Ctrl-R history, Ctrl-G Git status, Ctrl-P file selection, Ctrl-T,
  cancellation/return, and Kitty image transport.
- Exact dispatcher validation against BibleStandard's
  `Sources/App/Resources/app_icon_87.png`: PASS, 17,722-byte Kitty payload, no
  `Binary content from file` warning.
- `fish/scripts/verify.sh`: PASS. Included transport security, environment,
  startup ownership, Fish syntax, FZF/FIF integrations, startup consumers, live
  PTY interactions, worker cleanup, scoped diff check, and a 30-run startup
  benchmark (final median 29.788 ms, p95 31.844 ms).

## Review Fix Loop

Fresh review found and the implementation now covers five additional composed
regressions that component-only checks had missed:

- Maintenance inherited legacy XDG cache roots while runtime Fish normalized
  them, preparing state that startup never consumed. Maintenance now uses the
  same deterministic roots, with a known-bad inherited-XDG fixture.
- Failed brew/fzf/zoxide/starship/Vivid generation could still replace cache
  files and claim PASS. Every generator, nonempty result, atomic move, link,
  and Git mutation now fails closed; the fzf failure fixture proves a nonzero
  result, no PASS, no temporary leak, and preservation of last-known-good data.
- The newly active fzf.fish adapter evaluated filenames as Fish source. The
  dispatcher now invokes configured argv directly; a quote/semicolon filename
  proves correct preview output and no injected side effect.
- A failed verified Fisher bootstrap could leave an empty target directory that
  made the next attempt return success. Directory creation now follows verified
  installer sourcing, incomplete newly-created output is removed after install
  failure, and two failed-fetch attempts both remain retryable.
- The first PTY return-path assertion could match echoed input and leak autopair
  command-line state. It now synchronizes on Fish execution markers, reads back
  and clears each composed state, waits on observable fzf result counts, and
  proves both Ctrl-P text and Ctrl-T image selection. Five consecutive focused
  PTY runs and the final full verifier passed.

## Review State

Final post-fix review is clean: Standards findings 0, Fidelity findings 0.

## Closure

Verified complete on 2026-07-22. The audit's deterministic matrix, exact
BibleStandard PNG dispatcher, five-run PTY stability check, final full Fish
verifier, performance limits, scoped diff check, and independent re-review all
passed. The one remaining human acceptance item is a visual Ghostty/tmux glance
at a PNG for subjective pixel quality; it does not block the objectively proven
dispatch, transport, or regression closure. No commit or push was performed.

## Reopened Visual Acceptance Failure

On 2026-07-22 Eddy rejected the remaining Ghostty/tmux visual acceptance. In
the exact BibleStandard `Ctrl-T` picker, `design/Images/Bottom cut-off.png`
produces Kitty payload but is visibly mis-rendered while selected; Eddy reports
that it renders correctly only when it is no longer on screen. This disproves
the claim that payload presence plus path return proves live image geometry.

The goal is reopened at the image sizing/placeholder seam. No further product
change is allowed until a deterministic or scripted live-path check can turn
red on the visible geometry symptom.

## Reopened Geometry Hypotheses

Ranked before changing the renderer:

1. The retained fzf.fish preview subprocess is not supplying a usable positive
   `FZF_PREVIEW_LINES`, so `_fzf_preview` falls back to 40 rows. Prediction:
   capturing the live retained-picker environment reports the inherited legacy
   `-200` value or no value, and the resulting payload is about 39 lines, as in
   Eddy's screenshot.
2. Kitty's Unicode-placeholder output consumes two more terminal rows than the
   requested `--place` height. Prediction: parsing Kitty's graphics metadata
   reports an `r` value greater than an explicitly supplied pane height; a
   renderer-side row reservation makes it fit without changing image routing.
3. The retained picker's bordered preview has fewer drawable rows than the old
   native widget's `noborder` preview. Prediction: both paths export positive
   geometry, but only the retained path's output exceeds its drawable region.
4. The final Perl reset rewrite damages the last placeholder row. Prediction:
   bypassing that rewrite changes the tail only and leaves the reported image
   row count and visible crop unchanged.
5. Shared-memory passthrough timing corrupts the placeholder grid. Prediction:
   transfer mode changes the live symptom but does not explain or remove the
   deterministic row-budget overflow.

## Reopened Geometry Diagnosis

- Confirmed hypothesis 1. In a fixed 120x40 interactive PTY, the retained
  picker exported a 62-column preview but `_fzf_preview` observed `62x40`.
- Cause: fzf exported its live pane geometry, then the Fish preview subprocess
  sourced `_fzf_envs.fish`, which replaced only `FZF_PREVIEW_LINES` with the
  legacy global value `-200`. The renderer rejected that non-positive value and
  fell back to 40 rows. `FZF_PREVIEW_COLUMNS` was untouched, producing the
  asymmetric geometry seen on screen.
- The old native widget did not use fzf.fish's Fish preview-shell boundary, so
  the unchanged renderer previously received usable geometry.
- Removing the unrelated global assignment changes the same live probe from
  `62x40` to fzf's actual `62x35` pane budget. No Kitty sizing, transfer mode,
  preview ownership, binding, or Herdr/tmux behavior changes are required.

## Reopened Geometry Implementation And Validation

- Removed only the legacy global `FZF_PREVIEW_LINES=-200` assignment. fzf now
  retains ownership of both preview dimensions inside its Fish subprocess. A
  guarded migration clears that exact retired value if an existing terminal or
  tmux server still exports it; positive fzf geometry is preserved.
- Added a deterministic source-preservation assertion for injected fzf pane
  geometry and a test-only geometry report in the canonical renderer.
- The physical-control-byte PTY check failed red at `62x40`, passed green at
  the exact fixed `62x35`, and passed five consecutive focused runs.
- Added an isolated tmux consumer check with a real interactive Fish reader,
  Ctrl-T byte, retained fzf.fish picker, Kitty placeholder output, exact
  `62x35` geometry, no bat warning, and selected-path return.
- The isolated tmux check passed with BibleStandard's exact reported portrait,
  `design/Images/Bottom cut-off.png`, not only its self-contained PNG fixture.
- Final `fish/scripts/verify.sh`: PASS, including direct PTY, isolated tmux,
  environment/startup/security checks, selection consumers, leak detection,
  and 30-run startup benchmark (28.469 ms median, 29.584 ms p95).
- Scoped `git diff --check`: PASS. No commit or push was performed.

## Reopened Geometry Review Fix Loop

The first fresh review found one Major Fidelity proof gap and one Minor
Standards documentation error; it did not find another product defect.

- The isolated tmux check previously proved geometry, routing, absence of a bat
  warning, and selection return, but did not require successful Kitty output.
  It now captures the raw pane stream and requires both the exact
  `FZF_PREVIEW_IMAGE_PLACE:62x35@0x0` branch marker and Kitty graphics plus
  Unicode-placeholder bytes for the selected image.
- The workflow document now names the separate direct-PTY and isolated-tmux
  scripts accurately.
- Post-fix exact BibleStandard portrait isolated-tmux run: PASS.
- Post-fix full `fish/scripts/verify.sh`: PASS (29.047 ms median, 29.942 ms
  p95). Scoped `git diff --check`: PASS.
- Fresh post-fix re-review: Standards findings 0, Fidelity findings 0.
- The inherited-sentinel migration assertion failed before its guard and passed
  afterward. Final full verification after the guard passed (28.580 ms median,
  29.905 ms p95); final re-review remained Standards 0, Fidelity 0.

## Reopened Geometry Status

Awaiting Eddy's visual confirmation in the real Ghostty/tmux pane. Automated
closure gates are green, but the active goal remains open because the reported
failure was visible image fidelity and only Eddy can accept that final screen.

## Second Visual Acceptance Rejection

On 2026-07-22 Eddy selected the exact `design/Images/Bottom cut-off.png` portrait
and showed that the `1/39` vertical-scroll symptom is gone but the image remains
horizontally clipped: the source's left status content (`10:09` and person icon)
is absent while the right signal/Wi-Fi/battery content remains visible. This
proves that raw Kitty transport and pre-fzf place geometry do not prove that fzf
preserved the full Unicode-placeholder grid it later displayed.

The goal was reopened at the visible Ghostty raster seam. Comparing raw Kitty
columns with tmux's placeholder cells is still insufficient; the regression
signal must measure the displayed image itself.

## Second Visual Feedback Loop And Minimisation

- Added `fish/tests/fzf_image_visual_ghostty.sh`: it creates an owned temporary
  session on the already-proven tmux server, opens an isolated real Ghostty
  window, drives Ctrl-T, captures that window, and compares the visible light
  portrait bounds with the source's 1206:2622 aspect ratio.
- The first analyzer falsely reported a live red because its own search region
  cropped the image. Largest-connected light-component analysis corrected that
  harness error; it does not change Eddy's captured failure.
- Eddy's captured screenshot is genuinely red at 0.283 versus source 0.460.
- A clean isolated window is green at 0.470, and the exact same long-lived
  Ghostty client in a matching 118-column pane is green at 0.466 after an owned
  tmux session switch reset its graphics state.
- Thirty rapid square/portrait transitions in that same client remain green at
  0.466, so ordinary preview cancellation is not currently reproducible.
- Current code and current client are green while the captured prior state is
  red. No further renderer hypothesis can be tested honestly until Eddy retries
  the restored pane or the stale graphics state recurs.

## Second Visual Ranked Hypotheses

1. fzf re-styles or otherwise alters the Unicode-placeholder foreground data
   that encodes Kitty image identity, leaving only part of a random-ID image
   addressable in a narrow preview. Prediction: the displayed placeholder color
   does not match the transmitted image ID; using a deterministic fzf-safe ID
   or preserving the encoding restores the full portrait.
2. Kitty rounds a `--place` height to more placeholder rows than fzf can show
   (`r` has repeatedly exceeded the requested rows by 2-3), and narrow panes
   expose the overflow as raster clipping. Prediction: reserving the measured
   rounding rows makes the real visual ratio green without changing width or
   transport.
3. Kitty's centered placement emits cursor-forward positioning that fzf does
   not preserve faithfully in narrow previews. Prediction: `--align=left`
   removes the crop while leaving the emitted image dimensions unchanged.
4. The bordered retained preview has fewer drawable cells than fzf reports.
   Prediction: `noborder` or an exact border reservation repairs the ratio, but
   would also alter established picker appearance and is therefore lower rank.
5. Shared-memory timing or selection cancellation corrupts the raster.
   Prediction: stream transfer changes the symptom. This is lowest rank because
   thirty rapid transitions in the same client are currently green.

These hypotheses remain provisional. The corrected live loop is currently
green, so none authorizes a product change yet.

## Final Visual Acceptance And Closure

- Eddy confirmed on 2026-07-22 that the retained Ctrl-T image preview is
  working well. The remaining mid-text cutoff is inside the source asset named
  `Bottom cut-off.png`; the rendered preview shows that asset's complete bottom
  edge and does not crop its canvas.
- The real-Ghostty harness was hardened after fresh review: fixed readiness
  delays were replaced with bounded checks for owned-client attachment, stable
  78-column pane geometry, visible retained picker state, and two consecutive
  matching full-raster analyses. Expected geometry is derived from the selected
  source fixture rather than hardcoded dimensions.
- Final live visual result: PASS, displayed ratio 0.471 versus source 0.460.
- Final `fish/scripts/verify.sh`: PASS (30-run startup median 37.299 ms, p95
  41.605 ms). `git diff --check`: PASS.
- Fresh post-fix re-review: Standards findings 0, Fidelity findings 0.
- The goal is complete. The earlier stale Ghostty graphics-state trigger was
  not isolated and no speculative renderer change was made. No unrelated
  Herdr/tmux/Zsh behavior was changed. No commit or push was performed.

## Third Visual Acceptance Rejection

Eddy's 2026-07-22 12:26 screenshot rejects the closure above. In the long-lived
Ghostty/tmux pane, selecting `design/Images/Search.png` renders only a very
narrow central strip despite a wide preview region. This is the same visible
raster seam at materially worse severity, not a source-image cutoff. The goal
is reopened and the prior completed intake entry is superseded until a
red-capable loop exercises this retained-client state and the repaired result
passes in Eddy's actual pane.

## Third Visual Reproduction And Ranked Hypotheses

- The failing long-lived pane is `1:1.3` at 118x34 cells in Ghostty window 300.
  tmux retains all 26 Unicode-placeholder columns while the visible raster can
  temporarily collapse to roughly 87x532 pixels (ratio 0.164 versus the
  1206x2622 source ratio 0.460).
- Repeated `Ctrl-J`/`Ctrl-K` selection changes reproduce the narrow strip in
  under 0.2 seconds. Leaving the same selection untouched for two seconds can
  expand it to the correct full 253x532 raster. The failure is therefore a
  delayed/intermittent render, not fzf dropping placeholder columns or a wrong
  source dimension.

Ranked falsifiable hypotheses:

1. Shared-memory image transfer returns before Ghostty has copied/rendered the
   new random-ID image, so fast preview replacement exposes partial raster
   state. Prediction: stream transfer makes the first post-selection frame
   complete across repeated navigation without changing place geometry.
2. Random image IDs plus `--clear` leave Ghostty resolving a fresh placeholder
   identity incrementally after each cancelled preview. Prediction: a stable,
   pane-scoped image ID makes immediate repeated selection frames complete.
3. Clearing all terminal images races the replacement payload. Prediction:
   replacing one stable image ID without global clear removes the partial
   interval while preserving stale-image cleanup.
4. Ghostty lazily paints a valid placeholder grid independent of transfer or
   identity. Prediction: all protocol variants retain the same partial-to-full
   delay, requiring a non-placeholder fallback or an upstream terminal fix.

## Third Visual Root Cause And Fix

- The minimal red loop opens the retained picker in a 118x20 tmux pane and
  expands that pane to 118x35 without changing the selection. Before the fix,
  the placeholder grid and raster retained the short pane's geometry; the live
  Ghostty result was only 139 pixels wide (required minimum 200) and remained
  wrong after two seconds.
- Root cause: fzf emits a `resize` event but does not rerun an existing preview
  automatically. The image renderer therefore never receives the new
  `FZF_PREVIEW_LINES`, so its valid old placement looks like intermittent
  horizontal and bottom clipping after a tmux layout change.
- Fix: the shared retained file-picker options bind
  `resize:refresh-preview`. This is scoped to fzf file/path pickers and does not
  change tmux, Herdr, text rendering, or key ownership.
- The same live Ghostty client red loop passed after the fix: the placeholder
  identity changed after resize and the displayed portrait measured 262 pixels
  wide at 118x35.
- The durable Ghostty check now creates one owned pane inside an attached
  Ghostty client, exercises 20 square/portrait transitions, resizes from 20 to
  35 rows, requires a replacement placeholder grid, and kills only that owned
  pane. It no longer launches or leaks extra Ghostty processes.
- macOS desktop capture subsequently returned an all-black frame, so the
  durable script reports the raster subcheck as unavailable in that condition
  instead of falsely accepting it. The successful same-client 262-pixel live
  measurement preceded that capture-service failure.
- Goal-specific checks passed: `fzf_preview_integration.sh`, direct PTY,
  isolated tmux, and the resized same-client Ghostty check. Full
  `fish/scripts/verify.sh` passed (30-run startup median 23.445 ms, p95 24.221
  ms); `git diff --check` passed.

## Third Visual Fresh Review And Current Gate

- Fresh independent review is clean: Standards 0 findings and Fidelity 0
  findings. The reviewer also confirmed shell syntax, focused integration,
  diff hygiene, and pane/process cleanup, with no unrelated tmux/Herdr runtime
  change.
- Automated implementation and validation are complete. The active goal stays
  open at `Awaiting User Approval` because the final desktop raster capture was
  unavailable and Eddy's actual long-lived Ghostty/tmux behavior is the
  irreducible acceptance gate.
- The required retest is a fresh Fish pane: open Ctrl-T, keep an image selected,
  resize the tmux pane shorter and taller, and navigate across several portrait
  and square images. The complete image, including its bottom edge, must remain
  visible without intermittent collapse.

## Fourth Visual Acceptance Rejection

- Eddy's 2026-07-22 15:29 live retest rejects closure: the attached frame is
  complete, but repeated navigation still alternates between correct and
  incorrect rendering. A single final-frame screenshot is therefore an
  insufficient acceptance signal.
- The active goal is reopened at `Ready To Act`. The next red/green loop must
  sample repeated intermediate portrait frames in the attached Ghostty/tmux
  client, not only the final settled selection.
- Primary-source comparison found a load-bearing mismatch: fzf's Kitty image
  preview documentation says `--transfer-mode=memory` cannot redraw images on
  terminal resize or `change-preview-window`; it requires
  `--transfer-mode=stream`. The local canonical previewer still hard-codes
  memory transfer while exercising resize and rapid preview replacement.
- The installed renderer is Kitty kitten 0.37.0; Ghostty is 1.3.1, tmux is
  3.7b, fzf is 0.74.0, and Chafa 1.18.2 is available as a fallback. No package
  upgrade is authorized or required before testing the documented stream path.

## Fourth Visual Root Cause And Fix

- Root cause: the canonical renderer used Kitty shared-memory transfer even
  though fzf cancels, replaces, and resizes preview processes. fzf's own Kitty
  preview guidance explicitly requires stream transfer when an image must be
  redrawn on terminal resize or preview-window change:
  <https://github.com/junegunn/fzf/blob/master/CHANGELOG.md#0430>.
- The goal-specific argument test went red while the real renderer emitted
  `--transfer-mode=memory` and green after changing only that argument to
  `--transfer-mode=stream`. The existing Unicode-placeholder placement,
  `resize:refresh-preview`, fzf.fish ownership, and tmux passthrough remain.
- The live harness was also corrected so numeric tmux session `1` cannot be
  mistaken for window index `1`; it now targets `session:` explicitly. An
  unintended temporary resize of `main:1` pane `%145` was restored immediately
  to its recorded 118x5 geometry. The readiness marker now runs after Fish
  configuration instead of racing startup with Ctrl-C.
- The harness resolves the exact Ghostty window and containing macOS display,
  then validates every portrait frame during 20 rapid square/portrait
  transitions before the 20-to-35-row resize. Five consecutive stream runs
  passed all 100 intermediate portrait frames and every final raster at 260x548
  (ratio 0.474 versus source 0.460).
- Full `fish/scripts/verify.sh` passed: all functional checks green, 30-run
  startup median 27.708 ms and p95 32.042 ms. An earlier p95-only noisy run
  failed at 71.596 ms; three isolated reruns passed at p95 34.939, 28.503, and
  28.908 ms before the complete verifier passed. `git diff --check` passed.
- Fresh post-fix review is clean: Standards 0 findings and Fidelity 0 findings.
  Targeted syntax, integration, diagnostic-residue, scoped-diff, and
  pane/process leak checks passed. Human live acceptance remains the only open
  stop-condition item.

## Fifth Visual Acceptance Rejection

- Eddy's 2026-07-22 16:03-16:04 fresh-pane stream retest rejects closure. Three
  distinct BibleStandard PNGs (library, Bible text, and undo-toast screens) all
  render as narrow vertical slices inside a much wider preview region. The
  behavior remains sporadic and is not confined to the previously tested
  `Bottom cut-off.png` transition or to a long-lived pre-stream client.
- This evidence falsifies the claim that stream transfer plus the existing
  two-fixture, 20-transition harness is sufficient. The current harness is
  green-capable but is not yet red-capable for the exact multi-image fresh-pane
  symptom, so no fifth renderer change is authorized until that loop is
  tightened.
- The active goal returns to `Ready To Act`. Preserve the retained fzf.fish
  picker, stream transfer, resize refresh, bindings, and unrelated tmux/Herdr
  behavior while comparing the real pane's exported geometry, Kitty placement
  metadata, placeholder grid, and visible raster with the harness.

## Fifth Visual Feedback Loop And Minimisation

- The prior harness could analyze the wrong macOS window or an all-black
  ScreenCapture frame as a raster failure. It now pins an optional tmux window,
  supports the real 50-row probe height, rejects predominantly pure-black and
  non-terminal captures, and retries both window and display capture paths.
- The 118x50 two-image fixture is green in both attached Ghostty clients, so
  pane height and source aspect ratio alone are falsified.
- A 100-transition run in the always-capturable `main` Ghostty client failed at
  transition 88. tmux had already observed a changed Unicode-placeholder grid,
  but Ghostty displayed no image raster in the preview region. This is a real
  intermittent incomplete-render frame at the same graphics seam as Eddy's
  narrow strips, not a screenshot-service artifact.
- Tight red command:
  `FISH_VISUAL_SESSION=main FISH_VISUAL_FINAL_ROWS=50 FISH_VISUAL_TRANSITIONS=100 fish/tests/fzf_image_visual_ghostty.sh`.
  It drives the actual Ctrl-T/fzf/Fish/Kitty/tmux/Ghostty path and fails on an
  objectively absent, clipped, or wrong-aspect portrait frame.

## Fifth Visual Ranked Hypotheses

1. Each cancelled preview sends a global Kitty `--clear` before drawing a new
   random-ID image. If process completion is reordered, an older clear can
   erase or partially detach the newer raster. Prediction: replacing only one
   stable picker-scoped image ID, without global clear on every selection,
   removes incomplete frames while resize redraw still passes.
2. Rapid fzf cancellation truncates the stream payload after placeholder cells
   are emitted. Prediction: allowing the image transport to complete outside
   the cancelled preview process removes incomplete frames even if image IDs
   remain random.
3. Random image IDs eventually collide with or outlive the foreground-color
   encoding used by Unicode placeholders. Prediction: a stable explicit image
   ID eliminates the failure without changing transfer mode or cancellation.
4. Multiple panes in one Ghostty process interfere through an overly broad
   clear action. Prediction: targeting deletion to the current image/placement
   fixes the failing client while an isolated single-window stress run remains
   unaffected.
5. Ghostty/tmux occasionally fails to compose an otherwise complete stream and
   placeholder grid. Prediction: protocol ordering and identity probes all
   retain the same failure rate, leaving a terminal fallback or upstream fix as
   the only honest resolution.

## Fifth Visual Diagnosis Pause

- The live-capture harness exposed two false-failure modes (wrong macOS window
  and an all-black ScreenCapture frame). Those are now rejected, but capture of
  the second Ghostty window still depends on macOS visibility and is not a
  deterministic acceptance loop.
- A retained raw pane stream showed complete tmux-wrapped image transfers on an
  incomplete visible frame; the simple truncated-stream hypothesis is therefore
  not supported by that run.
- Removing `--clear`, forcing a stable image ID, using file transfer, and
  manually wrapping the clear command each failed immediately. Every unverified
  runtime probe was reverted. The canonical renderer is back at the incoming
  stream-transfer implementation; no Chafa fallback or new production fix
  remains.
- Eddy stopped the run after the diagnosis consumed excessive time without a
  trustworthy fix. The goal remains active and must not be closed. Further
  renderer work requires an explicitly selected rollback boundary or a new
  deterministic loop that reproduces Eddy's exact partial-strip frame without
  relying on flaky macOS capture.

## User-Selected Visual Rollback

- After the experiment chain left live image rendering worse than before the
  visual work, Eddy explicitly selected rollback rather than further diagnosis.
- Restored the last accepted pre-geometry renderer behavior:
  `--transfer-mode=memory`, no `resize:refresh-preview` binding, and no
  macOS/Ghostty raster harness or resize-specific manual gate.
- Preserved the earlier accepted fixes: Ctrl-T remains owned by the retained
  fzf.fish picker, regular PNG files still dispatch through canonical
  `_fzf_preview` instead of `bat`, fzf-owned positive geometry remains
  preserved, and unrelated environment/startup/security and Herdr/tmux/Zsh
  work is untouched.
- Because Ghostty may retain graphics state from the failed stream runs, final
  acceptance must use a freshly reopened Ghostty window attached to the
  existing tmux session. No commit or push is authorized.
- Focused rollback verification passed: `fzf_preview_integration.sh`, direct
  interactive PTY, isolated interactive tmux, Fish syntax, shell syntax, and
  scoped `git diff --check`.
- Final `fish/scripts/verify.sh` passed, including transport security,
  environment/startup ownership, FIF/FZF consumers, PTY/tmux interactions,
  worker cleanup, and the 30-run startup benchmark (27.849 ms median, 28.510 ms
  p95). An earlier noisy p95-only run failed; three isolated reruns and the
  final full verifier passed.
- Fresh review found one Minor Fidelity prevention gap: the focused test did not
  prohibit reintroduction of `resize:refresh-preview`. A negative assertion was
  added, affected and full verification reran green, and fresh re-review is
  clean: Standards 0 findings, Fidelity 0 findings.

## Partial Closure And Deferral

- Eddy reports that live image rendering is still not reliably working after
  the rollback. The automated checks prove only routing, payload, PTY/tmux
  interaction, startup, and diff integrity; they do not override the failed
  visual result.
- On 2026-07-22 Eddy explicitly chose to commit the recovery state and try the
  visual problem again later. The goal is deferred unresolved, not completed.
- Commit is authorized for the scoped Fish/security/startup work and durable
  tracking. Push remains out of scope. Unrelated Herdr, tmux, Zsh, research,
  and prototype changes remain uncommitted.
