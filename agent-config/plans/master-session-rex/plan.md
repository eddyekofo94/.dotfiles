# Master session on Rex: workflow review and staged migration

Eddy, 2026-11-12: "I want to create a Master session that controls my whole
workflow that spans and closes other sessions … on a Rex multiplexer … with all
the agent specific niceties we have here on herdr … slowly migrate to Rex."

Status: AWAITING EDDY'S YES. Nothing live has changed. Every stage below needs
its own yes before it runs.

## 1. What Rex is (verified)

- **Rex** is a programmable terminal by Superlogical. It has a native macOS GUI
  over a background server that owns the PTYs, plus Linux and FreeBSD servers and
  an iOS TestFlight client. It is in invite-only testing.
  Source: https://www.superlogical.com/rex/docs/installation.
  - ⚠️ UNVERIFIED: that the author is Mitchell Hashimoto, that public testing
    opened 2026-10-05, and that Rex is closed source while in prerelease. These
    come from secondary write-ups (bitdoze.com, betterstack.com), not from
    Superlogical's own pages.
- **Model.** Rex has sessions, windows (the tab equivalent) and blocks (the pane
  equivalent). Config is Lua in `~/.config/rex/init.lua`, with `rex.bind` for
  tmux-style chords.
- **CLI** (https://www.superlogical.com/rex/docs/reference/cli.md):
  - Windows: `rex window new [-s S] [LABEL] [-- CMD]` with `-c/--cwd`, `--focus`
    (default true) and `--json`, plus `rex window ls|inspect|rename|close`.
  - Blocks: `rex block ls --json`, `rex send`, `rex send-key` and
    `rex capture --format text`.
  - Other: `rex wait TARGET`, `rex events --json`, `rex api call METHOD`,
    `rex do -e LUA`, `rex skill setup --agent claude`.
- **Agent state.** A program reports its state itself with
  `OSC 7501 ; state=… ST`. The states are idle, working, done, blocked (kinds:
  permission, question, auth), error, and clear. Rex shows these as spinners and
  badges, and Lua sees each change as `terminal.program_status_changed`.
  Source: https://www.superlogical.com/rex/docs/build/program-status.md.
- **`rex skill setup --agent claude`** writes `~/.claude/skills/rex` and adds a
  SessionStart hook to `~/.claude/settings.json`. That hook only tells the agent
  which session and block it is in. It does **not** report working, idle or
  blocked state. Source: https://www.superlogical.com/rex/docs/automate/agent-skill.
- **Not installed here.** There is no `rex` on PATH, no app in /Applications and
  no `~/.config/rex`. Getting access is step 0 of Stage 3.
- **Other things named "rex"** are unrelated: Homebrew's `rex` (rexify.org
  remote execution) and the crates.io `rex*` crates.

## 2. What the Claude Code docs say (verified unless marked)

- **Parallel work:** give each session its own checkout or worktree; name the
  sessions so they can be addressed (`--name`, `/rename`).
  Source: https://code.claude.com/docs/en/best-practices.
- **Thin long sessions:** every request resends the full conversation, and
  `/clear` between tasks is "still worth doing". Don't leave `/loop` running in a
  long conversation. Sources: https://code.claude.com/docs/en/costs.md and the
  best-practices page.
  - UNVERIFIED as an explicit doc line: "keep the coordinator thin". That is my
    inference from these pages.
- **Cross-session messaging** (v2.1.224+; v2.1.322 is installed):
  - `ListAgents` and `SendMessage` reach other local sessions. A per-session
    socket is exported as `CLAUDE_CODE_MESSAGING_SOCKET`, so hooks and scripts can
    post into a session.
  - `notify_when_idle` sends one notice when a watched session next goes idle or
    exits. A subscription lasts at most 12 hours, and only the main conversation
    can subscribe.
  - A message can't approve anything or change configuration.
  - A delivered message costs like a typed prompt: it starts a turn on full
    context.
  - Source: https://code.claude.com/docs/en/cross-session-messaging.md.
- **Agent view** (`claude --bg`, `claude agents --json` with
  `state` working|blocked|done|failed|stopped):
  - These are headless sessions under a supervisor, not multiplexer tabs, and the
    feature is a research preview.
  - Source: https://code.claude.com/docs/en/agent-view.md.
