# Cross-Session Agent Overview

## Goal

Let every independent Ghostty/Herdr window discover agents running in other
active named Herdr sessions without reintroducing mirrored windows.

## Exit Criteria

A settled, implementation-ready design defines the overview surface, the
cross-session identity model, session scope, and safe focus/read/message
semantics. Implementation may become `Ready To Act` only after
`herdr-independent-ghostty-windows` passes its close-all/reopen physical QA and
the active-goal pointer is cleared.

## Scope / Non-goals

In scope:

- preserve one independent named Herdr session per ordinary Ghostty window;
- discover agents across all running local named Herdr sessions;
- show session, agent, lifecycle status, and cwd for every result;
- provide explicitly settled safe focus, read, and message actions;
- preserve macOS/Ghostty `Command` shortcuts throughout the palette, including
  `Cmd-V` paste;
- handle stale sessions, disappearing agents, duplicate labels, and
  session-local IDs without targeting the wrong agent;
- preserve recovery, `pane_history = false`, tmux fallback, and existing dirty
  work.

Non-goals:

- putting multiple Ghostty windows back into one mirrored named session;
- replacing Herdr workspaces with named sessions for ordinary project
  navigation;
- changing native `Prefix+w`, native `Prefix+f`, or the current-session sidebar
  before a surface decision explicitly requires it;
- remote-host aggregation in the first slice;
- stopping sessions, closing panes, submitting agent input automatically,
  upgrading Herdr, committing, or pushing.

## Decisions

- Independent named sessions remain the hard isolation boundary for physical
  Ghostty windows. A workspace remains the project container inside one named
  session.
- Cross-session discovery is an aggregation layer, not a change to Herdr's
  session model.
- Each row must identify a target by session plus stable terminal/agent
  identity. Session-local pane IDs or agent labels alone are insufficient.
- The overview shows at least session, agent, status, and cwd.
- `Prefix+A` opens a dedicated session-modal cross-session agent palette.
  Lowercase `Prefix+a` remains the adaptive split. Native `Prefix+w`,
  `Prefix+f`, and the current-session sidebar remain unchanged.
- The palette is on-demand rather than continuously polling or replacing a
  native Herdr surface. It refreshes its cross-session inventory when opened
  and revalidates the selected target immediately before an action.
- Discovery and read are non-destructive. Focus and message must fail closed if
  the target session or agent changed after selection.
- Focus acts inside the agent's owning named Herdr session. It focuses that
  session's exact agent pane while the palette's current Ghostty window remains
  attached to its own independent session. It does not attach the current
  window to the target session or attempt to activate a macOS Ghostty window.
- macOS `Command` shortcuts remain owned by Ghostty rather than the Herdr
  palette. In particular, `Cmd-V` pastes through Ghostty; the palette must not
  bind or swallow it. The same ownership preserves Ghostty's normal `Cmd-C`,
  `Cmd-A`, `Cmd-F`, `Cmd-N`, `Cmd-W`, and other configured/default macOS
  behaviors.
- Message opens an editable composer inside the palette. The composer accepts
  ordinary typing and Ghostty-owned `Cmd-V` paste.
- Confirming Message revalidates the exact session-qualified agent identity,
  then inserts the composed text into that agent's input without synthesizing
  Enter or submitting it. Message does not change either session's focus; Focus
  remains a separate explicit action.
- Multiline text is preserved through the already proven bracketed-paste
  transport. An empty composition is a no-op. If target revalidation fails, no
  text is dispatched.
- Read opens a bounded, scrollable, read-only preview of the target agent's
  recent output inside the `Prefix+A` palette. It does not change focus in
  either session; Escape returns to the cross-session agent list. Refresh is
  explicit and the palette does not persist additional pane history.
- Native current-session navigation remains available. This feature
  `supersedes` only the earlier `herdr-picker-policy` decision that rejected a
  custom cross-session aggregator.
- The final independent-window close-all/reopen gate passed at 18:23 CEST on
  2026-07-29, so this is now the repository's sole active implementation goal.
- No commit or push is authorized.

## Evidence / Findings

- Live Herdr is v0.7.4.
- `herdr session list --json` exposes running named sessions and their exact
  socket paths.
