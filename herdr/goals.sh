#!/bin/bash
# herdr-goals: open one Herdr tab per live goal using the caller's agent family.
# Claude callers keep Opus high/medium routing. Codex and Pi callers stay in their
# own agent family and inherit that agent's configured model and permissions.
#
# Usage: herdr-goals [SPEC ...]     SPEC = label:model[:resume-target[:home[:paths]]]
#        herdr-goals --track NAME [--track NAME] [--dry-run]   one track tab each
#        herdr-goals --build ID [--track NAME] [--dry-run]     one /build tab
#   model is an alias (`opus`), not a pinned id, so a tab follows the
#   latest release of that family instead of aging into a retired model.
#   resume-target is a session id (resumes it directly), the literal `pick`
#   (opens the interactive picker), or omitted (fresh session).
#   home is `shared` (the shared checkout), a worktree slug, or omitted.
#
# Where a tab starts (FS-112 D1): a *fresh* build session is a new goal, so it
# opens in its own worktree on `feature/<slug>` cut from local `main` — never
# inheriting whatever branch the shared checkout happens to be parked on. A
# *resumed* session keeps the home it already had, which is the shared checkout
# unless `home` names its worktree. `grill` stays in the shared checkout:
# grilling reads the whole repo and writes records, not code. `verdict` opens
# the one `verdict-drain` checkout.
#
#   goal-x:opus                     fresh   -> worktree ../ios-sessions/goal-x
#   goal-x:opus:pick                resumed -> shared checkout
#   goal-x:opus:pick:fs110-ledge    resumed -> that worktree
#   goal-x:opus::fs110-ledge        fresh   -> that worktree (reused as-is)
#   notes:opus::shared              fresh   -> shared checkout anyway
#   grill:opus                      Eddy asked for one: shared, Opus high, /spec
#   verdict:sonnet                  the verdict lane: verdict-drain, /verdict auto
#
# With no SPEC this opens the lanes, and only the lanes (FS-262 D5): first a
# `/build <ID>` tab in each orphaned build's own checkout (`resume`, D9),
# then the work graph's fill order from `features_index.py --focus --json` — one record per
# track first, then more from a busy track — one `/build <ID>` build tab each
# until the build cap refuses an app record (exit 3; a record that takes no lane still opens); a record whose seams overlap a live
# build (exit 4) is skipped. Then the verdict lane, when unjudged agent rows
# wait and its seat is free (D3). Never a plan, grill or todo tab: grilling is
# Eddy's, at his pace (D4). A landed Ready To Act (or Ready To Build) flip runs this too (D8).
#
# Every tab starts in auto mode (--permission-mode auto): these are Eddy's
# own goal sessions on his own repo, and a permission prompt in an unfocused tab
# stalls the goal until he finds it, while full bypass gave up more than it
# bought. The repo_lock PreToolUse hook still runs, so cross-session write
# collisions are still refused.
# Set HERDR_GOALS_YOLO=0 to launch with prompts instead.
set -euo pipefail

# A ticket ID's tab/worktree name (copy of goal_done.sh's id_slug, FS-515):
# `IOS-FEAT-515` -> `ios-feat-515`, `BS-IOS-FEAT-537` -> `bs-ios-feat-537`;
# an old `FS-515` -> `fs515` (FS-490 R1, BibleStandard IOS-FEAT-537).
id_slug() {
  local id
  id=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  if printf '%s' "$id" | grep -Eq '^(bs-)?[a-z]+-(feat|bug|task)-[0-9]+$'; then printf '%s\n' "$id"
  else printf '%s\n' "$id" | tr -d '-'; fi
}

if [ "${HERDR_GOALS_YOLO:-1}" = "0" ]; then BUILD_MODE_FLAG=""; else BUILD_MODE_FLAG="--permission-mode auto"; fi

# The repo is discovered, never hardcoded: a new Canon Fidei repo has to work
# the day it is cloned, and a path baked in here breaks on every rename. In
# order: an explicit override, the repo the shell is standing in, then the
# default focus repo under the org root. `--git-common-dir` rather than
# `--show-toplevel` so a call from a linked worktree resolves to the main
# checkout, where tools/ actually lives.
CANONFIDEI_ROOT="${CANONFIDEI_ROOT:-$HOME/Programming/Projects/CanonFidei}"
HERDR_DEFAULT_REPO="${HERDR_DEFAULT_REPO:-${CANONFIDEI_ROOT}/biblestandard/ios}"
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
# Every `open` below runs in this tab's process, for a tab not yet made. A
# manager that knows `--place` names nothing then; without it, the open names
# the tab this ran from (BibleStandard BUG-313). Older managers lack the flag.
PLACE=""
if [ "$WORKTREE" != "true" ]; then
  open_help=$($WORKTREE open --help 2>&1 || true)
  if grep -Eq -- '(^|[[:space:]])--place([[:space:]=]|$)' <<<"$open_help"; then
    PLACE="--place"
  fi
