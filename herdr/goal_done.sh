#!/bin/bash
# goal-done: retire a finished goal tab and start the next goal in a new one.
#
# The end of a ticket is the one moment the workflow had no gesture for. The
# work merges, and the tab stays open on a worktree that is now a duplicate of
# `main`, holding a cap slot (FS-097), while the next thing to
# do sits unranked. Eddy then closes the tab by hand, opens another, and types
# the same prompt. This is that sequence, once, in the right order:
#
#   1. refuse unless the branch is genuinely merged  (nothing is thrown away)
#   2. release any path claim (a no-op since FS-153 D1: a worktree holds none)
#   3. sweep the worktree and shut down its QA simulators (frees the slot)
#   4. advance: resume each orphaned build in its own checkout (D9), then
#      open a fresh same-agent `/build <ID>` tab for every free build
#      lane, one per track first, then more from a busy track (FS-130 D3,
#      BibleStandard FS-262 D5); then the verdict lane when unjudged agent rows
#      wait and its seat is free (D3). Never a grill (D4); when nothing can
#      open, it says so and opens nothing
#   5. close the tab this ran in                     (last: it kills us)
#
# Step 5 is why the order matters and why the new tab is created before
# anything is destroyed: if tab creation fails there is still a live session
# holding the evidence of why.
#
# Claude opens at the routing table's model and effort (BS-IOS-FEAT-597). Codex and Pi stay in
# their current agent family and inherit that agent's configured model and
# permissions.
#
# Usage:
#   goal-done                 # from inside the finished goal's worktree
#   goal-done --force         # skip the merged check (branch is kept)
#   goal-done --park          # a stuck build: park its branch, free its lane
#   goal-done --park --for <ID>  # Eddy's order: park a still-Ready build for
#                                   # Queue: first <ID>, and open /build <ID> first
#   goal-done --keep-tab      # open the next tab, leave this one open
#   goal-done --no-todo       # just retire; do not advance or open anything
#   goal-done --dry-run       # print the five steps, change nothing
#   goal-done --tab <id>      # retire another tab (reap), not this one
#   goal-done --fill <repo>   # retire nothing: only fill <repo>'s free lanes
#   goal-done --name <ID>     # print the tab/worktree name for a ticket ID
#   goal-done --handoff <ID>  # a build past its time budget: open a fresh
#                                   # `/build <ID>` tab on this checkout, close this one
set -uo pipefail

# Ticket IDs come in two forms (FS-490 D2, FS-515): the new `<REPO>-<KIND>-<N>`
# (`IOS-FEAT-515`, slug `ios-feat-515`; `BS-IOS-FEAT-537`, slug `bs-ios-feat-537`,
# BibleStandard IOS-FEAT-537) and the old `FS-515` / `BUG-402` /
# `API-14` / `FW-123` (slug `fs515`, dashes dropped, FS-490 R1).
NEW_ID='(bs-)?[a-z]+-(feat|bug|task)-[0-9]+'
OLD_ID='[a-z]+[0-9]+'
id_slug() {
  local id
  id=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  if printf '%s' "$id" | grep -Eq "^${NEW_ID}\$"; then printf '%s\n' "$id"
  else printf '%s\n' "$id" | tr -d '-'; fi
}
# The goal ID a worktree slug starts with (`ios-feat-515-x` -> `ios-feat-515`).
slug_goal_id() {
  printf '%s' "$1" | sed -E "s/^(${NEW_ID}|${OLD_ID}).*/\\1/"
}

FORCE=0
PARK=0
PARK_FOR=""
KEEP_TAB=0
OPEN_TODO=1
DRY=0
BOOT=""
BOOT_SET=0
TARGET_TAB=""
FILL_REPO=""
HANDOFF=""
# The build budget guard reads this in the new tab's first message: a second hand-off
# in a row on one record parks and splits it (build_budget_guard.py HANDED_OFF).
HANDOFF_NOTE="handed off (build budget): read the plan file's Progress, then go on"

while [ $# -gt 0 ]; do
  case "$1" in
    --force)    FORCE=1 ;;
    --park)     PARK=1 ;;
    --for)      PARK_FOR="${2:?--for needs the record ID}"; shift ;;
    --keep-tab) KEEP_TAB=1 ;;
    --no-todo)  OPEN_TODO=0 ;;
    --dry-run)  DRY=1 ;;
    --name)     id_slug "${2:?--name needs a ticket ID}"; exit 0 ;;
    --boot)     BOOT="${2:?--boot needs a value}"; BOOT_SET=1; shift ;;
    --tab)      TARGET_TAB="${2:?--tab needs a tab id}"; shift ;;
    --fill)     FILL_REPO="${2:?--fill needs a repository root}"; shift ;;
    --handoff)  HANDOFF="${2:?--handoff needs the record ID}"; shift ;;
    -h|--help)  sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "goal-done: $*" >&2; exit 1; }
