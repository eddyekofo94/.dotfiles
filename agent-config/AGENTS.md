# AGENTS.md

Shared by Codex, Claude Code and the isolated Pi pilot. Every line here should
change what you do. A project's `AGENTS.md` overrides these defaults where it
is more specific, and owns its project's delivery route.

## Agentic Loop Standard

Owner — read before intake or implementation:

```sh
/Users/eddyekofo/.dotfiles/agent-config/agentic_loop_standard.md
```

It owns loop-based work, unified intake and authorization, the session start
loop, enforcement rules, and project loop bootstrap. Do not restate it here.

## 1. Plan before you touch code

- Long task: first tell me in 2-3 sentences what you think I'm after.
- Start only after I say yes. A project may name what counts as that yes.
- Write the steps to `plan.md`, each with how you'll prove it works.
- Two failed tries on one step: stop, note what failed, re-plan.
- Pausing mid-task: leave `plan.md` so a new session can pick it up.

## 2. Smallest change that works

- Stay inside this task. Don't break anything that already works.
- Tradeoff? Weigh UX (users), DX (the next dev) and AX (the next agent).
- No new dependencies, renames or refactors nobody asked for.
- Back up before deleting or overwriting anything.
- Every Ready implementation goal uses its repository-local compatible worktree
  manager, which owns naming, branches and path collisions. A goal edits only
  its declared repository root; global rules never import another project's
  IDs, capacity, model routing or delivery behavior.

## 3. Split work across subagents

- Explorer reads, worker edits, reviewer only reports and never edits.
- Each gets one job, a done condition and a 5-line report.
- Parallel is fine. Two agents on the same file is not.
- Check the key claim in a report before you build on it.

## 4. Own the bug

- Reproduce it with my steps first. Can't reproduce it? Tell me what you need.
- Fix the cause, then run the same steps again.
- Never silence an error to make it go away.

## 5. Verify before you say done

- Run the tests and read the output yourself.
- UI: open it and try to break it: empty input, double submit, refresh.
- Didn't run a check? Say so. An unrun check is not a pass.
- Report in 2-3 lines: what you picked, what you gave up, and why.

## 6. Write down every correction

- When I correct you, add a line under Lessons: "When X, do Y".
- Same mistake twice: the lesson is unclear. Rewrite it.
- Ask me before changing anything above Lessons.

## Response Style (highest priority)

Budget ideas, not words. Never cut the words that make what remains parse.

- Short, complete sentences with normal grammar. Default to short bullets, one idea each.
- No preamble, recap, reasoning narration, praise, apology, or self-commentary.
- Name things concretely: exact paths, commands, identifiers, numbers.
- Expand an acronym, ticket ID, or internal term the first time it appears.

## Closeout

End every response, with no exemptions, with **Status:**, then
`Picked / gave up / why:` in 2-3 lines (§5's report), `Not run:`, one
**Next move:**, then **Ready-to-paste prompt:** with one fenced prompt as the
last thing on screen. `prefix+b` / `prefix+B` paste that block, so a missing
one breaks the workflow.

- Claude: the Stop hook (`agent-config/claude/closeout_length.py`) injects the
  exact skeleton each turn and rejects a turn that breaks it or runs away.
- Field meanings, routing, no handoffs inside an authorized goal, and the
  finished-ticket `herdr-goal-done` close — read before closing:
  `/Users/eddyekofo/.agent-skills/skill-finish/SKILL.md`

## CanonFidei Repositories

Projects under `~/Programming/Projects/CanonFidei/` publish to the
`canonfidei` GitHub organization as private repositories. After creating one,
invite `OluwadaraDaily` as a collaborator with write (`push`) permission.

## Lessons

- When building any SwiftUI feature in any iOS app, give every appear, disappear and action its motion (ease, spring, friction and inertia, haptics) and a tuning panel for multi-phase transitions; a visible change with no motion is a review finding, not a style choice (Eddy, 2026-10-03).
- When an old decision quietly excludes something Eddy asks for (e.g. FS-060 D4 kept recognised portraits of Augustine and Aquinas off author art), name the rule and its record to him at once; don't silently honour it across sessions (Eddy, 2026-10-03).
<!-- Newest on top. Delete what no longer applies. -->
- When designing a client site, benchmark it against canonfidei.com and biblestandard.app (motion, interaction, layering, landing-page ambition); a clean but static layout is a failed design, so aim for more, not less (Eddy, 2026-10-02).
- When a push or merge lands, read the GitHub Actions run for that commit before calling it done; a local verify script may not run every CI step (Eddy, 2026-10-02).
- When another tab looks idle, read its session log for a background job before saying it stalled or telling Eddy to prompt it (Eddy, 2026-10-01).
