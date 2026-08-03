# New-Window Root CWD Diagnosis

Date: 2026-07-29

## Observation and Reproduction

Eddy's physical `Command-N` retest showed an independent Herdr window whose
only pane was an idle Fish shell at filesystem root `/`.

The focused regression is:

```sh
./herdr/prototype/validate_login_attach.sh
```

It launches the real Fish login adapter from `/`, records the cwd received by
the Herdr fixture, and requires `$HOME`. Before the fix it exits 1 with observed
cwd `/` and expected cwd `/Users/eddyekofo`.

Live evidence also showed retained session `window-3` was created at 13:15 with
one pane whose `cwd` and `foreground_cwd` are both `/`. Ghostty's effective
configuration already has `window-inherit-working-directory = true`; Herdr has
`terminal.new_cwd = "follow"`.

## Ranked Hypotheses

1. The top-level Fish login inherits Ghostty's outer tracked cwd `/`, and the
   adapter passes it unchanged into creation of a new named Herdr session.
   Prediction: normalizing only `/` to `$HOME` immediately before `exec herdr`
   makes the focused fixture green and makes a newly created physical session
   start at home.
2. Herdr ignores the client's launch cwd when creating a named-session root
   pane. Prediction: the fixture becomes green but a fresh disposable/physical
   named session still reports `/`.
3. Ghostty working-directory inheritance is disabled. Prediction: its effective
   configuration reports the inheritance setting false. This is falsified:
   effective configuration reports true.
4. The screenshot only reflects recovery of a previously created root-cwd
   session. This explains why `window-3` remains at `/`, but not why the
   original session was created there; the red isolated adapter reproduction
   proves the missing guard independently.

## Expected Behavior

- This original decision preserved a meaningful cwd and fell back from `/` to
  `$HOME`. Eddy's later lifecycle clarification supersedes it for automatic
  New Window: every automatic launch changes to `$HOME`, while restored Herdr
  panes retain their own persisted cwd.
- Do not change explicit recovery semantics or rewrite the cwd of an existing
  retained session.
