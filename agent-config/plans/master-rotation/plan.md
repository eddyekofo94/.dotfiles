# Master rotation guard (retro ios-2026-11-13, finding 1)

Goal: a master tab never runs past 8 compactions; it hands off and a fresh master takes the seat.
Package: none (stdlib Python + the herdr CLI already used by ensure_master.sh).

- [ ] 1. `agent-config/claude/master_rotation.py count` (PreCompact hook, master role, main session only):
      counts compactions per session in `agent-config/master/state/<session>.count`.
      Proof: test — 7 compactions stay quiet, the 8th prints the rotate order and arms `<session>.armed`.
- [ ] 2. `... resume` (SessionStart `compact`): when armed, inject "rewrite master/handoff.md, run `rotate`, stop".
      Proof: test — armed injects, unarmed and non-master stay silent.
- [ ] 3. `... rotate`: refuses unless handoff.md is newer than the arming; renames this tab
      `master-prev`, creates the new tab labelled `✻ master`, runs the launch line.
      Proof: test with a fake herdr binary — stale handoff refused, fresh handoff makes the 3 calls in order; `--dry-run` prints them.
- [ ] 4. Wire both hooks in `claude/settings.json`; add one line to `master/SKILL.md` Rules.
      Proof: settings test (JSON parses, hook commands exist).
- [ ] 5. Run all tests, commit path-limited, push.
