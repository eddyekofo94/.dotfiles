function fif -d "find entry in files"
    argparse filter f/follow 'p/path=' -- $argv; or return

    set -l path "."
    set -l start_in_filter 0
    set -q _flag_filter; and set start_in_filter 1

    set -l query (string join " " -- $argv)
    if set -q _flag_path
        if not test -d "$_flag_path"
            printf 'fif: path is not a directory: %s\n' "$_flag_path" >&2
            return 2
        end
        set path "$_flag_path"
    else if test (count $argv) -ge 2; and test -d "$argv[1]"
        set path "$argv[1]"
        set query (string join " " -- $argv[2..-1])
    end

    # Keep query state local to this fzf session so concurrent searches do not
    # collide. Prune state abandoned by a killed terminal, and register an exit
    # handler for interruptions that bypass the normal return path below.
    set -l state_root (string replace -r '/$' '' -- "$TMPDIR")
    test -d "$state_root"; or set state_root /tmp
    command find "$state_root" -maxdepth 1 -type d -name 'fif-state.*' \
        -mmin +1440 -exec rm -rf {} + 2>/dev/null

    set -l state_dir (mktemp -d "$state_root/fif-state.XXXXXX")
    or return

    function __fif_cleanup_state --on-event fish_exit --inherit-variable state_dir
        command rm -rf "$state_dir"
    end

    function __fif_cleanup_on_term --on-signal TERM --inherit-variable state_dir
        command rm -rf "$state_dir"
        exit 143
    end

    function __fif_cleanup_on_hup --on-signal HUP --inherit-variable state_dir
        command rm -rf "$state_dir"
        exit 129
    end

    set -l rg_query_file "$state_dir/rg-query"
    set -l filter_query_file "$state_dir/filter-query"
    set -l rg_args --column --line-number --no-heading --color=always --smart-case
    set -q _flag_follow; and set -a rg_args --follow
    set -l rg_prefix "rg "(string join ' ' -- (string escape -- $rg_args))
    set -l rg_cmd "query={q}; if [ \${#query} -ge 2 ]; then $rg_prefix -e \"\$query\" -- "(string escape -- "$path")"; fi"

    set -l functions_dir (status dirname)
    set -l preview_cmd "fish --no-config -c 'source \"\$argv[1]\"; source \"\$argv[2]\"; _fif_preview \"\$argv[3]\" \"\$argv[4]\" \"\$argv[5]\" \"\$argv[6]\" \"\$argv[7]\"' " \
        (string escape -- "$functions_dir/_fzf_preview.fish")" " \
        (string escape -- "$functions_dir/_fif_preview.fish")" {1} {2} {3} " \
        (string escape -- "$rg_query_file")" {4..}"
    set -l fzf_query "$query"
    set -l fzf_prompt '1. ripgrep> '
    set -l fzf_header 'TAB: Select & Next | ALT-A: All | CTRL-G: Toggle Mode | CTRL-D/U: Scroll Preview | CTRL-O: Open'
    set -l fzf_mode_opts --disabled

    if test $start_in_filter -eq 1
        printf "" >"$rg_query_file"
        printf "%s" "$query" >"$filter_query_file"
        set fzf_query ""
        set fzf_mode_opts --disabled
    else
        printf "%s" "$query" >"$rg_query_file"
        printf "" >"$filter_query_file"
        if test (string length -- "$query") -ge 2
            set fzf_mode_opts --disabled --bind "start:reload:$rg_cmd || true"
        end
    end

    # fzf runs this in sh. The escaped {q} placeholders are expanded only after
    # transform-query becomes an fzf action.
    set -l toggle_action "case \"\$FZF_PROMPT\" in \
        *ripgrep*) \
            printf '%s' 'unbind(change)+change-prompt(2. files> )+enable-search+transform-query:printf %s \\{q} > $rg_query_file; cat $filter_query_file' ;; \
        *) \
            printf '%s' 'rebind(change)+change-prompt(1. ripgrep> )+disable-search+transform-search(cat $filter_query_file)+transform-query(printf %s \\{q} > $filter_query_file; cat $rg_query_file)' ;; \
    esac"

    # fif owns both its input and preview lifecycle. Prevent global fzf defaults
    # and the built-in walker from injecting plain file rows that do not contain
    # the file:line:column fields required by the preview.
    set -lx FZF_DEFAULT_COMMAND ""
    set -lx FZF_DEFAULT_OPTS ""

    command fzf --ansi --query "$fzf_query" \
        $fzf_mode_opts \
        --multi \
        --with-shell "sh -c" \
        --info=inline-right \
        --no-sort \
        --height=96% \
        --reverse \
        --extended \
        --border=none \
        --no-separator \
        --cycle \
        --margin=1,0,0 \
        --padding=0,0 \
        --prompt "$fzf_prompt" \
        --header "$fzf_header" \
        --border-label "| Find In Files: $path |" \
        --delimiter : \
        --nth 1 \
        --color "bg+:#313244,spinner:#f5e0dc,hl:-1:underline,border:#45475a,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:010,fg+:#cdd6f4,prompt:#cba6f7,hl+:-1:underline:reverse" \
        --bind 'ctrl-j:down,ctrl-k:up' \
        --bind '?:toggle-preview' \
        --bind "zero:transform-header:printf 'No matches. Type at least 2 characters, edit the ripgrep query, or press CTRL-G to filter current results.'" \
        --bind "result:transform-header:printf '%s' "(string escape -- "$fzf_header") \
        --bind "change:reload(sleep 0.05; $rg_cmd || true)+transform-search(cat $filter_query_file)" \
        --bind "ctrl-g:transform:$toggle_action" \
        (_fzf_file_picker_common_opts "{+1}") \
        --preview "$preview_cmd" \
        --preview-window 'up,60%,border-bottom,~3' \
        --bind 'enter:become(fish -c '\''_fif_edit_match "$argv[1]" "$argv[2]" "$argv[3]"'\'' {1} {2} {3})' </dev/null

    __fif_cleanup_state
    functions -e __fif_cleanup_state __fif_cleanup_on_term __fif_cleanup_on_hup
end