- **Agent teams** are experimental and off by default, with one team per session
  and a lead fixed for life. That makes them a poor fit for many long-lived goals.
  Source: https://code.claude.com/docs/en/agent-teams.md, as reported by a
  subagent; not re-read here.
- **Hooks:**
  - Common input: `session_id`, `transcript_path`, `cwd`.
  - Stop gets `last_assistant_message` and `stop_hook_active`.
  - Notification types include `permission_prompt` and `idle_prompt`.
  - Source: https://code.claude.com/docs/en/hooks, as reported by a subagent;
    not re-read here.
  - ⚠️ UNVERIFIED: "command hooks have no /dev/tty". This decides how a hook can
    emit OSC 7501 (Stage 3, spike S4).

## 3. Review of the current workflow

What already matches the docs and should be kept:
- One goal per tab, each in its own worktree (`herdr-goals`).
- A finished tab retires itself (`close_on_land.py` → `herdr-goal-done`).
- Idle tabs are reaped and free lanes refilled (`herdr-reap`, run by launchd
  every 2 minutes).
- Model routing comes from a table (`model_route.sh`).
- Long sessions are bounded by `build_budget_guard`, `context_guard` and
  `compact_handoff`.

**Finding A: the master's engine already exists.** `herdr-reap` already
closes, fills and continues tabs. It is a deterministic loop, which is what the
loop standard prefers. What is missing is a **front door**: one session where
Eddy sees the board and gives orders, instead of opening and closing tabs by
hand. So the master should be a thin conversational layer over the existing
scripts, not a new brain that makes those decisions with model judgment.

Ranked recommendations:

1. **Give workers one structured status record.**
   - Today the state is read three ways:
     - `herdr-reap` parses closeouts out of transcripts;
     - herdr reads the screen with the regexes in `agent-detection/claude.toml`;
     - `closeout_capture.py` keeps its own file.
   - Instead, the Stop and Notification hooks write one JSON file per session
     under `~/.local/state/agents/`. It holds the repo, record, branch, closeout
     status, next move, context tokens and a mux pane id.
   - The master, the reaper and Rex's badges all read that one file. This is the
     single highest-leverage change, and it is also the Rex prerequisite.
2. **Put the multiplexer behind an adapter.** herdr CLI calls are scattered across
   `goals.sh`, `goal_done.sh`, `reap_idle.py`, `tab_status.sh` and the hooks
   (`tab create|list|close`, `pane run|read|get|list`, `tab rename`). One `mux`
   seam with herdr and rex backends makes "slowly migrate" possible, because each
   repo can move on its own.
3. **Remove dead hook spawns.** `tmux/scripts/agent_status.py` runs on 7 events
   in every session and exits outside tmux. Each Python hook costs about 0.15 s
   (timed here), and a tool call currently pays for 4 of them. Gate the tmux
   hooks on `$TMUX`, in the shell before Python starts.
4. **Merge the overlapping session-length guards.**
   - `close_on_land` stops a build after 20 compactions or 600 turns.
   - `build_budget_guard` stops it at 2 hours, 400 turns or 2 compactions.
   - `context_guard` acts at 70% and 90% of the context window.
   - Three different limits on one concept are hard for the next agent to reason
     about. Docs: "if you have hooks for things that are only preferences,
     delete them".
   - Not in scope here; it is a candidate for its own record.
5. **Inject the closeout skeleton less often.** It is injected on every prompt,
   about 2.2k characters each time. Inject it on the first prompt and after a
   rejected turn only; the Stop hook still enforces the format.
   - Low priority. It must keep the rule mechanical.
6. **Instruction weight:** global AGENTS.md (121 lines) and the loop standard
   (186 lines) load in every session, before any project file. That is
   under the 200-line guidance for each file, but over it together. Leave it
   as is for now; revisit when Stage 1 adds the master's own skill, which should
   load on demand instead.

## 4. Eddy's requirements (2026-11-12, round 2)

He said, verbatim: "The master orchestrates the whole workflow and it is never
closed and always 1 in the tab, everything else gets a 1+ and it's a Fable agent
and it should make sure we always have something building and always builds in
batches rather than single tasks, it can open batch specs or verdicts and is
aware of the resources of the machine and doesn't overwhelm it … our loop and
whole workflow should be based on [code.claude.com/docs/en/best-practices] … I
don't want to do things that the agents can now do themselves."

