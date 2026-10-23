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
- Tradeoff? Weigh UX (users), DX (the next dev) and AX (the next agent).
- No new dependencies, renames or refactors nobody asked for.
- Back up before deleting or overwriting anything.
- Every Ready implementation goal uses its repository-local compatible worktree
  manager, which owns naming, branches and path collisions. A goal edits only
  its declared repository root; global rules never import another project's
  IDs, capacity, model routing or delivery behavior.

## 3. Split work across subagents

- Explorer reads, worker edits, reviewer only reports and never edits.
- Research, drafting and review briefs go to the `researcher` agent (Sonnet), never a bare `general-purpose` (Opus).
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

- When you write the prompt that opens a `/spec` round, a grill or a review, answer one, or close a round that has landed, ask for every open decision at once with your calls (§1), the ones later rounds would ask too, so the record goes to build; never a prompt for Eddy's notes on the next round, "stop at the first question" or "show me each one in the Lab first", whatever `grill-me`'s "Ask the remaining questions one at a time" or a playbook's prototype step says. It broke four times on 2026-10-14: FS-415's D1–D3 went one per turn ("you are to think for me all at once than me choosing one by one"); FS-298's round 5 built a Lab per question, and round 6's prompt, written by the agent, asked for it again ("this has happened a few times today, can we reinforce this in the future? … this is the rule!"); FS-371's round 11 closed on "/spec FS-371 round 12 — my notes from tapping round 11: <notes>" ("Can you have all the rounds and all the decisions settled first then we can build? Isn;t this the rules for the /spec ?", Eddy).
- When a review or architecture pass finds work a record already owns in intent (a lab's look its build will promote), extend that record; never file a new one beside it (FS-412 split FS-371's spine across four records: "there are too many things happening all at once we need to clear things up", Eddy, 2026-10-14).
- When the build lanes are full, leave the ready record queued and stop; never hand Eddy a prompt to land or free other lanes so it can build ("you should not build anything if the lane is busy", Eddy, 2026-10-13).
- When Eddy's own words already say how a thing should be (a settled decision, or the ask in front of you), build exactly that; never turn it into a fork, a picker or a recommendation of the other way, and tell him a cost you find as the cost of his way, with its fix. FS-354 D8 made English always plain, yet he was asked UK or US and a toggle was queued ("You forgot, english is always plan, I thought I set this rule already?", 2026-10-13); FS-361's "slide under the hero" became an A/B with the opposite recommended ("this is quite clear isn't it?", Eddy, 2026-10-14).
- When Eddy calls a screen outdated or "one of my first designs", he means it lacks the motion and material of the newest surface he has passed (how each thing appears and moves, the glass): set the two side by side, measure that gap first and make polish parity the goal; a static critique (cards, stats) comes second ("it doesn't appear with motions, there is no "glass" look and feel … like they're 2 different apps, we want the level of polish concistency", Eddy, 2026-10-13, FS-392).
- When Eddy shares a link or a picture, take it as an example of the idea he wants (what belongs in a Reformed study), never as a seller to source from or license; design from it, and bring a full set of your own ideas so he need not supply them ("Don't go for missionary wear stuff, I am giving you example of what goes well in a reformed study/office since you seem to be struggling with ideas", Eddy, 2026-10-13).
- When a tool behaviour Eddy relied on "was working before", diff that logic across the installed versions (e.g. `~/.local/share/claude/versions/*`) and reproduce it live (tmux `send-keys`/`capture-pane`) before proposing anything; never offer substitute keybinds he did not ask for (2.1.295 clamped effort cycling, "stop being dumb and just do what was previously working", Eddy, 2026-10-12).
- When a plan needs generated art, ask which tool made Eddy's references and plan the generation on his own Claude subscription (its weekly limits), never a paid API he did not ask for ("why would it cost me? … It was generated with Claude", Eddy, 2026-10-04).
- When specifying, designing or building anything in any iOS app, give every tap, action and interaction its motion (appear, disappear, slide, fade, spring, friction and inertia) and its haptic where one fits, named in the spec's decisions rather than left to the build, with a tuning panel for multi-phase transitions; a tap or visible change with no motion is a review finding, not a style choice; that includes a door that opens another screen (a pocket face, a row), and a decision that leaves one a plain push or defers its motion to another slice is named to Eddy before the build, never shipped silent (Eddy, 2026-10-03; restated 2026-10-04: "every tap, action, interation of any sort should have a motion"; again 2026-10-13, FS-200: "anything being opened from the pocket should have the opening animation").
- When a bug reproduces red and a settled decision already names its fix, flip it to Ready To Act in that session, citing the decision, and hand it to the build chain; never hand Eddy a `/spec` prompt for it ("we need to be landing. I lose track of things", Eddy, 2026-10-04, BUG-390).
- When building or prototyping any motion in any iOS app, hold it to FS-297's polish bar without being asked: one velocity-continuous timeline (no chained delays), only transforms and opacity per frame (render-server playback while main works), no dropped frames measured on a ProMotion iPhone, and a lab A/B against the previous round; "looks great" is not done until it is that smooth ("I am enforcing it now as a standard", Eddy, 2026-10-04).
- When a turn in an agent-opened (`▸`) tab ends DONE or BLOCKED with nothing unlanded, do not offer the close: `herdr-reap` (launchd, every 2 min) closes it after 10 idle minutes via `herdr-goal-done --tab` and refills the free lanes; in Eddy's own tabs (no `▸`) keep the one line before **Status** naming `herdr-goal-done`, and run it when he says close (Eddy, 2026-10-04: "I don't want to clog space with idle sessions").
- When a SwiftUI build writes state from scrolling or changes a list's layout as it scrolls, swipe it in the simulator with a DEBUG flip and body-pass counter before calling it done; still frames and a recording missed a fold flipping every frame ("unusably janky", FS-196) (Eddy, 2026-10-03).
- When an old decision quietly excludes something Eddy asks for, name the rule and its record to him at once and offer to drop it as the first option, never a workaround that keeps it; when he says remove a rule, record it removed whole, never a narrower rule he did not say. FS-060 D4 kept recognised portraits off author art; his 2026-10-03 "Remove it!" was recorded as still barring invented likenesses, and on 2026-10-13 a nameless bust was designed around it: "You can soundly remove that rule! I thought we did already?" (Eddy, 2026-10-03, 2026-10-13).
<!-- Newest on top. Delete what no longer applies. -->
- When designing a client site, benchmark it against canonfidei.com and biblestandard.app (motion, interaction, layering, landing-page ambition); a clean but static layout is a failed design, so aim for more, not less (Eddy, 2026-10-02).
- When a push or merge lands, read the GitHub Actions run for that commit before calling it done; a local verify script may not run every CI step (Eddy, 2026-10-02).
- When another tab looks idle, read its session log for a background job before saying it stalled or telling Eddy to prompt it (Eddy, 2026-10-01).
