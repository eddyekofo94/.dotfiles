# Dotfiles Agent Status

This context defines the shared language for showing interactive coding-agent
attention state across tmux windows.

## Language

**Supported agent**:
An interactive Codex, Claude Code, OpenCode, AGY, or legacy Gemini CLI session
whose state can appear in a window status.
_Avoid_: AI process, assistant

**Agent pane**:
A tmux pane whose foreground interactive program is a supported coding agent.
_Avoid_: Agent tab, agent process

**Agent window**:
A tmux window containing one or more agent panes.
_Avoid_: Agent tab, agent page

**Agent label**:
The agent's name paired with the basename of its launch directory, captured for
the session, such as `codex:.dotfiles` or `claude:BibleStandard`.
_Avoid_: Process name, pane title

**Window status**:
The summary shown on an agent window's tab, containing the window number followed
by the label and current state of every agent pane in that window.
_Avoid_: Pane status, process status

**Sticky status**:
An agent state that remains visible across window selection changes and changes
only when that agent starts, requests attention, finishes, or exits.
_Avoid_: Seen status, unread status

**Running**:
An agent is actively processing the user's current turn.
_Avoid_: Busy, thinking

**Attention required**:
An agent has paused because it explicitly needs an answer, choice, clarification,
or approval from the user.
_Avoid_: Waiting, idle, blocked

**Question required**:
Attention required because the agent asked the user a conversational question. A
grilling question is a question required.
_Avoid_: Prompt, query

**Permission required**:
Attention required because the agent needs explicit permission or approval before
it can continue.
_Avoid_: Question, confirmation

**Finished**:
An agent has completed its current turn without requesting further user input.
_Avoid_: Idle, stopped, waiting

**Failed**:
An agent's turn ended unsuccessfully because of a crash or an API,
authentication, rate-limit, or equivalent operational error.
_Avoid_: Finished, permission required
