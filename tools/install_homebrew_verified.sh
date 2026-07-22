#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
homebrew_commit=99e13e96cbbdc1ac1ac09c0a40b450bf219ef3aa
homebrew_sha256=99287f194a8b3c9e6b0203a11a5fa54518be57209343e6bb954dec4635796d9d
homebrew_url="https://raw.githubusercontent.com/Homebrew/install/$homebrew_commit/install.sh"

install_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-homebrew.XXXXXX")
installer=$install_dir/install.sh
trap 'rm -rf -- "$install_dir"' EXIT HUP INT TERM

/bin/sh "$repo_dir/tools/fetch_verified.sh" "$homebrew_url" "$homebrew_sha256" > "$installer"
NONINTERACTIVE=1 /bin/bash "$installer"
