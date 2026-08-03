# Pi Isolated Pilot — Implementation Brief

## Source

- `.working/interviews/pi-isolated-pilot/decisions.md`
- `docs/research/pi-coding-agent-migration-2026-07-29.md`

## Active Scope

Implement one reversible Pi 0.82.1 pilot:

1. Pinned checksum-verified installation and isolated launcher.
2. Curated shared skills and a minimal `$skill-name` compatibility extension.
3. Named-session, recovery, compaction-continuity, measurement, and rollback
   validation.
4. Herdr managed integration, cross-session overview, and `Prefix+b/B` parity.
5. Interaction polish: Catppuccin Mocha, an editor `❯`, durable
   current-branch prompt history on Ctrl-P/Ctrl-N, and pinned FFF-backed `@`
   mention autocomplete; Ctrl-Shift-M opens model selection and Ctrl-L
   clears/redraws the viewport with the editor/footer visible and without
   changing session history or unsent editor text.
6. Full project verification and fresh two-axis review.

## Non-goals

- Default-agent promotion.
- Codex/Claude removal or behavior changes.
- General MCP, subagent, or background-job implementation.
- Third-party Pi packages other than the explicitly selected and pinned
  `@ff-labs/pi-fff@0.10.1`.
- Commit, push, or publication.

## Implementation Seams

- New repository-owned `pi/` pilot configuration, launcher, extension, tests,
  evidence, and rollback tooling.
- Existing Herdr process recognition and ready-prompt replay.
- Existing Herdr agent integration and overview validation.
- Existing Fish/Herdr aggregate verification.
- Pi's custom theme, `CustomEditor`, session branch reconstruction, and
  interactive TUI suspension APIs.

## Stop Condition

The automated gates, provider comparison, and physical Herdr QA prove the exit
criteria; the Pi editor visibly uses Catppuccin Mocha and `❯`; prompt history
survives reload/resume/tree navigation; FFF health and fuzzy `@` completion are
proven in the isolated pilot; rollback is demonstrated; and
fresh Standards/Fidelity review has zero findings. If physical interaction
cannot be completed without Eddy, leave only that exact gate open and do not
promote Pi.

## Baseline

Pre-existing dirty work is excluded from this goal except where explicitly
listed as an implementation seam. Before implementation, the relevant file
hashes were:

```text
2bad340d9085442c5cea46622eb87a62a850ca227a18cedc9663d624f7690cbe  herdr/config.toml
f5efa74864757cdf10c00ed43c4391b58b22a8e43dfb53fce9a4c81c32861302  herdr/prototype/ready_prompt.sh
ec0e1a88b58bdf58438cc9c5bdc16d548133c1a36950977deb4b198d2dfba220  herdr/prototype/validate_ready_prompt.sh
f6373dd24cb6a5beae254770e9b8b48ed243888c74910f7f65bb8d6d94697f2d  herdr/prototype/agent_overview.sh
a394a5d9aec51878c82cf41d33de7e20355421ad7e3f0bcde9aea20a923e01f7  herdr/prototype/validate_agent_overview.sh
4fda38f7c5c9ce53c1b449c081ac0d6b8b6d7ca2a963c704c6cf92d7f5395e52  herdr/verify.sh
56929d6ea4a9ef1ffc00f445323535f926f6872a67b756ee62dda171224eef20  fish/scripts/verify.sh
7565117256e3a1d19bbba4c5b3aaa2d0939f12cdbe8929648419fc2032d2ecda  tmux/scripts/ready_prompt.sh
8fb15b79d312ba9f495f131ec91be25690c2d49af25f57f8187983163336c3dd  tmux/tests/ready_prompt_test.sh
```

## Validation

Use the exact validation plan in the decisions record. Preserve raw evidence
under `pi/evidence/` and record manual gates honestly.
