# Fish Fcat Empty Ignored-File Result — Diagnosis

## Observation

On 2026-07-31, Eddy ran `fcat Business_Registration_Details.md` twice from the
RubyandRiver repository. Both invocations returned immediately with neither a
path header nor contents.

The file exists at the repository root and contains 2,733 bytes.

## Tight Reproduction

`fish/tests/fcat_integration.sh` now drives `fcat` through its actual
`FZF_DEFAULT_COMMAND` producer with a root-level fixture excluded by a local
`.gitignore`. The mock derives its target from fzf's real `--query=` argument,
so the test invokes the reported `fcat fixture.txt` route rather than a
test-only selection path. Before the production fix, the command fails because
the mock fzf receives no exact candidate to return.

## Ranked Hypotheses

1. **VCS ignore exclusion.** If `fd` is omitting the file because of
   `.gitignore`, `git check-ignore` will name the rule and `--no-ignore-vcs`
   will restore the exact candidate.
2. **Malformed fzf query plumbing.** If `--query="$argv"` loses the filename,
   feeding the restored producer through an exact fzf filter will still fail.
3. **Candidate path-shape mismatch.** If `fd --strip-cwd-prefix` emits a leading
   `./` or another path shape, the restored candidate will differ from the
   requested root filename.
4. **Stale Fish autoload.** If the running shell retained an old `fcat`, a fresh
   Fish process will show behavior different from the active source file.

## Evidence

- `git check-ignore -v Business_Registration_Details.md` reports
  `.gitignore:8:Business_Registration_Details.md`.
- The normal producer emits 783 entries but no exact business-details file.
- Adding `--no-ignore-vcs` emits exactly `Business_Registration_Details.md`.
- The exact file query and stripped path shape therefore survive once the VCS
  ignore boundary is changed, falsifying hypotheses 2 and 3.
- A fresh Fish process loads the current path-header implementation, so stale
  autoload does not explain the empty candidate set.

## Root Cause

Hypothesis 1 is confirmed. `fcat` intentionally requests hidden files but still
inherits VCS ignore rules from `fd`, making ignored local reference files
undiscoverable. Because fzf uses `--exit-0`, an exact query with no candidate
returns silently. The former integration test bypassed the producer by handing
the mock fzf a preselected path, so it could not fail on this route.

## Fix

Add `--no-ignore-vcs` only to `fcat`'s `fd` producer while preserving
`--exclude .git`. Extend the focused test so its mock fzf consumes the real
`FZF_DEFAULT_COMMAND` inside a temporary Git repository where the exact fixture
is listed in `.gitignore`, with the match derived from fzf's actual `--query=`
argument. A `.git/should-not-appear` sentinel queried through that same route
must remain undiscoverable, and an `fd` recording wrapper must confirm that the
actual producer invocation retains the explicit `--exclude` plus `.git`
argument pair.