[ -z "$PARK_FOR" ] || [ "$PARK" = 1 ] || die "--for takes --park"

# Eddy, 2026-10-02: while this file exists a finished goal retires without
# opening the next tab, as if `--no-todo`. `rm` it to resume the chain.
CHAIN_PAUSE="${HERDR_CHAIN_PAUSE:-$HOME/.config/herdr/chain-paused}"
if [ "$OPEN_TODO" = 1 ] && [ -e "$CHAIN_PAUSE" ]; then
  OPEN_TODO=0
  echo "goal-done: chain paused ($CHAIN_PAUSE) — retiring without opening a tab" >&2
fi

# Every step that destroys or creates something goes through this, so --dry-run
# covers the real sequence rather than a second copy of it that can drift.
run() {
  if [ "$DRY" = 1 ]; then echo "would run: $*"; return 0; fi
  "$@"
}

command -v jq >/dev/null || die "jq required"
# BS-IOS-FEAT-597: every tab's model and effort come from the routing table.
# A copy of this script without its helper still opens Sonnet medium, never Opus.
route_helper="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/model_route.sh"
if [ -f "$route_helper" ]; then . "$route_helper"; else
  ROUTE_MODEL=sonnet; ROUTE_EFFORT=medium
  model_route() { :; }
  echo "herdr: no ${route_helper} — opening sonnet medium (BS-IOS-FEAT-597)" >&2
fi

# Master plan B6/B7: a fill never opens a tab; open_tab queues it for the master, live
# or not (it opens the queue on its next wake or seat). `hm` is herdr aimed at the
# master's session; closing or reading the caller's own tab stays plain `herdr`.
MASTER_SOCK=$("$(dirname "$(readlink -f "$0")")/master_socket.sh" 2>/dev/null || true)
hm() { if [ -n "$MASTER_SOCK" ]; then HERDR_SOCKET_PATH="$MASTER_SOCK" herdr "$@"; else herdr "$@"; fi; }
NEXT_QUEUE="${AGENT_STATE_DIR:-$HOME/.local/state/agents}/next.tsv"

# The session's `--name`: its tab label, or `<repo>-<lane>` (`ios-home`) for a
# `/build batch <lane>` tab, which is labelled for its head record's worktree.
agent_name() {  # label boot
  case "$2" in
    "/build batch "*) printf '%s-%s' "$(basename "${shared:-repo}")" \
      "$(printf '%s' "${2#/build batch }" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')" ;;
    *) printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' ;;
  esac
}

# Open one agent tab and start its session. The `▸ ` marks a tab an agent
# opened (FS-237 D8); repo_lock keeps it.
open_tab() {  # cwd label boot model mode [effort]
  local tab_cwd="$1" tab_label="$2" boot="$3" model="$4" tab_mode="$5" launch pane effort
  # The caller passes the routing table's pair (BS-IOS-FEAT-597); a record the
  # graph marks escalated opens once at high (BibleStandard BS-IOS-TASK-1140).
  effort="${6:-medium}"
  if [ "$session_agent" = "claude" ]; then
    # Orders 2026-11-12: every tab is named, so the master can message it and get a
    # `notify_when_idle` notice; `AGENT_NAME` lets agent_state.py record the name.
    launch="env AGENT_NAME=$(agent_name "$tab_label" "$boot") claude --name $(agent_name "$tab_label" "$boot") --model ${model} --effort ${effort} ${tab_mode} \"${boot}\""
  elif [ "$session_agent" = "codex" ]; then
    launch="codex \"${boot}\""
  else
    launch="pi \"${boot}\""
  fi
  # Master plan B6/B7: the master is the one dispatcher, live or not. The fill queues
  # the tab in NEXT_QUEUE; the master opens it with `open-next` on its `landed`
  # wake, or on its seat sweep when it was down.
  if [ "$DRY" = 1 ]; then
    echo "would queue: ▸ $tab_label — ${boot}"
    echo "  cwd: ${tab_cwd}"
    echo "  launch: ${launch}"
    return 0
  fi
  mkdir -p "$(dirname "$NEXT_QUEUE")"
  printf '%s\t%s\t%s\t%s\t%s\n' "${AGENT_NAME:-$(basename "$PWD")}" "$tab_cwd" "▸ $tab_label" "$boot" "$launch" >> "$NEXT_QUEUE"
  echo "goal-done: queued ${boot} for the master (open-next) — ${tab_cwd}"
  return 0
}

