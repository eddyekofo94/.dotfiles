# Fresh Standards and Fidelity Review

Date: 2026-09-12
Baseline: `71d51e9be5956f8cd52227d78a3626568c8434a7`
Spec: `.working/interviews/herdr-direct-agent-cycling/decisions.md`
Brief: `.working/interviews/herdr-direct-agent-cycling/implementation-brief.md`

## Standards

Findings: 0.

The implementation consumes native CLI order without sorting, revalidates the
session-scoped terminal/pane/agent identity before focus, delegates focus to
Herdr, and avoids a private source patch. The named-worktree trial fix prevents
tests from silently executing shared-checkout helpers. No applicable baseline
code smell remains.

## Fidelity

Findings: 0.

The isolated four-tab fixture proves three ordered agent rows, one skipped
non-agent tab, next/previous movement, both wraps, directional entry from the
non-agent tab, exact Kitty CSI-u transport, and preserved `Ctrl+Alt+h/l` tab
movement. The merged-checkout popup evidence was regenerated and the aggregate
prototype gate passes. Cross-session cycling and sidebar rendering remain
excluded.

Physical Ghostty acceptance: PASS 2026-09-12. Eddy reported that the installed
feature works well and according to the requested behavior.

## Summary

Standards findings: 0. Fidelity findings: 0. The focused, merged-checkout
prototype, and source-build gates pass after the final change. The implementation
is locally merged, installed, and reloaded without a push. Full build-local
`herdr/verify.sh` reaches the unchanged external integration audit and stops
because the separately managed Pi integration reports `outdated (v5 < v8)`.
No verifier weakening or external integration overwrite was accepted. Eddy's
physical Ghostty acceptance passed on 2026-09-12.
