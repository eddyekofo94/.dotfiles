# Pi physical acceptance diagnosis — 2026-07-30

## Trigger

The physical Ghostty pass showed two failures:

1. Pi displayed a static painted cursor even though Ghostty was configured to
   blink.
2. After `/reload`, Ctrl-L raised
   `clearScreenSequence is not a function` instead of clearing and redrawing.

The same pass also raised two separate requests: frequency-ranked slash
commands and Xcode 27.

## Selected scope

Fix the cursor and post-`/reload` Ctrl-L regressions inside the active
`pi-isolated-pilot` goal. Do not install Xcode, Pi MCP, or iOS packages in this
slice. Keep slash-command frecency as investigated feature intake because it is
not supplied by FFF's file index.

## Reproduction

- Screenshot: physical Pi session after `/reload`, then Ctrl-L, showing the
  shortcut-handler exception twice.
- `node pi/tests/compat_core_test.mjs`: RED because Ctrl-L depended on an
  imported helper instead of the hot-reloadable extension entrypoint.
- `./pi/tests/theme_ui_test.sh`: RED because the pilot did not enable Pi's
  hardware cursor.

## Ranked hypotheses

### Ctrl-L

1. **Stale imported ESM helper after `/reload`.** If correct, keeping the ANSI
   sequence in the re-evaluated entrypoint removes the error without requiring
   a process restart.
2. **Reload replaces the custom editor before new shortcut delegation is
   wired.** If correct, reinstalling the editor after the reload task completes
   restores Ctrl-L and other app shortcuts.
3. **Repository and installed extension differ.** If correct, the live settings
   link or installed source hash differs from the repository.
4. **The old shortcut handler remains registered.** If correct, only restarting
   Pi, rather than reloading, repairs the failure.

The screenshot's `undefined` imported binding and the existing documented Pi
reload boundary support hypothesis 1. A fresh-process `/reload` integration
then showed the newly installed editor lost Ctrl-L completely. Pi resets
extension UI before `session_start`, but only wires the replacement extension
shortcuts after `session_start` returns, confirming hypothesis 2. The pilot
uses repository-linked settings/extensions, falsifying hypothesis 3.

### Cursor

1. **Ghostty blinking is disabled.** Falsified: resolved Ghostty 1.3.1 config
   reports `cursor-style-blink = true`.
2. **Herdr suppresses cursor blinking.** Falsified by Pi's own terminal
   documentation and settings surface.
3. **Pi hides the hardware cursor and paints a static fake cursor.** Confirmed:
   Pi 0.82.1 defaults `showHardwareCursor` to false and documents the static
   fake-cursor behavior.

## Fix and prevention

- Keep `CLEAR_SCREEN_SEQUENCE` in `eddy-compat.ts`, matching the existing rule
  for reload-sensitive handoff behavior.
- Reinstall the custom editor on the next task after `/reload`, after Pi wires
  the replacement extension shortcuts.
- Own Ctrl-L directly in the editor rather than Pi's reload-fragile extension
  shortcut bridge.
- Enable `showHardwareCursor` only in the isolated Pi pilot; Ghostty's existing
  blink policy remains authoritative.
- Regression tests fail if Ctrl-L is moved back behind a reload-stale import or
  if hardware-cursor visibility is removed.
- The post-reload Herdr fixture now starts Pi from the repository root before
  asserting FFF `@pi/settings` completion. This exposed and removed a false
  empty-index diagnosis caused by the disposable pane starting from `$HOME`;
  a native create/destroy/recreate finder test separately protects the FFF
  reload lifecycle.

## Stop condition

Focused and aggregate Pi verification plus fresh Standards/Fidelity review
pass. Physical Ghostty confirmation remains required for visible blinking and
Ctrl-L after `/reload`.
