# Herdr Shared Buffer History

## Goal

Determine whether the retained Herdr v0.7.4 provides a supported,
security-conscious equivalent to tmux's session-shared paste-buffer list and
interactive `choose-buffer` workflow.

## Exit Criteria

Either:

- identify a supported Herdr v0.7.4 named-buffer/history primitive and settle
  an evidence-backed implementation and validation plan; or
- prove that Herdr's supported clipboard surface is single-entry system
  clipboard integration and durably defer multi-entry retention rather than
  creating an unapproved clipboard-history product or emulation.

## Scope / Non-goals

- Inspect the exact tmux bindings and live buffer metadata without reading
  buffer contents.
- Inspect the installed Herdr v0.7.4 CLI, generated default config, complete
  socket API schema, official documentation/changelog, and exact tagged source.
- Preserve ordinary Herdr copy mode, mouse copy, host-terminal paste, and the
  system clipboard.
- Preserve Herdr v0.7.4, `pane_history = false`, tmux, and all existing dirty
  work.
- Do not store clipboard entries in files, plugin state, pane history, shell
  history, or another persistence layer.
- Do not build a picker around intercepted clipboard writes, poll `pbpaste`,
  inject terminal input, or otherwise emulate a native buffer store.
- Do not inspect live clipboard or tmux-buffer contents, upgrade Herdr, change
  production configuration, commit, push, or remove tmux.

## Decisions

- Classify `herdr-shared-buffer-history` as **durably deferred and
  upstream-limited on Herdr v0.7.4**.
- Retain Herdr's supported single-entry system-clipboard workflow as the
  security-conscious replacement for ordinary copy and paste. It is not
  multi-entry `choose-buffer` parity.
- Do not add clipboard retention or a chooser. Herdr v0.7.4 exposes no supported
  named-buffer/history store, lifecycle, list/read/delete API, or retention
  policy to configure.
- Do not treat a custom popup, plugin-state log, `pbpaste` poller, or
  pane-readback scraper as a supported equivalent. Each would create a new
  sensitive-data product whose capture, scope, lifetime, deletion, remote
  behavior, and crash persistence have not been approved.
- Reopen the parity goal only when a retained supported Herdr release documents
  a native multi-entry clipboard/buffer facility. A separately selected product
  goal may also reopen it, but must first settle the security boundary listed
  under Open Questions. Neither route authorizes a Herdr upgrade.

## Evidence / Findings

- `tmux/tmux.conf` binds `Prefix+C-r`, `Prefix+"`, and copy-mode `"` to
  `choose-buffer`. The normal `Prefix+]` / `Prefix+p` path reads the current
  system clipboard, loads it into tmux, and pastes it with bracketed-paste
  support.
- The live tmux server reports `buffer-limit = 50` and exactly 50 auto-named
  buffers. Only names, byte sizes, and creation times were inspected; contents
  were not read.
- `@resurrect-capture-pane-contents` is `off`. The shared buffers are live tmux
  server state, not an approved durable clipboard archive.
- tmux documents named paste buffers, automatic buffer eviction at
  `buffer-limit`, interactive selection/search/paste through `choose-buffer`,
  and explicit buffer deletion. This is a real multi-entry store, not merely
  an alias for the current OS clipboard.
- The installed binary is exactly `herdr 0.7.4`. Its help exposes no clipboard
  or buffer command. Its complete generated default config contains only
  clipboard-copy behavior/toast settings, remote image paste, pane screen
  history, and terminal scrollback settings; it has no clipboard-history or
  named-buffer setting.
- The installed v0.7.4 socket API schema has no clipboard, paste-buffer,
  buffer-history, or copy-history request.
- The exact `v0.7.4` tagged source resolves to commit
  `50aaa2ec046ee26ff407c20f49de496f522512a8`. Source inspection shows selection
  and copy-mode writes to the current platform clipboard, host paste routing,
  OSC 52 forwarding, and bounded remote image staging. It contains no
  multi-entry clipboard/buffer model or chooser.
- Herdr's official keyboard and quick-start documentation describe copy mode
  and mouse selection as copying to “your clipboard.” The official
  configuration reference documents `ui.copy_on_select`, clipboard feedback,
  and remote image paste, but no clipboard history or buffer chooser.
- Herdr's session-state documentation explicitly keeps pane screen-history
  persistence off by default because terminal output can contain secrets,
  tokens, prompts, and command output. Clipboard entries carry the same class
  of risk and must not be redirected into `session-history.json` or plugin
  state.
- The completed project picker proves a safe transactional fzf popup transport,
  but only for structured project/workspace identities. Reusing its UI shell
  would not supply a supported clipboard store or settle content retention,
  ownership, and deletion semantics.

Primary references:

- <https://herdr.dev/docs/keyboard/>
- <https://herdr.dev/docs/config-reference/>
- <https://herdr.dev/docs/session-state/>
- <https://github.com/ogulcancelik/herdr/tree/v0.7.4>
- <https://man.openbsd.org/tmux.1>

## Tradeoffs / Risks

- tmux's live-server buffer ring is convenient and currently holds up to 50
  entries, but duplicating that behavior would retain copied secrets beyond the
  single current OS clipboard value and make them searchable from any attached
  client in scope.
- Memory-only retention would reduce disk exposure but would not settle client
  authorization, remote attach, lifetime, size limits, explicit clearing,
  crash/core-dump exposure, or whether background clipboard writes are captured.
- macOS may provide clipboard behavior outside Herdr, but adopting an OS or
  third-party history manager is a separate system-level security decision and
  is not Herdr parity.
- A chooser over pane readback would conflate terminal history with intentional
  copies, risk capturing unrelated secrets, and violate the retained
  `pane_history = false` posture.
- Deferral loses multi-entry recall when using Herdr, but ordinary copy/paste
  remains supported and tmux remains available when the chooser is required.

## Validation Plan

No implementation is authorized on Herdr v0.7.4. If a future retained Herdr
release documents a native multi-entry facility:

1. confirm the facility in that exact binary's help/default config, complete API
   schema, tagged source, and official version-matched documentation;
2. require explicit decisions for capture source, session/client scope, local
   versus remote access, memory versus disk, entry/byte/TTL limits, restart
   behavior, deletion/clear-all, content types, and secret-facing warnings;
3. validate in an isolated session with non-sensitive sentinels that ordering,
   selection, paste, eviction, deletion, clear-all, detach/reattach, full
   restart, and unauthorized cross-session/remote access match the settled
   boundary;
4. prove ordinary single-entry system copy/paste and copy mode remain intact;
5. prove no clipboard payload enters `session-history.json`, logs, evidence
   artifacts, shell history, or plugin state unless the settled boundary
   explicitly authorizes that exact storage;
6. confirm Herdr's retained version, `pane_history = false`, tmux availability,
   and unchanged unrelated production-config hashes;
7. run `./herdr/verify.sh` and `./fish/scripts/verify.sh`; and
8. run fresh Standards and Fidelity review against this record, the active
   brief, actual diff, and security evidence.

## Ready To Act

Not Ready — durably deferred and upstream-limited on Herdr v0.7.4. There is no
supported multi-entry buffer primitive to configure, and the permitted scope
rejects clipboard persistence or emulation without a separately settled product
and security boundary.

## Open Questions

These are intentionally deferred, not unanswered requirements for the current
v0.7.4 classification. If Eddy explicitly promotes a custom clipboard-history
product, settle capture source, scope, local/remote access, memory/disk storage,
limits/TTL, restart behavior, content types, deletion, and secret warnings
before marking that new goal Ready To Act.
