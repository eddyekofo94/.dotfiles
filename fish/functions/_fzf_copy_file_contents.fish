function _fzf_copy_file_contents --description "Copy selected fzf file contents to the clipboard"
    set -l files

    for selected in $argv
        set -l file (printf "%s" "$selected" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g')
        test -f "$file"; and set -a files "$file"
    end

    test (count $files) -gt 0; or return 0
    command cat $files | clipcopy
end
