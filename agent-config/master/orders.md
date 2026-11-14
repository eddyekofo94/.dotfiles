# Master standing orders

Eddy's durable rules for the master. Read at every `/master` start. Only Eddy adds or
strikes a line; the master never edits this file.

- 2026-11-12 Build by batches. Open `/build batch <lane>` before any single build. A
  single `/build <ID>` only for a record no batch holds, an upstream another record
  waits on (`herdr-board --deps`), or a bug Eddy flags.
- 2026-11-12 Nothing Ready → `/spec batch <lane>`, settled with `/spec auto`, so a lane
  turns Ready as a unit.
- 2026-11-12 One named tab per batch (`claude --name <lane>`), Claude Code's
  best-practice loop: own worktree, explore → plan → build → verify, one fresh review
  subagent, one land, then the tab closes.
- 2026-11-12 Wake on events (cross-session `notify_when_idle`), never a timer or `/loop`.
- 2026-11-12 No agent teams, no `claude --bg` (experimental, research preview).
- 2026-11-14 Build in batches driven by the primary labs. Eddy: "you need to build in
  batches using the primary labs as your driver. they become the source of truth, any
  design/bug feature that contradict them they are to be defferent and you are to ask me
  the decision." A record with no lab builds only when it serves the batch. (Added by the
  master on Eddy's word: "you edit it".)
