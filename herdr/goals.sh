#!/bin/bash
# herdr-goals: open one Herdr tab per live goal using the caller's agent family.
# Claude callers keep Fable/Opus routing. Codex and Pi callers open Codex.
#
# Usage: herdr-goals [SPEC ...]     SPEC = label:model[:resume-target[:home[:paths]]]
#   model is an alias (`fable`, `opus`), not a pinned id, so a tab follows the
#   latest release of that family instead of aging into a retired model.
#   resume-target is a session id (resumes it directly), the literal `pick`
#   (opens the interactive picker), or omitted (fresh session).
#   home is `shared` (the shared checkout), a worktree slug, or omitted.
#
# Where a tab starts (FS-112 D1): a *fresh* build session is a new goal, so it
# opens in its own worktree on `feature/<slug>` cut from local `main` — never
# inheriting whatever branch the shared checkout happens to be parked on. A
# *resumed* session keeps the home it already had, which is the shared checkout
# unless `home` names its worktree. `plan` stays in the shared checkout: ranking
# and grilling read the whole repo and write records, not code.
#
#   goal-x:opus                     fresh   -> worktree ../BibleStandard-sessions/goal-x
#   goal-x:opus:pick                resumed -> shared checkout
#   goal-x:opus:pick:fs110-ledge    resumed -> that worktree
#   goal-x:opus::fs110-ledge        fresh   -> that worktree (reused as-is)
#   notes:opus::shared              fresh   -> shared checkout anyway
#
# With no SPEC this asks the work graph what is next (FS-129 D7): the focus
# track's ranked, unclaimed candidates from
# `features_index.py --focus --json`, one build tab each (max three), booted
# into `/deliver <ID>`, plus the plan tab. `/goals` may still pass SPECs to
# override the ranking; nothing else has to.
#
# The `plan` tab starts in plan mode (--permission-mode plan), not YOLO: FS-100
# says Fable plans and grills, and plan mode is what enforces it.
#
# Every build tab starts in auto mode (--permission-mode auto): these are Eddy's
# own goal sessions on his own repo, and a permission prompt in an unfocused tab
# stalls the goal until he finds it, while full bypass gave up more than it
# bought. The repo_lock PreToolUse hook still runs, so cross-session write
# collisions are still refused.
# Set HERDR_GOALS_YOLO=0 to launch with prompts instead.
set -euo pipefail

if [ "${HERDR_GOALS_YOLO:-1}" = "0" ]; then BUILD_MODE_FLAG=""; else BUILD_MODE_FLAG="--permission-mode auto"; fi

# The repo is discovered, never hardcoded: a new Canon Fidei repo has to work
# the day it is cloned, and a path baked in here breaks on every rename. In
# order: an explicit override, the repo the shell is standing in, then the
# default focus repo under the org root. `--git-common-dir` rather than
# `--show-toplevel` so a call from a linked worktree resolves to the main
# checkout, where tools/ actually lives.
CANONFIDEI_ROOT="${CANONFIDEI_ROOT:-$HOME/Programming/Projects/CanonFidei}"
HERDR_DEFAULT_REPO="${HERDR_DEFAULT_REPO:-${CANONFIDEI_ROOT}/BibleStandard}"
if [ -n "${HERDR_GOALS_REPO:-}" ]; then
  REPO="$HERDR_GOALS_REPO"
elif common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  REPO=$(dirname "$common")
else
  REPO="$HERDR_DEFAULT_REPO"
fi
[ -d "$REPO" ] || { echo "herdr-goals: no such repo: $REPO" >&2; exit 2; }

# A repo without the loop tooling still opens tabs; it just cannot rank goals or
# cut worktrees. Degrade to a no-op rather than dying on a missing script.
if [ -f "${REPO}/tools/session_worktree.py" ]; then
  WORKTREE="python3 ${REPO}/tools/session_worktree.py"
else
  WORKTREE="true"
fi

# A SPEC is a label, so a flag reaching the loop below is taken for one: `--help`
# opened a tab called `--help` in a directory that was argparse's usage text.
# Refuse anything flag-shaped before a single tab exists.
case "${1:-}" in
  -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -*)        echo "herdr-goals: not a goal label: $1 (see --help)" >&2; exit 2 ;;
esac

