---
status: accepted
---

# Feed one tmux status component from native agent events

Use native hooks or plugins from Codex, Claude Code, OpenCode, AGY, and legacy
Gemini CLI to feed one shared tmux-status component while preserving the normal
agent commands. This costs more adapter work than process-name or pane-output
heuristics, but it is required to distinguish running, conversational questions,
permission gates, successful completion, and failure without brittle screen
scraping or a separate command users must remember.

Internal subagents roll up into the top-level interactive pane because the pane,
not an internal worker, is the unit through which the user can respond.
