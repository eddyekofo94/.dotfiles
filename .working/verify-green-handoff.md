# verify.sh green (Codex/Pi retired) — handoff 2026-11-05

Done (uncommitted, in ~/.dotfiles/agent-config): verify.sh Codex/Pi lines removed; tests/statusline_test.sh second-boundary margins (+60/+1830).
Remaining verify.sh failures, none from Codex:
1. default_model_test: settings.json "model" is "opus" (uncommitted picker edit, not mine) -> needs Eddy: set back to "sonnet".
2. Xcode settings stale: needs `agent-config/install.sh` (rewrites ~/Library/.../ClaudeAgentConfig).
Next: commit verify.sh + tests/statusline_test.sh path-limited, push. Leave settings.json alone.
Run the check without default_model line: /tmp/retro/verify_nodm.sh (copy to agent-config/.verify_tmp.sh, then delete).
