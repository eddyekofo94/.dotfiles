# Active Goal

`pi-compaction-continuity-fixture` — selected 2026-08-03 when Eddy authorized
continuing the Pi migration. `pi/verify.sh` is red and blocks every other Pi
item, so it is the first slice.

**Diagnosed, not yet fixed.** `pi/tests/session_validation.py:282` fails with
`missing=['pi-global-response-style-parity', '256b38f...', 'canonical
repository', 'concurrency-safe', 'physical-device', 'fresh Standards/Fidelity
review']`. Four of ten sentinels survive.

Cause: the test runs with `cwd=ROOT`, so `loopRecords`
(`pi/extensions/eddy-compat.ts:182`) reads this repository's live
`.working/ACTIVE_GOAL.md`, takes the **first** backticked slug in it, and loads
`.working/interviews/<slug>/decisions.md`. The sentinels were written when
`pi-global-response-style-parity` was the active goal. That goal closed, the
document moved on, and the first slug became
`ready-prompt-parser-relocation` — whose record lives under
`herdr/.working/interviews/closeout-prompt-authoring/`, not
`.working/interviews/`. The lookup misses, `decisions` is empty, and every
sentinel sourced from it disappears. Compaction itself is deterministic and
correct; no model quality is involved.

Two defects, both real:

1. Test: it asserts against mutable repository prose, so closing any goal can
   redden an unrelated gate. Fix is a fixture `.working/` tree so the test
   proves behavior instead of today's content.
2. Product: first-backticked-slug-wins selects a *closed* goal from what is
   effectively a closure log, and the missing decisions file degrades silently
   to "No matching decisions record found". Real continuity loss in daily Pi
   use, not only under test. Fix is to prefer a candidate slug whose
   `decisions.md` exists.

Stop condition: `pi/verify.sh` green, the test independent of which goal is
active, and slug selection covered by a case where the first slug has no
record.

`ready-prompt-parser-relocation` closed 2026-08-02. The shared handoff parser
moved from `tmux/scripts/ready_prompt.sh` to
`herdr/prototype/ready_prompt_parser.sh`; the tmux replay driver, its test
suite, and its `prefix+b` binds are deleted. `prefix+b` and the `ctrl+g` shim
now resolve to one parser. Source:
`herdr/.working/interviews/closeout-prompt-authoring/decisions.md`
("Parser relocation").

**Blocked, pre-existing, not caused by that goal:**
`herdr/prototype/verify.sh` (the deep audit gate, `HERDR_VERIFY_AUDIT=1`) is
red because two goals awaiting Eddy's physical confirmation landed config
changes without regenerating their evidence:

- `herdr-copy-mode-pending-commands` made `copy_mode` an array — assertion
  updated in place.
- `herdr-alt-ctrl-n-new-tab` added a 36th `type = "shell"` binding — count
  assertion updated in place.

Update 2026-08-02, after Eddy authorized bumping all 13 to 0.7.5 and
regenerating: 12 of 13 cleared. Version pins bumped in `verify.sh` and in the
four validators that hardcoded them (`validate_recovery.sh`,
`validate_workspace_navigation.sh`, `validate_picker_reference.sh`,
`validate_capability_gaps.sh`). Also finished the config-shape assertions the
copy-mode and alt+ctrl+n goals left behind: the `copy_mode` array form in
`verify.sh`, `validate_capability_gaps.sh:55`, `validate_picker.sh:280`; the
key count 43->44 in `validate_picker.sh:305`; and the new
`vim_pending_commands` check in the copy-mode gate assertion.

The picker gate is now green too; the audit gate passes end to end. Two picker
findings, both decided by the agent at Eddy's direction:

1. **Test bug, not a product regression.** `overlay_text()` ended the overlay at
   the first bare `└`, and 0.7.5 renders last-child tree rows as `└──`. The
   extractor truncated at the first elbow, hiding every result below it —
   which is why `Beta Project` looked absent. It is present. Terminator changed
   to `┘`, the overlay's actual bottom-right corner.
2. **Accepted rendering change.** 0.7.5 dropped the `→` selection arrow; the
   current pane is marked by the `◆` gutter glyph alone. The assertion now
   checks `◆`. The claim under test is unchanged. Caveat: the highlighted row
   is now conveyed only by reverse video, which the plain-text capture cannot
   see, so that aspect is no longer covered.

`run.sh:44` still pins `version=v0.7.4` for the download
fallback (unused; the source-build binary is preferred) and was left alone
because its `expected_size` would also need updating.

Earlier diagnosis, superseded in part: the gate was mid-migration from 0.7.4 to
0.7.5. The installed binary is 0.7.5 and `verify.sh:852` (tab-lifecycle) was
already bumped, but 13 other assertions still pin `"herdr 0.7.4"` (lines 587,
628, 667, 679, 684, 689, 722, 792, 826, 1085, 1149, 1362, 1425). Clearing the
gate means re-running those 13 validators on 0.7.5 and rewriting 13 dated
evidence records — which `herdr/verify.sh:204-212` warns against, since each is
a record of what was validated on a specific release. **That is Eddy's call,
not mechanical cleanup.**

Operational note: prototype validators must run with the ambient Herdr env
stripped (`clean_multiplexer_env` in `herdr/verify.sh:13`). Without it,
`adaptive_split.sh:22` calls the bare binary, which resolves to the caller's
own session and fails `pane_not_found` — not a live-session requirement, as
first assumed.

Everyday gates are green: `herdr/verify.sh`, `tmux/scripts/verify.sh`,
`~/.config/nvim/tools/verify.sh`, and the 49-case parser suite.

`terminal-cursor-blink-ownership` closed DONE on 2026-08-01. Focus-owned
Herdr blinking passed focused tests, full Herdr/Fish verification, fresh review
at Standards 0 / Fidelity 0, and Eddy's physical multi-window Ghostty
acceptance. Source:
`.working/interviews/fish-vi-cursor-not-blinking/closure.md`.

`fish-prompt-return-latency` closed DONE on 2026-08-01. RubyandRiver stayed at
its exact path; the stale index lock was quarantined recoverably; Git status,
Starship Git presentation, and unchanged `ll --git` are fast. Both prompt
gates, full Fish verification, physical Ghostty, and fresh review passed.

`herdr-alt-ctrl-n-new-tab` closed DONE on 2026-08-03. Eddy physically confirmed
the Ghostty `Left Option+Control+n` chord works. Implementation, automated
evidence, and the Standards 0 / Fidelity 0 review were already complete. Source:
`.working/interviews/herdr-alt-ctrl-n-new-tab/decisions.md` ("Closure").

Awaiting human confirmation: `herdr-copy-mode-pending-commands`, implemented
2026-08-01. Copy-mode counts, `zz`, Esc-discards-pending, and the Alt+/ /
Alt+b / Alt+s keybinding moves passed focused Rust tests, the copy-mode PTY
gate, and full Herdr/Fish verification. Fresh Standards/Fidelity review has not
run. Eddy still owes physical acceptance in a newly created session. Source:
`.working/interviews/herdr-copy-mode-pending-commands/closure.md`.