He also wants the same keymaps on Rex, and `/master` on herdr now.

## 5. What we can stop doing

Source: the best-practices page, section "What you can stop doing", fetched
2026-11-12.

| Our hand-built piece | What the page says now | Call |
| :- | :- | :- |
| `context_guard.py` (70% and 90% bands, refuses tools at 90%) | "1M-token window … compaction happens on its own, so running out is rare" | Retire. Its resume file is already required (AGENTS.md §1, `/build` keeps `plan.md`), and its 90% hold is what stalls a worker. |
| `compact_handoff.py` (goal-aware summary; after a compaction, points at `plan.md` and says the goal's authorization stands) | Same row | Keep through Stage 2. Workers on a 10–20 record batch will still compact, and an unattended worker must not stop to ask for a yes afterwards. Fix: it cuts a wrapped `- [ ]` step at its first line. Retire only if a batch compacts with it off and resumes on its own. |
| `autoCompactWindow: 182000` | Same row | Keep. It caps cost, not space: each turn resends the whole context (costs.md). |
| `close_on_land` cap at 20 compactions or 600 turns; `build_budget_guard` cap at 2 compactions | Same row. `/clear` between tasks "costs nothing" | Drop the compaction caps. Each batch `/clear`s between records instead. |
| `herdr-reap` "Continue": resends the PARTIAL prompt and `/clear`s at 120k | "Tell Claude to keep going … gone. For runs nobody's watching, `/goal` or a `Stop` hook enforces it" | Replace with `/goal` on each record. The reaper keeps closing and filling tabs. |
| Closeout skeleton injected on every prompt | "If the line is getting lost in a long file, the file needs to be shorter"; "keep the enforced set small" | Keep the Stop-hook check. Inject the skeleton only after a rejected turn. |
| tmux status hooks running in herdr | "Every hook … someone has to maintain" | Gate them on `$TMUX`. |
| Our own worktree cutting and sweep | `claude -w`, `.worktreeinclude`, automatic cleanup | Keep ours for now, because the lane and naming rules live there. Revisit once the adapter exists. |

Keep: the 2-hour and two-missed-tries rules in `build_budget_guard`. They are
project rules, not context management. Also keep `repo_lock`, the routing table,
and the verdict and spec flow.

## 6. The master (design, my calls)

- **M1 Seat.** The master is tab 1: `1 master`, running Fable (`--model fable`,
  confirmed in `claude --help`).
  - It is never closed. It carries no `▸` mark, and `herdr-reap`,
    `herdr-goal-done` and `close_on_land` all skip a tab labelled `master`.
  - Herdr has no command to move a tab (`herdr tab --help`: list, create, get,
    focus, rename, close). So `window_session.sh` creates the master first,
    whenever a herdr session starts. Today's session gets it at its next restart.
  - Every other tab numbers 2 and up, as `tab_status.sh` does today.
- **M2 Something is always building.** The heartbeat stays deterministic:
  launchd's `herdr-reap` already fills free lanes every 2 minutes for the repos
  in `always-build`. The master handles the cases where nothing can fill:
  - no record is Ready: it opens a batch `/spec` tab (`herdr-goals --settle
    <track>`);
  - unjudged rows are waiting: it opens `/verdict auto`.
- **M3 Batches by default, single records when that fits** (batches settled in
  BS-IOS-TASK-1709 and `BATCH_GROUPING_2026-11-12.md`). Eddy, round 4: "not
  necessarily, it can span single tasks too". A lone record (a fix, an
  upstream dependency, a record with no batch) opens as `/build <ID>`.
  Where a batch exists, it opens:
  - `/build batch <lane>`: 10–20 Ready records in one worktree, with one gate,
    one review and one land;
  - `/spec batch <lane>` when a batch still has Spec Needed members.
  - It picks from `workflow_status.py next` and `features_index.py --batch`. In
    the grouping, the first 6 batches cover 68 Ready records.
  - One lane seat holds one batch.
  - It also closes TASK-1709's open question: `herdr-goals` and the reaper's
    fill read `batch.verb` instead of opening `/build <next[0]>`.
