# CanonFidei working rules

Read before work in any repo under `~/Programming/Projects/CanonFidei/`. The incidents and Eddy's words
behind each rule are in `archive/canonfidei-before-audit-2026-11-12.md`.

## Partner mail

- Partner mail (Zoho: `contact@` and `bible.standard@canonfidei.com`) goes through
  `~/.dotfiles/agent-config/claude/zoho_mail.mjs` (`folders`, `list`, `read`, `attachments`, `send`, `reply`).
  Its tokens are Keychain items `cf-zoho-client-secret`, `cf-zoho-refresh-token` (read) and
  `cf-zoho-send-token` (send): you have mail access, so never ask Eddy for credentials. Partner replies sit
  in the `Bible Standard` folder; some land in `Spam`.
- Before you draft, send or report on a partner email, read the thread itself: their full latest message,
  our earlier mail to them (Sent and every IMAP folder), and the dates. Never act from a summary, a report
  row or an old draft; send only text that fits what they actually said. These emails are critical to the
  business.
- Reply with `zoho_mail.mjs reply <folder> <messageId> <body.txt>` so it stays on their thread, and end the
  body at "Eddy": the tool adds his Zoho signature (its logo needs a hosted copy in `LOGO_URL`).
- Anything about Bible Standard goes out from `bible.standard@canonfidei.com`, never `contact@`; every other
  activity has its own address. The App Store account is `eddy@canonfidei.com`, never the Gmail.
- Save source files partners send into the data repo
  (`biblestandard/data/data/library/bibles/<group>/<code>/raw/`), never `~/Downloads`.
- Before a partner call or letter, write a report on them (app, business, catalogue, channels,
  distribution, what could work for us) and a selling strategy with objections and questions in
  `canonfidei-business/biblestandard/partners/<name>-report.md`. When two or three contacts name the same
  company or tool, tell Eddy at once and research it.
- Email, partners, publishers and outreach work from `~/Programming/Projects/CanonFidei/canonfidei-business`
  (`business/` in each repo); read its `AGENTS.md` first.
- People who joined a mailing list the early way (a mailto, a plain email) consented; never mark them
  unconsented or list it as open.

## People and decisions

- Eddy is the super admin of the Bible Standard Group (iOS, API, web, data and the clients to come): every
  record is `Decider: Eddy`, the API's and web's technical ones too. Emmanuel's pull requests merge on
  Eddy's yes once their own gate is green (a red `Workers Builds` preview they did not cause never holds
  them). Tell Emmanuel what changed in a PR that names `@emmanuelrichard01`; never hold work for his
  permission, and never ask Eddy whether his yes counts.
- The Group's developer, and the only person invited to its repos, is Emmanuel (`emmanuelrichard01`, API and
  web). Never name anyone else for that role.
- A PR opened for Emmanuel to continue (its body tags `@emmanuelrichard01` with "for you to continue" or
  "what is left for you") stays open. Before any `gh pr merge`, check the body for that tag; merge only PRs
  Eddy names as his own to land. GitHub cannot reopen a merged PR.
- A passing question about legal or rights checks ("is there a trademark for …?") gets an answer and
  stops there; never file it as a task, an errand or a release gate unless Eddy asks.
- The business is a sole trader who works with other people: never call it a company, team or
  partnership in copy. Name the studio and Eddy as the provider; subcontracting goes in the terms.
- Name repos for the product (`biblestandard-qa`, `biblestandard-design`), never `canonfidei-*`; CanonFidei
  is the org.
- Ruby and River (`RubyandRiver`, `rubyandriver_services`, its Shopify theme or shop): do nothing. The shop
  is closed.

## Bible Standard operations

- Work that touches accounts, sync, profiles, friends, posts or anything the server answers: pull
  `biblestandard/api` (the Cloudflare API) to its latest `main` first, and spec or build against what it
  already serves. Tick what is built; never plan it as new.
- A data job (building, relinking or auditing packages, uploading to the R2 bucket `bs-libraries`, writing
  the manifest) runs the data repo's tool from whichever Bible Standard repo you are in; R2 belongs to data.
- A verb only iOS ships (`/verdict`, `/sweep`, `/focus`) runs in any Bible Standard repo through its router in
  `~/.agent-skills/<verb>/SKILL.md`. A verb missing from a repo is a router to add.
- To press a SwiftUI row in the simulator, use a held touch (`axe touch --down --up --delay 0.2`); a plain
  `axe tap` reports success but does not fire it.
- Supporters update or sync: run `~/.local/bin/sync-supporters` and show the diff. The key is stored; no
  Keychain or paste steps.
