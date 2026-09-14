# Global Agent Configuration

`agent-config/AGENTS.md` is the single canonical global rule source.

- Codex: `~/.codex/AGENTS.md` symlinks directly to it.
- Codex: `~/.codex/config.toml` symlinks to the tracked personal configuration
  at `agent-config/codex/config.toml`.
- Codex: optional integrations are disabled in the base config. Start a
  deliberate capability session with `codex --profile browser`,
  `computer-use`, `design`, `docs`, `ios`, `office`, or `sites`.
- Codex: the base catalog keeps the six routine workflow skills visible.
  `$name`, `/name`, and `/skill:name` load every other validated top-level
  shared skill through the prompt hook without adding its description or body
  to startup context.
- Claude: `~/.claude/CLAUDE.md` symlinks a one-line supported import adapter
  that points at it.
- Claude: the same six workflow skills remain model-visible; every other
  validated top-level shared skill is `user-invocable-only` and loads when
  explicitly selected.
- Pi pilot: `$PI_CODING_AGENT_DIR/AGENTS.md` symlinks to `pi/AGENTS.md`, a
  compat symlink the pilot's own scripts read; `pi/AGENTS.md` itself symlinks
  to `agent-config/AGENTS.md`, so there is still exactly one file to edit.
- Claude's prompt hook extracts the response/closeout sections from that same
  source; it does not maintain another rule copy.

`~/.claude/settings.json` is a managed link too, because the closeout scripts do
nothing until its hook entries register them. Claude Code and
`herdr integration install` rewrite that file in place rather than replacing it,
so their edits follow the link and land as reviewable repository diffs — expect
`/model`, plugin, and integration changes to show up as working-tree changes
here. A writer that swapped in a fresh file would leave an unmanaged regular
file, which `verify.sh` fails on.

`~/.claude/keybindings.json` is likewise a managed link to
`agent-config/claude/keybindings.json`. Codex and Claude authentication files,
session histories, caches, and other runtime state remain outside this
repository.

Install reviewed links:

```sh
./agent-config/install.sh
```

The installer accepts only exact reviewed predecessor hashes, saves migrated
regular files under `.backups/agent-config`, and rejects unrelated files,
retargeted links, symlinked parents, or invalid sources. Verify current links:

```sh
./agent-config/verify.sh
```
