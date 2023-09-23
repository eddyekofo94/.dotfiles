# xargs < install.sh -n 1 cargo install
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
sudo yum update # This is for just incase there are packages which need to be updated
source "$HOME/.cargo/env"
bat
cargo-generate
cargo-update
exa
fd-find
git-delta
lsd
ripgrep
vivid
zoxide