- **M4 Machine-aware.** Before opening anything, the master reads
  `memory_pressure`, the load average and the count of running simulators. It
  opens nothing while pressure is warn/critical or the load is above
  1.5× the core count. The repo's existing gates (BUG-349's busy machine, and
  `repo_lock` `SESSION_CAP + WORKFLOW_CAP`) still refuse on their own.
- **M5 Thin.** The master's eyes are the status files from recommendation 1.
  - The reaper wakes it with one batched message, and only for a decision:
    BLOCKED, AWAITING, the queue running dry, or the budget passing 90%.
  - It runs no `/loop`, and it `/clear`s itself daily, with the board rebuilt
    from files.
- **M6 Authority.** It closes tabs only through `herdr-goal-done`, under the
  reaper's guards. Workers keep their own permission modes.

- **M7 Icon.** The master's tab reads `1 ✻ master`, using the Claude spark glyph.
  - `tab_status.sh` cycles the glyph (✻ ✼ ✽) on each pass while the master's pane
    is live, so it pulses.
  - If the launchd pass is too slow to read as a pulse, a patch to herdr's
    reviewed source build draws it in the sidebar.
  - "Always running" means the process is always alive and wakes on events. It
    does not mean an endless turn, which would spend tokens for nothing (costs.md).
- **M8 Fable decides and judges; Opus does the work** (Eddy's image of the
  master-agent talk).
  - The master runs `/spec auto` and `/verdict auto` itself, and gives the "yes"
    that starts a settled batch.
  - It answers workers' questions that their records already settle.
  - It still escalates to Eddy:
    - one-way doors (publish, delete, external sends, money);
    - subjective visual confirmation;
    - changes to AGENTS.md.
  - Fallback: if `/usage` shows Fable's share is too high, switch the master to
    Opus. The routing table owns that switch.
- **M9 Whole workflow, every repo** (Eddy, round 4). The master runs ios, data,
  api, web and android, not just iOS, as the work needs.
  - It sequences across repos by each record's `depends on`. Example: an iOS
    record needs an API change. The master opens the API record first, waits for
    it to land, sees it merged and live, and only then opens the iOS record.
  - "Merged and live" is checked in two steps. CI runs only on pushes to
    `production` (api and web today; data, ios and android have none).
    - Locally: the worker's own repo gate passed before it landed.
    - In production: the master reads the GitHub Actions run for the merge commit
      (`gh run list --branch production --commit <sha>`, then `gh run watch`).
      Green means live. Red reopens the upstream record and holds the dependent
      one.
  - It never opens a record around its `depends on` (canonfidei.md), and it
    keeps the lane rules: one shared data/web/API lane.

## 7. Staged plan (replaces v1 §5; v1 kept in `plan.v1.bak.md`)

### Stage 1: `/master` on herdr
- [x] 1a. Status writer: the Stop and Notification hooks write
  `~/.local/state/agents/<session>.json`. Proof: fixture tests, and a live turn
  updates the file within 2 s.
- [x] 1b. `herdr-board`, read-only, with `--json`. It shows tabs, records, states,
  lanes and machine load (M4). Proof: its output matches `herdr tab list` across
  3 live tabs.
- [ ] 1c. The `/master` skill (`~/.agent-skills/master/`) with the verbs board,
  open, batch, spec, verdict, close and nudge, each mapped to one script call.
  `window_session.sh` opens `1 master` first, and the reaper, goal-done and
  close-on-land skip it (M1). Proof: restart herdr, see `1 master`, and get
  through open, board and close on a throwaway record.
- [ ] 1d. Dispatch (M3): `herdr-goals` and the reaper's fill open
  `/build batch <lane>` or `/spec batch <lane>` from `batch.verb`, and
  `/build <ID>` for a record with no batch. Proof: with fixture records,
  `--dry-run` prints the batch verb for a batch and `/build <ID>` for a lone
  record, and an iOS dry run names B1 (Home).
- [x] 1f. Cross-repo sequencing (M9): `herdr-board --deps` lists each held record,
  what it waits on, and that upstream's merge commit and CI state. The master
  opens the dependent only when the upstream is landed and its `production` run
  is green. Proof: a fixture iOS record that depends on an API record. A dry run
  opens the API record first and holds the iOS one. A stubbed green run releases
  it; a stubbed red run keeps it held.
