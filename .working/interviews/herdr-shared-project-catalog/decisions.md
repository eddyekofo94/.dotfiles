# Herdr Shared Project Catalog

## Goal

Settle one implementation-ready project-catalog contract that lets Herdr open or
reuse repository workspaces immediately, includes BibleStandard, learns from
actual use without depending on Neovim, and replaces the blocking full-root scan.

## Exit Criteria

The interview ends at decision-only `Ready To Act` when project eligibility,
source authority, canonical identity, worktree treatment, ranking, freshness,
refresh behavior, popup latency, validation, and the physical Ghostty gate are
settled without implementation-changing questions.

## Scope / Non-goals

- In scope: candidate discovery for `herdr/project_picker.sh`; optional Neovim
  history and Zoxide adapters; configured roots; Git worktrees; canonicalization;
  deduplication; ranking; caching; refresh; immediate popup rendering; focused,
  aggregate, and physical validation.
- Non-goals: replacing `project.nvim`, changing Neovim's project picker, making
  Herdr require Neovim or Zoxide, changing Herdr workspace/tab/session semantics,
  launching agents automatically, deleting Zoxide or Neovim history, or fixing
  unrelated Herdr behavior.

## Proposal

### Grill collaboration contract

- Each fork starts with the agent's evidence-backed recommendation, not a neutral
  menu of choices.
- The recommendation must name the strongest alternative, the blind spot that
  could make the recommendation wrong, and the evidence that would overturn it.
- Eddy settles genuine product preferences; the agent settles questions already
  answered by repository evidence, platform semantics, or primary-source research.

### Current behavior

- `Prefix+Shift+w` runs `herdr/project_picker.sh`, which synchronously scans the
  dotfiles checkout plus `~/Documents`, `~/Projects`, `~/projects`, `~/work`,
  and `~/code` to depth 10 for `.git`, expands registered worktrees, then opens
  fzf. `~/Programming` is absent.
- BibleStandard's canonical checkout is
  `~/Programming/Projects/CanonFidei/BibleStandard`; Neovim and Zoxide both know
  its symlinked `~/Programming/Projects/BibleStandardGroup/BibleStandard` path.
- Neovim detects roots during buffer/LSP activity from configured markers and
  writes a recent-project history. Its picker reads that history; it does not
  perform Herdr's full recursive scan when opened.
- Zoxide records directory frecency, not project identity. Its live list includes
  BibleStandard, useful repositories, ordinary directories, backup trees, deep
  subdirectories, and temporary paths.

### Proposed change

- Deepen project discovery behind one `list_projects` interface returning a
  canonical path, display path, label, source set, last-seen/frecency signals,
  and main-checkout/worktree identity.
- Treat Neovim history and Zoxide as optional candidate adapters. Neither owns
  project truth; absence or malformed data must not break Herdr.
- Retain configured-root and Git-worktree adapters for never-visited projects.
  Replace broad implicit roots with explicit high-value roots including
  `~/Programming/Projects` and bounded domain roots rather than all of
  `~/Documents`.
- Canonicalize candidates before validation and deduplication so symlink aliases
  converge. Preserve genuine linked worktrees as separate selectable identities.
- Rank accepted projects by explicit source precedence: configured pins, Herdr
  successful-selection recency, Neovim recency, Zoxide ordinal frecency for
  otherwise-unranked projects, then stable label/path ordering. Existing
  workspace state is presentation metadata, not a ranking boost. A weak source
  may rank but may not make an invalid directory a project.
- Open fzf from a validated last-known catalog immediately. Refresh bounded
  discovery separately and atomically for the next invocation; expose an explicit
  refresh action. Never block first paint on a recursive scan.
- Keep the existing workspace `project_cwd` identity, focus/reuse behavior,
  session lock, tokenless restart adoption, and target-only rollback.

### Strongest rejected alternatives

