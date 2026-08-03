# Global Agent Configuration

`pi/AGENTS.md` is the single canonical global rule source.

- Codex: `~/.codex/AGENTS.md` symlinks directly to it.
- Claude: `~/.claude/CLAUDE.md` symlinks a one-line supported import adapter.
- Pi pilot: `$PI_CODING_AGENT_DIR/AGENTS.md` symlinks directly to it.
- Claude's prompt hook extracts the response/closeout sections from that same
  source; it does not maintain another rule copy.

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
