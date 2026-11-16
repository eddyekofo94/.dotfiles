# tab_launch_guard: Opus by full model id

Finding: the guard already denies `--model opus` outside /build and /spec. A full id
(`--model claude-opus-5-5`, `ANTHROPIC_MODEL=` not covered) slips past `--model[ =]opus\b`.
51c208ba was an in-session `/model` switch; a Bash hook cannot see it (not fixable here).

Steps
1. claude/tab_launch_guard.py: match `--model[ =](claude-)?opus` (any opus id). Proof: new tests red first, then green.
2. claude/tests_tab_launch_guard.py: full id denied for /verdict, ok for /build, ok for /spec.
3. Run `python3 claude/tests_tab_launch_guard.py`. Commit path-limited, push.
