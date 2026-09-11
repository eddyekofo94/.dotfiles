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
#   4. advance: ask the work graph for the next focus-track record and open a
#      fresh same-agent tab booted into `/deliver <ID>`; with nothing ranked,
#      a /todo tab on the shared checkout instead               (FS-130 D3)
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

# FS-130 D3: the finished tab picks the next goal itself. The work graph ranks
# the focus track's unclaimed records (FS-129 D7); with none anywhere the grill
# lane is the bottleneck and saying so out loud is the point.
label=todo
mode="--permission-mode plan"
cwd="$shared"
next_id=""
next_paths=""
if [ "$OPEN_TODO" = 1 ] && [ -f "$shared/tools/features_index.py" ]; then
  next_record=$( (cd "$shared" && python3 tools/features_index.py --focus --json 2>/dev/null) |
                   jq -c '.next[0] // empty' ) || next_record=""
  if [ -n "$next_record" ]; then
    next_id=$(printf '%s\n' "$next_record" | jq -r '.id // empty')
    next_paths=$(printf '%s\n' "$next_record" |
                   jq -r '(.owned_paths // .paths // [])[]?')
  fi
fi
if [ -n "$next_id" ]; then
  MODEL=opus  # alias, so the tab follows the latest Opus (5 today)
  mode="--permission-mode auto"
  [ "$BOOT_SET" = 1 ] || BOOT="/deliver ${next_id}"
  # The id is all this step knows, so the name it can build is `fs094` — while
  # the goal's checkout is called `fs094-offers`. `open` adopts the existing
  # tree for a bare id (FS-099), and the tab is then labelled from the path it
  # actually got: deriving the label here instead would name the tab after a
  # directory that does not exist.
  label=$(printf '%s' "$next_id" | tr 'A-Z' 'a-z' | tr -d '-')
  worktree_args=(open "$label" --goal "$next_id")
  if [ -n "$next_paths" ]; then
    manager_help=$(cd "$shared" && python3 tools/session_worktree.py open --help 2>&1)
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
      echo "goal-done: worktree manager has no owned-path interface" >&2
      next_id=""
    fi
  fi
  if [ -z "$next_id" ]; then
    label=todo
    MODEL=fable
    mode="--permission-mode plan"
    BOOT=/todo
  elif [ "$DRY" = 1 ]; then
    printf 'would run: python3 tools/session_worktree.py'
    printf ' %q' "${worktree_args[@]}"
    printf '\n'
    # Repository-local managers own naming and adoption. Opening one would
    # mutate state, so dry-run reports that unresolved boundary explicitly.
    cwd="<resolved by repository worktree manager>"
  elif cwd=$(cd "$shared" && python3 tools/session_worktree.py "${worktree_args[@]}"); then
    # Adoption can land somewhere other than $label; the tab is named for where
    # it will actually sit.
    label=$(basename "$cwd")
  else
    echo "goal-done: could not open a worktree for ${next_id}; opening the planning backlog instead" >&2
    next_id=""
    label=todo
    MODEL=fable
    mode="--permission-mode plan"
    BOOT=/todo
    cwd="$shared"
  fi
fi

if [ "$OPEN_TODO" = 1 ]; then
  if [ "$session_agent" = "claude" ]; then
    launch="claude --model ${MODEL} ${mode} \"${BOOT}\""
  elif [ "$session_agent" = "codex" ]; then
    launch="codex \"${BOOT}\""
  else
    launch="pi \"${BOOT}\""
  fi
  if [ "$DRY" = 1 ]; then
    if [ -n "$next_id" ]; then
      echo "would advance to: ${next_id}"
    else
      echo "would advance to: nothing ranked — the decision backlog is the bottleneck"
    fi
    echo "would run: herdr tab create --cwd $cwd --label $label --no-focus"
    echo "would run: herdr pane run <new> ${launch}"
  else
    pane=$(herdr tab create --cwd "$cwd" --label "$label" --no-focus |
             jq -r '.result.root_pane.pane_id') || die "could not open the ${BOOT} tab"
    [ -n "$pane" ] && [ "$pane" != null ] || die "could not read the new tab's pane id"
    herdr pane run "$pane" "$launch" ||
      die "opened the tab but could not start ${session_agent} in $pane"
    echo "goal-done: opened ${BOOT} in ${pane} (${session_agent}) — ${cwd}"
  fi
fi

# Last, and only now: this ends the session running the script.
if [ "$KEEP_TAB" = 0 ]; then
  run herdr tab close "$HERDR_TAB_ID" ||
    echo "goal-done: could not close $HERDR_TAB_ID; close it with prefix+X" >&2
fi
