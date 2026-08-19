# Shared prototype-server lifecycle for the validators. Source it; do not run it.
#
# DEFECT (2026-08-12, herdr-daily-driver-promotion decisions, Evidence item 2):
# a validator that died without completing its teardown left its
# `.runtime/bin/herdr server` running. The next audit run then collided with the
# orphan and failed somewhere else entirely — a layout-menu popup timeout, then a
# silent exit 4 after login-attach — while each validator passed standalone. The
# recorded cause of a red audit gate was therefore untrustworthy.
#
# Traps alone cannot fix this: `kill -9` runs no trap, and 8 of the 14 validators
# never killed the server at all, relying on `session stop` succeeding. So the
# teardown is moved off the dying shell and onto a watchdog that outlives it,
# with a sweep at startup as the backstop for a watchdog that was itself killed.
#
# Both functions only ever signal a process whose command line is the prototype
# runtime binary, so neither can touch Eddy's production `~/.local/bin/herdr`.

# The validators start the server both bare (`herdr server`) and session-scoped
# (`herdr --session lm server`), so match the runtime path and the subcommand
# separately. The `/.runtime/bin/` anchor is what keeps this off the production
# `~/.local/bin/herdr server`.
herdr_is_prototype_server() {
  case "$(ps -o command= -p "$1" 2>/dev/null)" in
    */.runtime/bin/herdr*\ server*) return 0 ;;
    *) return 1 ;;
  esac
}

# herdr_sweep_stale_server <socket>
# Reap any prototype server still holding this validator's socket from a previous
# run, then clear the stale socket file. Safe when nothing is listening.
herdr_sweep_stale_server() {
  herdr_sweep_socket=$1
  if [ -S "$herdr_sweep_socket" ]; then
    for herdr_sweep_pid in $(lsof -t "$herdr_sweep_socket" 2>/dev/null || true); do
      herdr_is_prototype_server "$herdr_sweep_pid" || continue
      kill "$herdr_sweep_pid" 2>/dev/null || true
      herdr_sweep_wait=0
      while [ "$herdr_sweep_wait" -lt 20 ] && kill -0 "$herdr_sweep_pid" 2>/dev/null; do
        sleep 0.1
        herdr_sweep_wait=$((herdr_sweep_wait + 1))
      done
      kill -9 "$herdr_sweep_pid" 2>/dev/null || true
    done
  fi
  rm -f "$herdr_sweep_socket" 2>/dev/null || true
}

# herdr_guard_server <socket>
# Outlive the validator: poll the caller and reap whatever holds the socket once
# the caller is gone, however it went. On a clean run the validator's own
# teardown stops the server first and this finds nothing to do.
#
# It keys on the socket, not on a server pid, so it can be armed *before* the
# server is launched. A pid-keyed guard could only be armed on the line after
# `server_pid=$!`, and a SIGKILL landing in that window leaked the server anyway
# — observed, not theorised.
herdr_guard_server() {
  herdr_guard_socket=$1
  herdr_guard_owner_pid=$$
  (
    while kill -0 "$herdr_guard_owner_pid" 2>/dev/null; do
      sleep 1
    done
    herdr_sweep_stale_server "$herdr_guard_socket"
    # stdin must be detached as well as stdout/stderr: these validators drive a
    # PTY client that reads the script's stdin, and a background subshell left
    # holding that descriptor starves the client — the pane never appears and the
    # gate times out on "initial pane". Observed, then isolated by disabling only
    # this guard.
  ) </dev/null >/dev/null 2>&1 &
  herdr_guard_pid=$!
}
