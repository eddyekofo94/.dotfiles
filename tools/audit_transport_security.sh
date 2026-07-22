#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

ssl_verify=$(git config --file git/.gitconfig --type=bool --get http.sslVerify || true)
if [ "$ssl_verify" != true ]; then
    echo 'transport security audit: git http.sslVerify must be true' >&2
    exit 1
fi

active_files='install_all.zsh
zsh/.zprofile
homebrew/setup/install/install
fish/functions/init_fisher.fish
fisher/deps.fish
rust/setup/setup
tools/fetch_verified.sh
tools/fetch_fisher_verified.sh
tools/install_homebrew_verified.sh
tools/ensure_rustup.sh'

findings=$(
    printf '%s\n' "$active_files" |
        xargs rg -n -e 'curl[^#]*\|[[:space:]]*(/bin/)?(ba|z|fi)?sh' \
            -e 'curl[^#]*\|[[:space:]]*(builtin[[:space:]]+)?source' \
            -e 'wget[^#]*\|[[:space:]]*(/bin/)?(ba|z|fi)?sh' \
            -e 'wget[^#]*\|[[:space:]]*(builtin[[:space:]]+)?source' \
            -e '(/HEAD/|/(main|master)/).*(install\.sh|fisher\.fish)' \
            -e 'https://sh\.rustup\.rs' || true
)
if [ -n "$findings" ]; then
    echo 'transport security audit: active mutable or pipe-to-execute bootstrap found' >&2
    printf '%s\n' "$findings" >&2
    exit 1
fi

require_callsite() {
    file=$1
    pattern=$2
    description=$3
    if ! rg -q -- "$pattern" "$file"; then
        echo "transport security audit: $description is not using its verified helper" >&2
        exit 1
    fi
}

require_callsite install_all.zsh \
    '^[[:space:]]*/bin/sh "\$DOTFILES_DIR/tools/install_homebrew_verified\.sh"$' \
    'install_all Homebrew bootstrap'
require_callsite install_all.zsh \
    '^[[:space:]]*rustup_bin_dir=\$\(/bin/sh "\$DOTFILES_DIR/tools/ensure_rustup\.sh"\) \|\| return$' \
    'install_all Rust bootstrap'
require_callsite zsh/.zprofile \
    '^[[:space:]]*/bin/sh "\$DOTFILES_DIR/tools/install_homebrew_verified\.sh"$' \
    'live Zsh Homebrew bootstrap'
require_callsite homebrew/setup/install/install \
    '^[[:space:]]*/bin/sh "\$repo_dir/tools/install_homebrew_verified\.sh"$' \
    'Homebrew setup entry point'
require_callsite fish/functions/init_fisher.fish \
    '^[[:space:]]*if not /bin/sh "\$repo_dir/tools/fetch_fisher_verified\.sh" >\$fisher_installer$' \
    'live Fisher bootstrap'
require_callsite fisher/deps.fish \
    '^[[:space:]]*if not /bin/sh "\$repo_dir/tools/fetch_fisher_verified\.sh" >\$fisher_installer$' \
    'Fisher dependency bootstrap'
require_callsite rust/setup/setup \
    '^[[:space:]]*/bin/sh "\$repo_dir/tools/ensure_rustup\.sh"$' \
    'Rust setup entry point'

rg -q '^homebrew_commit=[0-9a-f]{40}$' tools/install_homebrew_verified.sh
rg -q '^homebrew_sha256=[0-9a-f]{64}$' tools/install_homebrew_verified.sh
rg -q '^homebrew_url="https://raw\.githubusercontent\.com/Homebrew/install/\$homebrew_commit/install\.sh"$' \
    tools/install_homebrew_verified.sh
rg -q '^fisher_commit=[0-9a-f]{40}$' tools/fetch_fisher_verified.sh
rg -q '^fisher_sha256=[0-9a-f]{64}$' tools/fetch_fisher_verified.sh
rg -q '^fisher_url="https://raw\.githubusercontent\.com/jorgebucaran/fisher/\$fisher_commit/functions/fisher\.fish"$' \
    tools/fetch_fisher_verified.sh
rg -q "curl --proto '=https' --tlsv1\.2 --fail" tools/fetch_verified.sh
rg -q "brew install rustup" tools/ensure_rustup.sh

if rg -n -v '^[^@[:space:]]+@[0-9a-f]{40}$' fish/fish_plugins; then
    echo 'transport security audit: every Fisher plugin must pin an exact commit' >&2
    exit 1
fi
if rg -n 'fisher install' fish/functions/init_fisher.fish fisher/deps.fish |
    rg -v 'fisher install [^@[:space:]]+@[0-9a-f]{40}([[:space:]]|$)'; then
    echo 'transport security audit: Fisher install must pin an exact commit' >&2
    exit 1
fi

/bin/sh tools/tests/transport_security_test.sh

for file in install_all.zsh zsh/.zprofile; do
    zsh -n "$file"
done
for file in \
    homebrew/setup/install/install \
    rust/setup/setup \
    tools/fetch_verified.sh \
    tools/fetch_fisher_verified.sh \
    tools/install_homebrew_verified.sh \
    tools/ensure_rustup.sh \
    tools/tests/transport_security_test.sh; do
    sh -n "$file"
done
for file in fish/functions/init_fisher.fish fisher/deps.fish; do
    fish --no-execute "$file"
done

git diff --check -- \
    .working/ACTIVE_GOAL.md \
    .working/UNIFIED_INTAKE.md \
    .working/interviews/transport-security-baseline/decisions.md \
    git/.gitconfig \
    install_all.zsh \
    zsh/.zprofile \
    homebrew/setup/install/install \
    fish/functions/init_fisher.fish \
    fish/fish_plugins \
    fisher/deps.fish \
    rust/setup/setup \
    tools

echo 'transport security audit: PASS'