# `--tab`: retire that tab as if this ran inside it — its pane, its checkout,
# its agent — so `reap` can close an idle tab from outside (Eddy,
# 2026-10-04: "I don't want to clog space with idle sessions").
if [ -n "$TARGET_TAB" ]; then
  target=$(herdr pane list 2>/dev/null |
    jq -c --arg tab "$TARGET_TAB" '[.result.panes[]? | select(.tab_id == $tab)][0] // empty') || target=""
  [ -n "$target" ] || die "no Herdr pane in tab $TARGET_TAB"
  HERDR_TAB_ID="$TARGET_TAB"
  HERDR_PANE_ID=$(jq -r '.pane_id' <<<"$target")
  HERDR_GOAL_DONE_AGENT=$(jq -r '.agent // empty' <<<"$target")
  cwd=$(jq -r '.cwd' <<<"$target")
  # A checkout already removed (swept after its land) leaves nothing on disk
  # to lose, and its branch stays in git: close the tab rather than strand it
  # (BS-IOS-BUG-679, 2026-10-26: TASK-626's landed tab stuck open).
  if [ ! -d "$cwd" ]; then
    herdr tab close "$TARGET_TAB" >/dev/null && echo "goal-done: tab $TARGET_TAB closed; its checkout $cwd was already gone" >&2
    exit 0
  fi
  cd "$cwd" || die "cannot enter tab $TARGET_TAB's checkout"
fi

# `--fill`: step 4 alone, for a lane that freed with no tab retiring — a build
# parked, a claim lapsed, a record turned Ready while a lane sat free. Eddy,
# 2026-10-04: "when there's a free lane, if I am not there the harness should
# go on". `reap` runs it every pass; the manager's gate still says no to
# a full cap or a busy machine (BUG-349), so it never piles builds up.
if [ -n "$FILL_REPO" ]; then
  [ "$OPEN_TODO" = 1 ] || exit 0
  cd "$FILL_REPO" || die "cannot enter $FILL_REPO"
  KEEP_TAB=1
  HERDR_GOAL_DONE_AGENT="${HERDR_GOAL_DONE_AGENT:-claude}"
  HERDR_TAB_ID="${HERDR_TAB_ID:-fill}"
fi

[ -n "${HERDR_TAB_ID:-}" ] || die "not inside a Herdr pane (no \$HERDR_TAB_ID)"

caller_agent="${HERDR_GOAL_DONE_AGENT:-}"
if [ -z "$caller_agent" ] && [ -n "${HERDR_PANE_ID:-}" ]; then
  caller_agent=$(herdr pane get "$HERDR_PANE_ID" 2>/dev/null |
    jq -r '.result.pane.agent // empty') || true
fi
if [ -z "$caller_agent" ]; then
  if [ -n "${CLAUDECODE:-}" ]; then
    caller_agent=claude
  elif [ -n "${CODEX_SESSION_ID:-}" ]; then
    caller_agent=codex
  elif [ -n "${PI_SESSION_ID:-}" ] || [ -n "${PI_CODING_AGENT_DIR:-}" ]; then
    caller_agent=pi
  else
    caller_agent=claude
  fi
fi
case "$caller_agent" in
  claude|codex|pi) session_agent="$caller_agent" ;;
  openai) session_agent=codex ;;
  *) die "unsupported caller agent: $caller_agent" ;;
esac

# Master plan M1: the master's seat is never retired — not by its own turn, not by
# the reaper's `--tab`, not by close-on-land. It closes workers with `--tab <id>`.
if [ -z "$FILL_REPO" ]; then
  tab_label=$(herdr tab list 2>/dev/null |
    jq -r --arg tab "$HERDR_TAB_ID" '.result.tabs[]? | select(.tab_id == $tab) | .label' 2>/dev/null) || tab_label=""
  tab_name=$(printf '%s' "$tab_label" | sed -E 's/^\[?[0-9]+\]? *//; s/^[✻✼✽ ]+//')
  if [ "$tab_name" = master ] || { [ -z "$TARGET_TAB" ] && [ "${AGENT_ROLE:-}" = master ]; }; then
    die "refused: tab $HERDR_TAB_ID is the master's seat"
  fi
