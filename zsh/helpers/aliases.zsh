#!/usr/bin/env zsh
# -------------------------------------------------------------------
# make some commands (potentially) less destructive
# -------------------------------------------------------------------

get_default_branch(){
    git branch -l master main | sed -r 's/^[* ] //' | head -n 1
}

get_current_branch(){
    git branch --show-current
}

# Play safe!
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
alias rmdf='rm -irf '

make_file_executable() {
    chmod +x "$1" || exit;
    ls -al
}

alias chmox='make_file_executable'

## super user alias
alias _='sudo '

alias 'mkdir=mkdir -p'

alias md='mkdir -p'
alias rd=rmdir

# Typing errors...
alias 'cd..= cd ..'

# List only directories and symbolic
# links that point to directories
alias lsd='ls -ld *(-/DN)'
alias lh='ls -a | egrep "^\."'

# Directory Aliases
# #####################################

# Different sets of LS aliases because Gnu LS and macOS LS use different
# exa (which I have used for a longtime is currently not maintained, therefore eza is now used)

if eza --icons &>/dev/null; then
    # alias ls='eza --git --icons auto --sort=modified' # system: List filenames on one line
    alias ls='eza --git --group-directories-first --icons --sort=modified'
    # alias l='eza --git --icons -lF'                          # system: List filenames with long format
    alias ll="eza --git --all --group-directories-first --no-filesize --no-user --long --icons --header --binary --group --sort=modified"
    alias l='eza --git --group-directories-first --icons --sort=modified --long --all --no-filesize --no-time --no-user --no-permissions'
    alias lll="eza -1F --git --icons auto"                        # system: List files with one line per file
    alias llm='ll --sort=modified'                                # system: List files by last modified date
    alias la='eza -lbhHigUmuSa --color-scale --git --icons auto'  # system: List files with attributes
    alias lx='eza -lbhHigUmuSa@ --color-scale --git --icons auto' # system: List files with extended attributes
    alias lt='eza --tree --level=2 --icons auto'                               # system: List files in a tree view
    alias llt='eza -lahF --tree --level=2'                        # system: List files in a tree view with long format
    alias ltt='eza -lahF --icons auto | grep "$(date +"%d %b")"'               # system: List files modified today
    alias tree='eza --tree $eza_params'
elif command -v eza &>/dev/null; then
    alias ls='eza --group-directories-first --icons'
    alias ls='eza --git --icons auto'
    alias ll='eza --git -lF --icons auto'
    alias l='eza -lahF --git --icons auto'
    alias lll="eza -1F --git --icons auto"
    alias llm='ll --sort=modified --icons auto'
    alias la='eza -lbhHigUmuSa --color-scale --git'
    alias lx='eza -lbhHigUmuSa@ --color-scale --git'
    alias lt='eza --tree --level=2'
    alias llt='eza -lahF --tree --level=2'
    alias ltt='eza -lahF | grep "$(date +"%d %b")"'
    alias tree='eza --tree $eza_params'
elif command -v colorls &>/dev/null; then
    alias ll="colorls -1A --git-status"
    alias ls="colorls -A"
    alias ltt='colorls -A | grep "$(date +"%d %b")"'
elif [[ $(command -v ls) =~ gnubin || $OSTYPE =~ linux ]]; then
    alias ls="ls --color=auto"
    alias l="ls -l --color=auto"
    alias ll='ls -FlAhpv --color=auto'
    alias ltt='ls -FlAhpv| grep "$(date +"%d %b")"'
else
    alias ls="ls -G"
    alias ll='ls -FGlAhpv'
    alias ltt='ls -FlAhpv| grep "$(date +"%d %b")"'
fi

alias -g ..="cd .."
alias -g ...="cd ../.."
alias -g ....='../../..'
alias -g .....='../../../..'
alias g=git
alias zconf="$EDITOR $ZSH_DOT_DIR/.zshrc"
alias nconf="$EDITOR $NVIM_DIR"
alias reload="source $ZDOTDIR/.zshenv && source $ZDOTDIR/.zprofile && source $ZDOTDIR/.zshrc"
# alias reload="$(exec zsh)"

rm_cores() {
    if [[  "$PWD" != "$HOME" ]]; then
        if (( $+commands[fd] )); then
            echo "$(which fd) is found"
            fd -I "core.[0-9][0-9][0-9][0-9]"
            rm $(fd -I "core.[0-9][0-9][0-9][0-9]")
        else
            echo "using $(which find)"
            find . -name 'core.[0-9][0-9][0-9][0-9]'
            rm -i $(find . -name 'core.[0-9][0-9][0-9][0-9]')
        fi
    else
        echo "You cannot do this in the $HOME direction"
    fi
}