fi
# A SPEC is a label, so a flag reaching the loop below is taken for one: `--help`
# opened a tab called `--help` in a directory that was argparse's usage text.
# Refuse anything flag-shaped before a single tab exists.
# BibleStandard BS-IOS-TASK-849: `--track` opens one long-lived `track-<slug>`
# tab in the shared checkout, booted `/build track <name>`; `--build` opens the
# one `/build <ID>` tab a track tab opens for each record in its order.
TRACKS=(); BUILD_ID=""; DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --track|--build)
      [ -n "${2:-}" ] || { echo "herdr-goals: $1 needs a value" >&2; exit 2; }
      if [ "$1" = --track ]; then TRACKS+=("$2"); else BUILD_ID="$2"; fi
      shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -*)        echo "herdr-goals: not a goal label: $1 (see --help)" >&2; exit 2 ;;
    *)         break ;;
  esac
done

SPECS=("$@")
BOOTS=()
FOCUS_MD="${REPO}/project/workflow/FOCUS.md"
track_slug() { tr '[:upper:]' '[:lower:]' <<<"$1" | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g'; }
if [ -n "$BUILD_ID" ]; then
  SPECS+=("$(id_slug "$BUILD_ID"):opus")
  BOOTS+=("/build ${BUILD_ID}${TRACKS[0]:+ — track ${TRACKS[0]}}")
elif [ ${#TRACKS[@]} -gt 0 ]; then
  # B2: two track tabs run at once only when neither track is exclusive, or
  # Eddy names both in one call.
  exclusive=$(awk '/^### /{name=substr($0,5)} /^- Exclusive: yes/{print name}' "$FOCUS_MD" 2>/dev/null || true)
  open_tracks=$(herdr tab list 2>/dev/null | jq -r '.result.tabs[]?.label' 2>/dev/null | sed -n 's/.*▸ track-//p' || true)
  named=""
  for name in "${TRACKS[@]}"; do
    canon=$(awk -v want="$name" '/^### /{n=substr($0,5); if (tolower(n) == tolower(want)) {print n; exit}}' "$FOCUS_MD" 2>/dev/null)
    [ -n "$canon" ] || { echo "herdr-goals: no track \"$name\" in FOCUS.md" >&2; exit 2; }
    slug=$(track_slug "$canon"); named="$named $slug"
    if grep -qx "$slug" <<<"$open_tracks"; then echo "herdr-goals: track-${slug} is already open" >&2; continue; fi
    SPECS+=("track-${slug}:opus::shared"); BOOTS+=("/build track ${canon}")
  done
  others=$(grep -vx "${named# }" <<<"$open_tracks" | grep . || true)
  if [ ${#TRACKS[@]} -eq 1 ] && [ ${#SPECS[@]} -gt 0 ] && [ -n "$others" ]; then
    while read -r ex; do
      [ -n "$ex" ] && grep -qx "$(track_slug "$ex")" <<<"${named# }"$'\n'"$others" || continue
      echo "herdr-goals: another track tab is open and ${ex} is exclusive — name both to run them together (BS-IOS-TASK-849 B2)" >&2
      exit 3
    done <<<"$exclusive"
  fi
  # Every named track already has its tab: open nothing, never the lane fill.
  [ ${#SPECS[@]} -gt 0 ] || exit 0
fi
if [ "$DRY_RUN" = 1 ]; then
  [ ${#SPECS[@]} -gt 0 ] || { echo "herdr-goals --dry-run: name --track or --build" >&2; exit 2; }
  for i in "${!SPECS[@]}"; do
    echo "would open ${SPECS[$i]%%:*} (boot ${BOOTS[$i]:-none}) in ${REPO}"
    case "${BOOTS[$i]:-}" in "/build track "*)
      waiting=$(python3 "${REPO}/tools/features_index.py" --focus --json 2>/dev/null | jq -r '.waiting[]?.id' 2>/dev/null || true)
      python3 "${REPO}/tools/features_index.py" --list --track "${BOOTS[$i]#/build track }" --status "Ready To Build" 2>/dev/null |
        while read -r id rest; do
          grep -qx "$id" <<<"$waiting" && continue
          echo "  first record it can open: ${id} — $(sed -E 's/^Ready To Build +//' <<<"$rest")"; break
        done || true ;;
    esac
  done
  exit 0
fi
# Eddy, 2026-10-02: while this file exists the chain opens no tab by itself;
# a named SPEC still opens. `rm` it to let the lanes fill again.
CHAIN_PAUSE="${HERDR_CHAIN_PAUSE:-$HOME/.config/herdr/chain-paused}"
if [ ${#SPECS[@]} -eq 0 ] && [ -e "$CHAIN_PAUSE" ]; then
  echo "herdr-goals: chain paused ($CHAIN_PAUSE) — no tab opened; name one: herdr-goals <label>:opus::<worktree>" >&2
  exit 0
fi
if [ ${#SPECS[@]} -eq 0 ]; then
  # FS-129 D7 / FS-130 D3: the focus track chooses, so "open my windows" needs
  # no argument and no ranking session. `/build` runs a settled record to a
  # merged slice (BibleStandard FS-285 D1): the global verb opens the
  # repository's playbook when its `AGENTS.md` maps one, else its own.
  RUN="/build"
  focus_json=$(python3 "${REPO}/tools/features_index.py" --focus --json 2>/dev/null) || focus_json="{}"
  # Eddy, 2026-10-24 ("these other tabs have to wait till we split these files"):
  # a focus track marked `- Exclusive: yes` in FOCUS.md opens only its own records.
  exclusive=$(awk '/^### /{name=substr($0,5); f=0} /^- State: focus/{f=1} f && /^- Exclusive: yes/{print name; exit}' "${REPO}/project/workflow/FOCUS.md" 2>/dev/null)
  if [ -n "$exclusive" ]; then
    focus_json=$(jq -c --arg ex "$exclusive" '.next |= map(select(.track == $ex)) | .resume |= map(select(.track == $ex))' <<<"$focus_json" 2>/dev/null) || focus_json="{}"
  fi
  # FS-262 D9: a build whose owner is dead is resumed in its own checkout
  # before any new record takes a lane; it already holds its lane.
  while IFS=$'\t' read -r id slug; do
    [ -n "$id" ] && [ -n "$slug" ] || continue
    label=$(id_slug "$id")
    SPECS+=("${label}:opus::${slug}")
    BOOTS+=("${RUN} ${id} — resumed (FS-262 D9): git merge main first")
  done < <(jq -r '.resume[]? | [.id, .slug] | @tsv' <<<"$focus_json")
  while IFS=$'\t' read -r id title; do
    [ -n "$id" ] || continue
    label=$(id_slug "$id")
    SPECS+=("${label}:opus")
    BOOTS+=("${RUN} ${id}")
  done < <(jq -r '.next[]? | [.id, .title] | @tsv' <<<"$focus_json")
  # FS-262 D3: the verdict lane opens only while unjudged agent rows wait and
  # its one seat is free; an empty queue opens none.
  if [ "$(jq -r '.unjudged // 0' <<<"$focus_json")" -gt 0 ] &&
     [ "$(jq -r '.verdict_seat // "held"' <<<"$focus_json")" = free ]; then
    SPECS+=("verdict:sonnet")
    BOOTS+=("/verdict auto")
  fi
  [ ${#SPECS[@]} -gt 0 ] || echo "herdr-goals: nothing Ready and no verdict waiting — /spec when you have the attention (no tab opened)" >&2
fi

herdr status server >/dev/null 2>&1 || { echo "herdr server not running; open Herdr first" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

# Herdr owns the reliable caller identity. Environment fallbacks cover direct
# invocations and tests, while an explicit override makes the contract easy to
# diagnose without opening a real agent session.
caller_agent="${HERDR_GOALS_AGENT:-}"
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
  claude) session_agent=claude ;;
  codex|openai) session_agent=codex ;;
  pi) session_agent=pi ;;
  *) echo "herdr-goals: unsupported caller agent: $caller_agent" >&2; exit 2 ;;
esac

# D4: say it once, before any tab exists, while it is still cheap to fix.
$WORKTREE shared-status >/dev/null || true

index=-1
cap_full=0
for spec in ${SPECS[@]+"${SPECS[@]}"}; do
  index=$((index + 1))
  IFS=: read -r label model resume home paths <<<"$spec"
  # Eddy, 2026-10-24: the cap counts app work only. A full cap no longer ends the
  # builds after it: the manager grants a record that takes no lane (tools, hooks,
  # playbooks, records, docs) and refuses an app record with exit 3, one by one.
  # Resolve the tab's working directory before creating the tab: a worktree that
  # cannot be made must not leave a half-opened window behind.
  if [ -z "${home:-}" ]; then
    if [ "$label" = "grill" ] || [ -n "${resume:-}" ]; then home="shared"
    elif [ "$label" = "verdict" ]; then home="verdict-drain"
    else home="$label"; fi
  fi
  # No worktree tooling in this repo means no per-goal checkout to open, and an
  # unresolvable home would hand the tab an empty cwd. Everything shares the root.
  [ "$WORKTREE" = "true" ] && home="shared"
  if [ "$home" = "shared" ]; then
    cwd="$REPO"
  else
    worktree_args=(open "$home")
    [ -n "$PLACE" ] && worktree_args+=("$PLACE")
    [ "$label" = "verdict" ] || worktree_args+=(--goal "$label")
    if [ "$WORKTREE" != "true" ] && [ -n "${paths:-}" ]; then
      IFS=, read -ra owned_paths <<<"$paths"
      manager_help=$($WORKTREE open --help 2>&1)
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
    fi
    if cwd=$($WORKTREE "${worktree_args[@]}"); then
      :
    else
      # The manager's gates exit apart (FS-243 D8): a full build cap ends the
      # build tabs, an overlapping seam skips only this record (FS-262 D5).
      rc=$?
      # FS-262 D1: the manager owns the one verdict seat; exit 3 there means
      # a drain is already open, never a full build cap.
      if [ "$label" = verdict ]; then
        if [ "$rc" = 3 ]; then
          echo "skipped verdict: the verdict lane is already open (verdict-drain)" >&2
        else
          echo "skipped verdict: could not open verdict-drain (exit ${rc})" >&2
        fi
        continue
      fi
      case "$rc" in
        3) echo "build lanes full — ${label} (app work) waits (FS-243 D1)" >&2; cap_full=1; continue ;;
        4) echo "skipped ${label}: its seams overlap a live build — the manager's line above names it (FS-262 D5)" >&2; continue ;;
        5) echo "skipped ${label}: a live session owns ${home}, or a fill just placed a tab there (BUG-316, FS-262 D9)" >&2; continue ;;
        *) echo "skipped ${label}: could not open worktree ${home}" >&2; continue ;;
      esac
    fi
  fi

  # The tab is named for the checkout it actually got, not for the id it was
  # asked with: `open` adopts `fs094-offers` for a bare `fs094` (FS-099), and a
  # tab reading `fs094` next to a directory called `fs094-offers` is the stale
  # bar the naming exists to remove. `goal_done.sh` derives it the same way, so
  # a tab opened here and a tab opened there carry one shape.
  if [ "$home" = "shared" ]; then tab_label="$label"; else tab_label=$(basename "$cwd"); fi

  mode_flag="$BUILD_MODE_FLAG"
  # The verdict drain runs in yolo (Eddy, 2026-10-29: "verdict drain should run on yolo mode").
  if [ "$label" = "verdict" ] && [ -n "$mode_flag" ]; then mode_flag="--permission-mode bypassPermissions"; fi

  # An explicit `grill` opens already working the decision backlog, and
  # `verdict` already draining (FS-262 D4/D2). A positional prompt seeds the
  # session and leaves it interactive — `-p` would print one answer and exit.
  boot=""
  if [ -z "${resume:-}" ]; then
    case "$label" in grill) boot="/spec" ;; verdict) boot="/verdict auto" ;; esac
  fi
  # A no-argument run already knows what each tab is for (FS-129 D7).
  if [ ${#BOOTS[@]} -gt "$index" ] && [ -n "${BOOTS[$index]:-}" ]; then boot="${BOOTS[$index]}"; fi

  # FS-237 D8: an agent-opened tab carries `▸ `; Eddy's own tabs carry none.
  # The opener owns the mark, and repo_lock's later renames keep it.
  pane=$(herdr tab create --cwd "$cwd" --label "▸ $tab_label" --no-focus | jq -r '.result.root_pane.pane_id')
  if [ "$session_agent" = "claude" ]; then
    case "${resume:-}" in
      "")     resume_args="" ;;
      pick)   resume_args=" --resume" ;;
      *)      resume_args=" --resume ${resume}" ;;
    esac
    # FS-100 (Eddy, 2026-09-25), amended 2026-10-24: a grill decides at high, never
    # max unless Eddy asks ("I don't want to use Max effort ... it's token eating");
    # builds and the verdict lane build at medium.
    if [ "$label" = "grill" ]; then effort=high; else effort=medium; fi
    launch="claude --model ${model} --effort ${effort} ${mode_flag}${resume_args}${boot:+ \"${boot}\"}"
  elif [ "$session_agent" = "codex" ]; then
    case "${resume:-}" in
      "")     launch="codex${boot:+ \"${boot}\"}" ;;
      pick)   launch="codex resume" ;;
      *)      launch="codex resume ${resume}" ;;
    esac
  else
    case "${resume:-}" in
      "")     launch="pi${boot:+ \"${boot}\"}" ;;
      pick)   launch="pi --resume" ;;
      *)      launch="pi --session ${resume}" ;;
    esac
  fi
  herdr pane run "$pane" "$launch"
  boot_note="${boot:+ boot ${boot}}"
  echo "opened ${tab_label} (${session_agent}${boot_note}) in pane ${pane} — ${cwd}"
done
# FS-262 D8: a full build cap opens nothing more; the chain fills a lane when
# a build lands. Nothing here asks Eddy to deliver.
if [ "$cap_full" = 1 ]; then
  echo "build lanes full — the chain fills a lane when a build lands; /spec when you have the attention" >&2
fi