- Neovim history alone is fast and already contains BibleStandard, but it makes
  Herdr depend on another application's lifecycle and cannot discover a project
  before Neovim has visited it.
- Zoxide alone has better cross-shell coverage and useful frecency, but its unit
  is any visited directory. The live database proves it would surface backups,
  temporary paths, and nested project subdirectories without a validator.
- A tuned recursive scan is independent and exhaustive inside its roots, but it
  still pays discovery cost during interaction and can silently omit roots such
  as `~/Programming`.
- Running headless Neovim from the popup would reuse plugin behavior directly,
  but adds startup cost, couples Herdr availability to Neovim/plugin health, and
  crosses application ownership unnecessarily.

### Confirm-by-silence recommendations

- Add Zoxide as an optional candidate and ranking adapter, not an authority.
- Read Neovim's JSON history directly through a defensive adapter; do not import
  plugin Lua or launch headless Neovim.
- Keep one catalog owner in dotfiles rather than maintaining separate discovery
  rules inside each picker.
- Resolve symlinks and validate existence without rewriting either source's data.
- Keep popup startup independent from refresh success.

### Recommendation: project eligibility

- Automatically admit a directory only when Git identifies it as a main checkout
  or linked worktree.
- Permit intentionally non-Git projects through an explicit project registry;
  do not auto-admit them from marker files, Neovim history, or Zoxide alone.
- Let Neovim history and Zoxide propose and rank candidates, then require the Git
  validator or an explicit registry entry before the catalog accepts them.

This is the best default because the requested unit is a repository workspace,
Git supplies portable identity and linked-worktree provenance, and Herdr already
models repositories and worktrees as workspace-level concerns. Zoxide measures
directory frecency, while `project.nvim` detects editor roots from buffer/LSP
context; neither signal proves that a directory should become a Herdr workspace.

The strongest alternative is automatic marker-based eligibility. It would find
non-Git and nested monorepo projects without configuration, but the same markers
can identify packages, configuration roots, and nested directories that should
not be separate workspaces. It should replace the recommendation only if Eddy has
real non-Git projects that must be discovered automatically rather than pinned.

### Recommendation: catalog persistence

- Keep human intent in a small, versioned, repository-owned
  `herdr/project_catalog.json` containing configured discovery roots and explicit
  non-Git projects.
- Keep learned and validated records in an untracked derived cache at
  `${XDG_CACHE_HOME:-$HOME/.cache}/herdr/project-catalog-v1.json`.
- Never let refresh rewrite the declarative configuration. Write only the cache,
  through validation followed by an atomic rename.
- Allow `HERDR_PROJECT_CATALOG_CONFIG` and `HERDR_PROJECT_CATALOG_CACHE` overrides
  for tests and genuinely machine-local configuration.

The tracked configuration plus disposable cache is the best boundary because
configured roots and non-Git admission are user intent, while Neovim/Zoxide
signals and validation results are reconstructable observations. It also follows
the repository's existing pattern of reviewed configuration with runtime state
kept outside the checkout. JSON is appropriate here because the picker already
requires `jq`; adopting TOML would require a new parser, while line-oriented text
cannot validate typed roots and projects cleanly.

The strongest alternative is a machine-local declarative configuration under
`~/.config/herdr`, still separated from its disposable cache. It keeps private
or host-specific paths out of Git and supports divergent machines naturally, but
loses reviewable history, backup through the dotfiles repository, and automatic
availability on a new machine. The tracked default should be overturned if
catalog paths are private or differ materially across machines; the environment
override preserves that case without weakening the default contract.

### Recommendation: refresh policy

- Refresh on demand from the picker, not from every shell directory change.
- Every picker invocation reads the last valid cache immediately. When the cache
  is missing, stale, or older than the tracked configuration, it requests one
  detached bounded refresh without delaying the visible candidate list.
- Add an explicit refresh operation and expose it as `Ctrl-r` inside fzf. The
  existing list remains usable while refresh runs; successful completion reloads
  the list, while failure preserves the old cache and reports a concise status.