- [x] 1e. Wake-ups (M5), per orders 2026-11-12: `notify_when_idle`, never a timer or
  `/loop`. The master subscribes (SendMessage `notify_when_idle`) to each tab it opens
  or messages, by the tab's `--name`. On a notice it runs `herdr-board --wake <name>`:
  `decide` (exit 0) for BLOCKED, AWAITING USER APPROVAL, PARTIAL or a blocked prompt,
  once per turn; `quiet` (exit 1) for DONE, a closed tab, WAITING, or a turn already
  escalated. It never re-subscribes to an idle tab (the notice would fire at once).
  Proof: `test_master_wake.py`: a BLOCKED fixture decides once, the second call is
  quiet; a DONE (landed) fixture is quiet.

### Build-tab steps (orders 2026-11-12, opened by the master)
- [x] B1. The fill opens the batch head first: `batch_boot.jq` puts the head (booting
  the batch verb) at the front of `.next` and drops the other members, so no member
  opens as a single build beside its batch. Proof: `test_batch_dispatch.py`, head
  listed after a lone record and a member also in `.next` → head opens first, member
  absent, lone record after.
- [x] B2. Tabs open with `claude --name <name>` and `AGENT_NAME=<name>` (agent_state.py
  records it as `name`, so `--wake` finds the file). Name = the tab label; a
  `/build batch <lane>` tab is `<repo>-<lane>` (`ios-home`); the master is `master`.
  Proof: goals.sh and the fill dry runs print `--name`; agent_state test reads `name`.
