#!/bin/sh
set -eu

usage() {
  echo "usage: window_session.sh <owner-pid> <herdr-binary>" >&2
  exit 64
}

is_positive_integer() {
  case ${1:-} in
    ''|*[!0-9]*|0) return 1 ;;
    *) return 0 ;;
  esac
}

process_start_identity() {
  ps -p "$1" -o lstart= 2>/dev/null |
    awk '{$1=$1; print}'
}

is_automatic_session() {
  case ${1:-} in
    main) return 0 ;;
    window-*)
      number=${1#window-}
      case "$number" in 0*) return 1 ;; esac
      is_positive_integer "$number" &&
        [ "$number" -ge 2 ] &&
        [ "$number" -le 999 ]
      ;;
    *) return 1 ;;
  esac
}

prepare_private_directory() {
  private_path=$1
  private_kind=$2

  case "$private_path" in
    /*) ;;
    *) echo "window-session $private_kind must be an absolute path" >&2; exit 65 ;;
  esac
  case "$private_kind:${private_path##*/}" in
    runtime:herdr-window-sessions-*|state:herdr-window-sessions|state:herdr-window-sessions-*) ;;
    *)
      echo "window-session $private_kind has an unsafe leaf: $private_path" >&2
      exit 65
      ;;
  esac
  if [ -L "$private_path" ] ||
    { [ -e "$private_path" ] && [ ! -d "$private_path" ]; }; then
    echo "window-session $private_kind is not a safe directory: $private_path" >&2
    exit 65
  fi

  umask 077
  if [ ! -d "$private_path" ]; then
    if ! mkdir -m 700 "$private_path" 2>/dev/null; then
      [ -d "$private_path" ] && [ ! -L "$private_path" ] || {
        echo "window-session $private_kind could not be created safely: $private_path" >&2
        exit 65
      }
    fi
  fi
  private_uid=$(/usr/bin/stat -f '%u' "$private_path") || {
    echo "window-session $private_kind owner could not be inspected: $private_path" >&2
    exit 65
  }
  private_mode=$(/usr/bin/stat -f '%Lp' "$private_path") || {
    echo "window-session $private_kind mode could not be inspected: $private_path" >&2
    exit 65
  }
  if [ "$private_uid" != "$(id -u)" ] || [ "$private_mode" != 700 ]; then
    echo "window-session $private_kind must be user-owned mode 700: $private_path" >&2
    exit 65
  fi
}

remember_session() {
  remembered_session=$1
  remembered_state=$2
  [ -f "$remembered_state/known/$remembered_session" ] &&
    [ ! -L "$remembered_state/known/$remembered_session" ] ||
    return 65
  remembered_tmp="$remembered_state/.last-session.remember.$$"
  printf '%s\n' "$remembered_session" >"$remembered_tmp"
  chmod 600 "$remembered_tmp"
  mv "$remembered_tmp" "$remembered_state/last-session"
}

require_state_lock() {
  locked_state=$1
  if /usr/bin/lockf -t 0 "$locked_state/allocator.lock" \
    /usr/bin/true 2>/dev/null; then
    echo "window-session internal mode requires the state lock" >&2
    exit 65
  fi
}

if [ "${1:-}" = "--finish-locked" ]; then
  [ "$#" -eq 6 ] || usage
  finish_pid=$2
  finish_start=$3
  finish_session=$4
  finish_runtime=$5
  finish_state=$6
  is_positive_integer "$finish_pid" || usage
  is_automatic_session "$finish_session" || usage
  prepare_private_directory "$finish_runtime" runtime
  prepare_private_directory "$finish_state" state
  require_state_lock "$finish_state"
  finish_lease="$finish_runtime/$finish_session.lease"
  [ -f "$finish_lease" ] && [ ! -L "$finish_lease" ] || exit 0
  IFS='	' read -r recorded_pid recorded_start <"$finish_lease" || exit 0
  [ "$recorded_pid" = "$finish_pid" ] &&
    [ "$recorded_start" = "$finish_start" ] || exit 0
  remember_session "$finish_session" "$finish_state"
  rm -f -- "$finish_lease"
  exit 0