- `herdr agent list` is scoped to the current `HERDR_SESSION` and
  `HERDR_SOCKET_PATH`; the live `main` session reports the current Codex agent,
  while `window-2` through `window-6` currently report no agents.
- Read-only queries against each exact running-session socket work, so a local
  cross-session inventory is feasible without merging server namespaces.
- Herdr v0.7.4's native sidebar and `goto` surface are current-session-only.
- The existing `herdr-picker-policy` deliberately excluded cross-session
  aggregation to keep native navigation scoped. This dedicated feature is a
  later explicit product decision and therefore supersedes only that
  exclusion.
- Existing session-modal fzf helpers demonstrate a validated custom-palette
  seam.
- `Prefix+A` (`prefix+shift+a`) is currently unbound. Lowercase `Prefix+a`
  already owns adaptive split and remains distinct.
- `herdr agent read`, `agent focus`, and `agent send` are available per target
  session. `agent send` inserts literal text without Enter.
- The existing `ready_prompt.sh` transport wraps exact multiline content in
  bracketed-paste markers and dispatches it with `pane send-text`. Its focused
  and live validation proves exact multiline insertion with
  `submitted:false`, no return key, and no command execution.
- The live Ghostty configuration does not override Command-key clipboard or
  editing behavior. Ghostty 1.3.1's effective defaults map `super+v` to
  clipboard paste, `super+c` to copy, `super+a` to select all, `super+f` to
  search, `super+n` to new window, and `super+w` to close surface.

## Tradeoffs / Risks

- The selected separate palette is feasible and keeps native navigation stable,
  but adds one explicit command/binding.
- Focus deliberately changes the owning session's internal pane focus without
  moving the current window or raising the other macOS window. The result is
  predictable and preserves isolation, but the user must click or cycle to the
  owning Ghostty window to see it.
- Palette input must cooperate with Ghostty's bracketed/safe paste path; custom
  terminal key handling must not reinterpret macOS Command chords.
- Message intentionally separates insertion from submission. This adds one
  final review step in the owning window, but prevents a cross-session palette
  from executing a stale, malformed, or accidentally pasted prompt.
- The bounded in-palette Read preview keeps the user in the current independent
  window and avoids another modal surface, at the cost of less space than a
  dedicated reader.
- Cross-session actions must validate the selected session socket and stable
  agent identity immediately before dispatch to prevent stale-target mistakes.
- Agent names and pane IDs can repeat across sessions; every display and action
  needs session-qualified identity.

## Validation Plan

- Use two or more isolated named Herdr sessions with agents in distinct cwd and
  lifecycle states.
- Prove the overview lists each agent once with correct session, agent, status,
  and cwd, while native current-session navigation remains unchanged.
- Prove duplicate agent labels and repeated pane IDs remain unambiguous through
  session-qualified stable identities.
- Prove stopped sessions, stale sockets, disappearing agents, and changed
  identities fail closed without dispatching to a replacement target.
- Prove read is bounded and read-only; Message preserves exact single-line and
  multiline text through bracketed paste, sends no Return key, executes
  nothing, and leaves both sessions' focus unchanged; Focus follows the settled
  physical/session behavior.
- In physical Ghostty QA, prove `Cmd-V` pastes into every palette text-entry
  surface and that representative native `Cmd-C`, `Cmd-A`, `Cmd-F`, `Cmd-N`,
  and `Cmd-W` ownership is not displaced.
- Preserve `pane_history = false`, independent-window allocation and recovery,
  tmux fallback, all current Herdr/Fish gates, and production hashes outside
  the authorized feature seam.
- Run `./herdr/verify.sh`, `./fish/scripts/verify.sh`, `git diff --check`, fresh
  Standards/Fidelity review, and physical multi-window QA after activation.

## Ready To Act

Ready. `herdr-independent-ghostty-windows` passed its final physical
close-all/reopen QA and is durably closed. Implement the dedicated helper and
`Prefix+A` binding, deterministic stale-target/action validation, evidence,
full Herdr/Fish gates, fresh Standards/Fidelity review, and physical
two-window QA without commit or push.

Complete. Implementation, deterministic validation, full Herdr/Fish
verification, physical two-window and macOS Command-key acceptance, and fresh
post-fix Standards/Fidelity review all pass. See `physical-qa.md`,
`review.md`, and `closure.md`.

## Open Questions

None.
