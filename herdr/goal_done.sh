#!/bin/bash
# herdr-goal-done: retire a finished goal tab and start the next goal in a new one.
#
# The end of a ticket is the one moment the workflow had no gesture for. The
# work merges, and the tab stays open on a worktree that is now a duplicate of
# `main`, holding a cap slot (FS-097), while the next thing to
# do sits unranked. Eddy then closes the tab by hand, opens another, and types
# the same prompt. This is that sequence, once, in the right order:
#
#   1. refuse unless the branch is genuinely merged  (nothing is thrown away)
#   2. release any path claim (a no-op since FS-153 D1: a worktree holds none)
#   3. sweep the worktree                            (frees the cap slot)
#   4. advance: open a fresh same-agent `/deliver <ID>` tab for every free build
#      slot, one per track (FS-130 D3, FS-243 D6); a full cap with nothing
#      opened boots /grill-next, nothing ranked boots /todo      (FS-243 D5)
#   5. close the tab this ran in                     (last: it kills us)
#
# Step 5 is why the order matters and why the new tab is created before
# anything is destroyed: if tab creation fails there is still a live session
# holding the evidence of why.
#
# Claude keeps its Fable/Opus and permission-mode routing. Codex and Pi stay in
# their current agent family and inherit that agent's configured model and
# permissions.
#
# Usage:
#   herdr-goal-done                 # from inside the finished goal's worktree
#   herdr-goal-done --force         # skip the merged check (branch is kept)
#   herdr-goal-done --keep-tab      # open the next tab, leave this one open
#   herdr-goal-done --model NAME    # override the model the next tab gets
#   herdr-goal-done --no-todo       # just retire; do not advance or open anything
#   herdr-goal-done --dry-run       # print the five steps, change nothing
set -uo pipefail

FORCE=0
KEEP_TAB=0
OPEN_TODO=1
DRY=0
MODEL=fable  # alias, so the tab follows the latest Fable (5.1 today)
BOOT=/todo
BOOT_SET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --force)    FORCE=1 ;;
    --keep-tab) KEEP_TAB=1 ;;
    --no-todo)  OPEN_TODO=0 ;;
    --dry-run)  DRY=1 ;;
    --model)    MODEL="${2:?--model needs a value}"; shift ;;
    --boot)     BOOT="${2:?--boot needs a value}"; BOOT_SET=1; shift ;;
    -h|--help)  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "goal-done: $*" >&2; exit 1; }

# Every step that destroys or creates something goes through this, so --dry-run
# covers the real sequence rather than a second copy of it that can drift.
run() {
  if [ "$DRY" = 1 ]; then echo "would run: $*"; return 0; fi
  "$@"
}