- Enforce a single-flight refresh lock, per-adapter time bounds, a whole-refresh
  deadline, temporary-file validation, and atomic cache replacement.
- Do not add Fish/Zsh directory-change hooks, a resident daemon, or a scheduled
  launch agent. Zoxide already observes navigation; duplicating that work would
  add startup/runtime ownership without proving project identity.

This demand-driven policy is the best fit because the catalog is consumed at
picker time, repositories change far less often than directories are visited,
and current shell configuration already has a `PWD` event hook plus Zoxide's
navigation integration. It keeps discovery off the popup's critical path and
prevents multiple shells from launching refresh work on routine navigation.

The strongest alternative is a lightweight directory-change hook that validates
the new directory and incrementally updates the cache. It can make a newly cloned
repository appear before the first picker invocation, but it still misses
repositories created by editors, scripts, or other applications; duplicates
Zoxide's observation point; and introduces cross-shell locking on a hot path.
The demand-driven policy should be overturned if measured usage shows frequent
repository creation followed by an immediate picker open where even one stale
invocation or `Ctrl-r` is unacceptable.

### Recommendation: ranking

- Use explicit, explainable precedence rather than combining raw numeric scores.
- Rank configured pins first in their declared order. Registration alone does
  not imply a pin; Git and explicit non-Git projects otherwise follow the same
  ranking rules.
- Rank remaining projects by Herdr's own most-recent selections, recorded in the
  derived cache when a project is successfully opened or focused.
- Rank projects without Herdr history by Neovim's exported recent-project order.
- Rank projects absent from both histories by Zoxide's frecency order, converted
  to ordinal rank rather than importing its raw score.
- Put discovery-only projects last in stable case-insensitive label/path order.
- Show current-session workspace state as an `[open]` annotation. Do not promote
  it into a ranking tier because `Prefix+w` already owns workspace navigation.
- Preserve source ranks and the winning reason in each cache record so fixtures
  and diagnostics can explain why a project appears where it does.

This precedence is the best default because Herdr's own successful choices are
the closest signal to Herdr intent, Neovim history is a bounded project-aware
recent list, and Zoxide's much wider numeric range measures all directory use.
It remains stable when an optional adapter disappears and avoids unexplained
movement caused by arbitrary cross-source weights.

The strongest alternative is ordinal rank fusion, such as weighted reciprocal
rank fusion across Herdr, Neovim, and Zoxide lists. It rewards projects supported
by several sources and avoids comparing raw Zoxide values, but introduces weight
and smoothing constants that make ordering less obvious and harder to debug.
The precedence model should be overturned if a red-capable comparison against
real catalog usage shows that multi-source consensus consistently predicts the
next selected project better without destabilizing the top results.

The main blind spot is stale source precedence: an old Neovim entry can remain
above a heavily used Zoxide-only repository until Herdr selects it. This is
bounded by Herdr learning on successful selection and can be tested with a
fixture where stale Neovim and current Zoxide signals conflict.

### Recommendation: latency and stale-cache behavior

- Use stale-while-revalidate with a 10-minute freshness window. A configuration
  file newer than the cache makes the cache stale immediately.
- A valid stale cache never hard-expires. Render it immediately, label it stale
  or refreshing in the fzf header, and preserve it when refresh fails.
- Before display, cheaply omit paths that no longer exist. Before opening or
  focusing a workspace, revalidate the selected Git/worktree or explicit
  non-Git identity so stale state cannot authorize the wrong directory.
- On a missing or corrupt cache, synchronously build only a fast seed from the
  tracked configuration, Neovim history, and Zoxide candidates. Start fzf from
  that seed while bounded configured-root discovery runs in the background.
  Never perform recursive root discovery before first paint.
- If the fast seed is empty, open the picker with a clear `refreshing` status and
  reload on successful discovery rather than presenting a blocked blank popup.