alias rmcore="rm_cores"

alias cl=clear
alias ga='git add'
alias gaa='git add --all'
alias gau='git add --update'
alias gapa='git add --patch'
alias gap='git apply'
alias gb='git branch -vv'
alias gba='git branch -a -v'
alias gban='git branch -a -v --no-merged'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias ggsup='git branch --set-upstream-to=origin/$(get_current_branch)'
alias gbl='git blame -b -w'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsr='git bisect reset'
alias gbss='git bisect start'
alias gc='git commit -v'
alias gc!='git commit -v --amend'
alias gcn!='git commit -v --no-edit --amend'
alias gca='git commit -v -a'
alias gca!='git commit -v -a --amend'
alias gcan!='git commit -v -a --no-edit --amend'
alias gcv='git commit -v --no-verify'
alias gcav='git commit -a -v --no-verify'
alias gcav!='git commit -a -v --no-verify --amend'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcs='git commit -S'
alias gscam='git commit -S -a -m'
alias gcfx='git commit --fixup'
alias gcf='git config --list'
alias gcl='git clone'
alias gclb='git clone --bare'
alias gclean='git clean -di'
alias gclean!='git clean -dfx'
alias gclean!!='git reset --hard; and git clean -dfx'
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gd='git diff'
alias gdca='git diff --cached'
alias gds='git diff --stat'
alias gdsc='git diff --stat --cached'
alias gdt='git diff-tree --no-commit-id --name-only -r'
alias gdw='git diff --word-diff'
alias gdwc='git diff --word-diff --cached'
alias gdto='git difftool'
alias gignore='git update-index --assume-unchanged'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gfm='git fetch origin $(get_default_branch) --prune; and git merge FETCH_HEAD'
alias gfo='git fetch origin'
alias gl='git pull'
alias ggl='git pull origin $(get_current_branch)'
alias gll='git pull origin'
alias glr='git pull --rebase'
alias glg='git log --stat'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glo='git log --oneline --decorate --color'
# alias glog='git log --oneline --decorate --color --graph'
alias glog='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
alias gloga='git log --oneline --decorate --color --graph --all'
alias glom='git log --oneline --decorate --color $(get_default_branch)..'
alias glod='git log --oneline --decorate --color dev..'

git config --global alias.ll 'log --graph --format="%C(yellow)%h%C(red)%d%C(reset) - %C(bold green)(%ar)%C(reset) %s %C(blue)<%an>%C(reset)"'

fzf_git_log() {
    local selection=$(
        git ll --color=always "$@" | \
            fzf --no-multi --ansi --no-sort --no-height \
            --preview "echo {} | grep -o '[a-f0-9]\{7\}' | head -1 |
        xargs -I@ sh -c 'git show --color=always @'"
    )
    if [[ -n $selection ]]; then
        local commit=$(echo "$selection" | sed 's/^[* |]*//' | awk '{print $1}' | tr -d '\n')
        git show $commit
    fi
}

alias gloo='fzf_git_log'

fzf_git_reflog() {
    local selection=$(
        git reflog --color=always "$@" |
        fzf --no-multi --ansi --no-sort --no-height \
            --preview "git show --color=always {1}"
    )
    if [[ -n $selection ]]; then
        git show $(echo $selection | awk '{print $1}')
    fi
}

alias grl='fzf_git_reflog'

alias gm='git merge'
alias gmt='git mergetool --no-prompt'
alias gmom='git merge origin/$(get_default_branch)'

gp(){
    if [[ $(get_default_branch) == $(get_current_branch) ]]; then
        echo "Error: you cannot push on the $(get_default_branch) branch"
    else
        git push
    fi
}

