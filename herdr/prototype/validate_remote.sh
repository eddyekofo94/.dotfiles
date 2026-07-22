#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$prototype/../.." && pwd)
herdr="$prototype/.runtime/bin/herdr"
evidence_dir="$prototype/evidence"
evidence="$evidence_dir/remote-validation.jsonl"
runtime=$(mktemp -d /tmp/herdr-remote-validation.XXXXXX)
evidence_tmp="$runtime/remote-validation.jsonl.tmp"
ssh_log="$runtime/sshd.log"
client_log="$runtime/client.log"
session=remote-audit
sshd_pid=
client_pid=
agent_pid=

[ -x "$herdr" ] || {
  echo "remote validation requires the prototype Herdr binary" >&2
  exit 2
}
[ -x /usr/sbin/sshd ] || {
  echo "remote validation requires sshd" >&2
  exit 2
}

production_hashes() {
  jq -cn \
    --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
    --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
    --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
    --arg nvim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
    '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$nvim}'
}

record() {
  jq -cn --arg check "$1" --argjson evidence "$2" \
    '{check:$check,evidence:$evidence}' >>"$evidence_tmp"
}

cleanup() {
  exit_code=$?
  trap - EXIT INT TERM
  if [ -n "$client_pid" ]; then
    kill "$client_pid" 2>/dev/null || true
    wait "$client_pid" 2>/dev/null || true
  fi
  if [ -n "$sshd_pid" ]; then
    kill "$sshd_pid" 2>/dev/null || true
    wait "$sshd_pid" 2>/dev/null || true
  fi
  if [ -n "$agent_pid" ]; then
    SSH_AUTH_SOCK="$runtime/agent.sock" SSH_AGENT_PID="$agent_pid" \
      ssh-agent -k >/dev/null 2>&1 || true
    kill "$agent_pid" 2>/dev/null || true
    wait "$agent_pid" 2>/dev/null || true
  fi
  rm -rf -- "$runtime"
  exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$runtime/local/herdr" "$runtime/local-home/.ssh" \
  "$runtime/remote/herdr" "$evidence_dir"
cp "$prototype/config.toml" "$runtime/local/herdr/config.toml"
cp "$prototype/config.toml" "$runtime/remote/herdr/config.toml"
: >"$evidence_tmp"

production_before=$(production_hashes)
help=$($herdr --help)
defaults=$($herdr --default-config)
printf '%s\n' "$help" | grep -F -- '--remote <target>' >/dev/null
printf '%s\n' "$help" | grep -F -- '--remote-keybindings <local|server>' >/dev/null
printf '%s\n' "$defaults" | grep -F '# allow_nested = false' >/dev/null
record capability "$(jq -cn --arg version "$($herdr --version)" \
  '{version:$version,remote_attach:true,local_or_server_keybindings:true,nesting_default:"disabled"}')"

ssh-keygen -q -t ed25519 -N '' -f "$runtime/client_key"
cp "$runtime/client_key.pub" "$runtime/authorized_keys"
ssh-keygen -q -t ed25519 -N '' -f "$runtime/host_key"
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
user=$(id -un)
remote_path="$prototype/.runtime/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
{
  printf 'Port %s\n' "$port"
  printf 'ListenAddress 127.0.0.1\n'
  printf 'HostKey %s\n' "$runtime/host_key"
  printf 'PidFile %s\n' "$runtime/sshd.pid"
  printf 'AuthorizedKeysFile %s\n' "$runtime/authorized_keys"
  printf 'StrictModes no\n'
  printf 'PasswordAuthentication no\n'
  printf 'KbdInteractiveAuthentication no\n'
  printf 'UsePAM no\n'
  printf 'PermitRootLogin no\n'
  printf 'AllowUsers %s\n' "$user"
  printf 'PermitTTY yes\n'
  printf 'PrintMotd no\n'
  printf 'SetEnv XDG_CONFIG_HOME=%s HERDR_CONFIG_PATH=%s PATH=%s\n' \
    "$runtime/remote" "$runtime/remote/herdr/config.toml" "$remote_path"
} >"$runtime/sshd_config"
/usr/sbin/sshd -t -f "$runtime/sshd_config"
/usr/sbin/sshd -D -e -f "$runtime/sshd_config" 2>"$ssh_log" &
sshd_pid=$!

attempt=0
while ! nc -z 127.0.0.1 "$port" 2>/dev/null; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 50 ] || {
    echo "disposable sshd did not become ready" >&2
    exit 1
  }
  sleep 0.1
done

