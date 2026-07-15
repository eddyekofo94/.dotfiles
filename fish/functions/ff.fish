function __ff_open_files_or_dir --description 'Use xdg to open files' -a path
    if test (count $argv) = 1; and test -d "$path"
        cd $path
        return
    end

    set -l is_macos (test (uname) = "Darwin"; and echo Darwin)

    for target in $argv
        if test -d $target
            or string match -req 'text|empty' "$(file -b $target)"
            set -af text_or_dirs $target
        else
            set -af others $target
        end
    end

    if test "$is_macos" = "Darwin"
        for other in $others
            open $other 2>/dev/null
        end
    else if type -q xdg-open
        for other in $others
            xdg-open $other 2>/dev/null
        end
    else if set -q others
        echo 'open/xdg-open not found, omitting files: ' $others 1>&2
    end

    if set -q text_or_dirs
        type -q $EDITOR
        and $EDITOR $text_or_dirs
        or echo '$EDITOR not found, omitting files: ' $text_or_dirs 1>&2
    end
end

function ff --description 'Use fzf to open files or cd to directories' \
    --argument-names base query
    set -l base (test -n "$base"; and echo $base; or echo $PWD)

    set -l expanded_base $base
    if string match -rq '^~' $base
        set expanded_base (string replace '~' $HOME $base)
    end

    if test (count $argv) = 1; and test -f "$expanded_base"
        __ff_open_files_or_dir $argv
        return
    end

    if not type -q fzf
        echo 'fzf is not executable' 1>&2
        return 1
    end

    set -l fd_cmd
    if type -q fd
        set fd_cmd fd
    else if type -q fdfind
        set fd_cmd fdfind
    else
        echo 'fd is not executable' 1>&2
        return 1
    end

    set -l selection (
        $fd_cmd -0 -p -H -L -td -tf -tl -c=always $expanded_base \
        | fzf --read0 -m --ansi --query=$query (_fzf_file_picker_opts "$expanded_base")
    )

    if test -z "$selection"
        return 0
    end

    set -l targets (string split0 $selection)

    __ff_open_files_or_dir $targets
    return
end
