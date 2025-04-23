######################################
#
# Author: Eddy Ekofo - fish configs
#
######################################

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
        # Note that the next case has a wildcard which is quoted
    case '*'
        echo $unameOut
end

if status is-interactive
    # Commands to run in interactive sessions can go here
    eval (zellij setup --generate-auto-start fish | string collect)

    ######################################
    #
    # ENVS
    #
    ######################################

    for file in $HOME/.dotfiles/fish/env/*.fish
        if test -e $file
            . $file
        end
    end
end

if status is-login
    # TODO: See how properly do this without the error on MacOS
    if string match -q -- "WSL*" $OS
        echo "It is wsl"
        # For Homebrew/Linuxbrew to work
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        # export PYTHONPATH=:~/.local/lib/python3.11/site-packages/:~/.local/lib/python3.11/site-packages/

        # WSL specidic aliases & abbrs
        alias docker='docker.exe'
        alias wsl='wsl.exe'
        abbr -a -- psh 'powershell.exe'

        # IMPORTANT: this seems to work on WSL, so keep it!
        fzf_configure_bindings --history=\cr --git_status=\cg --directory=\cp

        # Fix the VPN issue: For Amadeus
        abbr -a -- fnet 'cd $HOME/onedrive/VPN && powershell.exe -File setup-vpn.ps1'
    end

    # Enables vim keybindings
    #fish_vi_key_bindings --no-erase insert
    set fish_key_bindings fish_user_key_bindings

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


    # starship init fish | source

    # FZF
    #export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --no-require-git --no-ignore --hidden --follow --glob "!.git/*"'
    #export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

    # set fzf_fd_opts --hidden --exclude=.git
end


set __file__ $HOME/.config/fish/config.fish


######################################
#
# ALIASSES & ABBRs
#
######################################

#  INFO: 2024-12-17 - source all abbrs
for file in $HOME/.dotfiles/fish/abbr/*.fish
    if test -e $file
        . $file
    end
end


######################################
#
# FUNCTIONS
#
######################################
for file in $HOME/.dotfiles/fish/functions/*.fish
    if test -e $file
        . $file
    end
end

## Bat things
if command -q bat
    alias cat 'bat -pp'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
end

#alias cat='bat --paging=never --style=changes'
#abbr --add bgr 'batgrep'
#abbr --add bman 'batman'
#
#abbr -a -- lg lazygit
#abbr -a -- lzd lazydocker
#abbr -a -- vim nvim
#abbr -a -- vi vim
#
#abbr -a -- bgr batgrep
#abbr -a -- bman batman
#
## Cargo abbreviations
#abbr -a -- cg cargo
#abbr -a -- cgc 'cargo clean'
#abbr -a -- cgi 'cargo install'
#abbr -a -- cgn 'cargo new'
#abbr -a -- cgs 'cargo search'
#abbr -a -- cgt 'cargo test'
#abbr -a -- cgu 'cargo uninstall'
#abbr -a -- cgug 'cargo upgrade'
#
#abbr -a -- h "history"
#abbr -a -- hg "history | grep "

# bang-bang fish plugin... installed by omf
#bind ! __history_previous_command
#bind '$' __history_previous_command_arguments

#bind -k \e. previous
#bind -k \cj accept-autosuggestion

#abbr -a -- bman batman

#https://github.com/gazorby/fifc
set -Ux fifc_editor $EDITOR

# INFO: Zoxide a smart cd to directories (needs rust)
zoxide init --cmd cd fish | source
