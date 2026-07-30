function _fzf_search_history --description "Search command history. Replace the command line with the selected command."
    # history merge incorporates history changes from other fish sessions
    # it errors out if called in private mode
    if test -z "$fish_private_mode"
        builtin history merge
    end

    if not set --query fzf_history_time_format
        # Reference https://devhints.io/strftime to understand strftime format symbols
        set -f fzf_history_time_format "%m/%d"
    end

    # Delinate time from command in history entries using the vertical box drawing char (U+2502).
    # Then, to get raw command from history entries, delete everything up to it. The ? on regex is
    # necessary to make regex non-greedy so it won't match into commands containing the char.
    set -f time_prefix_regex '^.*? │ '

    # Structure the list the way Fish highlights the command line: dimmed
    # timestamp, command token in $fish_color_command. Highlighting each entry
    # properly would cost one fish_indent process per entry, which is far too slow
    # for a large history, so the preview window keeps that job. FZF strips these
    # sequences from both matching and its returned selection, so the recalled
    # command stays byte-identical to what the history holds.
    #
    # Perl owns the substitution because it is the only readily available stream
    # editor that treats NUL as the record separator, which the multi-line entries
    # below require; \A keeps the match on the first line of each record. Styles
    # travel through the environment so escape sequences never reach the regex
    # source. set_color without a theme fails, leaving the styles empty and the
    # list unstyled rather than erroring.
    set -f dim_style (set_color $fish_color_comment 2>/dev/null)
    set -f command_style (set_color $fish_color_command 2>/dev/null)
    set -f reset_style (set_color normal)

    # Delinate commands throughout pipeline using null rather than newlines because commands can be multi-line
    set -f commands_selected (
        builtin history --null --show-time="$fzf_history_time_format │ " |
        FZF_HISTORY_DIM="$dim_style" \
            FZF_HISTORY_COMMAND="$command_style" \
            FZF_HISTORY_RESET="$reset_style" \
            perl -0pe 's/\A(.*? │ )(\S+)/$ENV{FZF_HISTORY_DIM}$1$ENV{FZF_HISTORY_COMMAND}$2$ENV{FZF_HISTORY_RESET}/' |
        _fzf_wrapper --read0 \
            --print0 \
            --multi \
            --scheme=history \
            --prompt="History> " \
            --query=(commandline) \
            --preview="string replace --regex '$time_prefix_regex' '' -- {} | fish_indent --ansi" \
            --preview-window="bottom:3:wrap" \
            $fzf_history_opts |
        string split0 |
        # remove timestamps from commands selected
        string replace --regex $time_prefix_regex ''
    )

    if test $status -eq 0
        commandline --replace -- $commands_selected
    end

    commandline --function repaint
end
