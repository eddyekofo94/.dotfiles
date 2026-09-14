# Herdr Shared Project Catalog Research

Date: 2026-09-14

## Question

What should define a shared project catalog for Herdr when Neovim history,
Zoxide, configured filesystem roots, Git repositories, and linked worktrees all
provide partially overlapping signals?

## Recommendation

Use a history-first catalog with strict identity validation:

1. Read the last-known validated catalog immediately so the picker never waits
   for discovery.
2. Use Neovim history and Zoxide as optional candidate and ranking adapters.
3. Automatically accept only Git main checkouts and linked worktrees.
4. Admit intentional non-Git projects through an explicit registry.
5. Canonicalize symlink aliases before deduplication, while preserving each real
   linked worktree as a separate selectable project.
6. Refresh configured roots and Git worktrees through a bounded, single-instance,
   atomic process outside the popup's first-paint path.

## Primary-source findings

### Herdr

- Herdr defines a workspace as the top-level container for a project or work
  context, owning its tabs and panes. It recommends using workspaces before
  sessions for ordinary project separation.
  Source: <https://herdr.dev/docs/concepts/>
- Herdr's quick start recommends one workspace per active project.
  Source: <https://herdr.dev/docs/quick-start/>
- Herdr has native Git-worktree operations and represents worktrees as ordinary
  workspaces with provenance. The catalog should preserve that model rather than
  flatten all worktrees into one checkout.
  Source: <https://herdr.dev/docs/cli-reference/>

### Git

- Git defines one main worktree and zero or more linked worktrees. Each worktree
  has separate per-worktree metadata even though the worktrees share repository
  data. Git commands are therefore the authoritative adapter for distinguishing
  main and linked worktree identities.
  Source: <https://git-scm.com/docs/git-worktree>

### Zoxide

- Zoxide remembers directories that a user visits frequently. Its unit is a
  directory, not a repository or project.
  Source: <https://github.com/ajeetdsouza/zoxide>
- Zoxide ranks entries with a frecency score and lazily removes stale paths.
  This is valuable ranking evidence, but it is not a durable project-identity
  contract.
  Source: <https://github.com/ajeetdsouza/zoxide/wiki/Algorithm>

## Decision analysis

### Why Git validation wins

- The requested organizing unit is primarily a repository.
- Git supplies identity and worktree provenance without depending on an editor's
  lifecycle or a shell-navigation database.
- It rejects Zoxide's ordinary, nested, backup, and temporary directories.
- It avoids marker rules turning nested packages into accidental workspaces.

### Strongest alternative

Automatic marker-based eligibility would discover non-Git projects and nested
monorepo roots without manual registration. It loses as the default because its
false-positive boundary is contextual: the same file can mark a repository, a
package, an editor root, or a tool configuration directory.

The recommendation should be overturned if there are recurring non-Git projects
that must appear automatically. In that case, marker discovery needs explicit
marker profiles, exclusion and nesting rules, and red-capable fixtures before it
can become an authority.

## Local evidence applied

- BibleStandard is a Git checkout at
  `~/Programming/Projects/CanonFidei/BibleStandard`.
- Neovim and Zoxide remember a symlinked `BibleStandardGroup` path, so candidate
  aliases need canonicalization before validation and deduplication.
- Herdr's current synchronous scan exceeds 30 seconds at its default depth, while
  bounded roots complete quickly. Discovery cannot stay on the popup's critical
  path.
- The live Zoxide database includes useful repositories and unrelated directories,
  confirming that it is a discovery/ranking signal rather than an authority.

## Implementation follow-through

The settled decision record subsequently authorized implementation. The resulting standard-library catalog validates Neovim's actual exported array-of-objects format, consumes Zoxide ordinally, expands Git's porcelain worktree registry, and keeps the tracked configuration separate from the disposable XDG cache. A live disposable-cache refresh completed in 0.88 seconds and converged BibleStandard's `BibleStandardGroup` alias onto the CanonFidei main checkout while retaining registered worktrees as separate records. The final post-preview aggregate run kept cached fixture candidate emission below 41 milliseconds p95 and cold/corrupt/empty seed emission below 212 milliseconds p95. Physical use exposed one presentation boundary the architectural research did not cover: the global Fish `_fzf_preview {}` command cannot preview a tab-separated catalog record from Herdr's POSIX popup. The picker therefore owns a bounded directory-tree preview against canonical field `{3}` instead of inheriting an unrelated global preview command.

## Boundary

This record supplies architectural and local-topology evidence. The settled contract and implementation/validation status live in `.working/interviews/herdr-shared-project-catalog/decisions.md`.
