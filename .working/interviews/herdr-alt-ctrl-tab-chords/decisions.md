# Herdr Alt-Ctrl Tab Chords

Status: DONE 2026-08-12 — chords implemented, physically accepted, and
`herdr/prototype/verify.sh` green end to end.

Supersedes the chord choice in
`.working/interviews/herdr-alt-ctrl-n-new-tab/decisions.md`.

## Settled contract

- Trigger: Eddy requested the rebind on 2026-08-12.
- `Alt-Ctrl-t` creates a tab (moved off `Alt-Ctrl-n`), keeping the existing
  cwd-following `new_tab.sh` behavior unchanged.
- `Alt-Ctrl-n` / `Alt-Ctrl-p` step to the next / previous tab.
- Next/previous are added to the native `next_tab` / `previous_tab` key arrays,
  not to a shell command binding: the built-in already wraps, and a native
  binding cannot drift from `Prefix+n` / `Prefix+p`.
- Herdr owns all three chords globally. They are deliberately not routed
  through `smart_action.sh`: tab movement means one thing in every app,
  including Neovim.
- Preserve native `Prefix+c` / `Prefix+n` / `Prefix+p`.
- Preserve plain `Alt-t`; it stays application-owned and unbound in Herdr.
- Preserve every unrelated Herdr, Fish, Neovim, tmux, and Ghostty binding.
- Do not commit or push.

## Stop condition and validation

- Live and prototype configs validate.
- `validate_tabs.sh` drives the Kitty CSI-u transports `116;7u` (create),
  `110;7u` (next), and `112;7u` (previous) and proves one focused cwd-following
  tab plus a correct two-tab cycle.
- `Alt-t` (`116;3u`) still creates and focuses no Herdr tab.
- `herdr/prototype/verify.sh` and `herdr/verify.sh` pass.
- Eddy physically presses the three chords in Ghostty and confirms.

Follow-on, same day: `Alt+Ctrl+Left` / `Alt+Ctrl+Right` were added as arrow
aliases for previous / next, mirrored into the prototype config.

## Automated evidence

- Focused live chord probe on the reviewed build, disposable session, real
  Kitty CSI-u transports: `alt+ctrl+t` created and focused one tab; `alt+ctrl+n`
  stepped forward and wrapped; `alt+ctrl+p` stepped back; `alt+t` changed
  neither tab count nor focus; `prefix+c/n/p` unchanged. PASS.
- `herdr/verify.sh` (production gate): PASS, after the live reload.
- Live config reloaded via `herdr/reload.sh` on reviewed 0.7.5.
- Every config-hash-pinned prototype validator re-run green: bindings, popups,
  layout menu, utilities, copy mode, urls, remote, capability gaps, recovery,
  workspace navigation, panes, agent overview, picker reference, agent states,
  ready prompt, login attach, picker.
- `herdr/prototype/verify.sh`: RED, on `tab-lifecycle-validation.jsonl` only.
- No commit or push.

## Physical acceptance (Eddy, 2026-08-12)

Eddy pressed the chords in Ghostty and confirmed all five behave as settled:
`Alt+Ctrl+t` new tab, `Alt+Ctrl+n` / `Alt+Ctrl+p` next / previous,
`Alt+Ctrl+Left` / `Alt+Ctrl+Right` previous / next. The human gate is closed;
the chord contract is accepted as shipped behavior.

## Gate takeover, 2026-08-12

The numbered-tab blocker below is **cleared**. `validate_tabs.sh` now proves the
positional contract instead of create-on-miss: `prefix+7` against four tabs is a
silent no-op (count, tab-id list, and focus all unchanged, no tab created), and
`prefix+4` / `prefix+1` focus positions 4 and 1. The evidence check renamed
`numbered_create` -> `numbered_noop`; `verify.sh`'s `.[5]` assertions were
rewritten to match.

Arrow-alias transport coverage landed: `tab_client.py` gained `\e[1;7C` /
`\e[1;7D`, `validate_tabs.sh` drives them from a known-different focus (so a
dead binding fails rather than passing vacuously), and the `alt_new_tab` record
carries a new `arrow_cycle` block asserted in `verify.sh`.

`validate_tabs.sh`: PASS, tab-lifecycle evidence regenerated. `validate_panes.sh`
re-run and regenerated too, because `verify.sh:1022` hash-pins `tab_client.py`
into the pane-lifecycle evidence.

