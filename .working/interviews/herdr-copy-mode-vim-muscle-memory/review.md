# Fresh Standards / Fidelity Review

## Fixed Point

- Goal: `herdr-copy-mode-vim-muscle-memory`
- Repository HEAD: `439b6bc39b2003ec6f56a32d74f60369bf0d8901`
- Decisions:
  `.working/interviews/herdr-copy-mode-vim-muscle-memory/decisions.md`
- Source base: annotated Herdr `v0.7.4` tag object
  `54208dc16efe15ea92d7f131439d43cbd84b489e`, peeled commit
  `50aaa2ec046ee26ff407c20f49de496f522512a8`
- Standards: repository/global instructions, agentic loop standard, tagged
  upstream `AGENTS.md` and `CONTRIBUTING.md`, and the source-build README/pins.

## Standards

Initial findings:

1. The first installer route authorized the current live digest dynamically,
   which could bless an unrelated predecessor. Fixed by allowing only the
   exact official v0.7.4 digest or the already-reviewed custom digest.
2. Prototype-binary refusal happened after the live binary replacement. Fixed
   by preflighting both destinations before installing the live binary.
3. Installer signal traps could enter cleanup with a successful status. Fixed
   by mapping HUP, INT, and TERM to non-zero exits so replacement rollback
   runs.
4. The new rollback regression fixture did not first force an activation
   failure and then left its directory read-only. Fixed with an accepted
   pre-existing config link, a read-only activation directory, explicit status
   capture, permission restoration, and exact predecessor-hash assertion.
5. The standalone focused validator inherited outer Herdr nesting markers.
   Fixed in the copy-mode-only PTY wrapper and verified over three consecutive
   runs.

Fresh re-review findings: **0**.

## Fidelity

- `a` and `i` share the existing `q` exit-without-copy dispatch.
- `Y` calls the existing whole-line selector and then the existing
  copy-and-exit operation.
- No injected-input emulation is installed.
- The tagged version stays `0.7.4`; exact source, patch, toolchain, patched
  source, and binary hashes enforce provenance.
- `pane_history = false`, recovery behavior, and the tmux fallback remain
  intact.
- `zz` is unchanged and remains outside scope because tagged v0.7.4 has no
  `z`/`zz` copy-mode command.

Fresh re-review findings: **0**.

## Verification

- `./herdr/source-build/build.sh --install`: PASS; formatting, Clippy with
  warnings denied, 41 copy-mode tests, locked release build, binary hash, and
  atomic install passed.
- `./herdr/prototype/validate_copy_mode.sh`: PASS three consecutive runs after
  the final PTY isolation fix; `a`/`i` preserved the clipboard sentinel and
  `Y` copied the exact current line.
- `./herdr/verify.sh`: PASS after all fixes, including source pins, live binary
  hash, installer refusal/rollback, recovery, integrations, prototype, and
  production checks.
- `./fish/scripts/verify.sh`: PASS, including environment/startup audits,
  interactive PTY/tmux, and startup benchmark.
- `python3 -m py_compile herdr/prototype/copy_mode_client.py`: PASS.
- `sh -n` on the goal's shell scripts: PASS.
- `git diff --check`: PASS.
- `shellcheck`: not run because it is not installed.

## Summary

- Standards: **0 findings after fixes**
- Fidelity: **0 findings after fixes**
- Remaining gate: physical `Prefix+s` then `a`, `i`, and `Y` acceptance in a
  newly created Herdr session.
