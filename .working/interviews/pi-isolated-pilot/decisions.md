# Pi Isolated Pilot

## Goal

Build a pinned, isolated, reversible Pi 0.82.1 pilot that can be evaluated
beside Codex and Claude without replacing either agent or becoming the default.

## Exit Criteria

- The official macOS arm64 Pi 0.82.1 artifact is checksum-verified and launched
  only through a repository-owned pilot wrapper.
- Pilot configuration, credentials, extensions, and sessions are isolated from
  any future normal Pi installation and have a tested rollback path.
- A curated subset of the canonical `/Users/eddyekofo/.agent-skills` tree is
  visible once, with `$skill-name` compatibility for enabled skills.
- Two named Pi sessions remain distinct, resume independently, and retain their
  full JSONL history across manual and forced-threshold compaction.
- Compaction preserves the active-goal, constraints, dirty-work exclusions,
  verification, manual gates, and active-skill obligations needed by Eddy's
  loop contract.
- Herdr's managed Pi integration reports session identity, status, and cwd in
  the existing cross-session overview.
- `Prefix+b` inserts the newest handoff into Pi without submission.
- `Prefix+B` creates a fresh persisted Pi session and inserts the handoff
  without submission, while the previous session remains resumable.
- The same bounded model task produces recorded native-Codex and Pi evidence
  for correctness, elapsed time, token/cost data where exposed, startup time,
  and peak memory.
- Existing Codex, Claude, Herdr independent-window behavior, recovery, tmux
  fallback, and shared skills remain intact.
- Project verification and fresh Standards/Fidelity review pass after the last
  implementation change.

## Scope / Non-goals

In scope:

- Pi 0.82.1 macOS arm64 standalone pilot.
- Repository-owned launcher, isolated settings, curated skills, minimal
  compatibility extension, deterministic validation, and rollback.
- Herdr managed integration plus existing `Prefix+b/B` and `Prefix+A`
  compatibility.
- Comparable measurements using accounts/models already available to Eddy.

Non-goals:

- Making `pi` the default command or launcher.
- Removing, renaming, or changing Codex or Claude.
- Rebuilding MCP, general-purpose subagents, or background orchestration during
  this pilot.
- Adding third-party Pi packages other than the explicitly selected and pinned
  `@ff-labs/pi-fff@0.10.1`.
- Commit, push, or hosted tracker changes.

## Decisions

- Pi is a candidate third harness, not an immediate replacement.
- Missing Pi sandboxing and command-permission prompts are an accepted
  non-blocker for Eddy's trusted personal repositories.
- Native MCP, independent-agent, and background-work gaps remain promotion
  criteria, but the pilot only proves one bounded workflow seam rather than
  recreating all three.
- Pi is pinned to 0.82.1 and must not self-update during the pilot.
- The pilot uses explicit isolated configuration and session roots.
- Shared skills remain canonical under `/Users/eddyekofo/.agent-skills`; the
  pilot loads only explicitly vetted skill directories.
- Pi's native `/skill:name` stays supported. A minimal extension additionally
  transforms known enabled `$skill-name` input and fails closed for unknown or
  disabled names.
- Herdr remains the owner of `Prefix+b/B`. Lowercase preserves exact
  bracketed-paste insertion. Uppercase uses a Pi-native new-session/prefill
  endpoint where deterministic; no handoff is submitted.
- Existing Codex and Claude replay branches must not change behavior.
- No physical or provider-dependent acceptance may be inferred from fixtures.
- Pi uses Catppuccin Mocha to match the live Ghostty and Fish environment.
- The interactive editor displays an accent-colored `❯` prompt without
  changing the submitted text or cursor semantics.
- Ctrl-P/Up and Ctrl-N/Down navigate current-branch submitted prompt history.
  The extension reconstructs that history after `/reload`, `/resume`, and
  `/tree`; synthetic handoff messages do not enter the prompt ring.
- Ctrl-Shift-M opens the model selector; ordinary Return remains submission.
  Ctrl-L clears and redraws the viewport while keeping the editor/footer
  visible and preserving unsent editor text and persisted conversation history.
- The user explicitly selected `@ff-labs/pi-fff` after reviewing its Pi
  extension. This supersedes the proposed repository-owned external-fzf
  picker.
- Pi loads the exact pinned `npm:@ff-labs/pi-fff@0.10.1` package in
  `tools-and-ui` mode. FFF supplies fuzzy, frecency-ranked, git-aware `@`
  autocomplete and adds its namespaced tools without replacing Pi's native
  tool names.