- Bound a complete background refresh to five seconds. A timeout or adapter
  failure preserves the previous valid cache and remains retryable with `Ctrl-r`.
- Automated fixture budget: cached candidate emission must stay at or below
  250 milliseconds at the 95th percentile across 20 warm invocations. Record the
  median and 95th percentile rather than relying on a single timing.
- Cold or corrupt-cache fast-seed emission must stay at or below 500 milliseconds
  at the 95th percentile across 20 fixture invocations.
- Physical Ghostty gate: `Prefix+Shift+w` must show candidates or an explicit
  refreshing state within 500 milliseconds by human-timed observation, remain
  interactive during refresh, and find BibleStandard without duplicate aliases.

This is the best balance because project membership changes infrequently, stale
entries are safe when identity is revalidated at action time, and the original
failure is latency before fzf appears. The split budgets distinguish catalog
production from terminal rendering, which automated shell timing cannot prove.

The strongest alternative is a fresh-before-display policy, at least when the
cache is missing or older than its freshness window. It guarantees a complete,
current list on every invocation and simplifies status presentation, but makes
the slowest filesystem adapter part of an interactive keybinding again and lets
one failed source block the whole picker. It directly recreates the reported
failure mode.

The main blind spot is that stale-while-revalidate can briefly show outdated
ordering or omit a newly created repository. The contract should be overturned
only if cold-start fixtures commonly produce an empty fast seed, or physical use
shows that one stale invocation plus `Ctrl-r` is less acceptable than a bounded
foreground wait.

### Exact implementation contract

#### Configuration

`herdr/project_catalog.json` uses a versioned JSON object with these fields:

```json
{
  "version": 1,
  "roots": [
    { "path": "~/.dotfiles", "max_project_depth": 0 },
    { "path": "~/.config/nvim", "max_project_depth": 0 },
    { "path": "~/Programming/Projects", "max_project_depth": 3 },
    { "path": "~/Documents/Family_Business", "max_project_depth": 2 },
    { "path": "~/Documents/Theology/epub_conversion/books", "max_project_depth": 2 }
  ],
  "explicit_projects": [],
  "pins": []
}
```

- `max_project_depth` counts candidate project directories below the root; zero
  validates only the root itself.
- `explicit_projects` accepts intentional Git or non-Git directories. Optional
  labels affect presentation only; canonical paths remain identity.
- `pins` is an ordered list of accepted project paths. A missing or unaccepted
  pin is a configuration error rather than an implicit admission rule.
- `~` expansion is accepted only at the start of a configured path. Configured
  paths are canonicalized without rewriting the tracked file.
- Keep the current generated/dependency-directory prune set. Do not recursively
  follow filesystem symlinks.

#### Catalog module and record contract

- Add `herdr/project_catalog.py`, using Python 3.9 standard library only, as the
  deep owner of config parsing, adapters, Git/worktree validation, canonical
  identity, alias deduplication, ranking, freshness, locking, time bounds, and
  atomic cache writes.
- Expose narrow operations for immediate list output, bounded refresh, refresh
  status, and recording a successful Herdr selection. Accept config, cache,
  adapter, clock, and scanner overrides for deterministic tests.
- Each cached record contains canonical path, canonical home-relative display
  path, label, `main`/`worktree`/`explicit-non-git` kind, main-worktree grouping
  path where applicable, source aliases, source ranks, successful-selection
  recency, validation timestamp, and the winning ranking reason.
- Canonical directory path is the workspace `project_cwd` and deduplication key.
  Source aliases remain searchable but never become separate identities.
- A main checkout and every accessible entry returned by
  `git worktree list --porcelain` are separate selectable records grouped by the
  main checkout. This includes registered worktrees outside configured roots;
  unavailable or prunable entries are omitted. The catalog never creates,
  repairs, prunes, or removes a worktree.
