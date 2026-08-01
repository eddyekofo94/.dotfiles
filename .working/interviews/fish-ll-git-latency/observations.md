# Fish ll Git Latency

Status: Resolved by `fish-prompt-return-latency`

## Observation

- Reported 2026-08-01: something still feels wrong when running `ll` in
  `/Users/eddyekofo/Documents/Family_Business/RubyandRiver`.
- This report arrived while `fish-prompt-return-latency` awaited physical
  acceptance. No production alias change is included in this investigation.

## Red-capable feedback loop

```sh
.working/interviews/fish-ll-git-latency/reproduce.sh \
  /Users/eddyekofo/Documents/Family_Business/RubyandRiver
```

- Measures the real Fish `ll` function against the same eza listing without
  per-file Git status.
- Reports RED when `ll` is at least 250 ms while the no-Git control stays below
  100 ms.

## Evidence

- Repository: clean; 706 tracked files; 273 MB tracked worktree; 208 MB `.git`.
- `git status --porcelain=v1`: 0.85-0.87 seconds on five consecutive runs.
- `ll`: 0.89 seconds on five consecutive runs.
- Exact eza flags with explicit `.` and `--git`: 0.87-0.88 seconds.
- Exact eza flags with explicit `.` but without `--git`: below the 10 ms
  resolution of `/usr/bin/time -p`.
- eza with no explicit target produces no listing in this environment, so the
  existing `.` default remains load-bearing for correct output.
- `git count-objects -vH` reports a 205.73 MB pack plus 121 garbage temporary
  objects totaling 968.66 KiB. Those small garbage objects do not explain the
  repeated 0.85-second worktree refresh.

## Diagnosis

RubyandRiver is not large by tracked-file count. Its Git metadata refresh is
abnormally expensive because a stale `.git/index.lock` prevents refreshed
index metadata from being persisted. `ll` and Starship are consumers of this
shared Git failure, not independent root causes. Fish vi mode is unrelated.

The repository is inside iCloud/File Provider-managed `Documents`. Its `.git`
contains `index 2`, `index 3`, `index 4`, seven object filenames suffixed ` 2`,
`HEAD.lock`, `index.lock`, `index.lock.stale`, `maintenance.lock`, and 114
`tmp_obj_*` files. Those conflict-copy names and stale artifacts are not normal
Git repository state and make recurrence likely if the repository remains
inside the synced domain.

## Root-cause proof

- Real index: five Git status runs remain 0.85-0.87 seconds; index mtime does
  not change.
- Isolated copy of the same index without the stale adjacent lock: first status
  0.85 seconds, then 0.01 seconds twice after the refreshed metadata persists.
- No active Git writer owns the lock. A Claude Virtualization process has the
  stale files open read-only through the shared filesystem.
- `git fsck --full` exits 0 but reports seven bad SHA-1 conflict-copy filenames
  plus one dangling commit.
- Worktree is clean. Local `main` is 14 commits ahead of the recorded
  `origin/main`; no stash exists. A blind reclone would not preserve all local
  history.

## Candidate safe repair

Preserve the existing repository and its 14 local commits, relocate it outside
the iCloud/File Provider domain, quarantine rather than immediately delete the
stale/conflict artifacts, refresh the real index, and re-run Git integrity and
latency checks. Then restore Starship Git status and keep `ll --git` if both
remain within the latency target. Moving the repository and choosing its new
path require explicit user approval.

## Selected in-place repair

- Eddy required the existing RubyandRiver path and authorized an in-place
  repair on 2026-08-01.
- Quarantined only the proven zero-byte stale lock as
  `.git/_stale/index.lock.20260801-0152`; no Git history or worktree file moved.
- First real status refreshed the index in 0.85 seconds; four subsequent status
  runs completed in 0.01 seconds.
- Unchanged `ll --git` completed in 0.02-0.03 seconds across five runs.
- The red-capable reproducer now reports `symptom not reproduced`.
- Starship Git status was restored. Remaining File Provider conflict artifacts
  are recorded recurrence risk; they were not modified.
