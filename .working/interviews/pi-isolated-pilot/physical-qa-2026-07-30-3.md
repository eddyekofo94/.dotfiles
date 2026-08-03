# Pi physical QA — 2026-07-30, pass 3

## Environment

- Physical Ghostty window in the retained Herdr setup.
- Existing isolated Pi 0.82.1 process reloaded after the interaction-refinement
  files changed.
- Screenshots are preserved under
  `screenshots/2026-07-30-physical-3/`.

## Results

- **FAIL — `/reload` process safety.** Pi exited with an uncaught
  `TypeError`: `stripPaintedCursor is not a function`. The re-evaluated
  `eddy-compat.ts` requested a newly added export from the older cached
  `ui-core.mjs` module.
- **BLOCKED — requested physical interaction checks.** Cursor shape/blink,
  Ctrl-L redraw, and slash ordering could not be exercised because Pi exited.
- **FAIL — immediate relaunch availability.** Two immediate
  `./pi/pilot.sh --name pi-physical-a` attempts reported `pinned FFF package
  verification failed`.
- **FAIL — continued relaunch availability during repair.** A later physical
  retry still hit the same FFF gate while a verifier that had started before
  the isolation change was completing with the already-resolved live state.

Promotion remains blocked.

## Diagnosis

- Pi reloads the extension entrypoint but can retain an already imported ESM
  dependency. New reload-critical exports are therefore unsafe even when a
  fresh-process fixture passes.
- `pi/verify.sh` ran `pi/install.sh` against the same default state used by the
  physical pilot. `npm ci` replaces the verified dependency tree in place, so
  a simultaneous user launch could observe the installation window and fail
  closed. Changing the script could not redirect a verifier process that had
  already sourced the old state path. The tree returned to its exact pinned
  hash after that process ended.

## Selected repair

- Keep all newly introduced cursor/slash helpers in `eddy-compat.ts`, matching
  the established reload-local rule for Ctrl-L and handoff behavior.
- Execute production helper assertions in the real Pi fixture before and after
  `/reload`.
- Run aggregate verification with disposable Pi state. It may reuse the
  checksum-pinned binary but must never reinstall packages in the live physical
  pilot state.

## Post-repair smoke

- No Pi installer or verifier process remained.
- The exact interactive Fish environment resolved the default pilot state and
  verified the pinned FFF source/tree hashes.
- A real Fish PTY started `./pi/pilot.sh --name pi-repair-smoke`, loaded FFF,
  Catppuccin, skills, and extensions, executed `/reload` without crashing,
  restored the `❯` editor/footer, and exited cleanly: **PASS**.

This agent-run smoke removes the launch/reload blocker. It does not replace
Eddy's physical cursor, Ctrl-L, and suggestion-order acceptance.
