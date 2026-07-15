# Tmux Workflow Loops

## Feature loop

1. Keep one tmux behavior as the bounded target.
2. Record settled interaction semantics before editing configuration.
3. Change only the owning tmux scripts, adapters, configuration, and docs.
4. Run `tmux/scripts/verify.sh`.
5. Exercise the exact interaction in a fresh tmux client.
6. Leave color, glyph, animation, and workflow feel awaiting user confirmation.

## Bug loop

1. Reproduce the failure in an isolated tmux server.
2. Add a deterministic case to the package test that exposes it.
3. Fix the smallest owning component.
4. Run `tmux/scripts/verify.sh` and the relevant item in `tmux/MANUAL_QA.md`.

## Review loop

Review configuration parsing, shell/Python/JavaScript syntax, unsafe quoting,
outside-tmux no-op behavior, status truthfulness, and unrelated worktree scope.
Rerun package verification after every real finding.
