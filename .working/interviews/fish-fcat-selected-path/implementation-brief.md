# Fish Fcat Selected Path — Implementation Brief

## Source

- `.working/interviews/fish-fcat-selected-path/decisions.md`

## Active Scope

1. Resolve the single FZF-selected file and `$HOME` to canonical absolute
   paths.
2. Include VCS-ignored local files in `fcat`'s producer while continuing to
   exclude `.git`; do not alter other FZF commands.
3. Abbreviate only a leading `$HOME/` to `~/`.
4. Print only that path in a subtle colour, reset colour, add one blank line,
   then preserve the existing file-content behavior.
5. Add focused regression coverage, including the real ignored-file producer,
   and wire it into the Fish aggregate gate.
6. Run full validation and fresh Standards/Fidelity review.

## Non-goals

- Decorative labels, bars, icons, or prefixes.
- Changes to other FZF commands, shared picker behavior, previews, or the
  `cat`/`bat` wrapper.
- Commit, push, hosted ticket, or publication.

## Acceptance Criteria

- Home selections display exactly `~/path/to/filename`.
- Outside-home selections display their absolute paths.
- Spaces are handled safely.
- ANSI colour is present around the path but leaves the visible/copyable text
  undecorated.
- Exactly one blank line separates the path from unchanged contents.
- Cancellation prints nothing.

## Implementation Seams

- `fish/functions/fcat.fish`
- `fish/tests/fcat_integration.sh`
- `fish/scripts/verify.sh`

## Stop Condition

Focused and full Fish verification pass, the scoped diff is clean, fresh
Standards/Fidelity review has zero findings, and durable records reflect the
evidence. Because colour subtlety is subjective, leave final closure awaiting
Eddy's physical terminal confirmation.

## Baseline

Pre-existing changes are preserved. Before this goal, `git hash-object`
computed these content fingerprints (they are fingerprints, not objects written
to the repository database):

```text
d5ca7c9a3ff463f4b6f8d82cf3fd2884f582bec4  fish/functions/fcat.fish
0b1142f5e7783a184c601540b51096f1874b23cc  fish/scripts/verify.sh
```

The only goal-owned change in the already-dirty `fish/scripts/verify.sh` is the
single invocation of `"$package_dir/tests/fcat_integration.sh"` immediately
after `fif_real_fzf.sh`. The worker-count function and its `awk` callers in the
same current Git diff predate and are excluded from this goal.

## Validation

Use the exact validation plan in the decision record. Do not treat automated
ANSI checks as physical acceptance of the chosen colour.
