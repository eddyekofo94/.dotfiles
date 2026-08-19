source ~/.dotfiles/terminal/base_directories

DOTFILES_DIR=${DOTFILES_DIR:-$HOME/.dotfiles}

install_brew_packages(){
    cd ~/.dotfiles/homebrew && brew bundle install
}

install_cargo_crates(){
    cd ~/.dotfiles/rust && xargs < install.sh -n 1 cargo install
}

# Homebrew setup linux
ensure_homebrew_installed() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "You may be asked for your sudo password to install Homebrew:"
        sudo -v
        /bin/sh "$DOTFILES_DIR/tools/install_homebrew_verified.sh"

        # TODO: 2023-09-23 - Try to export a different path on MacOs
        [[ -r ~/.zshenv ]] ||
        touch ~/.zshenv
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zshenv

        # Install some of the packages I use
        install_brew_packages
    fi
}

ensure_homebrew_installed

# Cargo/rust set up
ensure_cargo_installed(){
    if ! command -v cargo >/dev/null 2>&1; then
        echo "Cargo needs to be installed: "
	local rustup_bin_dir
	rustup_bin_dir=$(/bin/sh "$DOTFILES_DIR/tools/ensure_rustup.sh") || return
	export PATH="$rustup_bin_dir:$PATH"
    fi
    cd "$DOTFILES_DIR/rust"
    xargs < install.sh -n 1 cargo install
}

ensure_cargo_installed

# macOS default applications
ensure_default_apps_set(){
    [[ "$(uname -s)" == Darwin ]] || return 0
    /bin/sh "$DOTFILES_DIR/tools/set_macos_default_apps.sh"
}

ensure_default_apps_set
