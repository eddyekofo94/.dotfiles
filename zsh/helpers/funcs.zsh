#!/usr/bin/env zsh
# shellcheck shell=bash

function mixx() {
    mix $(mix help --names | fzf --delimiter=' ' --preview 'mix help {}' --reverse)
}

fuzzy-xdg-open() {
    local output
    output=$(fzf --height 40% --reverse </dev/tty) && xdg-open ${(q-)output}
    zle reset-prompt
}

zle -N fuzzy-xdg-open
bindkey '^o' fuzzy-xdg-open

function __close_all_apps() {
    if [[ "$(uname)" != "Darwin" ]]; then
        exit 0
    fi

    apps=$(osascript -e 'tell application "System Events" to get name of (processes where background only is false)' | awk -F ', ' '{for(i=1;i<=NF;i++) printf "%s;", $i}')
    while [ "$apps" ] ;do
        app=${apps%%;*}
        if [[ $app != 'alacritty' && $app != 'kitty' && $app != 'wezterm' ]]
        then
            pkill -x echo $app
        fi

        [ "$apps" = "$app" ] && \
            apps='' || \
            apps="${apps#*;}"
    done
}

function reboot() {
    __close_all_apps

    sudo reboot
}

function shutdown() {
    __close_all_apps

    sudo shutdown -h now
}


## -- [FZF] --------------------------------------------------------------------
# Open fzf in tmux popup
# function __fzfp() {
#   fzf-tmux -p -w 70% -h 70%
# }
# # Open project under workspace folder
# function fprj() {
#   cd $WORKSPACE; ls -d */ | __fzfp | {
#     cd -;
#     read result;
#     if [ ! -z "$result" ]; then
#       cd $WORKSPACE/$result
#     fi
#   }
#   zle && zle reset-prompt
# }
# # Run frequently used commands
# # First param takes local path to set of commands, i.e. ~/local/cmds
# function fcmd() {
#   echo $1
#   local cmd=$(cat $1 | ${2-"__fzfp"})
#   if [ -n "$cmd" ]; then
#     local escape=$(echo $cmd | sed 's/[]\/$*.^[]/\\&/g')
#     echo -e "$cmd\n$(cat $1 | sed "s/$escape//g" | sed '/^$/d')" > $1
#     echo ""
#     echo $fg[yellow] "$cmd"
#     echo ""
#     eval $cmd
#   else
#     echo $fg[red] "Run nothing!"
#   fi
# }

################
# git
################

is_in_git_repo() {
    git rev-parse HEAD > /dev/null 2>&1
}

fzf-down() {
    fzf --min-height 20 --border --bind ctrl-/:toggle-preview "$@"
}

function gall() {
    is_in_git_repo || return
    git add .
    if [ "$1" != "" ]
    then
        git commit -m "$1"
    else
        git commit -m update # default commit message is `update`
    fi # closing statement of if-else block
    git push origin HEAD
}

_gf() {
    is_in_git_repo || return
    git -c color.status=always status --short |
    fzf-down -m --ansi --nth 2..,.. \
        --preview '(git diff --color=always -- {-1} | sed 1,4d; cat {-1})' |
    cut -c4- | sed 's/.* -> //'
}

_gb() {
    is_in_git_repo || return
    git branch -a --color=always | grep -v '/HEAD\s' | sort |
    fzf-down --ansi --multi --tac --preview-window right:70% \
        --preview 'git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" $(sed s/^..// <<< {} | cut -d" " -f1)' |
    sed 's/^..//' | cut -d' ' -f1 |
    sed 's#^remotes/##'
}

_gt() {
    is_in_git_repo || return
    git tag --sort -version:refname |
    fzf-down --multi --preview-window right:70% \
        --preview 'git show --color=always {}'
}

_gh() {
    is_in_git_repo || return
    git log --date=short --format="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" --graph --color=always |
    fzf-down --ansi --no-sort --reverse --multi --bind 'ctrl-s:toggle-sort' \
        --header 'Press CTRL-S to toggle sort' \
        --preview 'grep -o "[a-f0-9]\{7,\}" <<< {} | xargs git show --color=always' |
    grep -o "[a-f0-9]\{7,\}"
}

_gr() {
    is_in_git_repo || return
    git remote -v | awk '{print $1 "\t" $2}' | uniq |
    fzf-down --tac \
        --preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" {1}' |
    cut -d$'\t' -f1
}

_gs() {
    is_in_git_repo || return
    git stash list | fzf-down --reverse -d: --preview 'git show --color=always {1}' |
    cut -d: -f1
}

