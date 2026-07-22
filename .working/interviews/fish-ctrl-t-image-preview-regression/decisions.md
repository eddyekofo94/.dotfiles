# Fish Ctrl-T Image Preview Regression

## Goal

Restore the configured image previewer for PNG and other supported image files
opened through the retained `fzf.fish` `Ctrl-T` directory picker.

## Exit Criteria

- `Ctrl-T` continues to invoke `_fzf_search_directory` in default and insert
  modes.
- Regular image files selected through that picker route to canonical
  `_fzf_preview`, not `bat`.
- Text and directory preview behavior remains intact, `Ctrl-P` retains the same
  picker, and generated native FZF ownership remains absent.
- The exact BibleStandard PNG reproduction, deterministic FZF integration, full
  Fish verification, live PTY image-path validation, and fresh
  Standards/Fidelity review pass.

## Scope / Non-goals

In scope: the adapter between the legacy `fzf.fish` file dispatcher and the
canonical `_fzf_preview` implementation, directly impacted regression coverage,
live PTY validation, Fish verification, and workflow records.

Non-goals: restoring generated `fzf --fish` bindings, changing the `Ctrl-T` or
`Ctrl-P` picker, redesigning preview layout, Herdr image transport, unrelated
Fish/Herdr/tmux/Zsh work, commits, pushes, or publication.

## Decisions

- The expected behavior is the screenshot's former behavior: supported images
  use Eddy's canonical image previewer inside `Ctrl-T`.
- Keep `fish_user_key_bindings.fish` as the sole FZF binding owner.
- Prefer the existing `fzf.fish` adapter variable
  `fzf_preview_file_cmd` to connect `_fzf_preview_file` to canonical
  `_fzf_preview`; do not duplicate extension routing or restore the native
  widget.
- Regression coverage must invoke `_fzf_preview_file` with an image after
  loading `_fzf_envs.fish`. Testing `_fzf_preview` directly is insufficient
  because it bypasses the failed dispatcher.

## Evidence / Findings

- User screenshot on 2026-07-22 shows `Ctrl-T` correctly opening `Directory>`
  in BibleStandard, selecting `Sources/App/Resources/app_icon_87.png`, and the
  preview pane rendering `[bat warning]: Binary content`.
- The exact PNG is `image/png`. A sub-second reproduction invoking
  `_fzf_preview_file` emits `Binary content from file` and exits the focused
  regression check 1.
- `_fzf_search_directory` hardcodes `_fzf_preview_file {}` for its ordinary
  file route. `_fzf_preview_file` calls `bat` whenever
  `fzf_preview_file_cmd` is unset; the live variable is currently unset.
- Canonical `_fzf_preview` already recognizes `.png` and routes it through
  kitten/icat with the established chafa/file fallbacks.
- Differential probe against the exact PNG:
  - legacy `_fzf_preview_file`: 322 bytes, bat warning present;
  - canonical `_fzf_preview`: 8,271 bytes, bat warning absent;
  - legacy dispatcher with temporary `fzf_preview_file_cmd=_fzf_preview`:
    8,268 bytes, bat warning absent.
- Before the startup cleanup, generated `fzf --fish` owned `Ctrl-T` through
  `fzf-file-widget`; `FZF_CTRL_T_OPTS` explicitly used `_fzf_preview {}`. The
  cleanup correctly removed that competing owner, and the completed Ctrl-T
  binding goal mapped the key to retained `fzf.fish`, exposing its unconfigured
  legacy file dispatcher.
- The existing FZF integration test rendered a PNG by calling `_fzf_preview`
  directly, so it could pass while the actual `Ctrl-T` dispatch path remained
  broken.

## Ranked Hypotheses And Results

1. **Confirmed:** retained `_fzf_search_directory` bypasses canonical image
   routing through an unconfigured legacy dispatcher. Prediction: direct legacy
   invocation warns, while setting its documented adapter to `_fzf_preview`
   removes the warning. Exact differential passed.
2. **Contributing condition:** `fzf_preview_file_cmd` was expected to bridge the
   dispatcher but is unset. Prediction: runtime provenance shows no value and a
   temporary value repairs the exact path. Confirmed.
3. **Falsified:** canonical extension detection no longer recognizes PNG.
   Prediction: `_fzf_preview` would also warn or fall through to text. It emits
   the image payload instead.
4. **Falsified:** tmux/Ghostty image transport is the primary failure.
   Prediction: the route would reach kitten/chafa before failing. The observed
   warning is emitted earlier by `bat`, and canonical rendering succeeds in the
   deterministic transport harness.

## Tradeoffs / Risks

- Connecting the documented file adapter affects every regular file routed
  through `_fzf_preview_file`, including the shared `Ctrl-P` picker and
  untracked-file fallbacks. Deterministic coverage must therefore prove text as
  well as image behavior.
- A shallow test of FZF variables or canonical preview output can miss this
  exact dispatcher regression again.
- Pixel quality and cleanup in the actual terminal remain live validation
  requirements even after deterministic output is correct.

## Validation Plan

- Add a focused red/green assertion at the real `_fzf_preview_file` seam using
  a PNG fixture after sourcing `_fzf_envs.fish`; reject any `Binary content`
  warning and require the established bounded image payload.
- Preserve existing text, directory, `Ctrl-T`/`Ctrl-P`, Ctrl-U, preview paging,
  and sole-owner assertions.
- Run `fish/tests/fzf_preview_integration.sh` and
  `fish/scripts/verify.sh`.
- In a real terminal/tmux PTY, press `Ctrl-T`, select a PNG, and confirm the
  image previewer renders without a bat warning or stale image residue.
- Run scoped `git diff --check` and fresh Standards/Fidelity review after the
  final change; fix and re-review until clean.

## Ready To Act

Resolved by the authorized `fish-regression-audit` goal on 2026-07-22.

## Closure Evidence

- `_fzf_preview_file` now invokes canonical `_fzf_preview` through the retained
  adapter without `eval`; quote/metacharacter filenames cannot execute Fish
  source.
- Image, text, directory, malicious-filename, Ctrl-P selection, Ctrl-T
  selection, and Kitty transport paths have deterministic or live PTY coverage.
- Exact BibleStandard `app_icon_87.png` dispatch passed with a 19,462-byte Kitty
  payload and no bat warning.
- Full Fish verification passed (29.788 ms median / 31.844 ms p95), followed by
  fresh Standards 0 / Fidelity 0 review.

## Open Questions

None.
