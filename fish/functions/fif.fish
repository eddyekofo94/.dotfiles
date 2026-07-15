function fif -d "find entry in files"
    set -l path "."
    set -l start_in_filter 0

    if test "$argv[1]" = "--filter"
        set start_in_filter 1
        set -e argv[1]
    end

    set -l query (string join " " -- $argv)
    if test -n "$argv[1]"; and test -d "$argv[1]"
        set path "$argv[1]"
        set query (string join " " -- $argv[2..-1])
    end

    # Keep query state local to this fzf session so concurrent searches do not collide.
    set -l state_dir (mktemp -d -t fif-state.XXXXXX)
    or return
    set -l rg_query_file "$state_dir/rg-query"
    set -l filter_query_file "$state_dir/filter-query"
    set -l rg_prefix "rg --column --line-number --no-heading --color=always --smart-case --follow"
    set -l rg_cmd "$rg_prefix -e {q} -- "(string escape -- "$path")
    set -l preview_cmd "fish -c '_fif_preview \"\$argv[1]\" \"\$argv[2]\" \"\$argv[3]\" \"\$argv[4]\" \"\$argv[5]\"' {1} {2} {3} "(string escape -- "$rg_query_file")" {4..}"
    set -l fzf_query "$query"
    set -l fzf_prompt '1. ripgrep> '
    set -l fzf_header 'TAB: Select & Next | ALT-A: All | CTRL-G: Toggle Mode | CTRL-D/U: Scroll Preview | CTRL-O: Open'
    set -l fzf_mode_opts --disabled

    if test $start_in_filter -eq 1
        printf "" > "$rg_query_file"
        printf "%s" "$query" > "$filter_query_file"
        set fzf_query ""
        set fzf_mode_opts --disabled
    else
        printf "%s" "$query" > "$rg_query_file"
        printf "" > "$filter_query_file"
        set fzf_mode_opts --disabled --bind "start:reload:$rg_cmd || true"
    end

    # fzf runs this in sh. The escaped {q} placeholders are expanded only after
    # transform-query becomes an fzf action.
    set -l toggle_action "case \"\$FZF_PROMPT\" in \
        *ripgrep*) \
            printf '%s' 'unbind(change)+change-prompt(2. files> )+enable-search+transform-query:printf %s \\{q} > $rg_query_file; cat $filter_query_file' ;; \
        *) \
            printf '%s' 'rebind(change)+change-prompt(1. ripgrep> )+disable-search+transform-search(cat $filter_query_file)+transform-query(printf %s \\{q} > $filter_query_file; cat $rg_query_file)' ;; \
    esac"

    fzf --ansi --query "$fzf_query" \
        $fzf_mode_opts \
        --multi \
        --with-shell "sh -c" \
        --info=inline-right \
        --no-sort \
        --prompt "$fzf_prompt" \
        --header "$fzf_header" \
        --border-label "| Find In Files: $path |" \
        --delimiter : \
        --nth 1 \
        --color "hl:-1:underline,hl+:-1:underline:reverse,marker:010" \
        --bind "zero:transform-header:printf 'No matches. Keep typing, edit the ripgrep query, or press CTRL-G to filter current results.'" \
        --bind "result:transform-header:printf '%s' "(string escape -- "$fzf_header") \
        --bind "change:reload(sleep 0.1; $rg_cmd || true)+transform-search(cat $filter_query_file)" \
        --bind "ctrl-g:transform:$toggle_action" \
        (_fzf_file_picker_common_opts "{+1}") \
        --preview "$preview_cmd" \
        --preview-window 'up,60%,border-bottom,~3' \
        --bind 'enter:become(fish -c '\''_fif_edit_match "$argv[1]" "$argv[2]" "$argv[3]"'\'' {1} {2} {3})'

    command rm -rf "$state_dir"
end
