DOTFILES_DIR="$HOME/.dotfiles"
if [[ ! -d $DOTFILES_DIR ]]; then
    echo "Creating a new dotfiles $DOTFILES_DIR"
    git clone https://github.com/eddyekofo94/.dotfiles.git $DOTFILES_DIR
    ln -s /home/$(whoami)/.dotfiles/zsh/.zshenv /home/$(whoami)/.zshenv
    ln -s /home/$(whoami)/.dotfiles/zsh/.zshrc /home/$(whoami)/.zshrc
    ln -s /home/$(whoami)/.dotfiles/zsh/.zprofile /home/$(whoami)/.zprofile
fi

# Identify the path of the 'brew' command if cannot already be found
if (( ! $+commands[brew] )); then
    local DEFAULT_BREW_PATHS=("/opt/homebrew/bin/brew" \
            "/usr/local/bin/brew" \
            "/home/linuxbrew/.linuxbrew/bin/brew" \
        "$HOME/.linuxbrew/bin/brew")
    for bp in "${DEFAULT_BREW_PATHS[@]}"; do
        if [ -x "$bp" ]; then
            local BREW_PATH="$bp"
            break
        fi
    done

    # If a path was found, setup the shell environment
    if [[ ! -z "$BREW_PATH" ]]; then
        eval "$("$BREW_PATH" shellenv)"

    else
        echo "You may be asked for your sudo password to install Homebrew:"
        sudo -v
        yes '' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi
fi

if (( $+commands[brew] )); then
    # If the 'HOMEBREW_PREFIX' environment variable is not populated then
    # request the prefix from 'brew' and populate
    if [[ -z "$HOMEBREW_PREFIX" ]]; then
        export HOMEBREW_PREFIX="$(brew --prefix)"
    fi

    # Add Homebrew 'site-functions directory to the FPATH
    local HOMEBREW_SITE_FUNCTIONS="$HOMEBREW_PREFIX/share/zsh/site-functions"

    if [[ -d "$HOMEBREW_SITE_FUNCTIONS" ]]; then
        typeset -TUx FPATH fpath
        fpath=("$HOMEBREW_SITE_FUNCTIONS" $fpath)

        autoload -Uz compinit
        compinit
    fi
fi

. "$HOME/.cargo/env"

if (( ! $+commands[cargo] )); then
    echo "Cargo needs to be installed: "
    curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- --no-modify-path

    DOTFILES_DIR_RUST = "$DOTFILES_DIR/rust/"
    if [[ -d $DOTFILES_DIR_RUST ]]; then
        source "$HOME/.cargo/env"
        sudo yum update # This is for just incase there are packages which need to be updated
        cd $DOTFILES_DIR_RUST && xargs < install.sh -n 1 cargo install
    fi
fi

if [[ ! -f $XDG_CONFIG_HOME/starship.toml ]]; then
    ln -s /home/$(whoami)/.dotfiles/starship/starship.toml /home/$(whoami)/.config/starship.toml
fi

# Download Znap, if it's not there yet.
[[ -r ~/.config/zsh/znap/znap.zsh ]] ||
git clone --depth 1 -- \
    https://github.com/marlonrichert/zsh-snap.git ~/.config/zsh/znap


if (( $+commands[bat] )); then
    BAT_THEMES_DIR=$(bat --config-dir)/themes
    if [[ ! -d $BAT_THEMES_DIR ]]; then
        echo "Making a new bat dir: $BAT_THEMES_DIR"
        mkdir -p $BAT_THEMES_DIR

        cd $BAT_THEMES_DIR
        #cp my own bat theme
        cp $HOME/.dotfiles/bat/Catppuccin-mocha.tmTheme $BAT_THEMES_DIR

        # Update the binary cache
        bat cache --build
        cd -
    fi

fi

if [[ ! -d $XDG_CONFIG_HOME/fsh ]]; then
    ln -s /home/$(whoami)/.dotfiles/fsh /home/$(whoami)/.config/fsh
fi
