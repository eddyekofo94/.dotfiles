# REFS:
# https://github.com/ahmedelgabri/dotfiles/blob/main/config/zsh.d/zsh/config/completion.zsh#L54

setopt list_packed
setopt extended_glob

_comp_options+=(globdots) # Include hidden files.

# zsh speedsup: https://carlosbecker.com/posts/speeding-up-zsh/
autoload -Uz +X compinit
for dump in ~/.zcompdump(N.mh+24); do
    compinit
done
compinit


# REF:
# https://github.com/mhanberg/.dotfiles/blob/main/zsh/funcs#L3
# https://github.com/mhanberg/.dotfiles/blob/main/zsh/git.zsh
compdef g=git

# persistent reshahing i.e puts new executables in the $path
# if no command is set typing in a line will cd by default
zstyle ':completion:*' rehash true

# Allow completion of ..<Tab> to ../ and beyond.
zstyle -e ':completion:*' special-dirs '[[ $PREFIX = (../)#(..) ]] && reply=(..)'

# Categorize completion suggestions with headings:
zstyle ':completion:*' group-name ''

# Added by running `compinstall`
zstyle ':completion:*' verbose yes
zstyle ':completion:*' expand suffix # or:  expand yes
zstyle ':completion:*' file-sort modification
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' list-suffixes true

# -- process names -------------------------------------------------------------
zstyle ':completion:*:processes-names' command \
    'ps c -u ${USER} -o command | uniq'

# -- ssh hosts -----------------------------------------------------------------
[[ -r "$HOME/.ssh/config" ]] && _ssh_config_hosts=(${${(s: :)${(ps:\t:)${${(@M)${(f)"$(<$HOME/.ssh/config)"}:#Host *}#Host }}}:#*[*?]*}) || _ssh_config_hosts=()

hosts=(
    "$(hostname)"
    "$_ssh_config_hosts[@]"
    # "$_ssh_hosts[@]"
    # "$_etc_hosts[@]"
    localhost
)
zstyle ':completion:*:hosts' hosts $hosts

# Make completion:
# (stolen from Wincent)
# - Try exact (case-sensitive) match first.
# - Then fall back to case-insensitive.
# - Accept abbreviations after . or _ or - (ie. f.b -> foo.bar).
# - Substring complete (ie. bar -> foobar).
# INFO: Put this back after if things don't work
# zstyle ':completion:*' matcher-list '' \
    #     '+m:{[:lower:]}={[:upper:]}' \
    #     '+m:{[:upper:]}={[:lower:]}' \
    #     '+m:{_-}={-_}' \
    #     'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR/zcompcache"

# INFO: https://thevaluable.dev/zsh-completion-guide-examples/
zstyle ':completion:*' menu select
zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' complete-options true
zstyle ':completion:*' file-sort change
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# use the vi navigation keys in menu completion
zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'l' vi-forward-char

# NOTE: Alt+. fix: https://unix.stackexchange.com/a/696981/305857
bindkey -M viins '\e.' insert-last-word

# zstyle ':completion:*' matcher-list 'r:[[:ascii:]]||[[:ascii:]]=** r:|=* m:{a-z\-}={A-Z\_}'