- Successful refresh merges prior Herdr selection recency by canonical identity.
  Deleting the disposable cache may reset learned ordering but cannot lose
  configured intent or alter projects.

#### Picker boundary

- Keep `herdr/project_picker.sh` as the fzf and Herdr-workspace orchestration
  adapter. It consumes catalog records, renders status/source/kind annotations,
  initiates detached refresh, binds `Ctrl-r`, records only successful selection,
  and preserves all current focus/reuse, session lock, tokenless adoption,
  cancellation, stale-target rejection, and target-only rollback behavior.
- Keep `Prefix+Shift+w` and popup dimensions unchanged. Preserve native
  `Prefix+w` and every unrelated Herdr, Fish, Neovim, tmux, and Ghostty binding.
- Do not edit `project.nvim`, fzf-lua, Neovim history, Zoxide data, Fish startup,
  Ghostty configuration, Herdr session history, or existing saved workspaces.

#### Implementation file scope

- Add `herdr/project_catalog.py` and `herdr/project_catalog.json`.
- Add focused standard-library tests under `herdr/tests/` and wire them into
  `herdr/verify.sh`.
- Modify only the catalog-facing portion of `herdr/project_picker.sh` and extend
  `herdr/validate_project_picker.sh` for real fzf/workspace regression coverage.
- Add `herdr/MANUAL_QA.md` with the physical Ghostty project-picker gate.
- Update this decision record, the research record, and
  `.working/UNIFIED_INTAKE.md` with exact evidence and relationship to the closed
  `herdr-project-sessionizer-workflow` and the resolved startup-latency symptom.
- Preserve every unrelated dirty, committed, and untracked file and all saved
  session histories. No commit, push, install, server restart, or worktree
  retirement is authorized unless a later feature-plan explicitly includes it.

### Flagged forks

None.

## Decisions

- During grills, the agent must lead with a researched recommendation, strongest
  alternative, blind spot, and overturning evidence before asking Eddy to decide.
- Automatic eligibility is limited to Git main checkouts and linked worktrees.
  Intentional non-Git projects require explicit registration; marker files,
  Neovim history, and Zoxide cannot admit them automatically.
- Durable configured roots and explicit non-Git registrations live in tracked
  `herdr/project_catalog.json`. Learned records live in a disposable XDG cache;
  `HERDR_PROJECT_CATALOG_CONFIG` may select a machine-local configuration.
- Refresh is cache-first and demand-driven. Stale or missing state starts one
  bounded background refresh; `Ctrl-r` requests an explicit reload; successful
  refresh replaces the cache atomically. No directory hooks or resident process
  are added.
- Ranking precedence is configured pins, Herdr successful-selection recency,
  Neovim recency, Zoxide ordinal frecency for otherwise-unranked projects, then
  stable label/path order. Existing workspaces receive an `[open]` annotation
  without a ranking boost, and raw cross-source scores are never combined.
- Latency uses stale-while-revalidate with a 10-minute freshness window, no hard
  expiry for valid stale caches, a five-second complete-refresh deadline,
  250-millisecond cached and 500-millisecond cold-seed p95 automated budgets,
  and a physical 500-millisecond Ghostty first-paint gate.
- Zoxide is in scope as an optional candidate and ranking adapter.
- Neovim history is in scope as an optional adapter, never the sole authority.
- Herdr must continue functioning when either adapter is absent or malformed.
- BibleStandard's symlink aliases must converge on the CanonFidei checkout.

## Evidence / Findings

- Herdr's official model defines a workspace as a top-level project container and
  recommends one workspace per repository, task, or investigation. Its native
  worktree commands create or open worktree-backed workspaces with provenance.
- Git documents a repository as one main worktree plus zero or more linked
  worktrees, each with distinct per-worktree metadata. Git-aware discovery can
  preserve those identities without treating symlink aliases as new projects.
- Zoxide officially describes its database as frequently used directories and
  ranks them with frecency. It does not claim to classify projects.

