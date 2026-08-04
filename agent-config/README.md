# Global Agent Configuration

`pi/AGENTS.md` is the single canonical global rule source.

- Codex: `~/.codex/AGENTS.md` symlinks directly to it.
- Claude: `~/.claude/CLAUDE.md` symlinks a one-line supported import adapter.
- Pi pilot: `$PI_CODING_AGENT_DIR/AGENTS.md` symlinks directly to it.
- Claude's prompt hook extracts the response/closeout sections from that same
  source; it does not maintain another rule copy.

`~/.claude/settings.json` is a managed link too, because the closeout scripts do
nothing until its hook entries register them. Claude Code and
`herdr integration install` rewrite that file in place rather than replacing it,
so their edits follow the link and land as reviewable repository diffs — expect
`/model`, plugin, and integration changes to show up as working-tree changes
here. A writer that swapped in a fresh file would leave an unmanaged regular
file, which `verify.sh` fails on.

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
