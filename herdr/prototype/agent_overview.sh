#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
picker=${HERDR_AGENT_OVERVIEW_PICKER:-fzf}
reader=${HERDR_AGENT_OVERVIEW_READER:-less}
lines=${HERDR_AGENT_OVERVIEW_LINES:-200}
runtime_base=${TMPDIR:-/tmp}
work_dir=''

die() {
  printf 'agent-overview: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [ -z "$work_dir" ] || rm -rf -- "$work_dir"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

command -v jq >/dev/null 2>&1 || die "jq is required"
case "$lines" in
  ''|*[!0-9]*) die "line limit must be a positive integer" ;;
esac
[ "$lines" -gt 0 ] || die "line limit must be a positive integer"
[ "$lines" -le 2000 ] || die "line limit must not exceed 2000"

decode_token() {
  printf '%s' "$1" | base64 -D 2>/dev/null |
    jq -ec '
      select(
        type == "object" and
        (.session | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")) and
        (.terminal_id | type == "string" and length > 0 and length <= 256) and
        (.pane_id | type == "string" and length > 0 and length <= 256) and
        (.agent | type == "string" and length > 0 and length <= 128) and
        (.agent_session | type == "object")
      )
    ' || die "invalid or untrusted target"
}

running_session() {
  session=$1
  sessions=$("$herdr" session list --json) ||
    die "unable to refresh running sessions"
  socket=$(printf '%s\n' "$sessions" | jq -er --arg session "$session" '
    [.sessions[]? |
      select(
        .running == true and
        .name == $session and
        (.socket_path | type == "string" and length > 0)
      ) |
      .socket_path] |
    select(length == 1) |
    .[0]
  ') || die "target session is no longer uniquely running"
  if [ "${HERDR_AGENT_OVERVIEW_ALLOW_NONSOCKET:-0}" != 1 ]; then
    [ -S "$socket" ] || die "target session socket is no longer active"
  fi
}

fresh_target() {
  target=$1
  session=$(printf '%s\n' "$target" | jq -r '.session')
  running_session "$session"
  agents=$("$herdr" --session "$session" agent list) ||
    die "unable to refresh target session"
  printf '%s\n' "$agents" | jq -ec --argjson target "$target" '
    [.result.agents[]? |
      select(
        .terminal_id == $target.terminal_id and
        .pane_id == $target.pane_id and
        .agent == $target.agent and
        .agent_session == $target.agent_session
      )] |
    select(length == 1) |
    .[0]
  ' || die "target agent changed or disappeared"
}

inventory() {
  sessions=$("$herdr" session list --json) ||
    die "unable to list Herdr sessions"
  printf '%s\n' "$sessions" | jq -er '
    .sessions |
    select(type == "array") |
    .[] |
    select(
      .running == true and
      (.name | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")) and
      (.socket_path | type == "string" and length > 0)
    ) |
    [.name, .socket_path] |
    @tsv
  ' | while IFS="$(printf '\t')" read -r session socket; do
    if [ "${HERDR_AGENT_OVERVIEW_ALLOW_NONSOCKET:-0}" != 1 ] &&
       [ ! -S "$socket" ]; then
      continue
    fi
    response=$("$herdr" --session "$session" agent list 2>/dev/null) || continue
    printf '%s\n' "$response" | jq -e '.result.agents | type == "array"' \
      >/dev/null || die "malformed agent inventory in session $session"
    printf '%s\n' "$response" | jq -r --arg session "$session" '
      def clean:
        tostring |
        gsub("[\u0000-\u001f\u007f]"; " ") |
        gsub("  +"; " ");
      .result.agents |
      select(type == "array") |
      .[] |
      select(
        (.agent | type == "string" and length > 0 and length <= 128) and
        (.agent_status | type == "string" and length > 0 and length <= 128) and
        (.terminal_id | type == "string" and length > 0 and length <= 256) and
        (.pane_id | type == "string" and length > 0 and length <= 256) and
        (.agent_session | type == "object")
      ) |
      {
        session:$session,
        terminal_id:.terminal_id,
        pane_id:.pane_id,
        agent:.agent,
        agent_session:.agent_session
      } as $target |
      [
        ($session | clean),
        (.agent | clean),
        (.agent_status | clean),
        ((.foreground_cwd // .cwd // "") | clean),
        ($target | @base64)
      ] |
      @tsv
    '
  done
}

action=${1:-}
case "$action" in
  --inventory)
    [ "$#" -eq 1 ] || die "unexpected inventory arguments"
    inventory
    exit
    ;;
  --read-token)
    [ "$#" -eq 2 ] || die "read requires one target"
    target=$(decode_token "$2")
    fresh=$(fresh_target "$target")
    session=$(printf '%s\n' "$target" | jq -r '.session')
    terminal=$(printf '%s\n' "$fresh" | jq -r '.terminal_id')
    response=$("$herdr" --session "$session" agent read "$terminal" \
      --source recent-unwrapped --lines "$lines" --format text) ||
      die "unable to read target agent"
    printf '%s\n' "$response" | jq -er --arg pane \
      "$(printf '%s\n' "$fresh" | jq -r '.pane_id')" '
        .result.read |
        select(.pane_id == $pane and (.text | type == "string")) |
        .text
      ' || die "read response no longer matches the selected agent"
    exit
    ;;
  --focus-token)
    [ "$#" -eq 2 ] || die "focus requires one target"
    target=$(decode_token "$2")
    fresh=$(fresh_target "$target")
    session=$(printf '%s\n' "$target" | jq -r '.session')
    terminal=$(printf '%s\n' "$fresh" | jq -r '.terminal_id')
    response=$("$herdr" --session "$session" agent focus "$terminal") ||
      die "unable to focus target agent"
    printf '%s\n' "$response" | jq -e --argjson target "$target" '
      .result.agent |
      .terminal_id == $target.terminal_id and
      .pane_id == $target.pane_id and
      .agent == $target.agent and
      .agent_session == $target.agent_session
    ' >/dev/null || die "focus response no longer matches the selected agent"
    printf 'Focused %s in session %s; switch to its Ghostty window to view it.\n' \
      "$(printf '%s\n' "$fresh" | jq -r '.agent')" "$session"
    exit
    ;;
  --message-token)
    [ "$#" -eq 3 ] || die "message requires one target and one file"
    [ -f "$3" ] || die "message file is unavailable"
    [ -s "$3" ] || exit 0
    [ "$(wc -c <"$3" | tr -d ' ')" -le 1048576 ] ||
      die "message exceeds the 1 MiB safety limit"
    target=$(decode_token "$2")
    fresh=$(fresh_target "$target")
    session=$(printf '%s\n' "$target" | jq -r '.session')
    pane=$(printf '%s\n' "$fresh" | jq -r '.pane_id')
    HERDR_INSERT_BIN="$herdr" HERDR_INSERT_SESSION="$session" \
      HERDR_INSERT_PANE="$pane" \
      "$prototype/agent_message_composer.py" --dispatch "$3" >/dev/null ||
      die "unable to insert message"
    printf 'Inserted message into %s in session %s; review it there before pressing Enter.\n' \
      "$(printf '%s\n' "$fresh" | jq -r '.agent')" "$session"
    exit
    ;;
  '')
    ;;
  *)
    die "unknown action"
    ;;
