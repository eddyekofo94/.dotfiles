#  FIX: 2025-01-13 - This is not working, make it compatible with fish
# fco - checkout git branch/tag
function fgco -d "fzf git checkout"
    set -l tags branches target
    set branches (
        git --no-pager branch --all \
            --format="%(if)%(HEAD)%(then)%(else)%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%1B[0;34;1mbranch%09%1B[m%(refname:short)%(end)%(end)" \
        | sed '/^$/d') || return
    set -l tags (
    git --no-pager tag | awk '{print "\x1b[35;1mtag\x1b[m\t" $argv[1]}') || return
    set -l target (
        echo "$branches"; echo "$tags" |
        fzf --no-hscroll --no-multi -n 2 \
        --ansi) || return


    if test (count $target) -gt 0
        git checkout (awk '{print $argv[2]}' $target )
    end
end


#alias glNoGraph='git log --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr% C(auto)%an $argv'
#set -l _gitLogLineToHash "echo {} | grep -o '[a-f0-9]\{7\}' | head -1"
#set -l _viewGitLogLine "$_gitLogLineToHash | xargs -I % sh -c 'git show --color=always % | delta'"
#
## fcoc_preview - checkout git commit with previews
#function fcoc_preview -d "fzf - checkout git commit with previews"
#    set -l commit
#    set commit ( glNoGraph |
#        fzf --no-sort --reverse --tiebreak=index --no-multi \
#            --ansi --preview="$_viewGitLogLine" ) &&
#    git checkout (echo "$commit" | sed "s/ .*//")
#end
