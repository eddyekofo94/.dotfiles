# Agent Status Prototype

**THROWAWAY PROTOTYPE — not production integration.**

This prototype asks whether two independently changing agent states remain
glanceable in one compact, Catppuccin-colored tmux window tab. It also exposes
the proposed transition rules, sticky attention states, failed-exit behavior,
project-title truncation, and non-agent fallback for manual inspection.

Run it from the repository root:

```sh
tmux/prototypes/agent-status/run.sh
```

The command opens an isolated tmux server and removes it when you detach with
`prefix+d`. It does not install hooks or modify the production tmux server.

## Controls

The prototype prefix is `Ctrl-a`. Select either simulated agent pane, then use:

| Binding | Event |
| --- | --- |
| `prefix+n` | Start or restart the agent in a ready state |
| `prefix+r` | Submit a prompt and enter running state |
| `prefix+q` | Ask a conversational or grilling question |
| `prefix+p` | Request permission or explicit approval |
| `prefix+g` | Finish successfully |
| `prefix+f` | Fail |
| `prefix+x` | Exit; a failed marker remains sticky |
| `prefix+d` | Detach and remove the isolated prototype server |

The first window contains Codex and Claude panes. The second window has no agent
and demonstrates the normal-name fallback.
