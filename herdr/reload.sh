#!/bin/sh
set -eu

# Reload Herdr's config the way Herdr does, plus the parts of this setup that
# live outside config.toml and would otherwise silently drift.
#
# `herdr server reload-config` only re-reads config.toml. It does not notice that
# the config symlink now points somewhere else, that the running binary is no
# longer the reviewed build, or that a plugin this config depends on was never
# provisioned. Those are exactly the things that break after an upgrade or a
# stray `herdr update`, so they are checked here and reported before the reload —
# a reload that "worked" against the wrong binary is the confusing case.

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
herdr_dir="$root/herdr"
herdr_bin=${HERDR_BIN_PATH:-"$HOME/.local/bin/herdr"}
config_link="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml"

# shellcheck source=/dev/null
. "$herdr_dir/source-build/pins.env"

warn() {
  printf 'herdr reload: %s\n' "$1" >&2
}

status=0

# 1. Is the config Herdr will read actually this repo's config?
if [ ! -L "$config_link" ]; then
  warn "config is not a symlink into this repo: $config_link"
  status=1
elif [ "$(readlink "$config_link")" != "$herdr_dir/config.toml" ]; then
  warn "config points at $(readlink "$config_link"), not $herdr_dir/config.toml"
  status=1
fi

# 2. Is the running binary the reviewed build? A stray `herdr update` swaps in
#    the official one, which accepts copy_mode_search and then does nothing.
if [ -x "$herdr_bin" ]; then
  bin_sha=$(shasum -a 256 "$herdr_bin" | awk '{print $1}')
  if [ "$bin_sha" != "$HERDR_BINARY_SHA256" ]; then
    warn "$herdr_bin is not the reviewed v$HERDR_VERSION build"
    warn "custom copy-mode bindings such as alt+s will be inert"
    warn "run: sh herdr/update.sh   (rebuilds and reinstalls the patched build)"
    status=1
  fi
else
  warn "no herdr binary at $herdr_bin"
  status=1
fi

# 3. Validate config.toml before asking a running server to load it, so a typo
#    surfaces here instead of as a half-applied reload.
if ! HERDR_PROTOTYPE_DIR="$herdr_dir/prototype" \
     HERDR_BIN_PATH="$herdr_bin" \
     HERDR_CONFIG_PATH="$herdr_dir/config.toml" \
     "$herdr_bin" config check >/dev/null 2>&1; then
  warn "config.toml failed validation — not reloading"
  HERDR_PROTOTYPE_DIR="$herdr_dir/prototype" \
  HERDR_BIN_PATH="$herdr_bin" \
  HERDR_CONFIG_PATH="$herdr_dir/config.toml" \
    "$herdr_bin" config check >&2 || true
  exit 65
fi

# 4. Provision plugins this config depends on. Idempotent.
if [ -x "$herdr_dir/ensure_plugins.sh" ]; then
  HERDR_BIN_PATH="$herdr_bin" "$herdr_dir/ensure_plugins.sh" >/dev/null 2>&1 || true
fi

# 5. A new Herdr often ships a newer agent-integration plugin, and the old one
#    keeps reporting agent state until it is reinstalled. Report rather than
#    rewrite: these live under ~/.claude, ~/.codex and ~/.config/opencode, which
#    a config reload has no business editing on its own. update.sh refreshes them.
outdated=$(
  "$herdr_bin" integration status 2>/dev/null |
    awk -F: '$2 ~ /outdated/ {print $1}' |
    paste -sd, - || true
)
if [ -n "$outdated" ]; then
  warn "outdated agent integrations: $outdated"
  warn "run: herdr integration install <name>   (or sh herdr/update.sh --apply)"
  status=1
fi

# 6. The normal thing. Three outcomes are worth telling apart, because only one
#    of them means "nothing to do": a reload that worked, a server still running
#    an older binary (upgrades do not restart running servers, so this is the
#    normal state right after an update), and no server at all.
reload_out=$("$herdr_bin" server reload-config 2>&1) && reload_ok=1 || reload_ok=0

if [ "$reload_ok" -eq 1 ] && ! printf '%s' "$reload_out" | grep -q '"error"'; then
  if [ "$status" -eq 0 ]; then
    echo "herdr reload: config reloaded (reviewed v$HERDR_VERSION build)"
  else
    echo "herdr reload: config reloaded, but see the warnings above" >&2
  fi
elif printf '%s' "$reload_out" | grep -q 'protocol_mismatch'; then
  socket=${HERDR_SOCKET_PATH:-}
  warn "the running Herdr server is an older build than this binary"
  warn "an upgrade deliberately leaves running servers alone, so this session is"
  warn "still on the previous version until its server is restarted"
  if [ -n "$socket" ]; then
    warn "restart it with (this exits the panes on that server):"
    warn "  HERDR_SOCKET_PATH=$socket herdr server stop"
  else
    warn "restart the server to pick up v$HERDR_VERSION (this exits its panes)"
  fi
  warn "new named sessions already start on the new binary"
  status=1
elif printf '%s' "$reload_out" | grep -q 'No such file\|not running\|connection refused'; then
  echo "herdr reload: no running server; config applies on next start"
else
  warn "reload failed:"
  printf '%s\n' "$reload_out" >&2
  status=1
fi

exit "$status"
