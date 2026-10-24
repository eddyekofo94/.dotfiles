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

- When Eddy asks in passing about a legal or rights check ("is there a trademark for …?"), answer it and stop; never file it as a task, his errand or a gate on the release unless he asks for one ("I don't care about a trademark lawyer, if I need it I will tell you. Just build Bible Stndrd is what we are going for.", Eddy, 2026-10-24: BS-IOS-FEAT-198's D12 made an attorney's search his errand and held the release on it).
- When a `/spec` covers a launch page, a splash or a mark's new place, search every record that settled the mark for its motion ("wave", "flag", "splash", "motion") and carry each settled motion into the decisions with its call, reusing the motion Eddy already passed; never drop one silently, and never swap a passed motion for a new look that must be prototyped first ("What happened to the flag waving?", Eddy, 2026-10-24, BS-IOS-FEAT-198: the launch calls left out the lamb's wave that FS-090 had settled since 2026-09-21).
- When a guard or the workflow blocks what is left of a task (a cleanup, a commit, a stuck hold), settle its fix as a record queued first and let the chain build it; never end on steps or a prompt for Eddy to run ("just add things to the que and make sure they run, I don't want to sit here and babysit the workflow that's meant to be automatic", Eddy, 2026-10-24, BS-IOS-BUG-581).
- When Eddy questions a tab's effort or model ("I shouldn't be running Max here?"), take it as the correction: say what the level costs, how he lowers it and what set it, and fix that setting in the same session; never explain why the level is fine (2026-10-24: `herdr-goals` opened every `/spec` tab at `max`, and FS-478's guard, passed 2026-10-23, was never built: "I don't want to use Max effort, I thought I put a reinforcement to stop this? it's token eating", Eddy).
- When Eddy asks whether something follows a form or rule (an ID shape, a name), search the decision files and records for it before answering, and answer from what they say; never answer from one record's older call ("I did make a mention of the new naming convention BS- … I mentioned it earlier", Eddy, 2026-10-24: the agent said IDs had no `BS-` front while FS-490 decisions.md lines 136-137 and `id-rename-plan.md` already set `BS-<REPO>-<KIND>-<N>`).
- When a pull request is opened for Emmanuel to continue (its body tags `@emmanuelrichard01` with "for you to continue" or "what is left for you"), it stays open: never merge it, and never write a prompt that merges it, including a "merge #A and #B" prompt that lists it among others; merge only PRs Eddy names as his own to land, and check each one's body for that tag before `gh pr merge`. Web #36 and API #67 were opened that way on 2026-10-24; #36 was merged by a pasted prompt this agent wrote ("Merge API PR #64 and web PR #36") and GitHub cannot reopen a merged PR, so Emmanuel's item became issue #37 ("I have made an absolute mess, today I created 2 PRs for emmanuel they're both merged by mistake", Eddy, 2026-10-24).
- When work in any Bible Standard Group repo (iOS, API, web, data) needs a decider, a merge or a yes, it is Eddy's, the super admin's: every record is `Decider: Eddy`, never `Decider: Emmanuel`, the API's and the web's technical ones too; a pull request merges on Eddy's yes once its own gate is green (a red `Workers Builds` preview it did not cause never holds it), Emmanuel's pull requests included, since he waits on Eddy; tell Emmanuel what changed in a pull request that names him (`@emmanuelrichard01`), never hold work for his permission, and never ask Eddy whether his yes counts ("I decide, but he needs to somehow know the changes", Eddy, 2026-10-24; FS-490's D5 still made Emmanuel decider and merger: "nothing is decided by emmanuel, I am the supper admin! He is waiting for me", Eddy, 2026-10-24).
- When a file a tool writes (a gate's report, an audit's output) blocks a commit, a land or a tab close more than once, fix its cause in that session (ignore it, or stop the tool writing it into the checkout) and land the fix; never hand Eddy a prompt to remove it again ("I keep seeing this, it is clearly blocking eeverything and it should be fixed?", Eddy, 2026-10-23: `qa/bible_translation_audit.md`).
- When work touches Ruby and River (`RubyandRiver`, `rubyandriver_services`, its Shopify theme or its shop), do nothing: no rename, reconnect, check or fix, because the shop is closed ("Don't do anything with ruby and river, the shop has been closed", Eddy, 2026-10-23: its repo was renamed to `rubyandriver-shop` in a table he had approved, before he said so).
- When work is housekeeping, research, drafting, review, retros or config (anything but `/build` on a project), run it on Sonnet and hand its subagents to Sonnet; Opus is for `/build` only, or when Eddy calls for it ("things like this should not be done with Opus … opus should only be for build on projects, not what we are doing here unless called upon", Eddy, 2026-10-23: a retro and a dotfiles review ran on Opus).
- When naming the Bible Standard Group's developer or the person to invite to a Group repo (iOS, API, web, data and the clients to come), it is Emmanuel (`emmanuelrichard01`, who builds the API and the web); `OluwadaraDaily` is someone else, on none of the Group's repos, so never name OluwadaraDaily for that role ("Oluwadara no it's emmanuel bro? (emmanuelrichard01)", Eddy, 2026-10-23, FS-490).
- When a session runs at `max` effort (a `/spec`, a `/plan`, an architecture pass), spend `max` on the decisions only: once the calls are made and the one decision review is back, hand the mechanical tail (child records written from the decisions, a reviewer's fact fixes, re-checked line numbers, the flip, commit, index and push) to a worker subagent at `medium` effort, and fold a "ready with fact fixes" review without another pass; never let a `max` session run on through bookkeeping ("I don't want the effort max to run endlessly like this, max is for planning and arcgitectural stuff explicitly … This is not token efficient", Eddy, 2026-10-23: BUG-402's `/spec` ran through two context windows at `max`).
- When `/build` takes a record, build what `/spec` settled on its prototype or Motion Lab exactly as passed; never measure, re-tune or re-check a settled value in the app, and never write a build prompt that asks for it; a doubt about a settled value goes back to `/spec`'s prototype (FS-371: a 45-minute in-app sweep of a frost the prototype had settled, written into the agent's own build prompt, the fifth time: "/build is literally building what we have settled, if in doubt we settle it again on the /spec prototype! For the 5th time I am tired of trying to enforce this!", Eddy, 2026-10-23).
- When Eddy says he already wrote something down, search his own words (each noun he used, one at a time) across every decision file, record and session log before saying it is not written, and give him its ID; never conclude "not in the records" from one phrase that he did not use ("I thought I mentioned we will have nature, room, painting & abstract in the background … chosen from unsplash?", Eddy, 2026-10-23: it was FS-431, Ready To Act, missed by a search for "abstract theme").
- When you launch any long check (an audit, a gate, a capture run), launch it so it ends itself at the first red line: the tool's fail-fast flag, or a watcher in the same background command that kills it when the first failure prints, so the job's exit tells you; never let a red run carry on to its end, and never chain passes (FS-371 L9 2026-10-22: red at 22:48, seen at 23:31; again 2026-10-23: look B's audit was red in its first minutes and ran 46 min until Eddy asked "why is this still taking so long?")).
- When work in Bible Standard touches accounts, sync, profiles, friends, posts or anything the server answers, pull `~/Programming/Projects/CanonFidei/biblestandard/api` (the Cloudflare API) to its latest `main` first and spec or build against what it already serves; check what is built in the API and the app and tick it, never rewrite it or plan it as new ("With fellowship alot of it is already done, so don't rewrite … it is hosting on cloudflare … always pull and work on the latest backend!", Eddy, 2026-10-22, FS-136; the checkout was 32 commits behind).
- When a record would take more than one landing (an umbrella, a plan with slices, more than one surface, or a plan over about six steps), split it into child records before it reaches `/build`, each one landing on its own under the fast gate in a few hours, so one finishes, lands, its tab closes and the next opens; never build a big record in one tab across many gates (FS-371 took 12 whole gates) ("I don't want big tasks, small but efficient … if it can be broken in chuncks it'll finish quicker", Eddy, 2026-10-22, FS-136).
- When a turn ends while its own background job (a gate run, a reviewer agent) is still running, end it with the one-line `**Status:** WAITING` and no prompt block, and pick the work up when the job exits; never hand Eddy a resume prompt to paste ("Why do I have to paste this? What happened to the automated workflow we are building?", Eddy, 2026-10-22, FS-197).
- When designing a welcome, sign-in, onboarding or first-run moment in any app, make it a splash: a hero scene from the app's own world (in Bible Standard its rooms, book covers and authors) that arrives with motion, then the title and the actions, each with its haptic and a Reduce Motion fallback; never words alone on a plain page, and when a rule takes away a plate or card, put imagery and motion in its place rather than leaving the page bare ("we can't have just a plan screen, there ought to be animations, spashes etc.", Eddy, 2026-10-16, FS-136).
- When sending or replying to email about Bible Standard (welcome, tester, supporter or any app mail), send from `bible.standard@canonfidei.com`, never `contact@canonfidei.com`; every other activity gets its own address, so pick the one that matches the activity ("it should go out on bible.standard@ not contact@ we will do everything regarding Bible standard through this!", Eddy, 2026-10-16).
- When designing a screen, a wireframe, a Motion Lab or a motion for an iOS app, build it in iOS's own grammar: native SwiftUI controls and layouts, the system's pushes and sheets, Dynamic Type text styles, and the app's own glass, tint, `Motion` tokens and haptics. A web prototype, a web page or an example picture gives the idea only; never copy its composition, sizes or controls. The web prototype shows placement and states, and the SwiftUI lab and the app's own code set the look. Before drawing, read the app's glass and design rules and match them; in Bible Standard those are `DESIGN.md`'s Liquid Glass rules, `project/standards/LIQUID_GLASS_API.md`, the `swiftui-liquid-glass` and `swiftui-motion` skills, `design/AGENTS.md`, `Sources/AGENTS.md` and the project's Lessons. Check each call against those rules and Apple's HIG, and cite the rule it follows; a call no rule backs is named to Eddy. Never invent a look the app does not have ("Remember the app's glass rules, do not forget you are creating a native application for ios, we have many rules and design in place for the iOS, match it as you design and create motions", Eddy, 2026-10-15; again, "Don't copy the web based design too strictly, this is an iOS it ought to have an ios feel to it.", Eddy, 2026-10-16, FS-136).
- When a plan or `/spec` covers a new screen or flow in any iOS app, it carries wireframes of every state (the Vite prototype) and a Motion Lab entry for every multi-phase motion, its doors and splashes included, before `Ready To Act`. Never leave layout or motion for `/build` to invent, and never leave a door as a plain push ("We will need the plans to include wire frames, motion labs etc? … the more we plan in advance the better", Eddy, 2026-10-15, FS-136).
- When Eddy says the business is a sole trader who works with other people, do not call it a company, team or partnership in copy, and do not turn that into the headline either: name the studio and Eddy as the provider, and put any subcontracting disclosure in the terms, not the hero ("I am a sole trader but I work with other people, how do you adapt the language", Eddy, 2026-10-15).
- When Eddy has already named the answer to an open question (e.g. "the app should ship WEB"), write it into the plan as settled and never re-ask it as a picker, even when a reviewer lists it as open ("I've said this before?", Eddy, 2026-10-15).
- When Eddy asks to update the supporters or run a sync, run `~/.local/bin/sync-supporters` directly and show the diff; never walk him through Keychain, key or paste steps once the key is stored ("it should just do it!", Eddy, 2026-10-15).
- When you write the prompt that opens a `/spec` round, a grill or a review, answer one, or close a round that has landed, ask for every open decision at once with your calls (§1), the ones later rounds would ask too, so the record goes to build; never a prompt for Eddy's notes on the next round, "stop at the first question" or "show me each one in the Lab first", whatever `grill-me`'s "Ask the remaining questions one at a time" or a playbook's prototype step says. It broke four times on 2026-10-14: FS-415's D1–D3 went one per turn ("you are to think for me all at once than me choosing one by one"); FS-298's round 5 built a Lab per question, and round 6's prompt, written by the agent, asked for it again ("this has happened a few times today, can we reinforce this in the future? … this is the rule!"); FS-371's round 11 closed on "/spec FS-371 round 12 — my notes from tapping round 11: <notes>" ("Can you have all the rounds and all the decisions settled first then we can build? Isn;t this the rules for the /spec ?", Eddy). The same holds when you file a bug or record whose fix is a look or a feel: set out its decisions with your calls in that turn, so one yes makes it Ready To Act; never write "proposal, Eddy to confirm" and hand him a `/build` prompt for a record nobody settled, and call a chain of settled records a build order, never rounds (BUG-434: "You are going by rounds, can we settle what are in these rounds so you can then build it all … Is everything already settled?", Eddy, 2026-10-15).
- When a review or architecture pass finds work a record already owns in intent (a lab's look its build will promote), extend that record; never file a new one beside it (FS-412 split FS-371's spine across four records: "there are too many things happening all at once we need to clear things up", Eddy, 2026-10-14).
- When the build lanes are full, a record whose change is app code (it names a `.swift` file or a path under `Sources/App/`, or names no file) waits queued, and nobody frees a lane for it; every other ready record (tools, hooks, playbooks, records, docs, another repo) builds and lands without a lane ("you should not build anything if the lane is busy", Eddy, 2026-10-13; "can we set the cap only for Swift @Sources/App/ and allow everything else to build and be commited?", Eddy, 2026-10-24: FS-478's guard and thirteen other tool records sat behind two app builds).
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
- When people joined a mailing list by the early way (a mailto, a plain email), they consented; never mark them as unconsented because today's form has a tick box, and never list it as an open question ("They signed up to the mailing list, it was the primitive way we had it, we cannot judge it with the one we just set up!", Eddy, 2026-10-16).
