# Fish workflow loops

Keep each pass limited to one startup, prompt, completion, or interactive
behavior. Before editing, record `git status --short -- fish` and a baseline for
the exact symptom.

For performance or process-lifecycle bugs, measure fresh-shell timing and RSS,
then exercise the relevant prompt or event hook repeatedly. A fix is complete
when `fish/scripts/verify.sh` passes and the original measurement no longer
reproduces the regression.

Fish startup consumes prepared state. Run `fish/scripts/refresh_startup.fish`
after installing or upgrading Homebrew, Fisher plugins, Zoxide, Starship, Java,
or Vivid, or after changing managed configuration links. Installation, cache
generation/expiry, symlink creation, and Git configuration do not belong in
`conf.d` or `config.fish`. `fish/scripts/audit_startup_ownership.sh` enforces
that boundary, and `fish/scripts/benchmark_startup.py` enforces the 30-run
median <=40 ms and p95 <=55 ms target.

`fish/scripts/audit_environment.sh` is the regression seam for deterministic
XDG/application variables, valid Java and Vivid output, optional environment
sources, universal-state leakage, and duplicate or nonexistent
configuration-owned PATH entries. Machine-derived environment belongs in
checked-in global configuration, not `fish_variables`.

`fish/tests/fif_integration.sh` is the regression seam for find-in-files query
gating, opt-in symlink traversal, preview isolation, and temporary-state cleanup.
`fish/tests/fzf_preview_integration.sh` is the regression seam for shared file
picker routing and tmux-safe image output in `fe`, Ctrl-T, and related pickers.
`fish/tests/interactive_consumer_pty.sh` and
`fish/tests/interactive_consumer_tmux.sh` run directly and through an isolated
tmux server, proving that the retained picker receives its exact pane geometry
and returns text and image selections through real control bytes.

Interactive behavior still requires the checks in `fish/MANUAL_QA.md`. Leave
the result awaiting user confirmation when terminal rendering or perceived
responsiveness cannot be proven automatically.
