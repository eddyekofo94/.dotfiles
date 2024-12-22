# Directory where user-specific configuration files should be stored.
set -Ux XDG_CONFIG_HOME "$HOME/.config"

# Directory where user-specific data files should be stored.
set -Ux XDG_DATA_HOME "$XDG_CONFIG_HOME/.local/share"

# Preference-ordered set of base directories to search for data files in
# addition to the $XDG_DATA_HOME base directory.
set -Ux XDG_DATA_DIRS "/usr/local/share/:/usr/share/"

# Preference-ordered set of base directories to search for configuration files
# in addition to the $XDG_CONFIG_HOME base directory.
set -Ux XDG_CONFIG_DIRS "/etc/xdg"

# Directory where user-specific non-essential data files should be stored.
set -Ux XDG_CACHE_HOME "$XDG_CONFIG_HOME/.cache"

# Editor vars
set -Ux TERM "xterm-256color"

set -Ux DOTFILES_DIR "$HOME/.dotfiles"

set -Ux TERM wezterm

# Main change, you can see directories on a dark background
set -Ux CLICOLOR 1

# Bat a modern cat with all the goodies
set -Ux BAT_CONFIG_PATH "$HOME/.dotfiles/bat/bat.conf"

# reduce ESC key delay to 0.1
set -Ux KEYTIMEOUT 1

if command -q nvim >/dev/null 2>&1
    set -Ux EDITOR "nvim"
    set -Ux VISUAL "nvim"
    set -Ux NVIM_DIR "$XDG_CONFIG_HOME/nvim"
else
    set -Ux EDITOR vim
    set -Ux VISUAL vim
end

# set -Ux JAVA_HOME "/usr/libexec/java_home"
set -Ux JAVA_HOME "$SDKMAN_DIR/candidates/java/current"

# LS colors using Vivid installed using Cargo
set -Ux LS_COLORS "(vivid generate $HOME/.dotfiles/vivid/catppuccin-mocha.yml)"

# Cargo: for Rust development
# set -Ua fis_user_paths $HOME/.cargo/bin
set -Ux PATH "$PATH:$HOME/.cargo/bin"

#  INFO: 2024-12-19 - Adds tab completion and other goodies
# Install: fisher install gazorby/fifc
#https://github.com/gazorby/fifc
set -Ux fifc_editor $EDITOR
