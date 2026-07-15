# Fish workflow loops

Keep each pass limited to one startup, prompt, completion, or interactive
behavior. Before editing, record `git status --short -- fish` and a baseline for
the exact symptom.

For performance or process-lifecycle bugs, measure fresh-shell timing and RSS,
then exercise the relevant prompt or event hook repeatedly. A fix is complete
when `fish/scripts/verify.sh` passes and the original measurement no longer
reproduces the regression.

`fish/tests/fif_integration.sh` is the regression seam for find-in-files query
gating, opt-in symlink traversal, preview isolation, and temporary-state cleanup.

Interactive behavior still requires the checks in `fish/MANUAL_QA.md`. Leave
the result awaiting user confirmation when terminal rendering or perceived
responsiveness cannot be proven automatically.
