# Fish Prompt Return Latency Validation

Status: Superseded mitigation evidence

## Change

- Disabled synchronous Starship `git_status`.
- Preserved directory, Git branch, right-side command duration, Fish vi mode,
  and all other prompt configuration.
- Added a real interactive PTY prompt-readiness regression to the full Fish
  verification gate with a raw 20,000-microsecond p95 boundary.

## Exact target results

- Dotfiles: 30 runs; median 15.986 ms; p95 16.556 ms; PASS.
- RubyandRiver: 30 runs; median 16.087 ms; p95 16.648 ms; PASS.
- Isolated simple-prompt controls: p95 0.747 ms and 0.726 ms.

## Full verification

- `./fish/scripts/verify.sh`: PASS.
- Embedded real-prompt p95: 16.786 ms.
- Fish startup benchmark: median 24.971 ms; p95 25.415 ms; PASS.
- Fresh Standards review: 0 findings.
- Fresh Fidelity review after fixes: 0 findings.
- `git diff --check` on the implementation scope: PASS.
- Commit/push: not performed.

## Manual gate

In physical Ghostty, enter RubyandRiver and confirm repeated prompt returns feel
instant. Confirm the Git branch and Fish vi behavior remain present; Git status
counts are intentionally absent.

This mitigation was rejected as the final behavior because Git presentation
must remain available. See `root-repair-validation.md` for current evidence.
