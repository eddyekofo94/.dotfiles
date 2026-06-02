if not status is-interactive
    exit
end

function __auto_ls \
    --on-variable PWD \
    --description 'List directory contents after changing cwd'
    set -l output (command eza --icons auto --group-directories-first --color=always 2>/dev/null; or command ls -G)

    if test -z "$output"
        return
    else
         eza -1F --git --icons auto
    end

    # set -l lines (tput lines 2>/dev/null; or 16)
    # set -l max_lines (math ceil $lines / 4)
    # set -l num_lines (count $output)
    #
    # if test "$num_lines" -le "$max_lines"
    #     printf '%s\n' $output
    # else
    #     printf '%s\n' $output | head -n $max_lines
    #     echo
    #     echo ... $num_lines lines total
    # end
end
