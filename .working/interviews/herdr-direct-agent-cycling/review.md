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
movement. Cross-session cycling and sidebar rendering remain excluded.

## Summary

Standards findings: 0. Fidelity findings: 0. The focused and prototype gates
pass after the final change. The production aggregate gate is explicitly build-local and cannot complete
against an unmerged named worktree because installed config/hook symlinks target
the shared checkout. Its unchanged-`main` integration subgate is independently
red because Pi reports `outdated (v5 < v8)`. No verifier weakening or external
integration overwrite was accepted. Physical Ghostty acceptance remains manual.
