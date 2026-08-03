# Fish Fcat Selected Path

## Goal

Make the file selected by `fcat` identifiable and directly copyable after the
FZF picker closes.

## Exit Criteria

- Before file contents, `fcat` prints only the selected file path.
- A selected file under `$HOME` displays as `~/path/to/filename`.
- A selected file outside `$HOME` retains its absolute path.
- The path uses a subtle terminal colour and is followed by one blank line.
- Labels, bars, icons, and other decoration are absent.
- Paths containing spaces remain safe and contents are unchanged.
- Focused coverage, `fish/scripts/verify.sh`, and fresh Standards/Fidelity
  review pass after the final implementation change.
- Colour appearance remains awaiting Eddy's physical terminal confirmation.

## Scope / Non-goals

In scope: `fcat`, focused automated coverage, Fish verification, durable local
workflow records, and fresh two-axis review.

Non-goals: changing the FZF picker, preview, `cat`/`bat` rendering, other
file-oriented functions, commits, pushes, hosted tickets, or publication.

## Decisions

- The visible format is exactly the path text, for example:

  ```text
  ~/.dotfiles/fish/functions/fcat.fish

  <file contents>
  ```

- Use a subtle terminal colour without adding visible characters; terminal
  selection therefore copies only the rendered path text.
- Resolve both the selected file and `$HOME` to canonical absolute paths before
  applying the home-relative abbreviation.
- Preserve an absolute path when the selected file is outside `$HOME`.
- Print one blank line between the path and contents.
- Let `fcat` discover VCS-ignored local files while retaining the explicit
  `.git` exclusion; do not change other FZF functions.

## Evidence / Findings

- Before this goal, `fcat` passed the FZF result directly to `cat`, so the
  selected file's identity disappeared when the picker closed.
- The repository's `cat` wrapper uses `bat -pp`, whose plain style intentionally
  omits a filename header.
- Eddy rejected decorative bars and labels because they would make the path
  inconvenient to copy.
- The accepted text prototype is the exact example recorded under Decisions.
- Eddy's 2026-07-31 physical RubyandRiver test showed two invocations of
  `fcat Business_Registration_Details.md` returning immediately with neither
  the path header nor file contents. The selected file exists at the repository
  root and contains 2,733 bytes.
- RubyandRiver's `.gitignore` explicitly lists
  `Business_Registration_Details.md`. On installed `fd` 10.4.2, the normal
  `fcat` producer emits 783 candidates but omits that file; adding
  `--no-ignore-vcs` restores its exact root-relative name.
- The original focused test mocked fzf by returning a preselected path, so it
  never exercised `FZF_DEFAULT_COMMAND` and could not detect an empty producer.
- In RubyandRiver, `--no-ignore-vcs` changes the producer from 783 to 834
  candidates and both forms complete in approximately 0.01 seconds.
- The worktree was already broadly dirty before this goal. This goal changes
  only its explicit implementation, test, verifier-wiring, and workflow-record
  allowlist.

## Tradeoffs / Risks

- Automated output checks can prove the ANSI colour is present and that it adds
  no visible decoration, but only physical terminal inspection can settle
  whether the chosen colour feels appropriately subtle.
- Resolving the selected path reports the canonical target when the selection
  traverses a symlink; resolving `$HOME` too preserves correct abbreviation
  when macOS canonicalizes a path prefix such as `/var` to `/private/var`.

## Validation Plan

- Run `fish/tests/fcat_integration.sh` against home-relative, outside-home,
  space-containing, VCS-ignored real-producer, and canceled selections.
- Run Fish syntax validation for the changed function.
- Run `fish/scripts/verify.sh`.
- Run scoped `git diff --check` and confirm the goal allowlist.
- Review Standards and Fidelity separately against this decision record,
  implementation brief, workflow rules, and actual diff; fix and re-review
  until clean.
- Leave the subtle-colour appearance awaiting Eddy's physical terminal check.

## Ready To Act

Implemented and closed on 2026-07-31. Physical QA exposed an empty ignored-file
producer; the repaired query-derived producer path, explicit `.git` boundary,
original RubyandRiver route, full validation, and fresh post-fix review passed.
Eddy then reloaded `fcat` and accepted the physical colour/copy behavior.

## Open Questions

None that change implementation. Physical colour acceptance remains a manual
closure gate.

## Validation And Review Evidence

See `.working/interviews/fish-fcat-selected-path/validation-and-review.md`.

Closure: `.working/interviews/fish-fcat-selected-path/closure.md`.