- The live Herdr discovery command exceeded 30 seconds at default depth 10.
  `~/Documents` at depth 5 took 6.85 seconds and depth 3 took 0.09 seconds.
- Restricting Herdr discovery to `~/Programming/Projects/CanonFidei` finds
  BibleStandard, BibleStandard worktrees, and the related CanonFidei repositories.
- Neovim's live project history contains BibleStandard, RubyandRiver, dotfiles,
  Neovim, Owen, and related repositories.
- Zoxide 0.10.0 lists BibleStandard with score 72.0 and its parent symlink with
  score 112.0, but ranks ordinary and stale directories too.
- The current Herdr picker validates Git top-levels, canonicalizes paths, expands
  registered worktrees, reuses `project_cwd`, safely adopts tokenless restored
  workspaces, and rolls back only the target it created.
- Fish already has a `PWD` event hook, and Zoxide initialization adds navigation
  tracking. A catalog-specific directory hook would add another hot-path observer.
- Existing repository fzf integrations use `reload` bindings, so an explicit
  in-picker refresh follows an established local interaction pattern.
- Neovim's exported history is an ordered list, and the custom Neovim picker
  reverses the plugin API list to match that exported order.
- Live Zoxide scores range from 1347.2 for `.config/nvim` to 72.0 for
  BibleStandard and include non-project directories. Importing raw values would
  let Zoxide dominate weaker but more project-specific signals.
- The live bounded topology places CanonFidei repositories and named worktrees
  within three project-directory levels of `~/Programming/Projects`,
  RubyandRiver within one level of `~/Documents/Family_Business`, and the Owen,
  Baptists, Bavinck, LCC, and PvM repositories within one level of the EPUB books
  root. No broad `~/Documents` root is needed.
- BibleStandard's Git registry currently contains its main checkout, named
  `BibleStandard-sessions` worktrees, and tool-created `.claude/worktrees`
  entries. Git registry membership, not filesystem spelling, is the worktree
  authority.
- `/usr/bin/python3` is available as Python 3.9.6, and production Herdr commands
  and verification already invoke Python 3. A standard-library catalog module
  adds no package dependency.

## Tradeoffs / Risks

- Consuming application histories improves relevance but inherits their stale
  entries and data-format drift; adapters must fail closed independently.
- Resolving symlinks prevents duplicate workspaces but changes displayed paths;
  preserve a friendly source path for presentation while identity stays canonical.
- Background refresh can leave duplicate processes or race catalog writes unless
  it is single-instance, bounded, and atomic.
- Broad marker-based discovery can turn nested packages and ordinary directories
  into noisy pseudo-projects, especially when combined with Zoxide.
- Source precedence is deliberately predictable rather than statistically
  optimized; stale Neovim order may temporarily outrank current Zoxide-only use.
- Stale-while-revalidate favors immediate availability over guaranteed complete
  first display; newly created repositories may require refresh completion.

## Validation Plan

- Add fixtures for valid, missing, malformed, stale, aliased, nested, non-Git,
  main-checkout, and linked-worktree candidates from every adapter.
- Prove BibleStandard appears once under its canonical identity when Neovim and
  Zoxide provide symlinked aliases.
- Prove source absence/failure is isolated and cannot erase other valid projects.
- Prove existing workspace focus/reuse, tokenless adoption, locking, cancellation,
  and rollback remain unchanged.
- Measure 20-run median and 95th-percentile candidate emission against warm,
  stale, cold, corrupt, empty-seed, and refresh-failure fixtures. Enforce the
  250-millisecond cached and 500-millisecond cold-seed 95th-percentile budgets.
- Prove a five-second refresh timeout leaves the previous valid cache unchanged,
  concurrent refresh requests collapse to one process, and configuration mtime
  invalidates freshness immediately.
- Prove missing cached paths are hidden and selected identities are revalidated
  before any Herdr workspace action.
