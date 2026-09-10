# Named worktrees

Global policy: a Ready implementation goal uses a repository-local compatible
manager. The manager creates `feature/<slug>` from local `main`, a sibling
`../<repo>-sessions/<slug>` worktree, and requires declared tracked paths.
Overlapping paths reject until `transfer` moves ownership explicitly. External
repositories use their own manager and worktree.

Dotfiles commands:

```sh
python3 tools/session_worktree.py open fish-prompt --path fish/config.fish
python3 tools/session_worktree.py transfer fish-prompt fish-keymaps --path fish/config.fish
python3 tools/session_worktree.py close fish-prompt
```

`create` aliases `open`, and `remove` aliases `close`, preserving the lifecycle
verbs used by `herdr/goals.sh` and `herdr/goal_done.sh`. `shared-status` reports
the shared checkout's branch and dirty state as JSON.