function gshd() { # smart show diffs
    git status &> /dev/null
    inside_git_repo=$?
    if [[ $inside_git_repo -eq 0 ]]; then

        git diff --quiet
        has_unstaged_changes=$?

        git diff --quiet --cached
        has_staged_changes=$?

        if [[ $has_unstaged_changes -eq 1 ]]; then
            echo "Showing diff of unstaged changes..."
            git difftool -d
        elif [[ $has_staged_changes -eq 1 ]]; then
            echo "Showing diff of staged changes..."
            git difftool -d --staged
        else
            echo "Showing last commit..."
            git difftool -d HEAD~1 HEAD
        fi

    else
        echo "Error: \"$0\" can only be used inside a Git repository."
    fi
}

# Thanks @dkarter!
# https://github.com/dkarter/dotfiles/blob/master/zshrc#L312-L339
# fgstash - easier way to deal with stashes
# type fstash to get a list of your stashes
# enter shows you the contents of the stash
# ctrl-d shows a diff of the stash against your current HEAD
# ctrl-b checks the stash out as a branch, for easier merging
function fgstash() {
    local out q k sha
    while out=$(
        git stash list --pretty="%C(yellow)%h %>(14)%Cgreen%cr %C(blue)%gs" |
        fzf --ansi --no-sort --query="$q" --print-query \
            --expect=ctrl-d,ctrl-b
        ); do
        mapfile -t out <<<"$out"
        q="${out[0]}"
        k="${out[1]}"
        sha="${out[-1]}"
        sha="${sha%% *}"
        [[ -z "$sha" ]] && continue
        if [[ "$k" == 'ctrl-d' ]]; then
            git diff $sha
        elif [[ "$k" == 'ctrl-b' ]]; then
            git stash branch "stash-$sha" $sha
            break
        else
            git stash show -p $sha
        fi
    done
}

# Test whether a given command exists
# Adapted from http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script/3931779#3931779
# NOTE: This function is duplicated in .zshrc so that it doesn't have to depend on this file,
# but this shouldn't cause any issues
function command_exists() {
    hash "$1" &> /dev/null
}

# Shows how long processes have been up.
# No arguments shows all processes, one argument greps for a particular process.
# Found at <http://hints.macworld.com/article.php?story=20121127064752309>
function psup() {
    ps acxo etime,command | grep -- "$1"
}