- [ ] B3 (1e above).
- [x] B4. The seat holds where Eddy really starts. Tonight `/master` ran in `1 ios` of
  session `window-114`: `ensure_master.sh` seated only `main`. Now (a) any session the
  login attach starts (`main` or `window-N`) gets the seat, still one master per
  machine and only a fresh lone tab; (b) `/master` typed in any tab runs
  `ensure_master.sh --here`, which labels that tab `✻ master` unless another live tab
  is master. Proof: `test_master_seat.py`, `window-5` seats; `--here` relabels
  `HERDR_TAB_ID`; `--here` with a live master elsewhere refuses. Live: needs a herdr
  restart (Eddy's), not run here.
- [x] B5. The fill opens in the master's session (master's finding 2026-11-12:
  BS-IOS-FEAT-387 landed in detached `window-113`; its fill opened BS-IOS-FEAT-342
  there, out of Eddy's sight). `herdr/master_socket.sh` prints the socket of the live
  session whose tab is labelled master; `goal_done.sh` open_tab and `goals.sh` create
  and run new tabs on it (`HERDR_SOCKET_PATH`), and fall back to the caller's own
  session when no master sits. Closing the landed tab stays in its own session.
  Proof: `test_fill_session.py`, a fill run from a worker session opens its tab in the
  master's session; with no master it opens in its own.
- Then: herdr suite + agent_state test, commit path-limited.

### Stage 2: stop doing what agents now do (§5)
- Each row is its own commit with its own test.
- `settings.json` gets a backup before each edit.
- Proof: one full batch runs with nothing in its transcript from the retired
  hooks.

### Stage 3: mux adapter; Stage 4: Rex spike; Stage 5: dual-run; Stage 6: move repos
These carry over from v1 §5, stages 2–5, unchanged. The Rex spike also ports
every herdr keymap into `~/.config/rex/init.lua`, with herdr's `MANUAL_QA.md`
key list as the proof.

## Open for Eddy (my call in brackets)
1. 👉 M8, what the master may approve in your name [starting settled batches,
   `/spec auto`, `/verdict auto`, and questions the records already settle].
   ✅ Settled 2026-11-12: Eddy said yes, and AGENTS.md §1 now says "Eddy or the
   master gives the yes", with this scope.
2. Stage 2 (§5), after `/master` works: [retire `context_guard` and Continue.
   Keep `compact_handoff` (fix its step cut) and `autoCompactWindow`, and test
   retiring the hook on one batch].
3. Master seat and icon [created first at herdr start; glyph pulse in the label,
   with a source-build patch only if the pulse can't be read].

## Resume (round 4 done)
- Round 4: M3 allows single records; M9 adds every repo, sequencing and CI checks;
  §5 keeps `compact_handoff` and the cost cap.
- Next: Eddy answers "Open for Eddy"; then a new tab builds Stage 1a–1d and 1f.

## Build log (Stage 1a–1d, 1f; Eddy's yes 2026-11-12) — resume here
- ✅ 1a: `agent-config/claude/agent_state.py`, `agent-config/tests/agent_state_test.py` (5 pass).
  Wired on Stop + Notification in `claude/settings.json` (backup
  `~/.local/state/agents-settings.json.bak-2026-11-12`; Eddy's effort hunk untouched).
  Live: a `claude -p` haiku turn wrote its file 0.74 s before exit.
- ✅ 1b: `herdr/board.py`, linked `~/.local/bin/herdr-board` (`--json`, `--gate`, `--deps`).
  Live run listed the same 5 tabs and labels as `herdr tab list`; ~7 s (lanes count).
- 1d code done: `herdr/batch_boot.jq`, used by `goals.sh` (fill + `--dry-run` alone now
  prints the fill) and `goal_done.sh` rank_fill/walk_fill (`/spec batch` opens shared,
  no lane). `herdr/tests/test_batch_dispatch.py` 6 pass. Live iOS `herdr-goals --dry-run`:
  "nothing Ready and no verdict waiting".
  Live iOS fill is empty now (next=0, 162 waiting; FEAT-372 batches alone), so B1 Home
  cannot be named live — report that, don't fake it.
- ✅ 1f: `herdr/tests/test_board_deps.py` 7 pass (not landed → hold + open api first;
  green → release; red → hold + reopen; pending → wait; no CI → live; PR slug merge
  lands; a records commit or `bs-api-feat-123` does not). Lands match merge *subjects*
  only: `merge.log` shortlogs list other branches in the body. Live: 165 held rows,
  5 release (3 real `merge: land` subjects checked), ~25 s.
- 1d: old herdr suite run, 99 pass. Fixture proof passes; live clause (names B1 Home)
  still open, so 1d stays unticked.
- 1c code done, proof NOT run (needs a herdr restart: Eddy's call, it kills live tabs).
  `~/.agent-skills/master/SKILL.md` (verbs → one script each). `herdr/ensure_master.sh`
  launched beside `ensure_plugins.sh` in `herdr/prototype/herdr_login_attach.fish`
  (deviation: window_session.sh starts no tab). Seats only session `main`, only a
  fresh lone tab 1 or one already labelled master, never a pane running an agent;
  one master per machine; off via `~/.config/herdr/no-master` or HERDR_NO_MASTER.
  Label `✻ master` (tab_status stamps `1 ✻ master`; the pulse, M7, not built).
  Guards: `goal_done.sh` refuses a master-labelled tab (or its own tab under
  AGENT_ROLE=master; `--tab <worker>` still works); `close_on_land.py` skips under
  AGENT_ROLE=master. Tests: `herdr/tests/test_master_seat.py` 6 pass,
  `close_on_land_test.py` 14 pass; herdr suite 105 pass. Live `main` is not served
  now, so `ensure_master.sh --dry-run main` stops at "never answered" (exit 75).
  LEFT: Eddy restarts herdr → see `1 ✻ master` → open, board, close a throwaway record.
- 2026-11-12 Master memory: `agent-config/master/orders.md` (Eddy's standing orders,
  incl. batch-first) and `agent-config/master/journal.md` (open items + log); the
  `/master` skill reads both on every start. Tab snapshot for the restart:
  `~/.local/state/agents/reopen-2026-11-12.txt`. Next: Eddy restarts herdr after
  BS-IOS-FEAT-1697 lands, then types `/master`.

## Resume (build tab B1–B5, 2026-11-12)
- Done, tests pass: B1 batch_boot.jq head first; B2 `--name`/AGENT_NAME (goals.sh,
  goal_done.sh, agent_state.py); B3 `herdr-board --wake` + test_master_wake.py; B4
  ensure_master.sh any session + `--here`, skill updated (~/.agent-skills/master, untracked
  there, not committed). tools/tests normalized with strip_name().
- ✅ B5 built: master_socket.sh; `hm` in goals.sh and goal_done.sh; test_fill_session.py 3 pass.
- Pre-existing at HEAD, not fixed: 8 session_worktree_test failures, `awk` on missing
  FOCUS.md exits 2 at herdr/goals.sh:~248 (no `|| true`).
