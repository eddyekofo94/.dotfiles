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

alias 'mkdir=mkdir -p'
# Typing errors...
alias 'cd..= cd ..'

# List only directories and symbolic
# links that point to directories
alias lsd='ls -ld *(-/DN)'
alias lh='ls -a | egrep "^\."'

# if command -v bat >/dev/null 2>&1; then
#     alias cat='bat --paging=never --style=changes'
# fi

# alias g=git
# alias lg="lazygit"
# Directory Aliases
# #####################################

# Different sets of LS aliases because Gnu LS and macOS LS use different
# flags for colors.  Also, prefer gem colorls or exa when available.

if exa --icons &>/dev/null; then
    alias ls='exa --git --icons'                             # system: List filenames on one line
    # alias l='exa --git --icons -lF'                          # system: List filenames with long format
    alias l="exa --git --group-directories-first --long --icons --header --binary --group"
    alias ll='exa -lahF --git --icons'                               # system: List all files
    alias lll="exa -1F --git --icons"                        # system: List files with one line per file
    alias llm='ll --sort=modified'                           # system: List files by last modified date
    alias la='exa -lbhHigUmuSa --color-scale --git --icons'  # system: List files with attributes
    alias lx='exa -lbhHigUmuSa@ --color-scale --git --icons' # system: List files with extended attributes
    alias lt='exa --tree --level=2'                          # system: List files in a tree view
    alias llt='exa -lahF --tree --level=2'                   # system: List files in a tree view with long format
    alias ltt='exa -lahF | grep "$(date +"%d %b")"'          # system: List files modified today
    alias tree='exa --tree $exa_params --icons'
elif command -v exa &>/dev/null; then
    alias ls='exa --git'
    alias l='exa --git -lF'
    alias ll='exa -lahF --git'
    alias lll="exa -1F --git"
    alias llm='ll --sort=modified'
    alias la='exa -lbhHigUmuSa --color-scale --git'
    alias lx='exa -lbhHigUmuSa@ --color-scale --git'
    alias lt='exa --tree --level=2'
    alias llt='exa -lahF --tree --level=2'
    alias ltt='exa -lahF | grep "$(date +"%d %b")"'
    alias tree='exa --tree $exa_params --icons'
elif command -v colorls &>/dev/null; then
    alias ll="colorls -1A --git-status"
    alias ls="colorls -A"
    alias ltt='colorls -A | grep "$(date +"%d %b")"'
elif [[ $(command -v ls) =~ gnubin || $OSTYPE =~ linux ]]; then
    alias ls="ls --color=auto"
    alias ll='ls -FlAhpv --color=auto'
    alias ltt='ls -FlAhpv| grep "$(date +"%d %b")"'
else
    alias ls="ls -G"
    alias ll='ls -FGlAhpv'
    alias ltt='ls -FlAhpv| grep "$(date +"%d %b")"'
fi


alias ..="cd .."
alias ...="cd ../.."
alias ....='../../..'
alias .....='../../../..'
alias g=git
alias zconf="$EDITOR $ZDOTDIR/.zshrc"
alias nconf="$EDITOR $NVIM_DIR"
alias reload="source $ZDOTDIR/.zshenv && source $ZDOTDIR/.zshrc"
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
alias glog='git log --oneline --decorate --color --graph'
alias glog='git log --pretty=format:"%C(yellow)%h\\ %ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate --date=short'  # A nicer Git Log
alias gloga='git log --oneline --decorate --color --graph --all'
alias glom='git log --oneline --decorate --color $(get_default_branch)..'
alias glod='git log --oneline --decorate --color dev..'
alias gloo="git\ log\ --pretty=format:\'\%C\(yellow\)\%h\ \%Cred\%ad\ \%Cblue\%an\%Cgreen\%d\ \%Creset\%s\'\ --date=short"
alias gm='git merge'
alias gmt='git mergetool --no-prompt'
alias gmom='git merge origin/$(get_default_branch)'

gpp(){
    if [[ $(get_default_branch) == $(get_current_branch) ]]; then
        echo "Error: you cannot push on the $(get_default_branch) branch"
    else
        git push
    fi
}

alias gp='git push'
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
alias grup='git remote update'
alias grv='git remote -v'
alias gsh='git show'
alias gsd='git svn dcommit'
alias gsr='git svn rebase'
alias gss='git status -s'
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
alias hg='history | grep '
alias zj='zellij'