ssh-agent -a "$runtime/agent.sock" >"$runtime/agent.env"
agent_pid=$(sed -n 's/^echo Agent pid \([0-9][0-9]*\);$/\1/p' "$runtime/agent.env")
SSH_AUTH_SOCK="$runtime/agent.sock" ssh-add "$runtime/client_key" >/dev/null 2>&1
target="ssh://$user@127.0.0.1:$port"
ssh_common="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p $port -i $runtime/client_key"
{
  printf 'Host 127.0.0.1\n'
  printf '  IdentityFile %s\n' "$runtime/client_key"
  printf '  IdentitiesOnly yes\n'
  printf '  StrictHostKeyChecking no\n'
  printf '  UserKnownHostsFile /dev/null\n'
  printf '  LogLevel ERROR\n'
} >"$runtime/local-home/.ssh/config"
chmod 700 "$runtime/local-home/.ssh"
chmod 600 "$runtime/local-home/.ssh/config"

# Prove the remote shell sees the exact prototype binary and isolated config.
remote_version=$(ssh $ssh_common "$user@127.0.0.1" 'herdr --version')
test "$remote_version" = "$($herdr --version)"
remote_config=$(ssh $ssh_common "$user@127.0.0.1" 'printf "%s|%s" "$XDG_CONFIG_HOME" "$HERDR_CONFIG_PATH"')
test "$remote_config" = "$runtime/remote|$runtime/remote/herdr/config.toml"
record ssh "$(jq -cn --arg target "$target" --arg version "$remote_version" \
  '{transport:"disposable-localhost-openssh",target:$target,authenticated:true,remote_binary:$version,production_remote_login_enabled:false}')"

# Use a real PTY thin client. It remains attached long enough for an independent
# SSH command to prove that the named remote server and its pane are live.
SSH_AUTH_SOCK="$runtime/agent.sock" XDG_CONFIG_HOME="$runtime/local" \
HERDR_CONFIG_PATH="$runtime/local/herdr/config.toml" \
HOME="$runtime/local-home" TERM=xterm-256color \
expect -c "
  log_user 1
  set timeout 20
  spawn -noecho $herdr --remote $target --session $session
  after 5000
  puts REMOTE_CLIENT_ATTACHED
  flush stdout
  after 6000
  send \\001q
  expect eof
" >"$client_log" 2>&1 &
client_pid=$!

attempt=0
while ! grep -F 'REMOTE_CLIENT_ATTACHED' "$client_log" >/dev/null 2>&1; do
  if ! kill -0 "$client_pid" 2>/dev/null; then
    sed -n '1,160p' "$client_log" >&2
    echo "remote client exited before attach" >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  [ "$attempt" -lt 150 ] || {
    sed -n '1,160p' "$client_log" >&2
    echo "remote client attach timed out" >&2
    exit 1
  }
  sleep 0.1
done

remote_status=$(ssh $ssh_common "$user@127.0.0.1" \
  "herdr --session $session status server --json")
if ! printf '%s\n' "$remote_status" | jq -e '.running == true or .result.running == true' >/dev/null; then
  sed -n '1,200p' "$client_log" >&2
  echo "remote server did not start" >&2
  exit 1
fi
remote_panes=$(ssh $ssh_common "$user@127.0.0.1" \
  "herdr --session $session pane list")
printf '%s\n' "$remote_panes" | jq -e '(.result.panes // .panes) | length >= 1' >/dev/null
record attach "$(jq -cn --arg target "$target" --arg session "$session" \
  --argjson status "$remote_status" --argjson panes "$remote_panes" \
  '{mode:"thin-client",target:$target,session:$session,server_status:$status,pane_inventory:$panes,attached:true}')"

wait "$client_pid"
client_pid=

# A closed endpoint must fail before creating a remote session or modifying a host.
closed_port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
set +e
SSH_AUTH_SOCK="$runtime/agent.sock" XDG_CONFIG_HOME="$runtime/local" \
HERDR_CONFIG_PATH="$runtime/local/herdr/config.toml" \
HOME="$runtime/local-home" \
$herdr --remote "ssh://$user@127.0.0.1:$closed_port" --session unavailable \
  </dev/null >"$runtime/fail.stdout" 2>"$runtime/fail.stderr"
fail_exit=$?
set -e
test "$fail_exit" -ne 0
grep -E 'remote platform detection failed|connect to host.*refused' "$runtime/fail.stderr" >/dev/null
record unavailable "$(jq -cn --argjson exit "$fail_exit" \
  --arg error "$(sed -n '1p' "$runtime/fail.stderr")" \
  '{fail_closed:true,exit:$exit,error:$error,input_sent:false,remote_install_attempted:false}')"

production_after=$(production_hashes)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn --argjson before "$production_before" \
  --argjson after "$production_after" \
  --arg config "$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')" \
  --arg validator "$(shasum -a 256 "$0" | awk '{print $1}')" \
  '{production_hashes_before:$before,production_hashes_after:$after,unchanged:($before==$after),artifact_hashes:{config:$config,validator:$validator}}')"
record result "$(jq -cn \
  '{status:"PASS",production_configuration_modified:false,remote_login_enabled:false,integration_installed:false,migration_authorized:false}')"

mv "$evidence_tmp" "$evidence"
printf 'Herdr remote validation: PASS (%s)\n' "$evidence"
