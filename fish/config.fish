######################################
# 
# Athor: Eddy Ekofo - WSL fish configs
#
######################################

if status is-interactive
    # Commands to run in interactive sessions can go here
end

if status is-login

    # INFO: To get WSL 2 working with VPN https://github.com/sakai135/wsl-vpnkit
    wsl.exe -d wsl-vpnkit service wsl-vpnkit start
    # For Homebrew/Linuxbrew to work
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    
    # Cargo: for Rust development
    # set -Ua fis_user_paths $HOME/.cargo/bin
    export PATH="$PATH:$HOME/.cargo/bin"
    
    # Zoxide a smart cd to directories (needs rust)
    zoxide init fish | source

    # Initialize XDG base directory environment variables as defined in:
    # https://specifications.freedesktop.org/basedir-spec/basedir-spec-0.6.html.
    #
    # Explicitly define them here so we don't need to add the additional code of
    # handling the case where they are not explicitly defined, simplifying the code
    # in the rest of our configurations which use XDG.
    
    # Directory where user-specific data files should be stored.
    export XDG_DATA_HOME="$HOME/.local/share"
    
    # Preference-ordered set of base directories to search for data files in
    # addition to the $XDG_DATA_HOME base directory.
    export XDG_DATA_DIRS="/usr/local/share/:/usr/share/"
    
    # Directory where user-specific configuration files should be stored.
    export XDG_CONFIG_HOME="$HOME/.config"
    
    # Preference-ordered set of base directories to search for configuration files
    # in addition to the $XDG_CONFIG_HOME base directory.
    #export XDG_CONFIG_DIRS="/etc/xdg"
    
    # Directory where user-specific non-essential data files should be stored.
    export XDG_CACHE_HOME="$HOME/.cache"
    
    # export JAVA_HOME="/usr/libexec/java_home"
    export JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
    
    # LS colors using Vivid installed using Cargo
    export LS_COLORS="$(vivid generate one-dark)"
    
    # FZF
    export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --no-require-git --no-ignore --hidden --follow --glob "!.git/*"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    
    # Bat a modern cat with all the goodies
    export BAT_CONFIG_PATH=$HOME/.dotfiles/bat/lib/login/bat.conf
end


# Enables vim keybindings
fish_vi_key_bindings

set __file__ $HOME/.config/fish/config.fish



######################################
#
# ALIASSES & ABBRs
#
######################################

# Moders ways to list files
alias ls="lsd"
alias l="exa --group-directories-first --icons --long --header --binary --group"
alias la="l -a"

# Bat things
alias cat='bat --paging=never --style=changes'
abbr --add bgr 'batgrep'
abbr --add bman 'batman'

abbr -a -U -- lg lazygit
abbr -a -U -- lzd lazydocker
abbr -a -U -- vim nvim

abbr -a -U -- bgr batgrep
abbr -a -U -- bman batman

# Cargo aliases 
abbr -a -U -- cg cargo
abbr -a -U -- cgc 'cargo clean'
abbr -a -U -- cgi 'cargo install'
abbr -a -U -- cgn 'cargo new'
abbr -a -U -- cgs 'cargo search'
abbr -a -U -- cgt 'cargo test'
abbr -a -U -- cgu 'cargo uninstall'
abbr -a -U -- cgug 'cargo upgrade'


# bang-bang fish plugin... installed by omf
bind ! __history_previous_command
bind '$' __history_previous_command_arguments

# WSL specidic aliases & abbrs
alias docker='docker.exe'