fi

if [ "${1:-}" = "--adopt-locked" ]; then
  [ "$#" -eq 8 ] || usage
  prior_pid=$2
  supervisor_pid=$3
  supervisor_start=$4
  supervisor_session=$5
  supervisor_runtime=$6
  supervisor_state=$7
  supervisor_parent=$8
  is_positive_integer "$prior_pid" || usage
  is_positive_integer "$supervisor_pid" || usage
  is_positive_integer "$supervisor_parent" || usage
  [ "$prior_pid" = "$supervisor_parent" ] || exit 65
  is_automatic_session "$supervisor_session" || usage
  prepare_private_directory "$supervisor_runtime" runtime
  prepare_private_directory "$supervisor_state" state
  require_state_lock "$supervisor_state"
  supervisor_lease="$supervisor_runtime/$supervisor_session.lease"
  [ -f "$supervisor_lease" ] && [ ! -L "$supervisor_lease" ] || exit 65
  IFS='	' read -r recorded_pid recorded_start <"$supervisor_lease" || exit 65
  [ "$recorded_pid" = "$prior_pid" ] &&
    [ "$(process_start_identity "$prior_pid")" = "$recorded_start" ] ||
    exit 65
  supervisor_tmp="$supervisor_runtime/.lease.$supervisor_pid.$$"
  printf '%s\t%s\n' "$supervisor_pid" "$supervisor_start" >"$supervisor_tmp"
  chmod 600 "$supervisor_tmp"
  mv "$supervisor_tmp" "$supervisor_lease"
  exit 0
fi

