# Fish Prompt Return Latency

Status: DONE

## Observation

- Reported 2026-08-01: fresh prompt feels delayed; after Enter, the next prompt
  is not ready instantly.
- Expected: no perceptible prompt-return delay.
- `pi-global-response-style-parity` closed DONE on 2026-08-01. Eddy selected
  this bounded fix through `feature-plan` and authorized local implementation.

## Red-capable feedback loop

```sh
fish/tests/measure_prompt_latency.exp \
  /Users/eddyekofo/.dotfiles
```

- Drives real interactive Fish through a PTY.
- Measures Enter until Fish emits its OSC 133 prompt-ready marker.
- Thirty `true` commands; fails when real p95 exceeds 50 ms.
- Identical-process simple-prompt control distinguishes prompt rendering from
  command execution and postexec hooks.

## Reproduction evidence

- Durable exact PTY loop, repeated twice: real Starship median 27 ms, p95
  28 ms; simple prompt median 0 ms, p95 0 ms. Both verdicts: RED. An initial
  ad-hoc run reached p95 40 ms.
- Fresh-shell configuration benchmark: median 25.309 ms, p95 26.649 ms; PASS.
  It does not render and wait for the real prompt, so it misses this report.
- One cold first-prompt probe reached prompt-ready in 93 ms.
- Direct Starship in `.dotfiles`: median 22.48-22.76 ms, p95 23.63-23.84 ms.
- Direct Starship in `/tmp`: median 5.06 ms, p95 5.60 ms.
- Clean empty Git repo: median 17.92 ms, p95 19.38 ms.
- Starship module timing in `.dotfiles`: `git_status` 28 ms, `directory` 15 ms,
  `lua` 4 ms, `git_branch` below 1 ms.
- Direct module isolation: character-only 3.84 ms; directory/no-Git 11.02 ms;
  Git branch-only 11.05 ms; Git status-only 21.51 ms.
- Right prompt subprocess: median 3.85 ms.
- Active Starship config is the standard symlink
  `~/.config/starship.toml -> starship/starship.toml`.
- Repository state during diagnosis: Starship reported 1 stash, 18 modified,
  97 untracked, and 34 commits ahead.

### RubyandRiver clean-worktree control

- Exact path: `/Users/eddyekofo/Documents/Family_Business/RubyandRiver`.
- `git status --short`: empty; 706 tracked files.
- Exact PTY prompt return: median 838 ms, p95 959 ms in the first 30-run probe.
- Starship timing: `git_status` 814 ms; directory 9 ms; branch below 1 ms.
- Direct Git timing: clean `git status --porcelain=v1` median 897.7 ms.
- Git performance trace: 912.167 ms of a 916.108 ms status call is index
  refresh; output formatting and tree diff are negligible.
- `--untracked-files=no` did not help (median 938.6 ms). The clean worktree is
  still expensive because Git refreshes tracked-file metadata.
- Starship keymap controls remained slow: insert 809.0 ms, default 863.9 ms,
  normal 820.8 ms. Vi-mode selection is not causal.

## Ranked hypotheses and probes

1. **Confirmed symptom, superseded root cause:** synchronous Starship
   `git_status` exposed RubyandRiver's stale-index refresh. Removing status made
   the symptom disappear but incorrectly removed useful Git presentation.
2. **Contributing:** Starship process startup and directory/Git-root discovery
   add a smaller fixed cost. Prediction confirmed by character-only 3.84 ms and
   directory-only 11.02 ms.
3. **Rejected as primary:** Fish postexec handlers delay readiness. Prediction:
   a simple prompt would remain slow; control instead measured 0 ms.
4. **Rejected for the post-command symptom:** Fish startup configuration is
   slow. Prepared-state benchmark remains about 25 ms and does not run on every
   prompt.

## Diagnosis

The perceived pause is real. Fish itself returns immediately. In RubyandRiver,
a stale zero-byte `.git/index.lock` prevented refreshed index metadata from
persisting, forcing Starship and `ll` to repeat an 0.85-second scan. This is a
repository-state failure shared by Git consumers, not a Fish vi-mode defect.

## Selected bounded fix

Quarantine the proven stale lock in place, refresh the real index, restore
Starship Git status, retain `ll --git`, and keep the real PTY loop in the Fish
gate. The automated threshold is p95 at most 50 ms with Git presentation
retained. Physical Ghostty feel remains a user gate.

## Superseded mitigation evidence

- The initial Starship-disable mitigation passed but was rejected as final
  behavior. Current root-repair evidence is in `root-repair-validation.md`.
- Exact dotfiles PTY: median 15.986 ms, p95 16.556 ms.
- Exact RubyandRiver PTY: median 16.087 ms, p95 16.648 ms.
- Full Fish verification: PASS; embedded prompt p95 16.786 ms and startup p95
  25.415 ms.
- Fresh final review: Standards 0 findings; Fidelity 0 findings.
- No commit or push.

## Current root-repair evidence

- Starship Git status is restored; `ll --git` is unchanged.
- Exact dotfiles PTY: median 30.043 ms, p95 31.372 ms.
- Exact RubyandRiver PTY: median 30.051 ms, p95 31.066 ms.
- Full Fish verification: PASS; embedded prompt p95 31.509 ms and startup p95
  25.694 ms.
- Fresh final review: Standards 0 findings; Fidelity 0 findings.
- No commit or push.
