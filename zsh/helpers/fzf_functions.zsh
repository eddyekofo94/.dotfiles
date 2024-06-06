#!/usr/bin/env zsh
echo "fzf_functions.zsh"

_fzf_compgen_path() {
    rg --files --glob "!.git" . "$1"
}

_fzf_compgen_dir() {
    fd --type d --hidden --follow --exclude ".git" . "$1"
}

_fzf_comprun() {
    local command=$1
    shift

    case "$command" in
        tree)         find . -type d | fzf --preview 'tree -C {}' "$@" ;;
        *)            fzf "$@" ;;
    esac
}

_fzf_complete_git() {
    _fzf_complete -- "$@" < <(
        echo log
        echo diff
    )
}

_fzf_complete_git() {
    _fzf_complete -- "$@" < <(
        git --help -a | grep -E '^\s+' | awk '{print $1}'
    )
}

# fe [FUZZY PATTERN] - Open the selected file with the default editor
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
#  NOTE: 2023-10-02 - This works but I will try another one
# fe() {
#     IFS=$'\n' files=($(fzf-tmux --query="$1" --multi --select-1 --exit-0))
#     [[ -n "$files" ]] && ${EDITOR:-vim} "${files[@]}"
# }

fzf_find_edit() {
    local file=$(
      fzf --query="$1" --no-multi --select-1 --exit-0 \
          --preview 'bat --color=always --line-range :500 {}'
    )
    if [[ -n "$file" ]]; then
        $EDITOR "$file"
    fi
}

alias fe='fzf_find_edit'

fzf_change_directory() {
    local directory=$(
      fd --type d | \
        fzf --query="$1" --no-multi --select-1 --exit-0 \
            --preview 'tree -C {} | head -100'
    )
    if [[ -n $directory ]]; then
        cd "$directory"
    fi
}

alias fcd='fzf_change_directory'

# cdf - cd into the directory of the selected file
cdf() {
    local file
    local dir
    file=$(fzf +m -q "$1") && dir=$(dirname "$file") && cd "$dir"
}

delete-branches() {
    local branches_to_delete
    branches_to_delete=$(git branch | fzf --multi)

    if [ -n "$branches_to_delete" ]; then
        git branch --delete --force $branches_to_delete
    fi
}

# using ripgrep combined with preview
# find-in-file - usage: fif <searchTerm>
fif() {
    if [ ! "$#" -gt 0 ]; then echo "Need a string to search for!"; return 1; fi
    rg --files-with-matches --no-messages "$1" | fzf --preview "highlight -O ansi -l {} 2> /dev/null | rg --colors 'match:bg:yellow' --ignore-case --pretty --context 10 '$1' || rg --ignore-case --pretty --context 10 '$1' {}"
}

# fco - checkout git branch/tag
fco() {
    local tags branches target
    branches=$(
        git --no-pager branch --all \
            --format="%(if)%(HEAD)%(then)%(else)%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%1B[0;34;1mbranch%09%1B[m%(refname:short)%(end)%(end)" \
        | sed '/^$/d') || return
    tags=$(
    git --no-pager tag | awk '{print "\x1b[35;1mtag\x1b[m\t" $1}') || return
    target=$(
        (echo "$branches"; echo "$tags") |
        fzf --no-hscroll --no-multi -n 2 \
        --ansi) || return
    git checkout $(awk '{print $2}' <<<"$target" )
}

# fco_preview - checkout git branch/tag, with a preview showing the commits between the tag/branch and HEAD
fco_preview() {
    local tags branches target
    branches=$(
        git --no-pager branch --all \
            --format="%(if)%(HEAD)%(then)%(else)%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%1B[0;34;1mbranch%09%1B[m%(refname:short)%(end)%(end)" \
        | sed '/^$/d') || return
    tags=$(
    git --no-pager tag | awk '{print "\x1b[35;1mtag\x1b[m\t" $1}') || return
    target=$(
        (echo "$branches"; echo "$tags") |
        fzf --no-hscroll --no-multi -n 2 \
        --ansi --preview="git --no-pager log -150 --pretty=format:%s '..{2}'") || return
    git checkout $(awk '{print $2}' <<<"$target" )
}

# fcoc - checkout git commit
fcoc() {
    local commits commit
    commits=$(git log --pretty=oneline --abbrev-commit --reverse) &&
    commit=$(echo "$commits" | fzf --tac +s +m -e) &&
    git checkout $(echo "$commit" | sed "s/ .*//")
}

# fshow - git commit browser
fshow() {
  git log --graph --color=always \
          --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
  fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
          --bind "ctrl-m:execute:
                (grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
                {}
FZF-EOF"
}

alias glNoGraph='git log --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr% C(auto)%an" "$@"'
_gitLogLineToHash="echo {} | grep -o '[a-f0-9]\{7\}' | head -1"
_viewGitLogLine="$_gitLogLineToHash | xargs -I % sh -c 'git show --color=always % | delta'"

# fcoc_preview - checkout git commit with previews
fcoc_preview() {
    local commit
    commit=$( glNoGraph |
        fzf --no-sort --reverse --tiebreak=index --no-multi \
            --ansi --preview="$_viewGitLogLine" ) &&
    git checkout $(echo "$commit" | sed "s/ .*//")
}

# fshow_preview - git commit browser with previews
fshow_preview() {
    glNoGraph |
    fzf --no-sort --reverse --tiebreak=index --no-multi \
            --ansi --preview="$_viewGitLogLine" \
            --header "enter to view, alt-y to copy hash" \
            --bind "enter:execute:$_viewGitLogLine   | less -R" \
            --bind "alt-y:execute:$_gitLogLineToHash | xclip"
}

fzf_kill() {
    if [[ $(uname) == Linux ]]; then
        local pids=$(ps -f -u $USER | sed 1d | fzf | awk '{print $2}')
    elif [[ $(uname) == Darwin ]]; then
        local pids=$(ps -f -u $USER | sed 1d | fzf | awk '{print $3}')
    else
        echo 'Error: unknown platform'
        return
    fi
    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill -9 "$@"
    fi
}

alias fkill='fzf_kill'

fzf_git_add() {
    local selections=$(
      git status --porcelain | \
        fzf --ansi \
            --preview 'if (git ls-files --error-unmatch {2} &>/dev/null); then
                           git diff --color=always {2}
                       else
                           bat --color=always --line-range :500 {2}
                       fi'
    )
    if [[ -n $selections ]]; then
        local additions=$(echo $selections | sed 's/M //g' | sed 's/?? //g')
        git add --verbose $additions
    fi
}

alias gadd='fzf_git_add'


# ZSH
# Make all kubectl completion fzf
#  BUG: 2023-09-26 - /proc/self/fd/13:2: command not found: compdef
# command -v fzf >/dev/null 2>&1 && {
#     source <(kubectl completion zsh | sed 's#${requestComp} 2>/dev/null#${requestComp} 2>/dev/null | head -n -1 | fzf  --multi=0 #g')
# }

# Install (one or multiple) selected application(s)
# using "brew search" as source input
# mnemonic [B]rew [I]nstall [P]ackage
bip() {
    local inst=$(brew search "$@" | fzf -m)

    if [[ $inst ]]; then
        for prog in $(echo $inst);
        do; brew install $prog; done;
    fi
}

# Update (one or multiple) selected application(s)
# mnemonic [B]rew [U]pdate [P]ackage
bup() {
    local upd=$(brew leaves | fzf -m)

    if [[ $upd ]]; then
        for prog in $(echo $upd);
        do; brew upgrade $prog; done;
    fi
}
