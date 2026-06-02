function fkill -d "Fuzzy kill processes"
    set pids (ps -ef | sed 1d | fzf -m \
        --header="Tab: select  Enter: kill selected" \
        --preview='ps -p {2} -o pid,ppid,user,%cpu,%mem,etime,command -w -w 2>/dev/null' \
        --preview-window=down,follow \
        | awk '{print $2}')

    if test -n "$pids"
        echo "Killing:"
        for pid in $pids
            echo "  PID $pid"
        end
        for pid in $pids
            kill -9 $pid
        end
    end
end
