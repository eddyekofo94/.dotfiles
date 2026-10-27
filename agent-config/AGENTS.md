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
- No new dependencies, renames or refactors nobody asked for.
- Back up before deleting or overwriting anything.
- Every Ready implementation goal uses its repository-local compatible worktree
  manager, which owns naming, branches and path collisions. A goal edits only
  its declared repository root; global rules never import another project's
  IDs, capacity, model routing or delivery behavior.

## 3. No subagents

- Never start a subagent (the Agent or Task tool, a fork included), in any project. The
  session that has the job reads, edits, plans and reviews itself (Eddy, 2026-10-26:
  "stop using subagents"). `permissions.deny: ["Agent"]` in `claude/settings.json` blocks it.
- A skill, playbook or hook text that says to spawn an agent means: do that step yourself, here.
- Review is a self-review in this session: read `git diff` against the rubric. A fresh
  `/review <ID>` tab runs only when Eddy asks for one.
- The model is the tab's: `/build` opens on Opus `medium`, everything else on Sonnet, set when
  the tab opens; never switch mid-session.

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
invite a collaborator with write (`push`) permission: `emmanuelrichard01` for a
Bible Standard Group repo (iOS, API, web, data and the clients to come), and
`OluwadaraDaily` for any other CanonFidei repo.

## Lessons

- Moved on 2026-10-27 (Eddy, BS-IOS-TASK-835 D7), text verbatim: in a CanonFidei repo read `~/.dotfiles/agent-config/canonfidei.md` first (partners, email, the Group, Bible Standard operations; the full wording of each rule below); iOS look and motion Lessons are in the iOS repo's `design/AGENTS.md`; `/spec` and build-boundary Lessons are in its `.claude/playbooks/spec.md`.
- When Eddy agrees ("yes", "do it", a pasted prompt) to a change, take it as the order to finish it: tests, commit, push, and anything else the change needs; never stop at a staged diff, an unpushed commit or a prompt for the next step. When a retro finds an improvement a tool, hook, guard or skill can carry, build, test, commit and push it in that run and report it as done; only a change above Lessons in an `AGENTS.md` waits for him.
- When a guard or the workflow blocks what is left of a task (a cleanup, a commit, a stuck hold), settle its fix as a record queued first and let the chain build it; never end on steps or a prompt for Eddy to run.
- When Eddy questions a tab's effort or model ("I shouldn't be running Max here?"), take it as the correction: say what the level costs, how he lowers it and what set it, and fix that setting in the same session; never explain why the level is fine.
- When a file a tool writes (a gate's report, an audit's output) blocks a commit, a land or a tab close more than once, fix its cause in that session (ignore it, or stop the tool writing it into the checkout) and land the fix; never hand Eddy a prompt to remove it again.
- When work touches Ruby and River (`RubyandRiver`, `rubyandriver_services`, its Shopify theme or its shop), do nothing: no rename, reconnect, check or fix, because the shop is closed.
- When work is housekeeping, research, drafting, review, retros or config (anything but `/build` on a project), run it in a Sonnet tab; Opus is for `/build` only, or when Eddy calls for it ("things like this should not be done with Opus … opus should only be for build on projects, not what we are doing here unless called upon", Eddy, 2026-10-23: a retro and a dotfiles review ran on Opus).
- When Eddy says he already wrote something down, search his own words (each noun he used, one at a time) across every decision file, record and session log before saying it is not written, and give him its ID; never conclude "not in the records" from one phrase that he did not use.
- When you launch any long check (an audit, a gate, a capture run), launch it so it ends itself at the first red line: the tool's fail-fast flag, or a watcher in the same background command that kills it when the first failure prints, so the job's exit tells you; never let a red run carry on to its end, and never chain passes.
- When a turn ends while its own background job (a gate run, a reviewer agent) is still running, end it with the one-line `**Status:** WAITING` and no prompt block, and pick the work up when the job exits; never hand Eddy a resume prompt to paste.
- When Eddy has already named the answer to an open question (e.g. "the app should ship WEB"), write it into the plan as settled and never re-ask it as a picker, even when a reviewer lists it as open.
- When Eddy's own words already say how a thing should be (a settled decision, or the ask in front of you), build exactly that; never turn it into a fork, a picker or a recommendation of the other way, and tell him a cost you find as the cost of his way, with its fix. FS-354 D8 made English always plain, yet he was asked UK or US and a toggle was queued ("You forgot, english is always plan, I thought I set this rule already?", 2026-10-13); FS-361's "slide under the hero" became an A/B with the opposite recommended.
- When a tool behaviour Eddy relied on "was working before", diff that logic across the installed versions (e.g. `~/.local/share/claude/versions/*`) and reproduce it live (tmux `send-keys`/`capture-pane`) before proposing anything; never offer substitute keybinds he did not ask for (2.1.295 clamped effort cycling, "stop being dumb and just do what was previously working", Eddy, 2026-10-12).
- When a push or merge lands, read the GitHub Actions run for that commit before calling it done; a local verify script may not run every CI step.
- When another tab looks idle, read its session log for a background job before saying it stalled or telling Eddy to prompt it.