# Pushes local SSH public key to another box
# Adapted from code found at <https://github.com/rtomayko/dotfiles/blob/rtomayko/.bashrc>
function push_ssh_cert() {
    if [[ $# -eq 0 || $# -gt 3 ]]; then
        echo "Usage: push_ssh_cert host [port] [username]"
        return
    fi
    local _host=$1
    local _port=22
    local _user=$USER
    if [[ $# -ge 2 ]]; then
        _port=$2
    fi
    if [[ $# -eq 3 ]]; then
        _user=$3
    fi
    test -f ~/.ssh/id_*sa.pub || ssh-keygen -t rsa
    echo "Pushing public key to $_user@$_host:$_port..."
    ssh -p $_port $_user@$_host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" < ~/.ssh/id_*sa.pub
}

chk() { grep $1 =(ps auxwww) }

changeMac() {
    local mac=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//')
    sudo ifconfig en0 ether $mac
    sudo ifconfig en0 down
    sudo ifconfig en0 up
    echo "Your new physical address is $mac"
}

path() {
    echo $PATH | tr ":" "\n" | \
        awk "{ sub(\"/usr\",   \"$fg_no_bold[green]/usr$reset_color\"); \
    sub(\"/bin\",   \"$fg_no_bold[blue]/bin$reset_color\"); \
    sub(\"/opt\",   \"$fg_no_bold[cyan]/opt$reset_color\"); \
    sub(\"/sbin\",  \"$fg_no_bold[magenta]/sbin$reset_color\"); \
    sub(\"/local\", \"$fg_no_bold[yellow]/local$reset_color\"); \
    sub(\"/.rvm\",  \"$fg_no_bold[red]/.rvm$reset_color\"); \
        print }"
}

fpath() {
    echo $FPATH | tr ":" "\n" | \
        awk "{ sub(\"/usr\",   \"$fg_no_bold[green]/usr$reset_color\"); \
    sub(\"/bin\",   \"$fg_no_bold[blue]/bin$reset_color\"); \
    sub(\"/opt\",   \"$fg_no_bold[cyan]/opt$reset_color\"); \
    sub(\"/sbin\",  \"$fg_no_bold[magenta]/sbin$reset_color\"); \
    sub(\"/local\", \"$fg_no_bold[yellow]/local$reset_color\"); \
    sub(\"/.rvm\",  \"$fg_no_bold[red]/.rvm$reset_color\"); \
        print }"
}

mcd() { mkdir -p $1 && cd $1 }
alias cdm=mcd
cdf() { cd *$1*/ } # stolen from @topfunky

## FZF FUNCTIONS ##

# fo [FUZZY PATTERN] - Open the selected file with the default editor
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)

# e - open 'frecency' files in $VISUAL editor

e() {
  local IFS=$'\n'
  local files=()

  files=(
  "$(
    zoxide query -l \
      | fzf \
          --reverse -1 \
          --no-sort \
          --multi \
          --tiebreak=index \
          --bind=ctrl-x:toggle-sort \
          --query "$*" \
          --preview="${FZF_PREVIEW_CMD}" \
          --preview-window='right:hidden:wrap' \
          --bind=ctrl-v:toggle-preview \
          --bind=ctrl-x:toggle-sort \
          --header='(view:ctrl-v) (sort:ctrl-x)' \
      )"
  ) || return

  "${EDITOR:-vim}" "${files[@]}"
}

# NOTE: 2024-06-13 - Opens recent files using zoxide
o() {
    local IFS=$'\n'
    local dirs=()

    dirs=( "$(zoxide query -i "$1")" ) || return

    "${EDITOR:-vim}" "${dirs[@]}"
}

fo() {
    local files
    IFS=$'\n' files=($(fzf-tmux --query="$1" --multi --select-1 --exit-0))
    [[ -n "$files" ]] && ${EDITOR:-vim} "${files[@]}"
}

# fh [FUZZY PATTERN] - Search in command history
fh() {
    print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}

# fbr [FUZZY PATTERN] - Checkout specified branch
# Include remote branches, sorted by most recent commit and limited to 30
fgb() {
    local branches branch
    branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&
    branch=$(echo "$branches" |
    fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
    git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

# fuzzy grep via rg and open in vim with line number
# NOTE: 2024-06-07 - this seems to not work as expected
fgr() {
    local file
    local line

    read -r file line <<<"$(rg --no-heading --line-number $@ | fzf -0 -1 | awk -F: '{print $1, $2}')"

    if [[ -n $file ]]
    then
        $EDITOR $file +$line
    fi
}

# fstash - easier way to deal with stashes
# type fstash to get a list of your stashes
# enter shows you the contents of the stash
# ctrl-d shows a diff of the stash against your current HEAD
# ctrl-b checks the stash out as a branch, for easier merging
fzstash() {
    local out q k sha
    while out=$(
        git stash list --pretty="%C(yellow)%h %>(14)%Cgreen%cr %C(blue)%gs" |
        fzf --ansi --no-sort --query="$q" --print-query \
        --expect=ctrl-d,ctrl-b);
    do
        mapfile -t out <<< "$out"
        q="${out[0]}"
        k="${out[1]}"
        sha="${out[-1]}"
        sha="${sha%% *}"
        [[ -z "$sha" ]] && continue
        if [[ "$k" == 'ctrl-d' ]]; then
            git diff $sha
        elif [[ "$k" == 'ctrl-b' ]]; then
            git stash branch "stash-$sha" $sha
            break;
        else
            git stash show -p $sha
        fi
    done
}

# fzf-tab https://github.com/Aloxaf/fzf-tab/wiki/Configuration#group-colors
#
# Usage: palette
palette() {
    local -a colors
    for i in {000..255}; do
        colors+=("%F{$i}$i%f")
    done
    print -cP $colors
}

# Usage: printc COLOR_CODE
printc() {
    local color="%F{$1}"
    echo -E ${(qqqq)${(%)color}}
}

wezshare() {
    local mode="${1:-on}"
    wezterm-cli SCREEN_SHARE_MODE "$mode"
}

#  BUG: 2024-07-18 - This is not working as expected
alias bathelp='bat --plain --language=help'
help() {
    "$@" --help 2>&1 | bathelp
}

# TODO: adapt this function to my own apps: fd, ripgrep, bat... etc
exp() {
    selection=$(find -type d | fzf --multi --height=80% --border=sharp \
    --preview='tree -C {}' --preview-window='45%,border-sharp' \
    --prompt='Dirs > ' \
    --bind='del:execute(rm -ri {+})' \
    --bind='ctrl-p:toggle-preview' \
    --bind='ctrl-d:change-prompt(Dirs > )' \
    --bind='ctrl-d:+reload(find -type d)' \
    --bind='ctrl-d:+change-preview(tree -C {})' \
    --bind='ctrl-d:+refresh-preview' \
    --bind='ctrl-f:change-prompt(Files > )' \
    --bind='ctrl-f:+reload(find -type f)' \
    --bind='ctrl-f:+change-preview(cat {})' \
    --bind='ctrl-f:+refresh-preview' \
    --bind='ctrl-a:select-all' \
    --bind='ctrl-x:deselect-all' \
    --header '
    CTRL-D to display directories | CTRL-F to display files
    CTRL-A to select all | CTRL-x to deselect all
    ENTER to edit | DEL to delete
    CTRL-P to toggle preview
    '
    )

    if [ -d "$selection" ]; then
        cd "$selection" || exit
    else
        eval "$EDITOR $selection"
    fi
}
