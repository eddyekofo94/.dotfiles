# conf.d runs first!

# https://fishshell.com/docs/current/tutorial.html
# https://github.com/jorgebucaran/fish-shell-cookbook
# https://github.com/fish-shell/fish-shell/blob/master/share/config.fish
# https://github.com/fish-shell/fish-shell/blob/da32b6c172dcfe54c9dc4f19e46f35680fc8a91a/share/config.fish#L257-L269

#
# Env
#

# Set vars for dotfiles and special dirs.
set -g ZDOTDIR $XDG_CONFIG_HOME/zsh
set -gx DOTFILES $HOME/.dotfiles

# Keep child processes such as tmux on the currently running fish binary.
# This repairs stale /usr/local/bin/fish values left by the Intel Homebrew era.
set -gx SHELL (status fish-path)

# Set initial working directory.
set -g IWD $PWD

if status is-interactive
    # Commands to run in interactive sessions can go here
    # eval (zellij setup --generate-auto-start fish | string collect)

    # Set TERM=kitty for undercurl support in neovim when running in Zellij or Ghostty
    # if test -n "$ZELLIJ_SESSION_NAME" -o "$TERM_PROGRAM" = Ghostty
    #     function nvim
    #         TERM=kitty command nvim $argv
    #     end
    # end

    if type -q fnm; and not string match -q "*fnm_multishell*" "$PATH"
        fnm env --use-on-cd | source
    end

    # Enables vim keybindings. Name the vi function here rather than
    # fish_user_key_bindings: fish runs the user hook right after whichever
    # function this names, and prompts (starship) only forward $fish_bind_mode
    # when this variable names a known vi/hybrid binding function.
    set -g fish_key_bindings fish_vi_key_bindings
end

if status is-login
    # TODO: See how properly do this without the error on MacOS
    if string match -q -- "WSL*" $OS
        echo "It is wsl"
        # export PYTHONPATH=:~/.local/lib/python3.11/site-packages/:~/.local/lib/python3.11/site-packages/

        # WSL specidic aliases & abbrs
        alias docker='docker.exe'
        alias wsl='wsl.exe'
        abbr -a -- psh 'powershell.exe'

        # Fix the VPN issue: For Amadeus
        abbr -a -- fnet 'cd $HOME/onedrive/VPN && powershell.exe -File setup-vpn.ps1'
    end

    # Attach the selected top-level multiplexer. Herdr's adapter fails closed to
    # the existing tmux path when its binary, state, or session name is unsafe.
    if test -r "$DOTFILES/herdr/prototype/herdr_login_attach.fish"
        source "$DOTFILES/herdr/prototype/herdr_login_attach.fish"
    end

    # Auto-start tmux on login when Herdr is unavailable, opted out, or not the
    # selected default.
    if not set -q TMUX
        if type -q tmux
            if tmux has-session 2>/dev/null
                if tmux ls 2>/dev/null | string match -q "*attached*"
                    # If a session is already active/attached elsewhere, open a new separate session
                    exec tmux new-session
                else
                    # If no session is currently active/attached, attach to the existing/old one
                    exec tmux attach-session
                end
            else
                # If no session exists at all, create a new one named 'main'
                exec tmux new-session -s main
            end
        end
    end

    # Emulates vim's cursor shape behavior
    # Set the normal and visual mode cursors to a block
    set fish_cursor_default block
    # Set the insert mode cursor to a line
    set fish_cursor_insert line
    # Set the replace mode cursor to an underscore
    set fish_cursor_replace_one underscore
    # The following variable can be used to configure cursor shape in
    # visual mode, but due to fish_cursor_default, is redundant here
    set fish_cursor_visual block

    # FZF
    #export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --no-require-git --no-ignore --hidden --follow --glob "!.git/*"'
    #export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

    # set fzf_fd_opts --hidden --exclude=.git
end

set __file__ $HOME/.config/fish/config.fish

#
# Utils
#

# Prompt, keybindings, and directory-jump hooks are only useful interactively.
# Keeping them out of `fish -c` avoids loading unnecessary functions and event
# handlers into short-lived script shells.
if status is-interactive
    # Preserve fzf's shell completion without loading its competing key binds.
    if test -r $DOTFILES_FISH_CACHE/fzf_completion.fish
        source $DOTFILES_FISH_CACHE/fzf_completion.fish
    end

    # Initialize zoxide for fast jumping with 'z'.
    if type -q zoxide
        if test -r $DOTFILES_FISH_CACHE/zoxide_init.fish
            source $DOTFILES_FISH_CACHE/zoxide_init.fish
        end
    end

    #
    # Prompt
    #

    # Greeting is handled by functions/fish_greeting.fish

    # Initialize starship.
    if type -q starship
        #set -gx STARSHIP_CONFIG $__fish_config_dir/themes/starship.toml
        if test -r $DOTFILES_FISH_CACHE/starship_init.fish
            source $DOTFILES_FISH_CACHE/starship_init.fish
        end
        #enable_transience
    end
end

#  CLEAN_UP: 2024-12-29 - Remove when finished!
#set fish_key_bindings fish_user_key_bindings

# Local
#

#if test -r $DOTFILES.local/fish/config.fish
#    source $DOTFILES.local/fish/config.fish
#end

# Functions needed for !! and !$
function __history_previous_command
    switch (commandline -t)
        case "!"
            commandline -t $history[1]
            commandline -f repaint
        case "*"
            commandline -i !
    end
end

function __history_previous_command_arguments
    switch (commandline -t)
        case "!"
            commandline -t ""
            commandline -f history-token-search-backward
        case "*"
            commandline -i '$'
    end
end

# The bindings for !! and !$
if [ "$fish_key_bindings" = fish_vi_key_bindings ]
    bind -Minsert ! __history_previous_command
    bind -Minsert '$' __history_previous_command_arguments
else
    bind ! __history_previous_command
    bind '$' __history_previous_command_arguments
end

# bun
set --global --export BUN_INSTALL "$HOME/.bun"
fish_add_path --global --prepend (path filter -d "$BUN_INSTALL/bin")

# Added by Antigravity
fish_add_path --global --prepend (path filter -d "$HOME/.antigravity/antigravity/bin")
