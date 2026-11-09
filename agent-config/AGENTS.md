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
- Settle everything, then build: set out every open decision at once with your call made; ask
  the critical or unsure ones up front, and again if still unsure; prototype only what must be
  seen. I can still adjust while you build ("this is the rule!", 2026-10-14).
- Write the steps to `plan.md`, each with how you'll prove it works.
- Two failed tries on one step: stop, note what failed, re-plan.
- Pausing mid-task: leave `plan.md` so a new session can pick it up.

## 2. Smallest change that works

- Stay inside this task. Don't break anything that already works.
- Tradeoff? Make the best decision that elevates all three: UX (users), DX (the next dev) and AX
  (the next agent), always, without breaking anything.
- UI copy: cut taglines, helper text and secondary labels. If a screen needs them to make sense,
  fix the layout.
- No renames or refactors nobody asked for.
- Reuse what is proven before hand-writing plumbing (storage, networking, downloads, crash reports,
  images, purchases, parsing): the platform's own frameworks first, then a maintained, widely used
  package. Name the package in the plan or record, so the yes covers it; never slip one in.
- Back up before deleting or overwriting anything.
- Every Ready implementation goal uses its repository-local compatible worktree
  manager, which owns naming, branches and path collisions. A goal edits only
  its declared repository root; global rules never import another project's
  IDs, capacity, model routing or delivery behavior.

## 3. Subagents

- Subagents are allowed again (Eddy, 2026-11-05: "Anthropic updated how subagents work ... it is
  efficient now"; this reverses "stop using subagents", 2026-10-26). Use one for bounded,
  read-only legwork (exploration, research, a pre-flight check) whose result is a short report;
  the session that owns the job still plans, edits and decides.
- Never two agents or tabs on one file. A subagent never closes the tab, lands or asks Eddy.
- Review of a build diff is a fresh subagent (Opus `high`); a `/review <ID>` tab runs when Eddy asks.
- The model is the tab's: `/build` opens on Opus `medium`, everything else on Sonnet, set when
  the tab opens; never switch mid-session. A review subagent runs on Opus `high`; the architecture pre-flight and plain lookups run on Sonnet (Eddy, 2026-11-09, retro `ios-2026-11-09`; supersedes the 2026-11-05 Opus call).

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
last thing on screen. `prefix+b` / `prefix+B` paste that block, so it stays on
every reply and does real work, never "check the board again".

- Nothing left to do: say so plainly, add **Offer:** above the prompt with 2-4
  concrete bullets of other work (a tab to `/spec` N records in a named repo,
  a `/verdict` batch, close this tab), and make the prompt the first offer.
  While the current repo has Spec Needed records, the first offer is always a
  batch `/spec` of them (Eddy, 2026-11-04: "I still want my ready to be paste
  prompt ... give me offer but as long as the current repo has specs to be
  settled always offer me batch settle").

- Mark for scanning (Eddy, 2026-10-23): the Status word takes its emoji
  after it (DONE ✅, PARTIAL 🟡, BLOCKED ⛔, AWAITING USER APPROVAL 👉,
  WAITING ⏳), and a body line starts with one where it helps: ✅ done,
  ⚠️ a risk or warning, ⛔ blocked, 👉 needs Eddy. One per line, never decoration.
- Claude: the Stop hook (`agent-config/claude/closeout_length.py`) injects the
  exact skeleton each turn and rejects a turn that breaks it or runs away.
- Field meanings, routing, no handoffs inside an authorized goal, and the
  finished-ticket `herdr-goal-done` close — read before closing:
  `/Users/eddyekofo/.agent-skills/skill-finish/SKILL.md`

## CanonFidei Repositories

Projects under `~/Programming/Projects/CanonFidei/` publish to the
`canonfidei` GitHub organization as private repositories. After creating one,
invite `emmanuelrichard01` with write (`push`) permission on a Bible Standard
Group repo (iOS, API, web, data, specs, design, QA and the clients to come). Any
other CanonFidei repo gets no invite unless Eddy names one.

## Lessons <!-- Archived 2026-11-05 to ~/.dotfiles/agent-config/archive/lessons-2026-11-05.md; auto-memory is on. Newest on top. -->
- Moved on 2026-10-27 (Eddy, BS-IOS-TASK-835 D7), text verbatim: in a CanonFidei repo read `~/.dotfiles/agent-config/canonfidei.md` first (partners, email, the Group, the CanonFidei repositories, Bible Standard operations and the tab chain; moved there 2026-11-05 with their full wording); iOS look and motion Lessons are in the iOS repo's `design/AGENTS.md`; `/spec` and build-boundary Lessons are in its `.claude/playbooks/spec.md`.
