# Tmux Agent Status Design

## Goal

Make the state of interactive coding agents visible in Catppuccin tmux window
tabs while working in a different window.

## Supported agents

- Codex (`codex`)
- Claude Code (`claude`)
- OpenCode (`opencode`)
- Antigravity CLI (`agy`)
- Legacy Gemini CLI (`gemini`)

Only the top-level interactive agent in each tmux pane gets an entry. Internal
subagents roll up into their parent agent's state.

## Window format

An agent window shows its tmux window number once, followed by every agent pane:

```text
1 codex:.dotfiles ⠋ · claude:BibleStandard 
```

Each agent label is `{agent}:{launch-directory-basename}`. The project portion
is captured when the session starts and stays fixed. Project names longer than
16 characters use a middle ellipsis; agent names and state icons remain visible.
Non-agent panes are omitted from agent windows. Windows with no agent panes keep
their existing Catppuccin window name.

## States

| State | Indicator | Catppuccin color | Meaning |
| --- | --- | --- | --- |
| Running | Animated spinner | Blue | The agent is processing a turn. |
| Question required | `` | Peach/orange | A direct conversational question, including grilling, needs an answer. |
| Permission required | `` | Red | A native permission prompt or explicit approval gate needs action. |
| Ready or finished | `` | Green | No work is pending, or the latest turn completed normally. |
| Failed | `` | Red | The agent crashed or hit an API, authentication, rate-limit, or equivalent error. |

Question, permission, ready, finished, and failed states are sticky across tmux
window selection. Submitting an answer or new prompt changes the corresponding
agent to running. Normal agent exit removes its entry. A failed entry survives
process exit until another agent starts in that pane or the pane closes.

## Interaction boundaries

- Existing `codex`, `claude`, `opencode`, `agy`, and `gemini` commands stay
  unchanged.
- Status is visual-only: no sounds, system notifications, automatic tab
  switching, or read-on-focus behavior.
- Native agent hooks or plugins feed one shared tmux-status component.

## Prototype stop condition

A throwaway prototype must demonstrate two simultaneous agent entries in one
Catppuccin window tab, independent state transitions for all five states,
stable project labels, normal non-agent fallback, and safe no-op behavior
outside tmux.

## Prototype validation

- Parse the tmux configuration in an isolated server.
- Exercise state transitions deterministically without making live model calls.
- Manually inspect the rendered indicators in Ghostty with CommitMono Nerd Font.
- Confirm each supported CLI can emit or be adapted to the required events
  before any production integration is accepted.

## Prototype artifact

The throwaway state-model prototype lives in
`tmux/prototypes/agent-status/`. Deterministic transition and isolated-server
checks pass.

## Implementation decision

On 2026-07-15, the user chose to proceed directly from the prototype into the
bounded production integration and test it in the real tmux configuration.
The shared engine, native hook/plugin adapters, Catppuccin renderer, automated
tests, and live config links are now installed. Production color, glyph,
animation, and interaction feel remain a manual visual confirmation; no
production hook may be called visually approved until that check is recorded.