fi

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not in a git repository"
# --git-common-dir points at the *shared* .git even from a linked worktree, so
# this resolves the main checkout without knowing the naming convention.
common=$(cd "$root" && git rev-parse --git-common-dir)
case "$common" in /*) ;; *) common="$root/$common" ;; esac
shared=$(dirname "$common")
slug=$(basename "$root")

# `--handoff`: the build budget guard held a build on time, compactions or turns
# (Eddy, 2026-10-30: "the limit is good but we should temporarily handoff where we
# are and create a new tab with the context"). FS-262 D9's resume, on this checkout:
# nothing is checked, swept or released; the branch, its dirt, its simulator and its
# lane stay for the fresh tab, which reads the plan file this session left.
if [ -n "$HANDOFF" ]; then
  [ -z "$FILL_REPO" ] && [ "$PARK" = 0 ] || die "--handoff takes neither --fill nor --park"
  [ "$root" != "$shared" ] || die "--handoff takes a goal's worktree, not the shared checkout"
  model_route "$shared" build app
  open_tab "$root" "$slug" "/build ${HANDOFF} — ${HANDOFF_NOTE}" "$ROUTE_MODEL" "--permission-mode auto" "$ROUTE_EFFORT"
  if [ "$KEEP_TAB" = 0 ]; then
    run herdr tab close "$HERDR_TAB_ID" ||
      echo "goal-done: could not close $HERDR_TAB_ID; close it with prefix+X" >&2
  fi
  exit 0
fi

if [ -n "$FILL_REPO" ]; then
  # Nothing retires: no branch to check, no worktree to sweep.
  [ "$root" = "$shared" ] || die "--fill takes the shared checkout, not a worktree ($root)"
  slug=""
elif [ "$root" = "$shared" ]; then
  # A tab in the shared checkout owns no worktree and no branch of its own.
  slug=""
  echo "goal-done: shared checkout — nothing to sweep, retiring the tab only"
else
  branch=$(cd "$root" && git rev-parse --abbrev-ref HEAD)
  dirty=$(cd "$root" && git status --porcelain)
  # FS-262 D9: a stuck build parks instead — its dirt and its unmerged branch
  # go to `parked/<slug>`, where `open <id>` resumes them, and its lane frees.
  if [ "$PARK" = 1 ]; then
    echo "goal-done: --park — $slug's work goes to parked/$slug; its lane frees"
  else
    [ -z "$dirty" ] || [ "$FORCE" = 1 ] || die "$slug has uncommitted changes; commit, --park a stuck build, or --force"
    # Merged means "main already contains this HEAD" — true after a --no-ff merge
    # and equally true for a branch that never diverged. Either way nothing is
    # lost by sweeping it.
    # BS-IOS-BUG-857: a records-only branch lands on main as a fresh commit, so
    # ancestry fails though main holds every byte. Landed also means each path
    # the branch changed since the merge-base is identical on main.
    if ! (cd "$shared" && {
        git merge-base --is-ancestor "$branch" main ||
        git diff -z --name-only "$(git merge-base main "$branch")" "$branch" |
          xargs -0 git diff --quiet main "$branch" --
      }) 2>/dev/null; then
      [ "$FORCE" = 1 ] || die "main does not contain $branch yet; merge it first, --park a stuck build, or --force"
      echo "goal-done: --force with $branch unmerged — keeping the branch"
    fi
  fi
fi

# The claim and the worktree are project mechanics: only touch them where the
# project actually implements them, so this stays usable in other repos.
if [ -n "$slug" ] && [ -f "$root/tools/repo_lock.py" ]; then
  # The worktree's *own* copy of the script, not the shared tree's: repo_lock
  # reads its checkout from `__file__`, not from the cwd, and needs no session
  # id there. Invoking the shared copy made it demand $CLAUDE_SESSION_ID, which
  # is not exported into an agent's shell — the release failed every time.
  # Since FS-153 D1 a worktree takes no claims, so this normally finds nothing
  # and says so; it stays because a checkout that predates D1 may still hold one.
  (cd "$root" && run python3 tools/repo_lock.py release) ||
    echo "goal-done: could not release the path claim (it lapses on its own)" >&2
fi

if [ -n "$slug" ] && [ -f "$shared/tools/session_worktree.py" ]; then
  # Leave the current directory before it is removed, or every later command
  # runs from a deleted inode.
  cd "$shared" || die "cannot enter $shared"
  if [ "$PARK" = 1 ]; then
    run python3 tools/session_worktree.py park "$slug" ${PARK_FOR:+--for "$PARK_FOR"} ||
      die "worktree $slug not parked — tab left open so the reason is readable"
  elif [ "$slug" = verdict-drain ]; then
    # FS-262 D3: the drain reopens on current `main`, never on its old branch.
    run python3 tools/session_worktree.py remove "$slug" --delete-branch ||
      die "worktree $slug not swept — tab left open so the reason is readable"
  else
    run python3 tools/session_worktree.py remove "$slug" ||
      die "worktree $slug not swept — tab left open so the reason is readable"
  fi
fi

# Every repo's finished worktrees, not just this goal's: merged, clean, tab gone
# (Eddy, 2026-10-24). A dry run until ~/.config/herdr/worktree-sweep reads "on".
if [ "$DRY" != 1 ]; then
  python3 "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/worktree_sweep.py" --auto >&2 ||
    echo "goal-done: worktree sweep failed (the tab closes anyway)" >&2
fi

# The goal's QA simulators go with its worktree (Eddy, 2026-09-25: "can we have
# a way that simulators close after the task is done?"). `sim_input.py acquire`
# names each one `BS QA <goal slug>`; nothing retired them, so six sat booted.
# Shut down, not deleted: the pool reuses a device, and a shutdown one costs
# no memory. Other goals' simulators are untouched — theirs close when they do.
[ "$DRY" = 1 ] && [ -n "$slug" ] && echo "goal-done: goal $(slug_goal_id "$slug")"
if [ -n "$slug" ] && command -v xcrun >/dev/null; then
  goal_id=$(slug_goal_id "$slug")
  # Its bookings go too, so the device reads free at once rather than busy for
  # 6 hours (BibleStandard IOS-TASK-563); release shuts each one down.
  if [ -f "$shared/tools/sim_input.py" ]; then
    (cd "$shared" && run python3 tools/sim_input.py release-goal "$slug" "$goal_id") >&2 ||
      echo "goal-done: could not release the goal's simulator leases" >&2
  fi
  while IFS= read -r udid; do
    [ -n "$udid" ] || continue
    run xcrun simctl shutdown "$udid" >/dev/null 2>&1 ||
      echo "goal-done: could not shut down simulator $udid" >&2
  done < <(xcrun simctl list devices booted 2>/dev/null |
             grep -E "BS QA (${slug}|${goal_id})( |-)[^(]*\(|BS QA (${slug}|${goal_id}) \(" |
             sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  # Simulator.app stays open with no device booted; it quits only when none is.
  [ -f "$shared/tools/sim_input.py" ] &&
    (cd "$shared" && run python3 tools/sim_input.py quit-idle) >/dev/null 2>&1
fi

# FS-130 D3, as filled by BibleStandard FS-262 D5: the finished tab starts the
# next goals itself — one `/build` tab per free build lane, walking the work
# graph's fill order (`--focus --json` `next`: one per track first, then the
# rest). Each open is gated by the repository's manager: exit 3 is a full
# build cap (the builds stop), exit 4 is a record whose seams overlap a live
# build (it waits; try the next). Then the verdict lane (D3), which a full
# build cap never blocks. Never a grill: grilling is Eddy's (D4).

opened=0
resumed=0
tried=0
cap_full=0
waiting=""
verdict_opened=0
# BibleStandard BS-IOS-TASK-1428: why each ranked record did not open goes to
# the chain log as it happens, so a tab killed mid-fill (1356's, exit 137) still
# leaves the reason on disk; the stop line names the last one.
chain_log="${HERDR_CHAIN_LOG:-$HOME/.local/state/herdr/chain.log}"
last_refusal=""
chain_note() {
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$(dirname "$chain_log")" &&
    printf '%s %s (after %s)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" "${goal_id:-${slug:-fill}}" >>"$chain_log"
}
refused() {  # id why
  last_refusal="$1 — $2"
  echo "goal-done: refused: $1 — $2" >&2
  chain_note "skipped $1 — $2"
}
# Eddy, 2026-11-09 ("If spec is needed tell me ... it just stopped"): the log and
# a passing notification went unseen, so a stop only a /spec can clear opens that
# /spec as a tab: one blocker at a time, and not again for 12 h if it is closed.
open_spec_blocker() {  # the Spec Needed blockers, one per line
  local id marker state_dir
  state_dir=$(dirname "$chain_log")
  mkdir -p "$state_dir"
  while read -r id; do
    [ -n "$id" ] || return 0
    [ -z "$(find "$state_dir/spec-opened-$id" -mmin -720 2>/dev/null)" ] || return 0
  done <<<"$1"
  id=$(head -n 1 <<<"$1")
  marker="$state_dir/spec-opened-$id"
  touch "$marker"
  model_route "$shared" spec --record "$id"
  if ( open_tab "$shared" "spec-$(id_slug "$id")" "/spec $id" "$ROUTE_MODEL" "--permission-mode auto" "$ROUTE_EFFORT" ); then
    chain_note "opened /spec $id: the chain waits on it"
  else
    rm -f "$marker"
    chain_note "could not open /spec $id"
  fi
}
# The work graph that names the next record: iOS's features_index.py, else a repo's
# records.py (BibleStandard BS-DATA-TASK-84: the data checkout, one build at a time).
focus_tool=""
if [ -f "$shared/tools/features_index.py" ]; then focus_tool=tools/features_index.py
elif [ -f "$shared/tools/records.py" ] && [ -f "$shared/tools/session_worktree.py" ]; then focus_tool=tools/records.py
fi
# Rank the graph's fill order into $focus_json and $fill.
rank_fill() {
  focus_json=$( (cd "$shared" && python3 "$focus_tool" --focus --json 2>/dev/null) ) || focus_json="{}"
  # Eddy, 2026-10-24 ("these other tabs have to wait till we split these files"):
  # a focus track marked `- Exclusive: yes` in FOCUS.md opens only its own records.
  exclusive=$(awk '/^### /{name=substr($0,5); f=0} /^- State: focus/{f=1} f && /^- Exclusive: yes/{print name; exit}' "$shared/project/workflow/FOCUS.md" 2>/dev/null)
  if [ -n "$exclusive" ]; then
    # A record the track's own records wait on opens too, whatever its track:
    # filtering it out deadlocked the chain (2026-11-03: BS-IOS-TASK-886 and
    # FEAT-867 waited on untracked BS-IOS-BUG-402 and 997, so nothing opened).
    focus_json=$(jq -c --arg ex "$exclusive" '([.waiting[]? | select(.track == $ex) | .waiting_on[]?]) as $need | .next |= map(select(.track == $ex or (.id as $i | any($need[]; . == $i)))) | .resume |= ((. // []) | map(select(.track == $ex)))' <<<"$focus_json" 2>/dev/null) || focus_json="{}"
  fi
  # Master plan 1d (M3): the batch head boots the batch's verb (batch_boot.jq).
  batch_jq="$(dirname "$(readlink -f "$0")")/batch_boot.jq"
  [ -f "$batch_jq" ] && focus_json=$(jq -c -f "$batch_jq" <<<"$focus_json" 2>/dev/null || printf '%s' "$focus_json")
  # FS-262 D9: orphaned builds first, each in its own checkout (`slug`); they
  # already hold their lanes. Then the new records.
  fill=$(jq -c '(.resume[]? | . + {resume: true}), .next[]?' <<<"$focus_json" 2>/dev/null) || fill=""
  # BibleStandard BS-IOS-TASK-1250: the record a `--park --for` freed the lane for opens
  # first, whatever the ranking says, and only once.
  if [ -n "$PARK_FOR" ]; then
    fill=$(jq -nc --arg id "$PARK_FOR" '{id: $id}'; jq -c --arg id "$PARK_FOR" 'select(.id != $id)' <<<"$fill" 2>/dev/null)
  fi
}
if [ "$OPEN_TODO" = 1 ] && [ -n "$focus_tool" ]; then
  rank_fill
  manager_help=$(cd "$shared" && python3 tools/session_worktree.py open --help 2>&1)
  place_flag=()
  # This open runs in the finishing tab, for the next goal's tab: a manager
  # that knows `--place` must not name this one after it (BibleStandard BUG-313).
  if grep -Eq -- '(^|[[:space:]])--place([[:space:]=]|$)' <<<"$manager_help"; then
    place_flag=(--place)
  fi
  dry_flag=()
  if [ "$DRY" = 1 ] && grep -Eq -- '(^|[[:space:]])--dry-run([[:space:]=]|$)' <<<"$manager_help"; then
    dry_flag=(--dry-run)
  fi
  # A dry open holds no lane, so the walk counts its own would-opens against
  # the free lanes; a real run lets exit 3 say when to stop (BibleStandard BUG-410).
  free=""
  if [ "$DRY" = 1 ]; then
    # The finishing checkout is still on disk in a dry run; a real run has
    # swept it by now, so its lane is free — but only if it counts at all (a
    # landed checkout already does not).
    free=$(cd "$shared" && GOAL_DONE_SLUG="$slug" python3 -c 'import os, sys; sys.path.insert(0, "tools")
import repo_lock, session_worktree
held = [s for s in session_worktree.slot_details() if s.get("kind", "worktree") == "worktree" and s["name"] != os.environ.get("GOAL_DONE_SLUG")]
print(max(repo_lock.SESSION_CAP + repo_lock.WORKFLOW_CAP - getattr(session_worktree, "seats_taken", len)(held), 0))' 2>/dev/null) || free=""
  fi
  # BS-IOS-FEAT-597: a build's pair is asked once per run, not per record.
  model_route "$shared" build app
  build_model="$ROUTE_MODEL"; build_effort="$ROUTE_EFFORT"
  # One walk of $fill: open a build tab per free lane, log each refusal.
  walk_fill() {
  while IFS= read -r record; do
    [ -n "$record" ] || continue
    next_id=$(printf '%s\n' "$record" | jq -r '.id // empty')
    next_track=$(printf '%s\n' "$record" | jq -r '.track // empty')
    next_paths=$(printf '%s\n' "$record" | jq -r '(.owned_paths // .paths // [])[]?')
    resuming=$(printf '%s\n' "$record" | jq -r '.resume // false')
    next_effort=$(printf '%s\n' "$record" | jq -r '.effort // empty')
    next_model="$build_model"; next_effort="${next_effort:-$build_effort}"
    next_boot=$(printf '%s\n' "$record" | jq -r '.boot // empty')
    [ -n "$next_id" ] || continue
    # Master plan 1d: a `/spec batch` settles in the shared checkout, takes no lane.
    case "$next_boot" in "/spec batch "*)
      spec_label="spec-batch-$(printf '%s' "${next_boot#/spec batch }" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"
      if hm tab list 2>/dev/null | jq -r '.result.tabs[]?.label' 2>/dev/null | grep -q "▸ ${spec_label}$"; then
        echo "goal-done: ${spec_label} is already open" >&2
      else
        model_route "$shared" spec app
        open_tab "$shared" "$spec_label" "$next_boot" "$ROUTE_MODEL" "--permission-mode auto" "$ROUTE_EFFORT"
      fi
      continue ;;
    esac
    tried=$((tried + 1))
    # The id is all this step knows, so the name it can build is `fs094` — while
    # the goal's checkout may be `fs094-offers`. `open` adopts the existing tree
    # for a bare id (FS-099), and the tab is labelled from the path it got. A
    # resume names its checkout outright.
    label=$(printf '%s\n' "$record" | jq -r '.slug // empty')
    [ -n "$label" ] || label=$(id_slug "$next_id")
    worktree_args=(open "$label" --goal "$next_id" ${place_flag[@]+"${place_flag[@]}"})
    if [ -n "$next_paths" ]; then
      if grep -Eq -- '(^|[[:space:]])--path([[:space:]=]|$)' <<<"$manager_help"; then
        while IFS= read -r owned_path; do
          [ -n "$owned_path" ] && worktree_args+=(--path "$owned_path")
        done <<<"$next_paths"
      elif grep -Eq -- '(^|[[:space:]])--paths([[:space:]=]|$)' <<<"$manager_help"; then
        worktree_args+=(--paths)
        while IFS= read -r owned_path; do
          [ -n "$owned_path" ] && worktree_args+=("$owned_path")
        done <<<"$next_paths"
      else
        echo "goal-done: worktree manager has no owned-path interface; skipping ${next_id}" >&2
        refused "$next_id" "the worktree manager has no owned-path interface"
        continue
      fi
    fi
    boot="${next_boot:-/build ${next_id}}"
    # FS-262 D9: a resumed branch was cut before main's record; it merges first.
    [ "$resuming" = true ] && boot="${boot} — resumed (FS-262 D9): git merge main first"
    if [ "$BOOT_SET" = 1 ] && [ "$opened" = 0 ]; then boot="$BOOT"; fi
    if [ "$DRY" = 1 ]; then
      if [ "$resuming" != true ] && [ -n "$free" ] && [ "$((opened - resumed))" -ge "$free" ]; then
        cap_full=1; waiting="$next_id"; break
      fi
      worktree_args+=(${dry_flag[@]+"${dry_flag[@]}"})
      printf 'would run: python3 tools/session_worktree.py'
      printf ' %q' "${worktree_args[@]}"
      printf '\n'
      if [ "${#dry_flag[@]}" = 0 ]; then
        echo "goal-done: ${next_id}: gate not asked — this manager has no open --dry-run"
        echo "would advance to: ${next_id}${next_track:+ (${next_track})}"
        open_tab "<resolved by repository worktree manager>" "$label" "$boot" "$next_model" "--permission-mode auto" "$next_effort"
        opened=$((opened + 1))
        [ "$resuming" = true ] && resumed=$((resumed + 1))
        continue
      fi
    fi
    open_err=$(mktemp)
    if cwd=$(cd "$shared" && HERDR_GROUP_LANE_OPENER=1 python3 tools/session_worktree.py "${worktree_args[@]}" 2>"$open_err"); then
      cat "$open_err" >&2; rm -f "$open_err"
      [ "$DRY" = 1 ] && echo "would advance to: ${next_id}${next_track:+ (${next_track})}"
      open_tab "$cwd" "$(basename "$cwd")" "$boot" "$next_model" "--permission-mode auto" "$next_effort"
      opened=$((opened + 1))
      [ "$resuming" = true ] && resumed=$((resumed + 1))
    else
      rc=$?
      # The manager's own last line says why (for exit 4, the clashing build).
      cat "$open_err" >&2
      why=$(grep -v '^[[:space:]]*$' "$open_err" | tail -n 1)
      rm -f "$open_err"
      case "$rc" in
        3) refused "$next_id" "build lanes full${why:+: $why}"
           cap_full=1; waiting="$next_id"; break ;;
        4) echo "goal-done: ${next_id}'s seams overlap a live build — it waits; trying the next record (FS-262 D5)" >&2
           refused "$next_id" "overlaps a live build${why:+: $why}" ;;
        5) echo "goal-done: ${label} is a live session's, or a fill just placed a tab there — skipped (BUG-316, FS-262 D9)" >&2
           refused "$next_id" "a live session holds it${why:+: $why}" ;;
        *) echo "goal-done: could not open a worktree for ${next_id} (exit ${rc}); trying the next record" >&2
           refused "$next_id" "exit ${rc}${why:+: $why}" ;;
      esac
    fi
  done <<<"$fill"
  }
  walk_fill
  # BS-IOS-TASK-1428 (2026-11-04: BS-IOS-BUG-1396 did not open when 1356 closed,
  # yet opened on a manual --fill a moment later): ranked records, a free lane
  # and none opened — wait for a clash or a just-placed hold to clear, then
  # rank and walk once more before the stop is written.
  if [ "$DRY" = 0 ] && [ "$opened" = 0 ] && [ "$cap_full" = 0 ] && [ "$tried" -gt 0 ]; then
    retry_secs="${HERDR_FILL_RETRY_SECS:-20}"
    echo "goal-done: ${tried} ranked, none opened — retrying the fill in ${retry_secs}s" >&2
    chain_note "${tried} ranked, none opened — retrying the fill in ${retry_secs}s"
    sleep "$retry_secs"
    tried=0
    rank_fill
    walk_fill
  fi

  # FS-262 D3: the verdict lane, when unjudged agent rows wait and its one
  # seat is free. A full build cap never blocks it: it is not a build lane.
  if [ "$(jq -r '.unjudged // 0' <<<"$focus_json" 2>/dev/null)" -gt 0 ] 2>/dev/null &&
     [ "$(jq -r '.verdict_seat // "held"' <<<"$focus_json")" = free ]; then
    model_route "$shared" verdict app
    if [ "$DRY" = 1 ] && [ "${#dry_flag[@]}" = 0 ]; then
      echo "would run: python3 tools/session_worktree.py open verdict-drain ${place_flag[*]:-} — gate not asked"
      open_tab "<resolved by repository worktree manager>" verdict-drain "/verdict auto" "$ROUTE_MODEL" "--permission-mode bypassPermissions" "$ROUTE_EFFORT"
      verdict_opened=1
    elif cwd=$(cd "$shared" && python3 tools/session_worktree.py open verdict-drain ${place_flag[@]+"${place_flag[@]}"} ${dry_flag[@]+"${dry_flag[@]}"}); then
      open_tab "$cwd" "$(basename "$cwd")" "/verdict auto" "$ROUTE_MODEL" "--permission-mode bypassPermissions" "$ROUTE_EFFORT"
      verdict_opened=1
    else
      rc=$?
      if [ "$rc" = 3 ]; then
        echo "goal-done: the verdict lane is already open (verdict-drain)" >&2
      else
        echo "goal-done: could not open the verdict lane (exit ${rc})" >&2
      fi
    fi
  fi
  # FS-262 D3: a drain that closes names what it left for Eddy.
  if [ "$slug" = verdict-drain ]; then
    eddy=$(jq -r '.eddy_waiting // 0' <<<"$focus_json" 2>/dev/null) || eddy=0
    echo "goal-done: ${eddy} wait on Eddy: /verdict"
  fi
fi

if [ "$OPEN_TODO" = 1 ]; then
  if [ "$cap_full" = 1 ]; then
    echo "goal-done: build lanes full — ${waiting} waits; ${opened} build tab(s) opened; the chain fills a lane when one lands (FS-243 D1)"
  fi
  if [ "$opened" = 0 ] && [ "$verdict_opened" = 0 ]; then
    if [ "$cap_full" = 1 ]; then
      echo "goal-done: nothing could start — /spec when you have the attention (no tab opened)"
    elif [ "$tried" -gt 0 ]; then
      echo "goal-done: ${tried} ranked, none could open (overlapping seams or errors above) — /spec when you have the attention (no tab opened)"
    else
      echo "goal-done: nothing Ready — /spec when you have the attention (no tab opened)"
    fi
    # Eddy, 2026-11-03 ("I went to sleep … nothing is running"): the lines above
    # print into a tab that closes a moment later, so a stopped chain was silent
    # all night. A stop with no build left running is written to a log and
    # posted as a notification, naming what the focus track waits on.
    if [ "$cap_full" = 0 ] && [ "$DRY" = 0 ]; then
      focus=$(jq -r '.focus // empty' <<<"$focus_json" 2>/dev/null)
      blockers=$(jq -r --arg t "$focus" '[.waiting[]? | select($t == "" or .track == $t) | .waiting_on[]?] | unique | join(", ")' <<<"$focus_json" 2>/dev/null)
      stop_msg="The build chain stopped: nothing in ${focus:-the focus track} can start"
      [ -n "$blockers" ] && stop_msg="${stop_msg}; its records wait on ${blockers} — /spec them"
      [ -n "$last_refusal" ] && stop_msg="${stop_msg}; last refusal: ${last_refusal}"
      chain_note "$stop_msg"
      echo "goal-done: ${stop_msg}"
      if [ "${HERDR_CHAIN_NOTIFY:-1}" = 1 ] && command -v osascript >/dev/null; then
        osascript -e "display notification \"${stop_msg//\"/}\" with title \"Build chain stopped\" sound name \"Basso\"" >/dev/null 2>&1 || true
      fi
      spec_blockers=$(jq -r --arg t "$focus" '[.waiting[]? | select($t == "" or .track == $t) | .waiting_on[]?] | unique | .[]' <<<"$focus_json" 2>/dev/null |
        while read -r blocker; do
          if grep -q '^- Status: Spec Needed' <<<"$(cd "$shared" && python3 "$focus_tool" --show "$blocker" 2>/dev/null)"; then
            echo "$blocker"
          fi
        done)
      [ -z "$spec_blockers" ] || open_spec_blocker "$spec_blockers"
    fi
  fi
fi

# Last, and only now: this ends the session running the script.
if [ "$KEEP_TAB" = 0 ]; then
  run herdr tab close "$HERDR_TAB_ID" ||
    echo "goal-done: could not close $HERDR_TAB_ID; close it with prefix+X" >&2
fi
