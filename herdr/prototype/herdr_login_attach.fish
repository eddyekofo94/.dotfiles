# PROTOTYPE ONLY: source from config.fish after migration is explicitly approved.

function __herdr_login_attach --description 'Attach a top-level login shell to Herdr'
    status is-login; and status is-interactive; or return 0

    # Herdr injects HERDR_ENV into pane processes. TMUX protects the current
    # production path while both multiplexers coexist during the trial.
    set -q HERDR_ENV; and return 0
    set -q HERDR_PANE_ID; and return 0
    set -q TMUX; and return 0
    set -q HERDR_NO_AUTO_ATTACH; and return 0

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

    exec "$herdr_bin" --session "$session"
end

__herdr_login_attach
functions -e __herdr_login_attach