- When a Bible Standard address, link or name changes, change every copy you can reach that turn, across
  every CanonFidei repo and checkout (studio site, testers form, idle worktrees, setup notes).
- Build lanes: five agent-opened builds in all. Two iOS app lanes (a record that names a `.swift` file, a
  path under `Sources/App/`, or no file; a build that really edits `Sources/App/` or `Packages/` holds one
  whatever it declares), one workflow lane for every other iOS record (tools, hooks, playbooks, records,
  docs), one shared data/web/API lane, and the verdict seat. A full lane means the record waits queued;
  nobody frees a lane for it. Eddy's own tabs are never capped.
- During a track build, Eddy's input or verdict goes first: a fix record born of it goes to the front of the
  focus track's `Next:` line in `project/workflow/FOCUS.md` (a `(0000)` entry with his words), so the chain
  opens it when the current build lands. Never open, close or pause a tab for it unless he calls it urgent.
- Before Eddy leaves the chain unattended, read what the fill opens next (`features_index.py --focus
  --json`: `next`, and `waiting` for the focus track) and name it. If the focus track waits on a record that
  is not Ready, settle or flag it before he goes; never open a waiting record around its `depends on`.

## The tab chain

- Eddy's yes (a "yes", "do it", a pasted prompt) orders the whole change: tests, commit, push, and what
  else it needs. A retro's improvement that a tool, hook, guard or skill can carry is built, tested,
  committed and pushed in that run; only a change above Lessons in an `AGENTS.md` waits for him.
- When a guard or the workflow blocks the rest of a task, queue its fix as a record first and let the chain
  build it; never end on steps or a prompt for Eddy to run.
- When a build is refused or held by another tab's work (an overlap, the cap, a parked build), free it
  yourself that turn and end only once the `/build` tab is open. Read the owning tab's screen
  (`herdr pane read`) before calling it idle. For a lane your own paused build holds: commit it, copy its
  plan to `~/Archive/github-backup/parked-notes/<ID>/`, `git worktree unlock` and `remove` it, then
  `herdr-goals --build <ID>`.
- "Close this tab and open a new one with:": do both yourself that turn. `herdr tab create`, `herdr pane run`,
  check it took the prompt (`herdr pane read`), then `herdr tab close` your own tab (from
  `herdr pane current`) as the last call.
- A tab that cannot run the next move (a guard refuses `/build` in a housekeeping or retro tab): open the
  prompt with "Close this tab and open a new one with:" and the `/build <ID>` line.
- A turn in an agent-opened (`▸`) tab that ends DONE or BLOCKED with nothing unlanded offers no close:
  `herdr-reap` closes it after 10 idle minutes and refills the lanes. In Eddy's own tabs (no `▸`), keep the
  line naming `herdr-goal-done` and run it when he says close.
- A prompt that continues a skill pinning a model (`/spec`, `/build` on Opus) starts with that slash
  command; a plain "yes" runs on the tab's default model.
- Models follow global `AGENTS.md` §3. When Eddy questions a tab's effort or model, take it as the
  correction: say what the level costs and what set it, and fix that setting in the same session.
- When Eddy names an order mid-task ("X runs first"), stop the current work that turn: park it as a WIP
  commit with a resume note and start X.
- A long check (audit, gate, capture run) ends itself at the first red line: the tool's fail-fast flag, or a
  watcher in the same background command. Never let a red run carry on, and never chain passes.
- A turn that ends while its own background job runs ends with the one-line `**Status:** WAITING` and
  picks the work up when the job exits.
- When another tab looks idle, read its session log for a background job before calling it stalled.
- When a push or merge lands, read the GitHub Actions run for that commit (where the repo has CI) before
  calling it done.
- A file a tool writes into the checkout that blocks a commit, land or close more than once gets its cause
  fixed that session (ignore it, or move the tool's output).
- Changes that would reach Codex or Pi (a wrapper, a hook, a harness route) are built for Claude only; a
  record that exists only for them is parked `Deferred — later`.

## Eddy's words

- When Eddy has already named the answer (a settled decision, the ask in front of you), build exactly that:
  never re-ask it as a picker, turn it into a fork, or recommend the other way. Tell him a cost you find as
  the cost of his way, with its fix.
- When Eddy says he already wrote something down, search each noun he used, one at a time, across every
  decision file, record and session log before saying it is not written, and give him its ID.
- When a tool behaviour "was working before", diff that logic across the installed versions
  (`~/.local/share/claude/versions/*`) and reproduce it live (tmux `send-keys`/`capture-pane`) before
  proposing anything; never offer substitute keybinds he did not ask for.