- FFF's package installation, native dependency, frecency database, and query
  history are contained under the isolated pilot state root. The package
  source version, registry integrity, reviewed npm lock, and complete installed
  tree hash are verified. Lifecycle scripts are disabled, and a reviewed
  pilot-local patch prevents persisted sessions or `/fff-mode` from changing
  the fixed `tools-and-ui` mode.

## Evidence / Findings

- Governing research:
  `docs/research/pi-coding-agent-migration-2026-07-29.md`.
- Current tools: Codex 0.145.0, Claude Code 2.1.202, Herdr 0.7.4, Ghostty
  1.3.1, arm64 macOS. Pi was not installed at activation.
- Herdr 0.7.4 advertises `herdr integration install pi`.
- Current physical-window and cross-session Herdr work is already closed and
  must be preserved.
- The worktree contains substantial pre-existing dirty Herdr/Fish changes.
  Relevant overlapping-file hashes were captured before implementation.
- The pinned standalone artifact installed successfully under
  `~/.local/share/pi-pilot`; the opt-in launcher keeps its settings,
  credentials, sessions, and Herdr integration under
  `~/.local/state/pi-pilot`. The real `~/.pi` tree and normal agent launchers
  remain untouched.
- `pi/verify.sh` passes and covers marker-owned rollback, exactly two curated
  canonical skills, `$skill` compatibility, named session independence and
  resume, manual plus forced-threshold compaction continuity, the real
  disposable Herdr/Pi TUI path, and both no-submit replay operations.
- `pi/evidence/herdr-validation.json` proves Herdr's managed `herdr:pi`
  identity, a distinct durable replacement session for `Prefix+B`, same-session
  insertion for `Prefix+b`, and Pi presence in cross-session inventory. It
  explicitly records `physical_ghostty: false`.
- The seven-run version-command measurement records ordered raw samples and
  distinguishes the initial unwarmed-order sample from subsequent warm
  candidates. It does not purge macOS caches and therefore does not claim a
  controlled cold start. This Pi build is lighter than Claude on that path,
  but materially heavier and slower than Codex. These figures are not
  provider-turn or interactive-TUI measurements; current values live in
  `pi/evidence/runtime-benchmark.json`.
- `herdr/verify.sh`, `fish/scripts/verify.sh`, and `git diff --check` pass after
  the pilot implementation.
- The isolated ChatGPT Plus/Pro login is active. The bounded no-tool comparison
  passed 5/5 for both agents. Pi (`openai-codex/gpt-5.5`) completed in 6.273998
  seconds with 806 reported tokens and a $0.009055 API-equivalent estimated
  cost. Native Codex completed in 15.990473 seconds with 22841 input tokens and
  74 output tokens; its JSON stream exposed no monetary cost. This is one
  bounded task and does not establish universal model or harness superiority.
- Physical Ghostty validation remains unperformed. Fixtures do not close the
  two-window, focus, native key delivery, close/reopen recovery, or subjective
  interaction gate.
- The first physical `Prefix+b` attempt on 2026-07-30 correctly inserted
  nothing because Pi had emitted an unlabeled code block. Capturing the live
  pane and running the production parser returned extraction status `10`
  (`no replayable handoff`). The pilot now appends a bounded handoff protocol
  to Pi's per-turn system prompt so natural requests for a ready-to-paste
  prompt use the required label and one fenced `text` block. The rule remains
  in the reloadable extension entrypoint because the live `/reload` experiment
  proved newly added imported helpers can remain stale. Compatibility tests
  enforce the source boundary, and the mock-provider session harness proves
  exactly one current protocol before and after `/reload`.
- The physical history retry used the real interactive pilot, not the provider
  benchmark or RPC fixture. It exposed a keybinding mismatch: Up/Down appeared
  inert and Pi's default Ctrl-P changed models. The pilot now owns
  `pi/keybindings.json`: Ctrl-P/Ctrl-N are previous/next in the editor and
  selectors, Ctrl-Shift-M opens the model picker, Ctrl-L clears/redraws the
  viewport with editor/footer details visible, and direct model cycling is
  unbound. Session-picker path/named filters move to Ctrl-Shift-P/N.
