# Herdr Project Sessionizer Workflow

## Goal

Replace the stale tmux-only project sessionizer with a Herdr-native project
entry workflow that discovers Git repositories and worktrees, reuses an
existing workspace for the selected directory, or creates and focuses one in
the daily `main` Herdr session.

## Exit Criteria

The behavior, scope, stop condition, and validation are specific enough to
implement without guessing; the resulting picker passes focused isolated
coverage, full Herdr/Fish verification, and fresh Standards/Fidelity review.

## Scope / Non-goals

- Add one Herdr project picker and one popup binding.
- Discover Git repositories and their linked worktrees from configurable roots.
- Reuse workspaces by canonical cwd; otherwise create and focus a workspace.
- Preserve native `Prefix+w` navigation and make project entry
  `Prefix+Shift+w`.
- Keep Herdr v0.7.4, `pane_history = false`, and the tmux fallback unchanged.
- Do not create or remove Git worktrees, create named Herdr sessions, upgrade
  Herdr, change the default multiplexer, commit, push, or publish.
- Pane transfer, history export, tab edges, layout presets, richer picker
  operations, and copy-mode gaps remain separate ranked goals.

## Decisions

- Ordinary projects are workspaces in the existing `main` Herdr session.
  Named sessions remain isolation boundaries, not one-session-per-project.
- A project target is identified by its physical canonical directory, not its
  label. Selecting an already-open cwd focuses that workspace without creating
  a duplicate.
- Default discovery includes the repository checkout and Git repositories
  below existing `~/Documents`, `~/Projects`, `~/projects`, `~/work`, and
  `~/code` roots. `HERDR_PROJECT_ROOTS` may replace those roots with a
  colon-separated list.
- Discovery follows each repository's `git worktree list --porcelain`, so
  linked worktrees outside a configured root remain selectable.
- Workspace labels use the selected directory basename for compact sidebar
  display. The picker display includes the full abbreviated path, so duplicate
  basenames remain distinguishable.
- `Prefix+Shift+w` opens the session-modal fzf project picker.
  Native `Prefix+w` remains the fast existing-workspace navigator.
- Cancel is a successful no-op. Missing dependencies, malformed API responses,
  an invalid/non-directory selection, or a workspace create/focus failure must
  fail closed with no target mutation.
- The picker accepts explicit dependency and selection overrides for
  deterministic tests; production defaults remain `herdr`, `fzf`, and the
  current pane's session socket.

## Evidence / Findings

- `tmux/scripts/sessionizer.sh` scans lowercase `~/projects`, `~/work`, and
  `~/code`, none of which exists on this machine. It also treats every
  directory as a project and keys tmux sessions only by basename.
- Actual repositories are primarily below `~/Documents`, at depths greater
  than the old `find -maxdepth 3` limit. The dotfiles checkout itself is outside
  that tree.
- `docs/migrations/tmux-to-herdr.md` already settles that everyday project
  navigation uses workspaces while named Herdr sessions remain isolation
  boundaries.
- Herdr v0.7.4 exposes structured `workspace list/create/focus` and
  `worktree list/create/open/remove` commands. The current production launcher
  attaches login shells to the `main` session.
- The native `Prefix+w` workspace picker and `Prefix+f` searchable navigator
  already have passing deterministic coverage and must not be repurposed.
- Production config and integration verification already assert
  `pane_history = false`, Herdr v0.7.4, and the retained tmux resurrection
  privacy posture.
- Herdr v0.7.4 does not expose a workspace cwd in `workspace list`. The
  implementation reports a canonical `project_cwd` workspace metadata token
  and, after a server restart, safely re-adopts the restored workspace through
  its pane cwd before recreating the token.
- The first live default scan exposed generated nested repositories under
  `.runtime`, `build`, CMake, dependency, cache, virtual-environment, and
  vendor directories. Discovery now owns an explicitly configured repository
  root without descending into it, prunes generated dependency trees, and uses
  `fd` when available with a portable `find` fallback.
- The final live discovery returns the same 111 real repository/worktree
  candidates in about 1.3 seconds on this machine, including `.dotfiles`,
  RubyandRiver, Owen, and BibleStandard, without `.runtime`, build, or internal
  `.git` storage paths.

## Tradeoffs / Risks

- Repository-only discovery intentionally retires the old behavior of listing
  every intermediate directory. Explicit non-Git directories can still be
  opened through native Herdr workspace creation; adding them to this picker
  would reintroduce noisy and ambiguous candidates.
- A separate named session per project gives stronger isolation, but fragments
  the approved cross-workspace navigation model and complicates reuse. It is
  rejected for daily project entry.
- Automatically creating Git worktrees from this picker would require branch,
  base, path, overwrite, and dirty-tree decisions. This slice only discovers
  and opens existing worktrees; creation stays in Herdr's native worktree
  workflow.
- Scanning `~/Documents` is broader than the old invalid roots. The
  implementation must bound traversal, suppress inaccessible paths, deduplicate
  canonical targets, and keep tests independent of the live home tree.
- Workspace metadata is runtime state rather than restart-persistent state in
  v0.7.4. Restart reuse therefore re-adopts a workspace only when its restored
  pane cwd still equals the selected canonical project; it fails toward a new
  correctly rooted workspace rather than focusing an unrelated stale target.

## Validation Plan

- Run a focused isolated picker validator covering discovery, linked
  worktrees, path/label collisions, existing-workspace reuse, new-workspace
  creation, cancellation, invalid targets, stale targets, failed API calls,
  named-session isolation, and unchanged production hashes.
- Prove the actual popup binding opens the picker in an isolated Herdr session
  and that selection focuses/reuses or creates the intended workspace.
- Run `./herdr/verify.sh`.
- Run `./fish/scripts/verify.sh`.
- Confirm the live binary remains `herdr 0.7.4`, production
  `pane_history = false`, and tmux remains available.
- Run fresh Standards and Fidelity review against this decision record, the
  active brief, actual diff, and validation evidence; fix and re-review until
  both axes have zero findings.

## Closed

Closed on 2026-07-27. Focused validation, full Herdr verification, full Fish
verification, and fresh closure review passed. Final review result: Standards
0 / Fidelity 0. Herdr remains v0.7.4 with `pane_history = false`; tmux remains
available. No Herdr upgrade, commit, or push occurred.

## Open Questions

None that would change implementation.
