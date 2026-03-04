# All variables are universals here. They can be overridden with globals in config.fish

set -q TERM; or set -Ux TERM xterm-256color

set -q DOT_DIR; or set -Ux DOT_DIR "$HOME/.dotfiles"

set -q NVIM_NF; or set -Ux NVIM_NF true



# Set editor variables.
set -q PAGER; or set -Ux PAGER less

if command -q nvim >/dev/null 2>&1
    set -q VISUAL; or set -Ux VISUAL nvim
    set -q EDITOR; or set -Ux EDITOR nvim
    set -Ux NVIM_DIR "$XDG_CONFIG_HOME/nvim"
else
    set -q VISUAL; or set -Ux VISUAL vim
    set -q EDITOR; or set -Ux EDITOR vim
end

# Set browser on macOS.
#switch (uname -a)
#    case Darwin
#set -q BROWSER; or set -Ux BROWSER open
#end

set unameOut (uname -a)

switch $unameOut
    case "*Microsoft*"
        set OS WSL #wls must be first since it will have Linux in the name too
    case "*microsoft*"
        set OS WSL2
    case "Linux*"
        set OS Linux
    case "Darwin*"
        set OS Mac
        set -q BROWSER; or set -Ux BROWSER open
        # Note that the next case has a wildcard which is quoted
    case '*'
        echo $unameOut
end

# XDG apps
set -q GNUPGHOME; or set -Ux GNUPGHOME $XDG_DATA_HOME/gnupg
set -q LESSHISTFILE; or set -Ux LESSHISTFILE $XDG_DATA_HOME/lesshst
set -q SQLITE_HISTORY; or set -Ux SQLITE_HISTORY $XDG_DATA_HOME/sqlite_history
set -q WORKON_HOME; or set -Ux WORKON_HOME $XDG_DATA_HOME/venvs
set -q PYLINTHOME; or set -Ux PYLINTHOME $XDG_CACHE_HOME/pylint

# Applications vars
set -q JAVA_HOME; or set -Ux JAVA_HOME "$SDKMAN_DIR/candidates/java/current"

# cargo/rust path
source "$HOME/.cargo/env.fish"

# Other vars
set -q FISH_THEME; or set -Ux FISH_THEME catppuccin-mocha

# LS colors using Vivid installed using Cargo
set -q LS_COLORS; or set -Ux LS_COLORS "(vivid generate $HOME/.dotfiles/vivid/catppuccin-mocha.yml)"

# Bat a modern cat with all the goodies
set -q BAT_CONFIG_PATH; or set -Ux BAT_CONFIG_PATH "$HOME/.dotfiles/bat/bat.conf"


#https://github.com/gazorby/fifc
set -q fifc_editor; or set -Ux fifc_editor $EDITOR