## Cleared blocker: multi-agent gate (independent of this goal)

`herdr/prototype/verify.sh` went RED on `multi-agent-compat-validation.jsonl`
once the tab-lifecycle fix stopped `set -e` from aborting the gate first.
`validate_multi_agent_compat.sh` exited 4 at the first lifecycle snapshot
(`claude` / `running` / `working`): after `semantic_agent_state.py hook`, the
pane readback carried `state_labels: null, tokens: null`, so
`pane report-metadata` was failing silently — the hook swallows every error by
design ("Agent hooks must never interrupt the agent itself") and delegates
fail-closed to exactly that readback.

**Source identity was not the cause; `--applies-to-source` was a red herring.**
Reproducing the hook's own `report-metadata` invocation against a live prototype
session surfaced the real error:

```text
{"error":{"code":"pane_not_found","message":"pane w1:p1 not found"}}   exit 1
```

`semantic_agent_state.py::report_metadata` built its command as bare
`herdr pane report-metadata …` with no `--session`. A pane id is only unique
within its session, so the request landed on the default session and failed
closed. Every validator's `cli` wrapper passes `--session`; the hook was the one
caller that did not, and exporting `HERDR_SESSION` does not reach the CLI.

Fix, one owner: `report_metadata` now prepends `--session "$HERDR_SESSION"` when
that variable is set, matching the established idiom in
`fixtures/pane_transfer_picker_fixture.sh`. Herdr injects `HERDR_SESSION` into
every pane, so production hooks target the right session too.

The same defect had been silently reddening `validate_agent_states.sh`; it was
green in recorded evidence only because that evidence predated the regression.
Both validators pass on the fix.

Also regenerated on the way through: `agent-overview-validation.jsonl`, whose
recorded `production_config` hash (`ea206a09…`) was stale against the current
`herdr/config.toml` (`55db975c…`).

Proven independent of the chords before the fix: the validator failed
identically (exit 4) with `git show HEAD:herdr/prototype/config.toml` swapped
into the working tree, and none of its inputs (`picker_client.py`,
`semantic_agent_state.py`, `tmux/scripts/agent_status.py`) is touched by this
goal. Working tree restored, hash-verified.

## Superseded blocker (cleared 2026-08-12)

`validate_tabs.sh` cannot regenerate tab-lifecycle evidence: a concurrent
session reworked `numbered_tab.sh` to be purely positional (never creates a
tab), and the gate still asserts the retired create-on-miss behavior at
`validate_tabs.sh:242` ("missing numbered tab creation", expects 5 tabs). That
session owns the fix. Once it lands, re-run `validate_tabs.sh` and
`herdr/prototype/verify.sh` — the `.[10]` assertions are already updated for the
new chords.

Re-checked 2026-08-12: still blocked. `numbered_tab.sh` is purely positional
("It never creates a tab", and a digit past the tab count is a silent no-op),
but `validate_tabs.sh:242` still runs `wait_for "missing numbered tab creation"
tab_count_is 5` and the `numbered_create` record at :251 still asserts a created
`label == "7"` tab. Both gates therefore stayed unrun; the fix remains owned by
the concurrent session that reworked `numbered_tab.sh`.

Note: both gates must run outside a Herdr pane, or with the multiplexer env
cleared (`env -u HERDR_ENV -u HERDR_PANE_ID …`), exactly as
`herdr/verify.sh`'s `clean_multiplexer_env` does. Nested attach is refused and
a leaked `HERDR_PANE_ID` points the gate's scripts at the wrong pane.

## Open gates

- ~~Physical Ghostty confirmation of `Left Option+Control+t/n/p` and the
  arrows.~~ Closed 2026-08-12.
- ~~Arrow-alias transport coverage in `validate_tabs.sh` (`\e[1;7C` /
  `\e[1;7D`).~~ Landed 2026-08-12.
- ~~`herdr/prototype/verify.sh` green, blocked on the independent multi-agent
  gate failure above.~~ Closed 2026-08-12:
  `env -u HERDR_ENV -u HERDR_PANE_ID sh herdr/prototype/verify.sh` → exit 0,
  "Herdr prototype verification: PASS".

No open gates. Nothing committed or pushed.
