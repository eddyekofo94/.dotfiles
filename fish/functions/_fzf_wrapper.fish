function _fzf_wrapper --description "Prepares some environment variables before executing fzf."
    # Make sure fzf uses fish to execute preview commands, some of which
    # are autoloaded fish functions so don't exist in other shells.
    # Use --function so that it doesn't clobber SHELL outside this function.
    set -f --export SHELL (command --search fish)

    # If neither FZF_DEFAULT_OPTS nor FZF_DEFAULT_OPTS_FILE are set, then set some sane defaults.
    # See https://github.com/junegunn/fzf#environment-variables
    set --query FZF_DEFAULT_OPTS FZF_DEFAULT_OPTS_FILE
    if test $status -eq 2
        if set --query FZF_COMMON_OPTIONS
            set --export FZF_DEFAULT_OPTS "$FZF_COMMON_OPTIONS"
        else
            set --export FZF_DEFAULT_OPTS "--inline-info --height 90% --border --ansi --reverse --extended --cycle --prompt='∷ '"
        end
    end

    fzf $argv
end
