source ~/.dotfiles/zsh/history.zsh

DOTFILES_DIR="$HOME/.dotfiles"
if [[ ! -d $DOTFILES_DIR ]]; then
    echo "Creating a new dotfiles $DOTFILES_DIR"
    gh repo clone eddyekofo94/.dotfiles $DOTFILES_DIR
    ln -s /home/$(whoami)/.dotfiles/zsh/.zshenv /home/$(whoami)/.zshenv
    ln -s /home/$(whoami)/.dotfiles/zsh/.zshrc /home/$(whoami)/.zshrc
    ln -s /home/$(whoami)/.dotfiles/zsh/.zprofile /home/$(whoami)/.zprofile
fi

# STARSHIP_CONFIG_DIR="$XDG_CONFIG_HOME/starship"
# if [[ ! -d $STARSHIP_CONFIG_DIR ]]; then
#     ln -s /home/$(whoami)/.dotfiles/starship /home/$(whoami)/.config/starship
# fi

if [[ ! -f $XDG_CONFIG_HOME/starship.toml ]]; then
    ln -s /home/$(whoami)/.dotfiles/starship/starship.toml /home/$(whoami)/.config/starship.toml
fi

# Download Znap, if it's not there yet.
[[ -r ~/.config/zsh/znap/znap.zsh ]] ||
git clone --depth 1 -- \
    https://github.com/marlonrichert/zsh-snap.git ~/.config/zsh/znap
source ~/.config/zsh/znap/znap.zsh # Start Znap

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

if [[ ! -d $XDG_CONFIG_HOME/fsh ]]; then
    ln -s /home/$(whoami)/.dotfiles/fsh /home/$(whoami)/.config/fsh
fi
