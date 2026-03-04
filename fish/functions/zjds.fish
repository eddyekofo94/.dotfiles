function zjds -d "zellij delete sessions"
    #local sessions
    set -l sessions
    set -l current_session_name "$ZELLIJ_SESSION_NAME"

    set sessions (zellij list-sessions -n -s | \
    fzf --exit-0 \
        --multi \
        --preview "echo {}" --preview-window 'nohidden:wrap' \
        --query="$argv[1]") || return

    if test (count $sessions) -gt 0
        for session in $sessions
            if test "$session" != "$current_session_name"
                echo $session
                zellij d --force "$session"
            end
        end

        echo "Cleaned Zellij sessions"
    end

    # zellij kill-session "${sessions[@]}"
end
