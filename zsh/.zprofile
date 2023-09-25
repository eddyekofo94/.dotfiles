
source ~/.dotfiles/zsh/history.zsh
source ~/.dotfiles/terminal/base_directories

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

DOTFILES_DIR="$HOME/.dotfiles"
if [[ ! -d $DOTFILES_DIR ]]; then
    echo "Creating a new dotfiles $DOTFILES_DIR"
    gh repo clone eddyekofo94/.dotfiles $DOTFILES_DIR
    ln -s /home/$(whoami)/.dotfiles/zsh/.zshenv /home/$(whoami)/.zshenv
    ln -s /home/$(whoami)/.dotfiles/zsh/.zshrc /home/$(whoami)/.zshrc
    ln -s /home/$(whoami)/.dotfiles/zsh/.zprofile /home/$(whoami)/.zprofile
fi

STARSHIP_CONFIG_DIR="$XDG_CONFIG_HOME/starship"
if [[ ! -d $STARSHIP_CONFIG_DIR ]]; then
    ln -s /home/$(whoami)/.dotfiles/starship /home/$(whoami)/.config/starship
fi

# start a prompt called starship
eval "$(starship init zsh)"

# Zoxide
eval "$(zoxide init zsh)"

# vivid
export LS_COLORS="$(vivid generate $HOME/.dotfiles/vivid/catppuccin-mocha.yml)"

# Bat a modern cat with all the goodies
export BAT_CONFIG_PATH=$HOME/.dotfiles/bat/lib/login/bat.conf

# Options to fzf command
# LS colors using Vivid installed using Cargo
export LS_COLORS="$(vivid generate $HOME/.dotfiles/vivid/catppuccin-mocha.yml)"

# FZF
export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --no-require-git --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# INFO: uselfull link for the layout etc.....
# https://thevaluable.dev/practical-guide-fzf-example/
export FZF_DEFAULT_OPTS=" \
  --height=70% --border --margin=1 --padding=1 \
  --layout=reverse \
  --prompt='$> ' \
  --pointer='→' \
  --info=hidden \
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=border:#6c7086 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

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