alias gpp='git push'
alias gp!='git push --force-with-lease'
alias gpo='git push origin'
alias gpo!='git push --force-with-lease origin'
alias gpv='git push --no-verify'
alias gpv!='git push --no-verify --force-with-lease'
alias ggp='git push origin $(get_current_branch)'
alias ggp!='git push origin $(get_current_branch) --force-with-lease'
alias gpu='git push origin $(get_current_branch) --set-upstream'
alias gpoat='git push origin --all; and git push origin --tags'
alias ggpnp='git pull origin $(get_current_branch); and git push origin $(get_current_branch)'
alias gr='git remote -vv'
alias gra='git remote add'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase --interactive'
alias grbm='git rebase $(get_default_branch)'
alias grbmi='git rebase $(get_default_branch) --interactive'
alias grbmia='git rebase $(get_default_branch) --interactive --autosquash'
alias grbom='git fetch origin $(get_default_branch); and git rebase FETCH_HEAD'
alias grbomi='git fetch origin $(get_default_branch); and git rebase FETCH_HEAD --interactive'
alias grbomia='git fetch origin $(get_default_branch); and git rebase FETCH_HEAD --interactive --autosquash'
alias grbd='git rebase dev'
alias grbdi='git rebase dev --interactive'
alias grbdia='git rebase dev --interactive --autosquash'
alias grbs='git rebase --skip'
alias ggu='git pull --rebase origin $(get_current_branch)'
alias grev='git revert'
alias grh='git reset'
alias grhh='git reset --hard'
alias grhpa='git reset --patch'
alias grm='git rm'
alias grmc='git rm --cached'
alias grmv='git remote rename'
alias grpo='git remote prune origin'
alias grrm='git remote remove'
alias grs='git restore'
alias grset='git remote set-url'
alias grss='git restore --source'
alias grst='git restore --staged'
alias group='git remote update'
alias grv='git remote -v'
alias gsh='git show'
alias gsd='git svn dcommit'
alias gsr='git svn rebase'
# alias gss='git status -s' #NOTE: using fzf: fdiff
alias gst='git status'
alias gsta='git stash'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --text'
alias gsu='git submodule update'
alias gsur='git submodule update --recursive'
alias gsuri='git submodule update --recursive --init'
alias gts='git tag -s'
alias gtv='git tag'
alias gsw='git switch'
alias gswc='git switch --create'
alias gunignore='git update-index --no-assume-unchanged'
alias gup='git pull --rebase'
alias gupv='git pull --rebase -v'
alias gupa='git pull --rebase --autostash'
alias gupav='git pull --rebase --autostash -v'
alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcod='git checkout dev'
alias gcom='git checkout $(get_default_branch)'
alias gfb='git flow bugfix'
alias gff='git flow feature'
alias gfr='git flow release'
alias gfh='git flow hotfix'
alias gfs='git flow support'
alias gfbs='git flow bugfix start'
alias gffs='git flow feature start'
alias gfrs='git flow release start'
alias gfhs='git flow hotfix start'
alias gfss='git flow support start'
alias gfbt='git flow bugfix track'
alias gfft='git flow feature track'
alias gfrt='git flow release track'
alias gfht='git flow hotfix track'
alias gfst='git flow support track'
alias gfp='git flow publish'
alias gwt='git worktree'
alias gwta='git worktree add'
alias gwtls='git worktree list'
alias gwtlo='git worktree lock'
alias gwtmv='git worktree move'
alias gwtpr='git worktree prune'
alias gwtrm='git worktree remove'
alias gwtulo='git worktree unlock'
alias gmr='git push origin $(get_current_branch) --set-upstream -o merge_request.create'
alias gmwps='git push origin $(get_current_branch) --set-upstream -o merge_request.create -o merge_request.merge_when_pipeline_succeeds'
alias lg=lazygit
alias lzd=lazydocker
alias vim=nvim
alias grep="grep --color=auto"
alias nvmc="NVIM_APPNAME=nvim.macro nvim"
alias chad="NVIM_APPNAME=nvim.chad nvim"
alias bak="NVIM_APPNAME=nvim.bak nvim"
alias vi=vim
alias bgr=batgrep
alias cg=cargo
alias cgc='cargo clean'
alias cgi='cargo install'
alias cgn='cargo new'
alias cgs='cargo search'
alias cgt='cargo test'
alias cgu='cargo uninstall'
alias cgug='cargo upgrade'
alias h=history

if (( $+commands[rg] )); then
    alias alrg="alias | rg "
    alias hg='history | rg '
else
    alias alrg="alias | grep "
    alias hg='history | grep '
fi

alias -g -- -h='-h 2>&1 | bat --language=help --style=plain'
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'

alias zj='zellij'
alias zja='zellij attach'
alias zje='zellij edit'
alias zjls='zellij list-sessions'
alias zjk='zellij kill-session'
alias zjka='zellij kill-all-sessions'
