# Pi Herdr Recovery Isolated ID Mismatch — Implementation Brief

Status: Done by Owner Acceptance

## Source

- `.working/interviews/pi-herdr-recovery-isolated-id-mismatch/decisions.md`
- `.working/UNIFIED_INTAKE.md`

## Scope

- Make the Pi Herdr integration prefer the isolated session ID over the absolute
  session path in every report.
- Preserve a path-only fallback.
- Add live-seam regression coverage for emitted locator kind, launcher
  acceptance, and history preservation.

## Non-goals

- Herdr integration-version migration, Herdr persistence changes, session-file
  rewrites, unrelated Pi settings/evidence changes, commit, push, or publication.

## Acceptance and stop condition

- The focused live fixture proves Herdr receives an ID and can replay the
  launcher with it while the path stays rejected and the session file intact.
- `./pi/verify.sh` passes.
- Fresh Standards and Fidelity review passes after all fixes.
- Tracking reflects closure or the remaining physical Ghostty gate.

## Validation

- `pi/validate_herdr.sh`
- `./pi/verify.sh`
- `git diff --check`
- Fresh Standards/Fidelity review against the decision record and actual diff.

## Result

- The integration emits the isolated Pi session ID and retains its path-only
  fallback.
- The disposable Herdr fixture stops and restarts the session, replays the same
  ID, restores the visible history marker, and leaves the JSONL history intact.
- Focused validation and `./pi/verify.sh` pass.
- Fresh Standards and Fidelity re-reviews pass with zero findings.
- Eddy accepted the unchecked physical Ghostty recovery behavior operationally
  until a contrary report; this is recorded as an owner waiver, not a witnessed
  pass.
