function zjcs -d "zellij clean sessions"
    set -l sessions (zellij list-sessions -n -s )
    set -l current_session_name $ZELLIJ_SESSION_NAME

    for session in $sessions
        if test "$session" != "$current_session_name"
            echo "Session: $session"
            zellij d --force "$session"
        end
    end
end