SPECS=("$@")
BOOTS=()
if [ ${#SPECS[@]} -eq 0 ]; then
  # FS-129 D7 / FS-130 D3: the focus track chooses, so "open my windows" needs
  # no argument and no ranking session. `/deliver` runs a settled record to a
  # merged slice; before it exists, fall back to the global build entry.
  if [ -d "${REPO}/.claude/skills/deliver" ]; then RUN="/deliver"; else RUN="feature-plan"; fi
  SPECS=("plan:fable")
  BOOTS=("")
  while IFS=$'\t' read -r id title; do
    [ -n "$id" ] || continue
    label=$(printf '%s' "$id" | tr 'A-Z' 'a-z' | tr -d '-')
    SPECS+=("${label}:opus")
    BOOTS+=("${RUN} ${id}")
  done < <(python3 "${REPO}/tools/features_index.py" --focus --json 2>/dev/null \
             | jq -r '.next[] | [.id, .title] | @tsv')
  if [ ${#SPECS[@]} -eq 1 ]; then
    # Nothing ranked anywhere: the decision backlog is the bottleneck, visibly.
    SPECS+=("todo:opus")
    BOOTS+=("/todo")
  fi
fi

herdr status server >/dev/null 2>&1 || { echo "herdr server not running; open Herdr first" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

# Herdr owns the reliable caller identity. Environment fallbacks cover direct
# invocations and tests, while an explicit override makes the contract easy to
# diagnose without opening a real agent session. Pi intentionally routes to
# Codex: Pi is the lightweight caller, not the session family opened for goals.
caller_agent="${HERDR_GOALS_AGENT:-}"
if [ -z "$caller_agent" ] && [ -n "${HERDR_PANE_ID:-}" ]; then
  caller_agent=$(herdr pane get "$HERDR_PANE_ID" 2>/dev/null |
    jq -r '.result.pane.agent // empty') || true
fi
if [ -z "$caller_agent" ]; then
  if [ -n "${CLAUDECODE:-}" ]; then
    caller_agent=claude
  elif [ -n "${CODEX_SESSION_ID:-}" ] || [ -n "${PI_SESSION_ID:-}" ]; then
    caller_agent=codex
  else
    caller_agent=claude
  fi
fi
case "$caller_agent" in
  claude) session_agent=claude ;;
  codex|openai|pi) session_agent=codex ;;
  *) echo "herdr-goals: unsupported caller agent: $caller_agent" >&2; exit 2 ;;
esac

# D4: say it once, before any tab exists, while it is still cheap to fix.
$WORKTREE shared-status >/dev/null || true

index=-1
for spec in "${SPECS[@]}"; do
  index=$((index + 1))
  IFS=: read -r label model resume home paths <<<"$spec"
  # Resolve the tab's working directory before creating the tab: a worktree that
  # cannot be made must not leave a half-opened window behind.
  if [ -z "${home:-}" ]; then
    if [ "$label" = "plan" ] || [ -n "${resume:-}" ]; then home="shared"; else home="$label"; fi
  fi
  # No worktree tooling in this repo means no per-goal checkout to open, and an
  # unresolvable home would hand the tab an empty cwd. Everything shares the root.
  [ "$WORKTREE" = "true" ] && home="shared"
  if [ "$home" = "shared" ]; then
    cwd="$REPO"
  elif [ "$WORKTREE" != "true" ] && [ -n "${paths:-}" ]; then
    IFS=, read -ra owned_paths <<<"$paths"
    worktree_args=(open "$home")
    manager_help=$(python3 "${REPO}/tools/session_worktree.py" open --help 2>&1)
    if grep -Eq -- '(^|[[:space:]])--path([[:space:]=]|$)' <<<"$manager_help"; then
      for owned_path in "${owned_paths[@]}"; do
        worktree_args+=(--path "$owned_path")
      done
    elif grep -Eq -- '(^|[[:space:]])--paths([[:space:]=]|$)' <<<"$manager_help"; then
      worktree_args+=(--paths "${owned_paths[@]}")
    else
      echo "skipped ${label}: worktree manager has no owned-path interface" >&2
      continue
    fi
    if ! cwd=$(python3 "${REPO}/tools/session_worktree.py" "${worktree_args[@]}"); then
      echo "skipped ${label}: could not open worktree ${home}" >&2
      continue
    fi
  elif ! cwd=$($WORKTREE open "$home" --goal "$label"); then
    echo "skipped ${label}: could not open worktree ${home}" >&2
    continue
  fi

  # The tab is named for the checkout it actually got, not for the id it was
  # asked with: `open` adopts `fs094-offers` for a bare `fs094` (FS-099), and a
  # tab reading `fs094` next to a directory called `fs094-offers` is the stale
  # bar the naming exists to remove. `goal_done.sh` derives it the same way, so
  # a tab opened here and a tab opened there carry one shape.
  if [ "$home" = "shared" ]; then tab_label="$label"; else tab_label=$(basename "$cwd"); fi

  # FS-100: the plan tab plans. Plan mode is the mechanical half of that rule —
  # Fable cannot quietly start editing — so it replaces the build-tab mode
  # rather than joining it (one --permission-mode per session).
  if [ "$label" = "plan" ]; then mode_flag="--permission-mode plan"; else mode_flag="$BUILD_MODE_FLAG"; fi

  # The plan tab opens already working the decision backlog: 29 records sit at
  # `Status: Spec Needed` and drain only when someone remembers them. A
  # positional prompt seeds the session and leaves it interactive — `-p` would
  # print one answer and exit, which is not a lane.
  if [ "$label" = "plan" ] && [ -z "${resume:-}" ]; then boot="/grill-next"; else boot=""; fi
  # A no-argument run already knows what each tab is for (FS-129 D7).
  if [ ${#BOOTS[@]} -gt "$index" ] && [ -n "${BOOTS[$index]:-}" ]; then boot="${BOOTS[$index]}"; fi

  pane=$(herdr tab create --cwd "$cwd" --label "$tab_label" --no-focus | jq -r '.result.root_pane.pane_id')
  if [ "$session_agent" = "claude" ]; then
    case "${resume:-}" in
      "")     resume_args="" ;;
      pick)   resume_args="--resume" ;;
      *)      resume_args="--resume ${resume}" ;;
    esac
    launch="claude --model ${model} ${mode_flag} ${resume_args}${boot:+ \"${boot}\"}"
  else
    case "${resume:-}" in
      "")     launch="codex" ;;
      pick)   launch="codex resume" ;;
      *)      launch="codex resume ${resume}" ;;
    esac
  fi
  herdr pane run "$pane" "$launch"
  if [ "$session_agent" = "claude" ]; then boot_note="${boot:+ boot ${boot}}"; else boot_note=""; fi
  echo "opened ${tab_label} (${session_agent}${boot_note}) in pane ${pane} — ${cwd}"
done
