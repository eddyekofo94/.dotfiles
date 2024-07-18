
# bindkey '^ ' autosuggest-accept #BUG: ctrl+space not working
bindkey '^j' autosuggest-accept

#  INFO: 2024-07-01 - Source zshrc file
bindkey -s '^x' "^usource $ZSHRC\n"
# NOTE: Alt+. fix: https://unix.stackexchange.com/a/696981/305857
bindkey -M viins '\e.' insert-last-word

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

bindkey -M vicmd v edit-command-line
