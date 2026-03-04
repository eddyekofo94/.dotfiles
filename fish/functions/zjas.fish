function zjas -d "zellij attach session"
    set -l old_session $ZELLIJ_SESSION_NAME

    set -l get_sessions (
            zellij list-sessions -n -s | \
            fzf \
            --no-multi \
            --select-1 \
            --query "$argv[1]" \
            --preview "echo {}" --preview-window 'nohidden:wrap' \
            ) || return

    if zellij ls -n -s | grep -q $get_sessions
        # zellij kill-session "${current_session}"
        echo "$old_session"
        zellij kill-session "$old_session" && zellij attach "$get_sessions"
    end

end