esac

command -v "$picker" >/dev/null 2>&1 || die "fzf is unavailable"
command -v "$reader" >/dev/null 2>&1 || die "reader is unavailable"
work_dir=$(mktemp -d "$runtime_base/herdr-agent-overview.XXXXXX")
inventory_file="$work_dir/inventory.tsv"
message_file="$work_dir/message.txt"
lesskey_file="$work_dir/read.lesskey"
printf '#command\n\\e[27;5;27~ quit\n\\e quit\n' >"$lesskey_file"

while :; do
  inventory >"$inventory_file"
  [ -s "$inventory_file" ] || die "no agents are running in local Herdr sessions"
  set +e
  result=$(
    FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= "$picker" \
      --delimiter="$(printf '\t')" --with-nth=1,2,3,4 \
      --header='Enter focus • Ctrl-R read • Ctrl-E message • Ctrl-L refresh • Esc close' \
      --prompt='Agents> ' --layout=reverse --border \
      --expect=enter,ctrl-r,ctrl-e,ctrl-l <"$inventory_file"
  )
  picker_status=$?
  set -e
  case "$picker_status" in
    0) ;;
    1|130) exit 0 ;;
    *) die "picker failed" ;;
  esac
  key=$(printf '%s\n' "$result" | sed -n '1p')
  selection=$(printf '%s\n' "$result" | sed -n '2p')
  [ "$key" = ctrl-l ] && continue
  [ -n "$selection" ] || continue
  token=$(printf '%s\n' "$selection" | awk -F '\t' '{print $5}')
  case "$key" in
    enter)
      "$0" --focus-token "$token"
      exit
      ;;
    ctrl-r)
      if [ "${reader##*/}" = less ]; then
        "$0" --read-token "$token" |
          "$reader" -R --lesskey-src="$lesskey_file"
      else
        "$0" --read-token "$token" | "$reader" -R
      fi
      ;;
    ctrl-e)
      : >"$message_file"
      if "$prototype/agent_message_composer.py" "$message_file"; then
        "$0" --message-token "$token" "$message_file"
      fi
      ;;
  esac
done