- Pi's native editor history is an in-memory array owned by the editor
  component. Replacing the editor during `/reload` therefore explains why a
  persisted session can have user messages while Up/Down appears empty. The
  supported `CustomEditor.addToHistory()` seam allows branch-local
  reconstruction from `SessionManager.getBranch()`.
- The live terminal stack already selects Catppuccin Mocha, and Pi 0.82.1
  supports repository-listed custom JSON themes plus hot reload.
- Pi's built-in `@` autocomplete is a small substring-oriented internal list.
  The user selected FFF's indexed, fuzzy, frecency-ranked, git-aware
  autocomplete instead of the researched external-fzf implementation.
- The pinned FFF native package loads in `tools-and-ui` mode, indexes the
  active cwd, and keeps frecency/query LMDB data under the isolated pilot state
  root. The installer seeds the reviewed npm lock before running `npm ci` with
  lifecycle scripts disabled; the launcher rejects any changed file in the
  installed dependency tree, database symlinks, or command-line mode/database
  overrides.

## Tradeoffs / Risks

- Provider login may require interactive browser/user confirmation.
- A model-quality comparison cannot be honest without actual provider turns.
- Peak memory and startup measurements are machine- and cache-dependent, so
  the report must retain raw methodology and distinguish cold/warm runs.
- Pi's extension API is broad but in-process; a compatibility extension is
  trusted local code and must remain small.
- Herdr physical focus, paste, recovery, and two-window behavior remain manual
  acceptance where deterministic fixtures cannot prove the macOS interaction.

## Validation Plan

- `pi/verify.sh`
- `herdr/prototype/validate_ready_prompt.sh`
- `herdr/prototype/validate_agent_overview.sh`
- `herdr/verify.sh`
- `fish/scripts/verify.sh`
- `git diff --check`
- Isolated install checksum and rollback test.
- Named-session, resume, JSONL, manual-compaction, forced-compaction, and
  active-skill continuity fixtures.
- Repeated startup and peak-RSS measurements with raw evidence.
- Identical bounded native-Codex and Pi provider task with correctness,
  elapsed-time, token/cost evidence where exposed.
- Physical two-window `Prefix+A`, `Prefix+b`, `Prefix+B`, independent typing,
  close/reopen recovery, and no-submit QA.
- Fresh Standards and Fidelity review after the final diff.

## Ready To Act

Ready.

## Execution Status

**AWAITING USER APPROVAL**

- `pi/verify.sh`: PASS
- `fish/scripts/verify.sh`: PASS
- Focused `herdr/prototype/validate_ready_prompt.sh`: PASS
- `git diff --check`: PASS
- Provider comparison: PASS
- Handoff protocol, post-`/reload` session harness, Catppuccin theme, custom
  prompt/history editor, keybindings, FFF indexing, deterministic reinstall,
  dependency tamper rejection, and database containment: PASS
- Physical pass 2's force-redraw, cursor-shape, and slash-ranking refinement
  passed aggregate verification and closed its post-fix review at Standards 0
  / Fidelity 0, then physical pass 3 superseded that acceptance state.
- The current pass-3 repair keeps new UI helpers reload-local and moves
  aggregate verification to disposable Pi state. Focused and aggregate
  verification pass. Its first fresh review found one verification-isolation
  test defect and this stale tracker status; both are fixed and the post-fix
  re-review reports Standards 0 findings and Fidelity 0 findings.
- Physical pass 4 exposed locale-sensitive FFF aggregate hashing in the actual
  Herdr/Fish pane. Source and dependency-tree ordering now force `LC_ALL=C`,
  while verification launches under both C and `en_US.UTF-8`. The exact
  physical pane passes launch, `/reload`, clean exit, restart preflight, and
  launch during aggregate verification. Aggregate gates pass; fresh review
  closed at Standards 0 findings and Fidelity 0 findings.
- Physical pass 5 confirms every applicable physical/manual interaction item,
  including `Prefix+b` and `Prefix+B`: PASS.
- Current broad `herdr/verify.sh`: blocked outside the Pi seam by the
  pre-existing aggregate assertion that expects 31 custom bindings while the
  current Herdr configuration contains 43
- Physical Ghostty acceptance: awaiting retry of `pi/MANUAL_QA.md`

Pi remains opt-in and may not be promoted while either manual gate is open.

## Open Questions

None that changes implementation. Provider authentication/comparison and
physical macOS acceptance are execution-time human gates, not unsettled product
design. Pi must not be promoted while either gate remains open.
