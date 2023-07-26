# -------------------------------------------------------------------
# make some commands (potentially) less destructive
# -------------------------------------------------------------------
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