[ -n "${HERDR_TAB_ID:-}" ] || die "not inside a Herdr pane (no \$HERDR_TAB_ID)"
command -v jq >/dev/null || die "jq required"

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

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not in a git repository"
# --git-common-dir points at the *shared* .git even from a linked worktree, so
# this resolves the main checkout without knowing the naming convention.
common=$(cd "$root" && git rev-parse --git-common-dir)
case "$common" in /*) ;; *) common="$root/$common" ;; esac
shared=$(dirname "$common")
slug=$(basename "$root")

if [ "$root" = "$shared" ]; then
  # A tab in the shared checkout owns no worktree and no branch of its own.
  slug=""
  echo "goal-done: shared checkout — nothing to sweep, retiring the tab only"
else
  branch=$(cd "$root" && git rev-parse --abbrev-ref HEAD)
  dirty=$(cd "$root" && git status --porcelain)
  [ -z "$dirty" ] || [ "$FORCE" = 1 ] || die "$slug has uncommitted changes; commit, or --force"
  # Merged means "main already contains this HEAD" — true after a --no-ff merge
  # and equally true for a branch that never diverged. Either way nothing is
  # lost by sweeping it.
  if ! (cd "$shared" && git merge-base --is-ancestor "$branch" main) 2>/dev/null; then
    [ "$FORCE" = 1 ] || die "main does not contain $branch yet; merge it first, or --force"
    echo "goal-done: --force with $branch unmerged — keeping the branch"
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
  run python3 tools/session_worktree.py remove "$slug" ||
    die "worktree $slug not swept — tab left open so the reason is readable"
fi

# FS-130 D3, as filled by FS-243 D6: the finished tab starts the next goals
# itself — one `/deliver` tab per free build slot, one per track, walking the
# work graph's fill set (`--focus --json` `next`). Each open is gated by the
# repository's manager: exit 3 is a full cap (stop), exit 4 is a busy track
# (FS-243 D4: that record waits; try the next). When nothing could be opened
# because the cap is full, the next decision is what the machine is short of,
# so the tab it opens is `/grill-next` (D5); with nothing ranked at all, `/todo`.

# Open one agent tab and start its session. The `▸ ` marks a tab an agent
# opened (FS-237 D8); repo_lock keeps it.
open_tab() {  # cwd label boot model mode
  local tab_cwd="$1" tab_label="$2" boot="$3" model="$4" tab_mode="$5" launch pane
  if [ "$session_agent" = "claude" ]; then
    launch="claude --model ${model} ${tab_mode} \"${boot}\""
  elif [ "$session_agent" = "codex" ]; then
    launch="codex \"${boot}\""
  else
    launch="pi \"${boot}\""
  fi
  if [ "$DRY" = 1 ]; then
    echo "would run: herdr tab create --cwd $tab_cwd --label \"▸ $tab_label\" --no-focus"
    echo "would run: herdr pane run <new> ${launch}"
    return 0
  fi
  pane=$(herdr tab create --cwd "$tab_cwd" --label "▸ $tab_label" --no-focus |
           jq -r '.result.root_pane.pane_id') || die "could not open the ${boot} tab"
  [ -n "$pane" ] && [ "$pane" != null ] || die "could not read the new tab's pane id"
  herdr pane run "$pane" "$launch" ||
    die "opened the tab but could not start ${session_agent} in $pane"
  echo "goal-done: opened ${boot} in ${pane} (${session_agent}) — ${tab_cwd}"
}

opened=0
tried=0
cap_full=0
waiting=""
cap=""
if [ "$OPEN_TODO" = 1 ] && [ -f "$shared/tools/features_index.py" ]; then
  fill=$( (cd "$shared" && python3 tools/features_index.py --focus --json 2>/dev/null) |
            jq -c '.next[]?' ) || fill=""
  manager_help=$(cd "$shared" && python3 tools/session_worktree.py open --help 2>&1)
  # Dry-run cannot ask the gate without opening, so it asks how many slots are
  # free and walks that many; a real run lets exit 3 say when to stop.
  free=""
  if [ "$DRY" = 1 ]; then
    free=$(cd "$shared" && python3 -c 'import sys; sys.path.insert(0, "tools")
import repo_lock, session_worktree
print(repo_lock.SESSION_CAP - len(session_worktree.occupied_slots()))' 2>/dev/null) || free=""
    # The finishing checkout is still on disk in a dry run; a real run has
    # swept it by now, so its slot is free. Its track still reads as busy
    # here, which a real run would not — said once, not silently.
    if [ -n "$free" ] && [ -n "$slug" ]; then
      free=$((free + 1))
      echo "goal-done: dry run — ${slug} is not swept, so its track may read as busy here"
    fi
  fi
  cap=$(cd "$shared" && python3 -c 'import sys; sys.path.insert(0, "tools")
import repo_lock; print(repo_lock.SESSION_CAP)' 2>/dev/null) || cap=""
  while IFS= read -r record; do
    [ -n "$record" ] || continue
    next_id=$(printf '%s\n' "$record" | jq -r '.id // empty')
    next_track=$(printf '%s\n' "$record" | jq -r '.track // empty')
    next_paths=$(printf '%s\n' "$record" | jq -r '(.owned_paths // .paths // [])[]?')
    [ -n "$next_id" ] || continue
    tried=$((tried + 1))
    # The id is all this step knows, so the name it can build is `fs094` — while
    # the goal's checkout may be `fs094-offers`. `open` adopts the existing tree
    # for a bare id (FS-099), and the tab is labelled from the path it got.
    label=$(printf '%s' "$next_id" | tr 'A-Z' 'a-z' | tr -d '-')
    worktree_args=(open "$label" --goal "$next_id")
    # This open runs in the finishing tab, for the next goal's tab: a manager
    # that knows `--place` must not name this one after it (BibleStandard BUG-313).
    if grep -Eq -- '(^|[[:space:]])--place([[:space:]=]|$)' <<<"$manager_help"; then
      worktree_args+=(--place)
    fi
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
        continue
      fi
    fi
    boot="/deliver ${next_id}"
    if [ "$BOOT_SET" = 1 ] && [ "$opened" = 0 ]; then boot="$BOOT"; fi
    if [ "$DRY" = 1 ]; then
      if [ -n "$free" ] && [ "$opened" -ge "$free" ]; then cap_full=1; waiting="$next_id"; break; fi
      printf 'would run: python3 tools/session_worktree.py'
      printf ' %q' "${worktree_args[@]}"
      printf '\n'
      echo "would advance to: ${next_id}${next_track:+ (${next_track})}"
      open_tab "<resolved by repository worktree manager>" "$label" "$boot" opus "--permission-mode auto"
      opened=$((opened + 1))
      continue
    fi
    if cwd=$(cd "$shared" && python3 tools/session_worktree.py "${worktree_args[@]}"); then
      open_tab "$cwd" "$(basename "$cwd")" "$boot" opus "--permission-mode auto"
      opened=$((opened + 1))
    else
      rc=$?
      case "$rc" in
        3) cap_full=1; waiting="$next_id"; break ;;
        4) echo "goal-done: ${next_track:-its track} busy — ${next_id} waits on that build; trying the next record" >&2 ;;
        *) echo "goal-done: could not open a worktree for ${next_id} (exit ${rc}); trying the next record" >&2 ;;
      esac
    fi
  done <<<"$fill"
fi

if [ "$OPEN_TODO" = 1 ]; then
  if [ "$cap_full" = 1 ]; then
    echo "goal-done: cap ${cap:-full}${cap:+/$cap} — ${waiting} waits; ${opened} build tab(s) opened (FS-243 D1)"
  fi
  if [ "$opened" = 0 ]; then
    if [ "$cap_full" = 1 ]; then
      echo "goal-done: nothing could start, so the next decision is the bottleneck — opening /grill-next"
      open_tab "$shared" grill-next /grill-next "$MODEL" "--permission-mode plan"
    else
      if [ "$tried" -gt 0 ]; then
        echo "goal-done: ${tried} ranked, none could open (busy tracks or errors above) — opening ${BOOT}"
      else
        echo "goal-done: nothing ranked — the decision backlog is the bottleneck — opening ${BOOT}"
      fi
      open_tab "$shared" "$(printf '%s' "${BOOT#/}" | cut -d' ' -f1)" "$BOOT" "$MODEL" "--permission-mode plan"
    fi
  fi
fi

# Last, and only now: this ends the session running the script.
if [ "$KEEP_TAB" = 0 ]; then
  run herdr tab close "$HERDR_TAB_ID" ||
    echo "goal-done: could not close $HERDR_TAB_ID; close it with prefix+X" >&2
fi
