function _fzf_copy_paths --description "Copy selected fzf file paths to the clipboard"
    set -l paths

    for selected in $argv
        set -l path (printf "%s" "$selected" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g')
        test -n "$path"; or continue

        if test -e "$path"
            set -a paths (path resolve -- "$path")
        else
            set -a paths "$path"
        end
    end

    test (count $paths) -gt 0; or return 0
    printf "%s\n" $paths | clipcopy
end