if [ "${1:-}" = "--supervise" ]; then
  [ "$#" -eq 4 ] || usage
  prior_pid=$2
  supervisor_session=$3
  herdr_bin=$4
  is_positive_integer "$prior_pid" || usage
  is_automatic_session "$supervisor_session" || usage
  case "$herdr_bin" in
    /*) ;;
    *) echo "window-session Herdr binary must be an absolute path" >&2; exit 65 ;;
  esac
  [ -x "$herdr_bin" ] || exit 65

  runtime_base=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}
  runtime=${HERDR_LOGIN_SESSION_RUNTIME:-"$runtime_base/herdr-window-sessions-$(id -u)"}
  state_base=${XDG_STATE_HOME:-"$HOME/.local/state"}
  state=${HERDR_LOGIN_SESSION_STATE:-"$state_base/herdr-window-sessions"}
  prepare_private_directory "$runtime" runtime
  prepare_private_directory "$state" state
  supervisor_pid=$$
  supervisor_parent=$(ps -p "$supervisor_pid" -o ppid= | awk '{$1=$1; print}')
  supervisor_start=$(process_start_identity "$supervisor_pid")
  is_positive_integer "$supervisor_parent" || exit 65
  [ -n "$supervisor_start" ] || exit 65
  /usr/bin/lockf -k -t 5 "$state/allocator.lock" \
    "$0" --adopt-locked "$prior_pid" "$supervisor_pid" "$supervisor_start" \
      "$supervisor_session" "$runtime" "$state" "$supervisor_parent" ||
    exit 65

  client_pid=
  forward_int() {
    [ -z "$client_pid" ] || kill -INT "$client_pid" 2>/dev/null || true
  }
  forward_term() {
    [ -z "$client_pid" ] || kill -TERM "$client_pid" 2>/dev/null || true
  }
  trap '' HUP
  trap forward_int INT
  trap forward_term TERM
  exec 3<&0
  (
    trap - HUP INT TERM
    exec "$herdr_bin" --session "$supervisor_session"
  ) <&3 3<&- &
  client_pid=$!
  exec 3<&-
  if wait "$client_pid"; then
    client_status=0
  else
    client_status=$?
  fi
  trap - HUP INT TERM
  /usr/bin/lockf -k -t 5 "$state/allocator.lock" \
    "$0" --finish-locked "$supervisor_pid" "$supervisor_start" \
      "$supervisor_session" "$runtime" "$state" || exit 65
  case "$client_status" in
    126|127) exit 75 ;;
    *) exit 0 ;;
  esac
fi

if [ "${1:-}" != "--locked" ]; then
  [ "$#" -eq 2 ] || usage
  owner_pid=$1
  herdr_bin=$2

  is_positive_integer "$owner_pid" || usage
  owner_start=$(process_start_identity "$owner_pid")
  [ -n "$owner_start" ] || {
    echo "window-session owner process is not alive: $owner_pid" >&2
    exit 65
  }
  case "$herdr_bin" in
    /*) ;;
    *) echo "window-session Herdr binary must be an absolute path" >&2; exit 65 ;;
  esac
  [ -x "$herdr_bin" ] || {
    echo "window-session Herdr binary is not executable: $herdr_bin" >&2
    exit 65
  }

  runtime_base=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}
  runtime=${HERDR_LOGIN_SESSION_RUNTIME:-"$runtime_base/herdr-window-sessions-$(id -u)"}
  state_base=${XDG_STATE_HOME:-"$HOME/.local/state"}
  state=${HERDR_LOGIN_SESSION_STATE:-"$state_base/herdr-window-sessions"}
  config_root=${HERDR_LOGIN_CONFIG_ROOT:-"${XDG_CONFIG_HOME:-"$HOME/.config"}/herdr"}
  case "$config_root" in
    /*) ;;
    *) echo "window-session config root must be an absolute path" >&2; exit 65 ;;
  esac

  prepare_private_directory "$runtime" runtime
  prepare_private_directory "$state" state
  exec /usr/bin/lockf -k -t 5 "$state/allocator.lock" \
    "$0" --locked "$owner_pid" "$owner_start" "$herdr_bin" \
      "$runtime" "$state" "$config_root"
fi

[ "$#" -eq 7 ] || usage
owner_pid=$2
owner_start=$3
herdr_bin=$4
runtime=$5
state=$6
config_root=$7
max_windows=${HERDR_LOGIN_MAX_WINDOWS:-64}
process_fixture=${HERDR_LOGIN_PROCESS_FIXTURE:-}

is_positive_integer "$owner_pid" || usage
prepare_private_directory "$runtime" runtime
prepare_private_directory "$state" state
require_state_lock "$state"
case "$config_root" in
  /*) ;;
  *) echo "window-session config root must be an absolute path" >&2; exit 65 ;;
esac
[ "$(process_start_identity "$owner_pid")" = "$owner_start" ] || {
  echo "window-session owner process identity changed" >&2
  exit 65
}
is_positive_integer "$max_windows" || {
  echo "HERDR_LOGIN_MAX_WINDOWS must be a positive integer" >&2
  exit 65
}
[ "$max_windows" -le 999 ] || {
  echo "HERDR_LOGIN_MAX_WINDOWS must not exceed 999" >&2
  exit 65
}

process_snapshot="$runtime/processes.$owner_pid.$$"
session_snapshot="$runtime/sessions.$owner_pid.$$"
active_snapshot="$runtime/active.$owner_pid.$$"
cleanup() {
  rm -f -- "$process_snapshot" "$session_snapshot" "$active_snapshot"
}
trap cleanup EXIT
trap 'exit 70' HUP INT TERM

if [ -n "$process_fixture" ]; then
  [ -r "$process_fixture" ] || {
    echo "window-session process fixture is not readable" >&2
    exit 65
  }
  cp "$process_fixture" "$process_snapshot"
else
  ps -axo pid=,command= >"$process_snapshot" || {
    echo "window-session could not inspect live Herdr clients" >&2
    exit 65
  }
fi

awk -v bin="$herdr_bin" '
  $2 == bin && $3 == "--session" { print $4 }
  $2 == bin && $3 == "session" && $4 == "attach" { print $5 }
' "$process_snapshot" >"$session_snapshot"
awk -v bin="$herdr_bin" '
  $2 != bin { next }
  NF == 2 { print "active"; next }
  $3 == "--session" { print "active"; next }
  $3 == "--remote" { print "active"; next }
  $3 == "session" && $4 == "attach" { print "active" }
' "$process_snapshot" >"$active_snapshot"

lease_is_live() {
  lease_file=$1
  [ -L "$lease_file" ] && {
    echo "window-session lease must not be a symlink: $lease_file" >&2
    exit 65
  }
  [ -f "$lease_file" ] || return 1
  IFS='	' read -r lease_pid lease_start <"$lease_file" || {
    lease_pid=
    lease_start=
  }
  current_start=
  if is_positive_integer "$lease_pid" && [ -n "$lease_start" ]; then
    current_start=$(process_start_identity "$lease_pid")
  fi
  if [ -n "$current_start" ] && [ "$current_start" = "$lease_start" ]; then
    return 0
  fi
  rm -f -- "$lease_file"
  return 1
}

any_active=false
if [ -s "$active_snapshot" ]; then
  any_active=true
fi
for existing_lease in "$runtime"/*.lease; do
  if lease_is_live "$existing_lease"; then
    any_active=true
  fi
done

known_dir="$state/known"
if [ -L "$known_dir" ] ||
  { [ -e "$known_dir" ] && [ ! -d "$known_dir" ]; }; then
  echo "window-session known-session state is unsafe: $known_dir" >&2
  exit 65
fi
if [ ! -d "$known_dir" ]; then
  mkdir -m 700 "$known_dir"
fi

max_slot=0
consider_session() {
  considered=$1
  is_automatic_session "$considered" || return 0
  if [ "$considered" = main ]; then
    considered_slot=1
  else
    considered_slot=${considered#window-}
  fi
  if [ "$considered_slot" -gt "$max_slot" ]; then
    max_slot=$considered_slot
  fi
}

for known_path in "$known_dir"/main "$known_dir"/window-* \
  "$config_root/sessions/main" "$config_root/sessions"/window-*; do
  [ -e "$known_path" ] || continue
  consider_session "${known_path##*/}"
