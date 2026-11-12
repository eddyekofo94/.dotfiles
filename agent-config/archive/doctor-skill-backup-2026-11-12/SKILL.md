---
name: doctor
description: Diagnose this Mac's CPU and memory health, identify sustained CPU consumers and user-closeable apps using substantial RAM, and conservatively clean proven stale processes. Use when the user says "doctor" or "/doctor", asks why CPU is high, asks if the Mac/RAM is healthy, reports slowness, heat, saturation, swapping, or WindowServer crashes, or asks to clean stale shells, dev servers, zellij, or tmux sessions. Pass --clean only after reviewing the report or a dry run. Also use with --icloud when Documents or Desktop suddenly return "Operation not permitted", when ls/git/getcwd fail but cd works, or when a local server 404s on every path.
---

# doctor — Mac CPU and memory health check

Wraps the `~/.local/bin/doctor` command (a 16 GB Mac; see the mac-memory-doctor
memory for the zellij-autostart root cause this was built to catch).

## What to run

- **Report only (default):**
  ```
  ~/.local/bin/doctor
  ```
- **Report + clean** — when the user passes `--clean`, says "clean", "clean it
  up", or asks to kill the stray processes:
  ```
  ~/.local/bin/doctor --clean --yes
  ```
  `--yes` is required here: this runs non-interactively, so without it the kill
  prompt is auto-declined and nothing gets cleaned. `--clean` only ever kills
  stray zellij (the user never uses zellij), detached idle tmux sessions older
  than 2h, explicit dev servers running >2h, and Fish shells older than 2h
  whose stdin, stdout, and stderr are all revoked after their terminal vanished.
  Attached tmux sessions and panes running non-shell commands are always
  protected. Helpers embedded inside normal `.app`
  bundles, generic Node processes, and MCP servers are excluded, and normal
  apps are never killed automatically. Separately, `--clean` permanently
  deletes archived Claude Code session transcripts older than 30 days from
  `~/.dotfiles/agent-config/evidence/session_archive` (via
  `session_archive.py --prune-only`); the dry run prints the file count and MB.
- **Cleanup dry run** — when verifying or previewing cleanup:
  ```
  ~/.local/bin/doctor --clean --dry-run
  ```
  This prints the exact cleanup candidates without changing any process. Use
  this before every real cleanup unless the user explicitly asks to clean now.

- **iCloud detached folder** — when `~/Documents` or `~/Desktop` starts
  returning `Operation not permitted`:
  ```
  ~/.local/bin/doctor --icloud        # check, then prompt to repair
  ~/.local/bin/doctor --icloud --yes  # repair non-interactively
  ```
  This is a separate mode: it reports and exits without running the CPU and
  memory sections. It exits 0 when the folders are healthy or recovered, and
  1 when they are still detached afterwards.

## Recognising a detached iCloud folder

With "Desktop & Documents Folders" sync on, those two directories are served
by the CloudDocs FileProvider. When the domain detaches, reads fail with
`EPERM` while the directory stays traversable. The signature:

- `cd` works, but `ls`, `git`, and `getcwd` all fail with `Operation not permitted`
- `test -x` passes while `test -r` fails, on a normal `drwx------` mode
- a local static server 404s on *every* path including `/`, because it cannot
  read a single file
- `ls -ld@ ~/Documents` shows `com.apple.fileprovider.detached#B`

**Do not send the user to Privacy & Security.** This looks identical to a
revoked Documents permission and is not one. Check first — the TCC database
is readable without Full Disk Access:

```
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "select service, client, auth_value from access where service like '%Documents%';"
```

`auth_value=2` means allowed. If the terminal, git, and claude-code are all
2, the permission is intact and the problem is the file provider.

Two more things not to do: **killing `bird` alone does nothing** — the
CloudDocs provider *extension* is what must be restarted, which is what
`--icloud` does — and **never toggle Desktop & Documents sync off** to fix
it, because that relocates files into an iCloud archive folder and is
genuinely destructive when a git repo lives inside. A reboot works but is
rarely necessary; try `--icloud` first.

## How to respond

1. Run the appropriate command above and show the user its output. The CPU
   section uses two interval samples because a single process snapshot can be
   misleading. Report both total CPU/load and sustained process groups. The
   `Where RAM is going` section explains btop's used-memory number with active,
   wired, compressed, inactive/cache, file-backed, and process-RSS figures.
2. Then give a short **verdict** based on the report:
   - For CPU, distinguish total pressure from one process's percentage. Call
     out groups above 50% and individual processes sustained above 20% across
     both samples. If btop shows `Cpu% ↑`, explain that it is ascending and the
     visible rows are the least CPU-intensive; reverse the sort to see culprits.
   - Treat high normal apps as recommendations only. Never kill an app merely
     because it uses CPU. Automatic CPU-related cleanup requires a narrow stale
     signature, such as Fish older than 2h with no TTY and all three standard
     descriptors revoked.
   - **Swap** is the headline metric. `healthy` (<8 GB) → all good. `HIGH`
     (>8 GB) or `CRITICAL` (>16 GB) → tell them to close things; on a 16 GB
     machine, critical swap is what crashes WindowServer.
   - Explain that macOS memory categories overlap and must not be added
     together. Active pages often correspond closely to btop's `used` number;
     inactive/file-backed cache is reclaimable, while wired memory is not.
   - Call out any **⚠ dev servers** (>2h), revoked-terminal shells, any
     **non-zero zellij** count, and
     detached idle **tmux sessions older than 2h**. Attached tmux sessions and
     sessions whose panes are running work are never cleanup candidates.
   - Call out grouped user apps above **1 GB** (`⚠ consider quitting`) and
     above **2 GB** (`● quit recommended`). These are recommendations only;
     `doctor` must never close normal apps automatically.
3. For `--icloud`, say plainly whether the folders are healthy, recovered, or
   still detached. If still detached after the restart, the next steps are log
   out and back in, or reboot. `fileproviderctl repair` rewrites the sync
   database behind the user's files — mention it last, and never run it
   without explicit approval.
4. If a report flags cleanup candidates, run `--clean --dry-run` first. Run
   `--clean --yes` only when the user asked to clean them. After cleanup,
   rerun the report and confirm that CPU/load fell and candidates disappeared.

Keep it short: the user wants "all good" or "here's what to clean," not an essay.
