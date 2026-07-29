# PROTOTYPE ONLY: source from config.fish after migration is explicitly approved.

function __herdr_login_attach --description 'Attach a top-level login shell to Herdr'
    status is-login; and status is-interactive; or return 0

    # Herdr injects HERDR_ENV into pane processes. TMUX protects the current
    # production path while both multiplexers coexist during the trial.
    set -q HERDR_ENV; and return 0
    set -q HERDR_PANE_ID; and return 0
    set -q TMUX; and return 0
    set -q HERDR_NO_AUTO_ATTACH; and return 0

    # Missing, malformed, or explicitly tmux state fails closed to the existing
    # tmux login path later in config.fish.
    set -l default_file "$XDG_CONFIG_HOME/herdr/default-multiplexer"
    if set -q HERDR_DEFAULT_FILE
        set default_file "$HERDR_DEFAULT_FILE"
    end
    test -r "$default_file"; or return 0
    read -l default_multiplexer <"$default_file"
    test "$default_multiplexer" = herdr; or return 0

    set -l herdr_bin
    if set -q HERDR_BIN_PATH; and test -x "$HERDR_BIN_PATH"
        set herdr_bin "$HERDR_BIN_PATH"
    else if command -sq herdr
        set herdr_bin (command -s herdr)
    else
        return 0
    end

    set -l session main
    if set -q HERDR_LOGIN_SESSION
        string match -qr '^[A-Za-z0-9._-]+$' -- "$HERDR_LOGIN_SESSION"; or return 0
        set session "$HERDR_LOGIN_SESSION"
    end

    set -gx HERDR_PROTOTYPE_DIR "$HOME/.dotfiles/herdr/prototype"
    set -gx HERDR_BIN_PATH "$herdr_bin"

    # The accepted golden-focus behavior is session-local Herdr state. Provision
    # it after the first server starts, without delaying the client attach.
    if not set -q HERDR_SKIP_PLUGIN_ENSURE
        "$HOME/.dotfiles/herdr/ensure_plugins.sh" "$session" >/dev/null 2>&1 &
    end

    exec "$herdr_bin" --session "$session"
end

__herdr_login_attach
functions -e __herdr_login_attach
