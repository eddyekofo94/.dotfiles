
#function _fzf_change_directory
#    set -l directory
#    set -l INITIAL_QUERY "{*:-}"
#
#    fd --type d | fzf --query="$argv" --no-multi --select-1 --exit-0 \
#        --bind 'enter:become(cd {1})'
#    #if test -d $directory
#    #    cd "$directory"
#    #    if command -q eza
#    #        eza --git --group-directories-first --long --icons --header --binary --group --sort=modified
#    #    else
#    #        ls -al --color=auto
#    #    end
#    #end
#end

set -Ux _fzf_change_directory fcd
#abbr _fzf_change_directory fcd