- Run focused project-picker validation, `./herdr/verify.sh`,
  `./fish/scripts/verify.sh`, `git diff --check`, and fresh Standards/Fidelity
  review with automatic fix/re-review.
- Require Eddy's physical Ghostty confirmation from `herdr/MANUAL_QA.md` that:
  `Prefix+Shift+w` shows candidates or `refreshing` within 500 milliseconds;
  typing `BibleStandard` shows one canonical project plus distinct registered
  worktrees without a symlink duplicate; `Enter` creates or focuses the correct
  workspace; reopening shows `[open]` without changing rank; and `Ctrl-r` keeps
  the picker interactive and reloads successfully.

## Final Decision Review

Reviewed: 2026-09-14

- Review method: independent second pass against current code, live project and
  worktree topology, the closed sessionizer decision, and the repository loop
  standard. This repository defines no dedicated decision-reviewer. Side-thread
  rules prohibit delegating to a fresh subagent, so that limitation is explicit.
- Corrected the invalid `~` cache fallback spelling to `$HOME/.cache`.
- Added the missing versioned configuration schema, exact initial roots and
  depths, record identity, worktree grouping, adapter boundary, file scope,
  implementation stop condition, and physical Ghostty checklist.
- Rejected extending the existing 700-line POSIX shell with catalog state and
  concurrency. A standard-library Python deep module keeps policy testable while
  the shell retains terminal and Herdr orchestration.
- Standards review: PASS for decision readiness. The scope preserves unrelated
  files, separates intent from derived state, names deterministic verification,
  and includes the missing human-only gate.
- Fidelity review: PASS for decision readiness. Every accepted eligibility,
  persistence, refresh, ranking, latency, canonicalization, and worktree decision
  is represented in the exact implementation contract.

## Ready To Act

Ready To Act for a future `feature-plan`; this grill itself authorizes no
production implementation.

Implement only the files and seams listed under Exact implementation contract.
Stop when focused catalog/picker coverage, the 20-run latency budgets,
`./herdr/verify.sh`, `./fish/scripts/verify.sh`, and `git diff --check` pass;
fresh Standards and Fidelity review report zero findings after automatic fixes
and re-review; durable tracking records the evidence; and `herdr/MANUAL_QA.md`
is handed to Eddy as the sole remaining physical Ghostty gate. Do not claim the
physical gate passed without Eddy's direct confirmation.

## Implementation Evidence — 2026-09-14

- Implemented in isolated named worktree `.dotfiles-sessions/herdr-shared-project-catalog` on `feature/herdr-shared-project-catalog`; the shared checkout's modified `pi/settings.json`, untracked interview/research sources, and saved histories were preserved.
- `herdr/project_catalog.json` tracks the settled roots, depths, explicit-project registry, and pins. `herdr/project_catalog.py` uses only the Python 3.9 standard library and owns defensive config/cache parsing, optional Neovim JSON and Zoxide adapters, parallel bounded Git validation, main/linked-worktree identity, symlink alias deduplication, ranking, ten-minute freshness, five-second single-flight refresh, atomic cache writes, action-time validation, and successful-selection recency.
- `herdr/project_picker.sh` now renders the cache/fast seed before recursive discovery, annotates kind/source/status and `[open]`, starts stale/missing refresh away from first paint, binds `Ctrl-r` to asynchronous fzf reload, and retains the prior session lock, tokenless adoption, focus/reuse, cancellation, stale-target rejection, and target-only rollback implementation.
- Thirteen focused tests cover config validation; Git, non-Git, nested, alias, malformed, missing, stale, corrupt, prunable-worktree, adapter-failure, rank, selection, lock, timeout, atomic-preservation, and open-annotation behavior. The real Herdr/fzf validator also proves `[open]`, `Ctrl-r`, restart adoption, locking, rollback, and session isolation.
- Latest aggregate 20-run candidate-emission results: warm 34.979 ms median / 36.156 ms p95; stale 34.753 / 35.146; refresh-failure 35.094 / 35.651; cold 51.964 / 54.548; corrupt 51.434 / 52.498; empty 35.738 / 37.988. All cached states remain below 250 ms p95 and all seed states below 500 ms p95.
- A live disposable-cache refresh completed in 0.88 seconds and produced one canonical BibleStandard main record at `~/Programming/Projects/CanonFidei/BibleStandard`, retaining the `BibleStandardGroup` symlink only as an alias and listing registered linked worktrees separately.
- Eddy authorized a narrow aggregate-blocker repair in `herdr/prototype/ready_prompt_parser.sh`. Pi's collapsed-output divider matcher now removes the Unicode rule glyph before matching its ASCII `↑ N more` core, so it works under the repository's `LC_ALL=C` environment. All 55 parser cases pass, including divider-shaped content inside fenced and marker prompts.
- `./herdr/verify.sh`, `./fish/scripts/verify.sh`, focused catalog tests, `herdr/validate_project_picker.sh`, shell/Python syntax checks, and `git diff --check` pass. The first Fish rerun encountered transient system load at 76.457 ms prompt p95; the immediate full rerun passed at 28.857 ms p95 and 24.944 ms startup p95.
- Fresh Standards review after the parser fix: PASS, zero findings. Fresh Fidelity review after the parser fix: PASS, zero findings. Only the physical Ghostty checklist remains; it is not recorded as passed.

