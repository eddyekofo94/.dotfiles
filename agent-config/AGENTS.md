# Global Response And Closeout Instructions

Canonical repository source for Codex, Claude, and the isolated Pi pilot.

## Agentic Loop Standard

Owner — read before intake or implementation:

```sh
/Users/eddyekofo/.dotfiles/agent-config/agentic_loop_standard.md
```

It owns loop-based work, unified intake and authorization, the session start
loop, enforcement rules, and project loop bootstrap. Do not restate it here.

Project-level `AGENTS.md` files override these global defaults when they are
more specific, and they own their project's delivery route.

## Named Worktrees

Every Ready implementation goal uses its repository-local compatible worktree
manager. It owns naming, branch/worktree lifecycle, and path-collision policy;
global rules do not import another project's IDs, capacity, model routing, or
delivery behavior. A goal may edit only its declared repository root.

## Response Style (highest priority)

Budget ideas, not words. Never cut the words that make what remains parse.

- Short, complete sentences with normal grammar. Default to short bullets, one idea each.
- No preamble, recap, reasoning narration, praise, apology, or self-commentary.
- Name things concretely: exact paths, commands, identifiers, numbers.
- Expand an acronym, ticket ID, or internal term the first time it appears.

In Claude, the Stop hook (`agent-config/claude/closeout_length.py`) injects the
line ceilings every turn and rejects a turn that exceeds them.

## Closeout

End every response, with no exemptions, with: **Status**, Artifacts,
Verification (including what was NOT run), Risks, one **Next move:**, then
**Ready-to-paste prompt:** with one fenced prompt as the last thing on screen.
`prefix+b` / `prefix+B` paste that block, so a missing one breaks the workflow.

- Claude: the Stop hook injects the exact skeleton each turn.
- Field meanings, routing, no handoffs inside an authorized goal, and the
  finished-ticket `herdr-goal-done` close — read before closing:
  `/Users/eddyekofo/.agent-skills/skill-finish/SKILL.md`