done
while IFS= read -r live_session; do
  consider_session "$live_session"
done <"$session_snapshot"

last_session=
if [ -f "$state/last-session" ] && [ ! -L "$state/last-session" ]; then
  IFS= read -r last_session <"$state/last-session" || last_session=
  is_automatic_session "$last_session" || last_session=
fi

if [ "$any_active" = false ]; then
  if [ -n "$last_session" ]; then
    session=$last_session
  elif [ "$max_slot" -eq 0 ]; then
    session=main
  elif [ "$max_slot" -eq 1 ]; then
    session=main
  else
    session=window-$max_slot
  fi
else
  next_slot=$((max_slot + 1))
  if [ "$next_slot" -eq 1 ]; then
    session=main
  elif [ "$next_slot" -le "$max_windows" ]; then
    session=window-$next_slot
  else
    echo "window-session allocation exhausted $max_windows slots" >&2
    exit 75
  fi
fi

state_tmp="$state/.last-session.$owner_pid.$$"
printf '%s\n' "$session" >"$state_tmp"
chmod 600 "$state_tmp"
mv "$state_tmp" "$state/last-session"

known_tmp="$known_dir/.known.$owner_pid.$$"
printf '%s\n' "$session" >"$known_tmp"
chmod 600 "$known_tmp"
mv "$known_tmp" "$known_dir/$session"

lease="$runtime/$session.lease"
lease_tmp="$runtime/.lease.$owner_pid.$$"
printf '%s\t%s\n' "$owner_pid" "$owner_start" >"$lease_tmp"
chmod 600 "$lease_tmp"
mv "$lease_tmp" "$lease"
printf '%s\n' "$session"
