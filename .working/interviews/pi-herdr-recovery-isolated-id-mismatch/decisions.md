# Pi Herdr Recovery Isolated ID Mismatch

## Goal

Restore native Herdr restart recovery for isolated Pi sessions by reporting the
session identifier that `pi --session` accepts.

## Exit Criteria

- When Pi exposes both a session ID and an absolute session file path, the Herdr
  integration reports the ID.
- Herdr persists and replays `pi --session <ID>`, never the rejected absolute
  JSONL path.
- Existing Pi session histories are neither rewritten nor deleted.
- Focused recovery coverage, `./pi/verify.sh`, and fresh Standards/Fidelity
  review pass after the fix.
- Physical Ghostty recovery remains an explicit user check if automation cannot
  prove the installed restart path.

## Scope / Non-goals

- In scope: Pi's managed Herdr integration payload, focused integration
  regression coverage, and durable workflow tracking.
- Non-goals: changing Pi's isolated locator policy, migrating every Herdr
  integration to version 8, altering Herdr persistence, editing saved sessions,
  or repairing unrelated dirty files.

## Decisions

- Prefer `sessionManager.getSessionId()` whenever it yields a non-empty string.
- Fall back to `sessionManager.getSessionFile()` only when no ID exists, so the
  integration retains compatibility with contexts that expose only a path.
- Apply the same preference to state reports and explicit session reports.
- Lock the contract at the live Pi-to-Herdr integration seam, not with a
  shallow helper-only test.

## Evidence / Findings

- Eddy's 2026-09-12 Ghostty recovery restored eight Pi panes with
  `pi --session <absolute-jsonl-path>`; all failed with
  `pi-pilot: session and fork locators must be isolated IDs`.
- The saved histories remain intact, and each JSONL header contains the accepted
  UUID.
- `pi/integrations/herdr-agent-state.ts` currently prefers
  `agent_session_path` when both path and ID are available.
- Red-capable command: `PI_PILOT_EVIDENCE_DIR=/private/tmp/pi-recovery-red-evidence
  /Users/eddyekofo/.dotfiles/pi/validate_herdr.sh`, followed by an assertion that
  `.managed_integration.kind == "id"`. The live fixture passed its old checks
  but the new assertion returned `false`; it reported kind `path` and an
  absolute JSONL value.

## Tradeoffs / Risks

- ID-first is intentionally specific to Pi's isolated launcher contract. A
  path-only fallback remains to avoid breaking environments without an ID.
- Automated fixture recovery can prove the emitted locator and launcher
  acceptance, but physical Ghostty restoration may still be perceptual/manual.

## Validation Plan

- Extend `pi/validate_herdr.sh` to assert that the live integration reports an
  isolated ID, that the corresponding session file still exists, and that the
  launcher accepts the ID while rejecting the path.
- Run the focused Pi Herdr integration validator against disposable state.
- Run `./pi/verify.sh` from the isolated worktree using disposable runtime and
  evidence roots.
- Run `git diff --check` and fresh Standards/Fidelity review; fix and re-review
  all actionable findings.

## Ready To Act

Ready. Eddy selected this exact goal through `/feature-plan` on 2026-09-12 and
settled the scope, preservation boundary, stop condition, and validation.

## Open Questions

None that change implementation.

## Implementation Result

- `selectSessionRef` prefers `agent_session_id` and preserves a path-only
  fallback for both state and explicit session reports.
- Focused helper coverage passes for ID-plus-path, path-only, and absent inputs.
- The disposable Herdr fixture passes an actual stop/restart cycle that replays
  the same isolated ID, restores its visible history marker, and preserves the
  original JSONL session file.
- `./pi/verify.sh` passes after the fixes.
- Fresh Standards and Fidelity reviews pass with zero actionable findings.
- Eddy closed the manual gate on 2026-09-14 by explicitly accepting the
  unchecked physical Ghostty recovery behavior until a contrary report. This is
  an owner waiver, not a witnessed pass.
- Status is **DONE by owner acceptance**. No push occurred.
