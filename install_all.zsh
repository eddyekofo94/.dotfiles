source ~/.dotfiles/terminal/base_directories

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
        yes '' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

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
 	# /bin/bash -c -i "$(curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh)"
	curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- --no-modify-path
    fi
    cd ~/.dotfiles/rust
    xargs < install.sh -n 1 cargo install
}

ensure_cargo_installed


