#!/bin/sh
set -eu

# PROTOTYPE ONLY: replay the newest labeled agent handoff through Herdr APIs.

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
parser=${HERDR_READY_PROMPT_PARSER:-"$root/tmux/scripts/ready_prompt.sh"}
capture_lines=${HERDR_READY_PROMPT_CAPTURE_LINES:-2000}
ready_attempts=${HERDR_READY_PROMPT_READY_ATTEMPTS:-50}
ready_interval=${HERDR_READY_PROMPT_READY_INTERVAL:-0.1}
clear_confirm_interval=${HERDR_READY_PROMPT_CLEAR_CONFIRM_INTERVAL:-0.2}
state_root=${HERDR_READY_PROMPT_STATE_DIR:-"$prototype/.runtime/ready-prompt"}

clear_first=0
if [ "${1:-}" = "--clear" ]; then
  clear_first=1
  shift
fi
[ "$#" -eq 0 ] || {
  echo "usage: ready_prompt.sh [--clear]" >&2
  exit 2
}

case "$capture_lines:$ready_attempts" in
  *[!0-9:]*|0:*|*:0)
    echo "ready-prompt: capture lines and ready attempts must be positive integers" >&2
    exit 2
    ;;
esac

pane=${HERDR_PANE_ID:-}
if [ -z "$pane" ]; then
  pane=$($herdr pane current --current | jq -er '.result.pane.pane_id')
fi
pane_key=$(printf '%s' "$pane" | tr -c '[:alnum:]_.-' '_')
state_dir="$state_root/$pane_key"
state="$state_dir/fingerprint"
lock_dir="$state_dir/active"
work_dir=''

notify() {
  title=$1
  body=$2
  $herdr notification show "$title" --body "$body" --sound none >/dev/null 2>&1 || true
  printf '%s: %s\n' "$title" "$body" >&2
}

mkdir -p "$state_dir"
if ! mkdir "$lock_dir" 2>/dev/null; then
  notify "Ready prompt" "Another replay is already active for this pane"
  exit 75
fi
cleanup() {
  [ -z "$work_dir" ] || rm -rf "$work_dir"
  rmdir "$lock_dir" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

read_pane_format() {
  source=$1
  format=$2
  shift 2
  response=$($herdr pane read "$pane" --source "$source" "$@" --format "$format")
  case "$response" in
    \{*) printf '%s\n' "$response" | jq -r '.result.text // .result.content // empty' ;;
    *) printf '%s\n' "$response" ;;
  esac
}

read_pane() {
  source=$1
  shift
  read_pane_format "$source" text "$@"
}

read_pane_ansi() {
  source=$1
  shift
  read_pane_format "$source" ansi "$@"
}

recognized_agent() {
  candidate=$1
  "$parser" --recognize "$candidate" >/dev/null 2>&1
}

processes=$($herdr pane process-info --pane "$pane") || {
  notify "Ready prompt" "Unable to inspect the focused pane"
  exit 1
}
agent=''
agent_candidates=$(printf '%s\n' "$processes" | jq -r '
  .result.process_info.foreground_processes[]? |
  [(.argv0 // empty), (.argv[0] // empty), (.name // empty)][] |
  select(length > 0)
')
while IFS= read -r candidate; do
  if [ -n "$candidate" ] && recognized_agent "$candidate"; then
    agent=$(basename -- "$candidate" | tr '[:upper:]' '[:lower:]')
    break
  fi
done <<EOF
$agent_candidates
EOF

if [ -z "$agent" ]; then
  notify "Ready prompt" "Focused pane is not a supported agent"
  exit 1
fi
if [ "$clear_first" -eq 1 ] && ! "$parser" --clear-support "$agent"; then
  notify "Ready prompt" "$agent cannot safely clear context before replay"
  exit 1
fi
runtime_base=${TMPDIR:-/tmp}
work_dir=$(mktemp -d "$runtime_base/herdr-ready-prompt.XXXXXX")
history_file="$work_dir/history.txt"
prompt_file="$work_dir/prompt.txt"

read_pane recent-unwrapped --lines "$capture_lines" >"$history_file" || {
  notify "Ready prompt" "Unable to read recent pane history"
  exit 1
}
set +e
HERDR_READY_PROMPT_CAPTURE_LINES="$capture_lines" \
  READY_PROMPT_CAPTURE_LINES="$capture_lines" \
  "$parser" --extract "$history_file" >"$prompt_file"
extract_status=$?
set -e
case "$extract_status" in
  0) ;;
  10)
    notify "Ready prompt" "No replayable handoff found"
    exit 1
    ;;
  11)
    notify "Ready prompt" "Newest handoff is incomplete"
    exit 1
    ;;
  *)
    notify "Ready prompt" "Prompt extraction failed"
    exit 1
    ;;
esac

fingerprint=$(shasum -a 256 "$prompt_file" | awk '{print $1}')
consumed=''
[ ! -f "$state" ] || consumed=$(sed -n '1p' "$state")
if [ "$clear_first" -eq 0 ] && [ "$consumed" = "$fingerprint" ]; then
  notify "Ready prompt" "Newest handoff was already inserted; use clear-and-replay"
  exit 1
fi

visible_file="$work_dir/visible.txt"
styled_visible_file="$work_dir/visible-styled.txt"
if [ "$clear_first" -eq 1 ]; then
  $herdr pane send-text "$pane" '/clear' >/dev/null
  $herdr pane send-keys "$pane" return >/dev/null
  sleep "$clear_confirm_interval"
  read_pane visible >"$visible_file"
  if "$parser" --clear-active "$agent" "$visible_file"; then
    $herdr pane send-keys "$pane" return >/dev/null
  fi

  attempt=0
  stable=0
  while [ "$attempt" -lt "$ready_attempts" ]; do
    read_pane_ansi visible >"$styled_visible_file" || break
    perl -pe 's/\e\[[0-9;]*m//g' \
      "$styled_visible_file" >"$visible_file" || break
    if "$parser" --ready-screen "$agent" "$visible_file" "$styled_visible_file"; then
      stable=$((stable + 1))
      [ "$stable" -lt 2 ] || break
    else
      stable=0
    fi
    sleep "$ready_interval"
    attempt=$((attempt + 1))
  done
  if [ "$stable" -lt 2 ]; then
    notify "Ready prompt" "Context cleared, but $agent did not become ready; prompt not inserted"
    exit 1
  fi
fi

prompt=$(cat "$prompt_file")
bracketed_prompt=$(printf '\033[200~%s\033[201~' "$prompt")
$herdr pane send-text "$pane" "$bracketed_prompt" >/dev/null || {
  notify "Ready prompt" "Unable to insert the extracted handoff"
  exit 1
}
printf '%s\n' "$fingerprint" >"$state"

if [ "$clear_first" -eq 1 ]; then
  notify "Ready prompt" "Context cleared and handoff inserted; review and press Enter"
else
  notify "Ready prompt" "Handoff inserted; review and press Enter"
fi