## Physical Ghostty Gate

Attempted 2026-09-14 from Ghostty; not a valid feature check. The screenshot showed the installed/shared-checkout picker returning one unrelated `CS...Problem_Set` result for `BibleSt`. The live Herdr config still resolves `Prefix+Shift+w` through `HERDR_PROTOTYPE_DIR=/Users/eddyekofo/.dotfiles/herdr/prototype`, while the implemented catalog remains isolated at `/Users/eddyekofo/.dotfiles-sessions/herdr-shared-project-catalog`. No install, restart, merge, or shared-checkout overlay was authorized, so the new picker was not active.

A fresh read-only catalog refresh still returns the canonical `~/Programming/Projects/CanonFidei/BibleStandard` main checkout, BibleStandardSite, and the registered BibleStandard worktrees.

Retested 2026-09-14 through an authorized temporary shared-checkout overlay in existing session `window-81`. Eddy reported first paint was “almost instantly,” refresh stayed interactive, BibleStandard appeared once under its canonical main identity, registered worktrees remained distinct, Enter focused/created the correct workspace, reopening showed `[open]` without changing rank, and `Ctrl-r` reloaded successfully. One Fidelity finding remained: the inherited global fzf preview opened an empty pane because `_fzf_preview {}` received the whole tab-separated record and was unavailable in the popup's POSIX shell.

Automatic fix: the picker now owns a single-selection, bounded two-level directory preview keyed to canonical field `{3}`, using `eza` when available and a `find` fallback. Focused coverage asserts the explicit preview and field boundary. Thirteen catalog tests, 55 parser tests, real-fzf/workspace validation, `./herdr/verify.sh`, `./fish/scripts/verify.sh`, and `git diff --check` pass after the fix. Latest aggregate latency remained within budget: cached states at or below 40.549 ms p95 and seed states at or below 211.708 ms p95. Fresh Standards re-review: PASS, zero findings. Fresh Fidelity re-review: PASS, zero findings. Eddy physically accepted the corrected preview and the complete checklist on 2026-09-14. Both temporary overlays were restored exactly; no install or restart occurred.

## Closure

**DONE 2026-09-14.** The settled catalog, picker integration, latency budgets, aggregate gates, parser blocker repair, fresh reviews, and full physical Ghostty checklist pass. Eddy authorized committing and merging the complete branch into local `main`. Nothing was pushed, installed, or restarted, and the named worktree remains available because retirement was not authorized.

## Open Questions

None that would change implementation.
