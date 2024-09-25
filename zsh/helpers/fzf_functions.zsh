#!/usr/bin/env zsh

has() {
    type "$1" &>/dev/null
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
        fzf --query="$1" --no-multi --select-1 --exit-0
    )
    if [[ -n $directory ]]; then
        cd "$directory"
        if has eza; then
            eza --git --group-directories-first --long --icons --header --binary --group --sort=modified
        else
            ls -al --color=auto
        fi
    fi
}

alias fcd='fzf_change_directory'
#  TODO: 2024-07-01 - Add C-f keymap
# bindkey -M '^[[f' fzf_change_directory

# cdf - cd into the directory of the selected file
cdf() {
    local file
    local dir
    file=$(fzf +m -q "$1") && dir=$(dirname "$file") && cd "$dir"
}

function delete-branches() {
  git branch |
    grep --invert-match '\*' |
    cut -c 3- |
    fzf --multi --preview="git log {} --" |
    xargs --no-run-if-empty git branch --delete --force
}


find_in_files() {
    # Switch between Ripgrep mode and fzf filtering mode (CTRL-T)
    rm -f /tmp/rg-fzf-{r,f}
    RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
    INITIAL_QUERY="${*:-}"
    fzf --ansi --disabled --query "$INITIAL_QUERY" \
        --bind "start:reload:$RG_PREFIX {q}" \
        --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
        --bind 'ctrl-t:transform:[[ ! $FZF_PROMPT =~ ripgrep ]] &&
        echo "rebind(change)+change-prompt(1. ripgrep> )+disable-search+transform-query:echo \{q} > /tmp/rg-fzf-f; cat /tmp/rg-fzf-r" ||
        echo "unbind(change)+change-prompt(2. fzf> )+enable-search+transform-query:echo \{q} > /tmp/rg-fzf-r; cat /tmp/rg-fzf-f"' \
        --color "hl:-1:underline,hl+:-1:underline:reverse" \
        --prompt '1. ripgrep> ' \
        --delimiter : \
        --header 'CTRL-T: Switch between ripgrep/fzf' \
        --preview 'bat --color=always {1} --highlight-line {2}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
        --bind 'enter:become($EDITOR {1} +{2})'
}

alias fif="find_in_files"

#  NOTE: 2024-06-14 - This finds a grep in a file then *cats* it
fcat() {
    if [ ! "$#" -gt 0 ]; then echo "Need a string to search for!"; return 1; fi

    local file
    file="$( rg --files-with-matches --no-messages "$*" | \
        fzf --preview "highlight -O ansi -l {} 2> /dev/null | \
        rg --colors 'match:bg:yellow' --ignore-case --pretty --context 10 '$1' || rg --ignore-case --pretty --context 10 '$1' {}" )"

    if [[ -n $file ]]; then
        echo "$file"
        bat -pp "$file"
    fi
}

fbat() {
    if [ ! "$#" -gt 0 ]; then echo "Need a string to search for!"; return 1; fi

    local file
    file="$( rg --files-with-matches --no-messages "$*" | fzf --preview "highlight -O ansi -l {} 2> /dev/null | rg --colors 'match:bg:yellow' --ignore-case --pretty --context 10 '$1' || rg --ignore-case --pretty --context 10 '$1' {}" )"

    if [[ -n $file ]]; then
        echo "$file"
        bat "$file"
    fi
}

#  REFC: 2024-07-04 - fix this one upm it might be useful
find_files_or_dirs() {
    fd --type file |
    fzf --prompt 'Files> ' \
        --header 'CTRL-T: Switch between Files/Directories' \
        --bind 'ctrl-t:transform:[[ ! $FZF_PROMPT =~ Files ]] &&
                echo "change-prompt(Files> )+reload(fd --type file)" ||
                echo "change-prompt(Directories> )+reload(fd --type directory)"' \
        --preview '[[ $FZF_PROMPT =~ Files ]] && bat --color=always {} || tree -C {}'
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
        --preview="git log {} --" \
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
        local pids=$(ps -ef -u $USER | sed 1d | fzf --bind='ctrl-r:reload(date; ps -ef)' --preview 'echo {}' --preview-window up:3:wrap | awk '{print $2}')
    elif [[ $(uname) == Darwin ]]; then
        local pids=$(ps -ef -u $USER | sed 1d | fzf --preview 'echo {}' --preview-window up:3:wrap | awk '{print $3}')
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
    git rev-parse --git-dir > /dev/null 2>&1 || { echo "You are not in a git repository" && return }
    local files=$(_fzf_git_status_git | cut -c4-) #get file from fzf
    if [[ $files ]]; then
        for file in $(echo $files);
        do; git add --verbose $file; done;
    fi
}

alias fga='fzf_git_add'

fdiff() {
    git rev-parse --git-dir > /dev/null 2>&1 || { echo "You are not in a git repository" && return }
    local files=$(_fzf_git_status_git | cut -c4-) #get file from fzf
    if [[ -f "$files" ]]; then
        for file in $(echo $files);
        do; git diff $file; done;
    else
        "git status is empty..."
    fi
}

# alias gss="fdiff"


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
        for file in $(echo $inst);
        do; brew install $file; done;
    fi
}

# Update (one or multiple) selected application(s)
# mnemonic [B]rew [U]pdate [P]ackage
bup() {
    local upd=$(brew leaves | fzf -m)

    if [[ $upd ]]; then
        for file in $(echo $upd);
        do; brew upgrade $file; done;
    fi
}

fzf_alias() {
    local selection
    selection="$(alias |
                       sed 's/=/\t/' |
                       column -s '	' -t |
                       fzf --preview "echo {2..}" --query="$1" |
                       awk '{ print $1 }')"
    echo "${selection}"
    eval "${selection}"
}

alias falias="fzf_alias"
