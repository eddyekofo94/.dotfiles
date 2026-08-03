# Cross-Session Agent Overview — Fresh Review

Date: 2026-07-29

## Standards

Initial findings:

1. Unicode backspace could leave the leading byte of a multibyte UTF-8
   character in the composer.
2. Hash-bound feature evidence did not include its validator.

Fixes:

- composer deletion now removes the complete final Unicode code point, with
  ASCII, accented, CJK, and emoji regressions;
- aggregate evidence now binds the current overview helper, composer, fixture,
  validator, production config, and prototype config.

Fresh re-review: 0 findings.

## Fidelity

Initial finding:

1. The default `less` read view did not make bare Escape return to the agent
   list as settled.

Fix:

- the palette supplies an isolated lesskey source mapping bare Escape to quit;
- a PTY regression proves Escape exits the read view.

Physical QA finding:

1. Herdr delivered Escape to `less` as Kitty CSI-u (`ESC[27;5;27~`), so the
   bare-Escape fix returned to the palette but leaked the encoded bytes into
   the fzf query.

Fix:

- the isolated lesskey source consumes both bare Escape and Herdr's Kitty
  CSI-u Escape encoding;
- the PTY regression now exercises both encodings;
- physical retest returned to an unchanged two-row palette.

Final fresh re-review: 0 findings.

## Summary

Standards findings: 0. Fidelity findings: 0. The implementation and physical
QA are complete. Full Herdr/Fish verification and affected deterministic
validation pass after the final fix, and both review axes are clean against the
final files.
