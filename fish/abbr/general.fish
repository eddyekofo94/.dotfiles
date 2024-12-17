#!/usr/bin/env fish
# -------------------------------------------------------------------
# make some commands (potentially) less destructive
# -------------------------------------------------------------------


# Play safe!
abbr -a -- rm 'rm -i'
abbr -a -- mv 'mv -i'
abbr -a -- cp 'cp -i'
abbr -a -- rmdf 'rm -irf '

function make_file_executable
    chmod +x "$1" || exit;
    ls -al
end

abbr -a -- chmox 'make_file_executable'

## super user alias
abbr -a -- _ 'sudo '

#  INFO: 2024-12-17 - Use the function instead
#abbr -a -- mkdir 'mkdir -p'

abbr -a -- md 'mkdir -p'
abbr -a -- rd rmdir

# Typing errors...
abbr -a -- cd.. 'cd ..'

# List only directories and symbolic
# links that point to directories
abbr -a -- lsd 'ls -ld *(-/DN)'
abbr -a -- lh 'ls -a | egrep "^\."'

# Directory Aliases
# #####################################

# Different sets of LS aliases because Gnu LS and macOS LS use different
# exa (which I have used for a longtime is currently not maintained, therefore eza is now used)

if command -q eza --icons &>/dev/null
    # abbr -a -- ls 'eza --git --icons auto --sort=modified' # system: List filenames on one line
    abbr -a -- ls 'eza --git --group-directories-first --icons --sort=modified'
    # abbr -a -- l 'eza --git --icons -lF'                          # system: List filenames with long format
    abbr -a -- ll "eza --git --all --group-directories-first --no-filesize --no-user --long --icons --header --binary --group --sort=modified"
    abbr -a -- l 'eza --git --group-directories-first --icons --sort=modified --long --all --no-filesize --no-time --no-user --no-permissions'
    abbr -a -- lll "eza -1F --git --icons auto"                        # system: List files with one line per file
    abbr -a -- llm 'll --sort=modified'                                # system: List files by last modified date
    abbr -a -- la 'eza -lbhHigUmuSa --color-scale --git --icons auto'  # system: List files with attributes
    abbr -a -- lx 'eza -lbhHigUmuSa@ --color-scale --git --icons auto' # system: List files with extended attributes
    abbr -a -- lt 'eza --tree --level=2 --icons auto'                               # system: List files in a tree view
    abbr -a -- llt 'eza -lahF --tree --level=2'                        # system: List files in a tree view with long format
    abbr -a -- ltt 'eza -lahF --icons auto | grep "(date +"%d %b")"'               # system: List files modified today
    abbr -a -- tree 'eza --tree $eza_params'
else if command -v eza &>/dev/null
    abbr -a -- ls 'eza --group-directories-first --icons'
    abbr -a -- ls 'eza --git --icons auto'
    abbr -a -- ll 'eza --git -lF --icons auto'
    abbr -a -- l 'eza -lahF --git --icons auto'
    abbr -a -- lll "eza -1F --git --icons auto"
    abbr -a -- llm 'll --sort=modified --icons auto'
    abbr -a -- la 'eza -lbhHigUmuSa --color-scale --git'
    abbr -a -- lx 'eza -lbhHigUmuSa@ --color-scale --git'
    abbr -a -- lt 'eza --tree --level=2'
    abbr -a -- llt 'eza -lahF --tree --level=2'
    abbr -a -- ltt 'eza -lahF | grep "(date +"%d %b")"'
    abbr -a -- tree 'eza --tree $eza_params'
else if command -v colorls &>/dev/null
    abbr -a -- ll "colorls -1A --git-status"
    abbr -a -- ls "colorls -A"
    abbr -a -- ltt 'colorls -A | grep "(date +"%d %b")"'
#  FIX: 2024-12-17 - Make this fish complait
#else if [(command -v ls) =~ gnubin || $OSTYPE =~ linux] 
#    abbr -a -- ls "ls --color=auto"
#    abbr -a -- l "ls -l --color=auto"
#    abbr -a -- ll 'ls -FlAhpv --color=auto'
#    abbr -a -- ltt 'ls -FlAhpv| grep "(date +"%d %b")"'
else
    abbr -a -- ls "ls -G"
    abbr -a -- ll 'ls -FGlAhpv'
    abbr -a -- ltt 'ls -FlAhpv| grep "(date +"%d %b")"'
end

abbr -a -- -g .. "cd .."
abbr -a -- -g ... "cd ../.."
abbr -a -- -g .... '../../..'
abbr -a -- -g ..... '../../../..'

abbr -a -- zconf "$EDITOR $ZSH_DOT_DIR/.zshrc"
abbr -a -- nconf "$EDITOR $NVIM_DIR"
abbr -a -- reload "source $ZDOTDIR/.zshenv && source $ZDOTDIR/.zprofile && source $ZDOTDIR/.zshrc"
# abbr -a -- reload "(exec zsh)"

function rm_cores
    if [[  "$PWD" != "$HOME" ]]
        if commands -q fd
            echo "(which fd) is found"
            fd -I "core.[0-9][0-9][0-9][0-9]"
            rm (fd -I "core.[0-9][0-9][0-9][0-9]")
        else
            echo "using (which find)"
            find . -name 'core.[0-9][0-9][0-9][0-9]'
            rm -i (find . -name 'core.[0-9][0-9][0-9][0-9]')
        end
    else
        echo "You cannot do this in the $HOME direction"
    end
end

abbr -a -- rmcore "rm_cores"

abbr -a -- cl clear
abbr -a -- lg lazygit
abbr -a -- lzd lazydocker
abbr -a -- vim nvim
abbr -a -- grep "grep --color=auto"
abbr -a -- nvmc "NVIM_APPNAME=nvim.macro nvim"
abbr -a -- chad "NVIM_APPNAME=nvim.chad nvim"
abbr -a -- bak "NVIM_APPNAME=nvim.bak nvim"
abbr -a -- vi vim
abbr -a -- bgr batgrep
abbr -a -- cg cargo
abbr -a -- cgc 'cargo clean'
abbr -a -- cgi 'cargo install'
abbr -a -- cgn 'cargo new'
abbr -a -- cgs 'cargo search'
abbr -a -- cgt 'cargo test'
abbr -a -- cgu 'cargo uninstall'
abbr -a -- cgug 'cargo upgrade'
abbr -a -- h history

if command -q rg
    abbr -a -- alrg "alias | rg "
    abbr -a -- hg 'history | rg '
else
    abbr -a -- alrg "alias | grep "
    abbr -a -- hg 'history | grep '
end

abbr -a -- -g -- -h '-h 2>&1 | bat --language=help --style=plain'
abbr -a -- -g -- --help '--help 2>&1 | bat --language=help --style=plain'

# bang-bang fish plugin... installed by omf
bind ! __history_previous_command
bind '$' __history_previous_command_arguments

abbr -a -- zj 'zellij'
abbr -a -- zja 'zellij attach'
abbr -a -- zje 'zellij edit'
abbr -a -- zjls 'zellij list-sessions'
abbr -a -- zjk 'zellij kill-session'
abbr -a -- zjka 'zellij kill-all-sessions'

function mkdir -d "Create a directory and set CWD"
    command mkdir $argv
    if test $status = 0
        switch $argv[(count $argv)]
            case '-*'

            case '*'
                cd $argv[(count $argv)]
                return
        end
    end
end
