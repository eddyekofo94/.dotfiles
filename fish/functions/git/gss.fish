function __gss_strip_ansi
    perl -pe 's/\e\[[0-9;]*[a-zA-Z]//g'
end

function __gss_path_from_line --argument-names line
    set -l clean (printf "%s" "$line" | __gss_strip_ansi)
    set -l path (string sub -s 3 -- "$clean" | string trim)
    set path (string replace -r '^.* -> ' '' -- "$path")

    if string match -q '"*"' -- "$path"
        set path (string trim -c '"' -- "$path")
        set path (string replace -a '\\"' '"' -- "$path")
        set path (string replace -a '\\\\' '\\' -- "$path")
    end

    printf "%s\n" "$path"
end

function __gss_status_from_line --argument-names line
    set -l clean (printf "%s" "$line" | __gss_strip_ansi)
    string sub -s 1 -l 2 -- "$clean"
end

function __gss_status
    git -c color.status=always -c core.quotePath=false status --short
end

function __gss_toggle
    for line in $argv
        set -l file_status (__gss_status_from_line "$line")
        set -l path (__gss_path_from_line "$line")
        test -n "$path"; or continue

        set -l index_status (string sub -s 1 -l 1 -- "$file_status")

        if test "$index_status" != " "; and test "$index_status" != "?"
            git restore --staged -- "$path"
        else
            git add -- "$path"
        end
    end
end

function __gss_stage
    for line in $argv
        set -l path (__gss_path_from_line "$line")
        test -n "$path"; and git add -- "$path"
    end
end

function __gss_unstage
    for line in $argv
        set -l path (__gss_path_from_line "$line")
        test -n "$path"; and git restore --staged -- "$path"
    end
end

function __gss_checkout
    for line in $argv
        set -l file_status (__gss_status_from_line "$line")
        set -l path (__gss_path_from_line "$line")
        test -n "$path"; or continue

        if string match -q '??' -- "$file_status"
            command rm -ri -- "$path"
        else
            git restore --worktree -- "$path"
        end
    end
end

function __gss_copy_paths
    set -l paths
    for line in $argv
        set -l path (__gss_path_from_line "$line")
        test -n "$path"; and set -a paths "$path"
    end

    test (count $paths) -gt 0; or return 0
    printf "%s\n" $paths | clipcopy
end

function __gss_edit
    set -l paths
    for line in $argv
        set -l path (__gss_path_from_line "$line")
        test -f "$path"; and set -a paths "$path"
    end

    test (count $paths) -gt 0; or return 0
    set -l editor $EDITOR
    test -n "$editor"; or set editor vim
    eval "$editor "(string escape -- $paths)
end

function __gss_preview --argument-names line
    set -l file_status (__gss_status_from_line "$line")
    set -l path (__gss_path_from_line "$line")
    test -n "$path"; or return 0

    # Resolve path relative to repository root if not present relative to current working directory
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    set -l resolved_path "$path"
    if not test -e "$resolved_path"; and test -n "$repo_root"
        if test -e "$repo_root/$path"
            set resolved_path "$repo_root/$path"
        end
    end

    printf "\033[1m%s\033[0m \033[2m%s\033[0m\n\n" "$file_status" "$resolved_path"

    if test -d "$resolved_path"
        eza -T --color=always --icons auto -- "$resolved_path" 2>/dev/null | head -200
        return
    end

    set -l index_status (string sub -s 1 -l 1 -- "$file_status")
    set -l worktree_status (string sub -s 2 -l 1 -- "$file_status")

    # Show diff only for unstaged changes ( M, MM)
    if test "$worktree_status" != " " -a "$worktree_status" != "?"
        set -l width 80
        if set -q FZF_PREVIEW_COLUMNS
            set width $FZF_PREVIEW_COLUMNS
        end

        if type -q delta
            git --no-pager diff --color=always -- "$resolved_path" | delta --paging=never --width $width
        else
            git --no-pager diff --color=always -- "$resolved_path"
        end
        printf "\n"
    end

    # If the file has staged changes only (and no unstaged changes), we temporarily unstage
    # the file so bat's git engine compares the file against HEAD, showing +, -, ~ in the gutter.
    set -l has_staged false
    if test "$index_status" != " " -a "$index_status" != "?"
        set has_staged true
    end
    set -l has_unstaged false
    if test "$worktree_status" != " " -a "$worktree_status" != "?"
        set has_unstaged true
    end

    set -l temp_unstaged false
    if test "$has_staged" = "true" -a "$has_unstaged" = "false"
        git reset HEAD -- "$resolved_path" >/dev/null 2>&1
        set temp_unstaged true
        # Register safety traps to ensure the changes are ALWAYS re-staged on exit/interruption
        trap "git add -- (string escape -- \$resolved_path) >/dev/null 2>&1" EXIT INT TERM
    end

    # Show file content through bat for all file types (with fallback to cat)
    if test -f "$resolved_path"
        if type -q bat
            bat --color=always --style=numbers,changes --line-range :500 -- "$resolved_path"
        else
            cat -- "$resolved_path" | head -500
        end
    end

    # Explicitly re-stage if we successfully completed normally
    if test "$temp_unstaged" = "true"
        git add -- "$resolved_path" >/dev/null 2>&1
    end
end

function gss -d "git status"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
        echo "gss: not in a git repository" >&2
        return 1
    end

    set -l source_file (path resolve -- (status filename))
    set -l list_cmd "git -c color.status=always -c core.quotePath=false status --short"
    set -l header "CTRL-SPACE: Toggle | F5: Stage all | F6: Unstage all | F7: Commit | F8: Amend | CTRL-X: Discard | CTRL-O: Edit | CTRL-Y: Copy path"

    __gss_status | fzf --ansi --multi --no-sort --header-first \
        --header "$header" \
        --preview "fish -c 'source \"\$argv[2]\"; __gss_preview \"\$argv[3..-1]\"' gss-preview "(string escape -- "$source_file")" '{}'" \
        --preview-window 'right,65%,border-left' \
        --bind "ctrl-space:execute-silent(fish -c 'source \"\$argv[2]\"; __gss_toggle \$argv[3..]' gss-toggle "(string escape -- "$source_file")" {+})+reload($list_cmd)+clear-selection" \
        --bind "f5:execute-silent(git add -A)+reload($list_cmd)+clear-selection" \
        --bind "f6:execute-silent(git restore --staged .)+reload($list_cmd)+clear-selection" \
        --bind "ctrl-x:execute(fish -c 'source \"\$argv[2]\"; __gss_checkout \"\$argv[3]\"' gss-checkout "(string escape -- "$source_file")" '{}')+reload($list_cmd)+clear-selection" \
        --bind "ctrl-o:execute(fish -c 'source \"\$argv[2]\"; __gss_edit \"\$argv[3]\"' gss-edit "(string escape -- "$source_file")" '{}')" \
        --bind "ctrl-y:execute-silent(fish -c 'source \"\$argv[2]\"; __gss_copy_paths \"\$argv[3]\"' gss-copy "(string escape -- "$source_file")" '{}')" \
        --bind 'f7:become(git commit)' \
        --bind 'f8:become(git commit --amend)' \
        --bind "f9:execute(git add --patch)+reload($list_cmd)" \
        --bind '?:toggle-preview' \
        --bind 'tab:toggle+down,shift-tab:toggle+up' \
        --bind 'ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down'
end
