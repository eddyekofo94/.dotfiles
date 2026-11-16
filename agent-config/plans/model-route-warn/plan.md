# model_route_warn: UserPromptSubmit warning for a live Opus / high-effort tab

Why: tab 51c208ba switched in-session (/model, /effort) to Opus high outside /build and /spec
(16.5M tokens, retro ios-2026-11-16). tab_launch_guard.py sees launches only.

Design
- claude/model_route_warn.py, UserPromptSubmit, main sessions only (no agent_id).
- Live state: last assistant line in the transcript tail: message.model, `effort`.
- Exempt tab: `<command-name>/build` or `/spec` (or a prompt starting `/build`/`/spec`) in the transcript head or tail.
- Warn when model is Opus, or effort is high/xhigh/max, and the tab is not exempt.
  One line, once per (model, effort) state per session (marker in $TMPDIR/claude-model-route-warn).
- Fable (master/Eddy tabs) only warns on effort. `HERDR_ALLOW_HIGH=1` in env silences it. Any error exits 0.
- Registered in claude/settings.json UserPromptSubmit (only my hunk is staged; the file has other dirt).

Proof
1. tests: Opus outside build warns; Opus in /build silent; Sonnet medium silent; effort high warns;
   same state warns once; /spec exempt; subagent skipped; garbage transcript silent.
2. run `python3 claude/tests_model_route_warn.py`.
