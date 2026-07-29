# Herdr Outer Terminal Title Parity

## Goal

Determine whether the retained Herdr v0.7.4 can reproduce tmux's dynamic outer
terminal title (`#S:#I #W`) in Ghostty through a supported Herdr title-template
configuration.

## Exit Criteria

Either:

- identify a supported Herdr v0.7.4 title-template setting and settle an
  evidence-backed implementation and validation plan; or
- prove that Ghostty title propagation is not the blocker and durably classify
  the goal as upstream-limited without custom emulation.

## Scope / Non-goals

- Verify Ghostty title propagation before judging Herdr support.
- Inspect the installed Herdr v0.7.4 binary, its generated default config,
  bundled API schema, tagged source, and official documentation.
- Configure only a documented Herdr title template.
- Preserve Herdr v0.7.4, `pane_history = false`, tmux, all existing dirty work,
  and the current Ghostty configuration.
- Do not add event hooks, polling, plugins, shell-title shims, or other custom
  automation around the one-shot title API.
- Do not upgrade Herdr, commit, push, or change the default multiplexer.

## Decisions

- Classify `herdr-outer-terminal-title-parity` as **upstream-limited** on Herdr
  v0.7.4.
- Do not change `herdr/config.toml` or the live Herdr config. Herdr v0.7.4 has
  no supported title-template configuration key.
- Do not reinterpret `herdr terminal title set/clear` or
  `client.window_title.set/clear` as a title template. They accept a literal
  one-shot string and would require custom event automation to track session,
  tab, and pane changes.
- Reopen this parity goal only if a retained supported Herdr release documents
  a dynamic outer-title template with session/tab/pane fields. An upgrade
  remains separately unauthorized.

## Evidence / Findings

- `tmux/tmux.conf` enables titles and defines
  `set-titles-string '#S:#I #W'`.
- The live terminal stack is Ghostty 1.3.1 and Herdr 0.7.4. The repository and
  live Herdr configs are byte-identical, retain `pane_history = false`, and do
  not contain a title setting.
- A controlled direct Ghostty probe emitted OSC 2 after startup. macOS
  accessibility readback observed the exact unique title
  `GHOSTTY_OSC_TITLE_PROBE_20260729`, proving Ghostty can receive and expose
  application-provided terminal titles.
- In the production `main` Herdr session, forty repeated
  `herdr --session main terminal title set
  HERDR_GHOSTTY_TITLE_PROBE_20260729` calls each reported
  `{"changed":true,"reason":"set"}`, but accessibility readback never exposed
  the probe title. Clearing restored the normal title path.
- A second direct Herdr/Ghostty test used an isolated config and named session
  with the installed v0.7.4 binary. `terminal title set` and `clear` again
  reported `changed: true`; the Ghostty window title remained unchanged.
- `herdr --default-config` contains no outer-title template or title key.
  `herdr api schema --json` exposes only literal
  `client.window_title.set/clear` requests.
- The official v0.7.4 changelog describes `client.window_title.set/clear` as
  supporting plugin host APIs. A search of the complete v0.7.4 tagged source
  found no `title_template` or title-template configuration field; the client
  implementation writes a literal OSC 0 value for the one-shot request.
- Current official configuration documentation likewise lists no outer-title
  template. Newer documentation does not retroactively create a supported
  v0.7.4 configuration surface.

## Tradeoffs / Risks

- A plugin or shell hook could assemble a tmux-like title from API state, but it
  would own event ordering, stale-client handling, sanitization, focus changes,
  and restoration. That is custom emulation, not configuration parity, and is
  explicitly rejected.
- A static literal title would prove only the one-shot API and would lose the
  session/tab/pane identity that makes the tmux title useful.
- The API's `changed: true` confirms dispatch to a foreground Herdr client, not
  successful durable presentation by Ghostty. Physical/readback evidence
  therefore remains the acceptance boundary for any future supported template.

## Validation Plan

No implementation is authorized for v0.7.4. If upstream later adds a supported
template and a separately authorized retained version includes it:

1. confirm the setting in that exact binary's `--default-config` and tagged
   source;
2. validate the proposed config with `herdr config check`;
3. use a direct Ghostty window and accessibility readback to prove the title
   updates across session attach, workspace focus, tab focus/rename, and pane
   focus/rename;
4. confirm `pane_history = false`, tmux availability, and unchanged unrelated
   config hashes;
5. run `./herdr/verify.sh` and `./fish/scripts/verify.sh`; and
6. run fresh Standards and Fidelity review against this record and the actual
   diff.

## Ready To Act

Not Ready — upstream-limited on Herdr v0.7.4. There is no supported title
template to configure, and the permitted scope rejects custom emulation.

## Open Questions

None that change the v0.7.4 classification.
