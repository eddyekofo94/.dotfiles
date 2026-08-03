# Pi physical QA — 2026-07-30, pass 2

## Environment

- Physical Ghostty 1.3.1 window inside the retained Herdr setup.
- Isolated Pi 0.82.1 pilot started from `/Users/eddyekofo/.dotfiles`.
- Evidence is preserved under
  `.working/interviews/pi-isolated-pilot/screenshots/2026-07-30-physical-2/`.

## Results

- **FAIL — Ctrl-L after `/reload`.** Pi printed `Viewport cleared`, then left a
  blank viewport with only a hardware cursor at the upper left. It did not
  reliably redraw the `❯` editor and footer. The expected redraw is preserved
  separately for comparison.
- **FAIL — cursor presentation.** The focused editor showed Pi's filled,
  reverse-video block combined with the hardware cursor. Eddy requires one
  stable-color blinking hardware cursor: bar while the Pi prompt owns focus,
  blinking block outside the prompt, and the terminal's outline cursor when
  the Ghostty surface is unfocused.
- **FAIL — slash suggestion order.** Typing `/re` selected `/resume` ahead of
  the just-used `/reload`. The selected contract is most-recent command first;
  among the remaining used commands, higher frequency wins, then recency.
- **PASS — `/tree` opens.** The session tree rendered the three recorded
  entries and footer. Branch navigation/return behavior remains covered by the
  broader manual checklist rather than this screenshot alone.
- **PASS — Ctrl-Shift-M opens the model picker.** Ordinary Enter was not
  remapped by the shortcut. The provider refresh timed out and Pi displayed
  cached models; that network refresh warning does not invalidate shortcut
  delivery.

Promotion remains blocked by the Ctrl-L, cursor, and slash-order failures.

## Root-cause evidence

- Pi 0.82.1's `TUI.requestRender(true)` explicitly resets cached viewport
  geometry and forces a full redraw. The pilot's Ctrl-L path externally erased
  the terminal but requested only an ordinary cached render.
- Pi's `showHardwareCursor` setting shows the terminal cursor at
  `CURSOR_MARKER`, but deliberately leaves the editor's reverse-video fake
  cursor in the rendered line. Both were visible at once.
- Pi's native `CombinedAutocompleteProvider` uses static fuzzy ordering. FFF
  wraps `@file` completion and does not rank slash commands.
